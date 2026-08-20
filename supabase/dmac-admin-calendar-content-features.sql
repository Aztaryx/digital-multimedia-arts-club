/* ═══════════════════════════════════════════════════════════════════
   dmac-admin-calendar-content-features.sql
   ═══════════════════════════════════════════════════════════════════
   Admin Panel round: Calendar tags/color + full CRUD, and Newsletter/
   Announcement image upload + author/date override fields.

   IDEMPOTENT — every statement is `if not exists` / `create or
   replace` / a guarded `do $$ ... $$` block, same convention as
   dmac-forum-removal-and-role-merge.sql and
   dmac-bits-threads-schema.sql. Safe to run against a fresh database
   or one that's already had this applied.

   Run this AFTER schema.sql, dmac-forum-removal-and-role-merge.sql
   (school_events + create_school_event live there), and
   dmac-news-cards-cover-images.sql (cover_url on announcements /
   club_announcements lives there).
   ═══════════════════════════════════════════════════════════════════ */


-- ═══════════════════════════════════════════════════════════════════
-- 1. CALENDAR — tags + background color on school_events
-- ═══════════════════════════════════════════════════════════════════
alter table public.school_events
  add column if not exists tags  text[] not null default '{}',
  add column if not exists color text;

-- Simple sanity cap so a stray paste can't jam an enormous array into
-- a single row — plenty of headroom for the multi-select UI's actual
-- use ("assign multiple tags ... at once").
alter table public.school_events
  drop constraint if exists school_events_tags_cap;
alter table public.school_events
  add constraint school_events_tags_cap check (array_length(tags, 1) is null or array_length(tags, 1) <= 12);

alter table public.school_events
  drop constraint if exists school_events_color_shape;
alter table public.school_events
  add constraint school_events_color_shape check (color is null or color ~* '^#[0-9a-f]{3}([0-9a-f]{3})?$');


/* ── create_school_event — extended with p_tags / p_color ──────────
   Dropped by its old 5-arg signature first (same reasoning
   dmac-news-cards-cover-images.sql documents for why a bare
   `create or replace` isn't enough when the parameter list changes —
   supabase-js calls RPCs with named args, so leaving both the old and
   new signature registered is ambiguous, not additive). Existing
   callers that don't pass p_tags/p_color keep working — both default
   to empty/null. */
drop function if exists public.create_school_event(uuid, text, date, text, text);

create or replace function public.create_school_event(
  p_session_token uuid,
  p_title         text,
  p_event_date    date,
  p_description   text default null,
  p_location      text default null,
  p_tags          text[] default '{}',
  p_color         text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me   uuid := public._resolve_member_id(p_session_token);
  v_role text;
  v_id   uuid;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;
  select site_role into v_role from public.members where id = v_me;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;
  if p_event_date is null then
    return json_build_object('success', false, 'message', 'A date is required.');
  end if;
  if p_color is not null and p_color !~* '^#[0-9a-f]{3}([0-9a-f]{3})?$' then
    return json_build_object('success', false, 'message', 'Color must be a hex code, like #38bdf8.');
  end if;

  insert into public.school_events (title, description, event_date, location, created_by, tags, color)
  values (
    trim(p_title),
    nullif(trim(coalesce(p_description, '')), ''),
    p_event_date,
    nullif(trim(coalesce(p_location, '')), ''),
    v_me,
    coalesce(p_tags, '{}'),
    nullif(trim(coalesce(p_color, '')), '')
  )
  returning id into v_id;

  return json_build_object('success', true, 'event_id', v_id);
end;
$$;

grant execute on function public.create_school_event(uuid, text, date, text, text, text[], text) to anon, authenticated;


/* ── UPDATE — same fields, keyed by id. Admin-only, same gate. ───── */
create or replace function public.admin_update_school_event(
  p_session_token uuid,
  p_event_id      uuid,
  p_title         text,
  p_event_date    date,
  p_description   text default null,
  p_location      text default null,
  p_tags          text[] default '{}',
  p_color         text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me   uuid := public._resolve_member_id(p_session_token);
  v_role text;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;
  select site_role into v_role from public.members where id = v_me;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;
  if p_event_date is null then
    return json_build_object('success', false, 'message', 'A date is required.');
  end if;
  if p_color is not null and p_color !~* '^#[0-9a-f]{3}([0-9a-f]{3})?$' then
    return json_build_object('success', false, 'message', 'Color must be a hex code, like #38bdf8.');
  end if;
  if not exists (select 1 from public.school_events where id = p_event_id) then
    return json_build_object('success', false, 'message', 'That event no longer exists.');
  end if;

  update public.school_events
     set title       = trim(p_title),
         description = nullif(trim(coalesce(p_description, '')), ''),
         event_date  = p_event_date,
         location    = nullif(trim(coalesce(p_location, '')), ''),
         tags        = coalesce(p_tags, '{}'),
         color       = nullif(trim(coalesce(p_color, '')), '')
   where id = p_event_id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.admin_update_school_event(uuid, uuid, text, date, text, text, text[], text) to anon, authenticated;


create or replace function public.admin_delete_school_event(
  p_session_token uuid,
  p_event_id      uuid
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me   uuid := public._resolve_member_id(p_session_token);
  v_role text;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;
  select site_role into v_role from public.members where id = v_me;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  delete from public.school_events where id = p_event_id;
  return json_build_object('success', true);
end;
$$;

grant execute on function public.admin_delete_school_event(uuid, uuid) to anon, authenticated;


/* ── KNOWN TAGS — powers the multi-select's suggestion list without
   a separate lookup table. Distinct tags currently in use, plus a
   small starter set so the picker isn't empty on a brand-new site. */
create or replace function public.list_school_event_tags()
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'success', true,
    'tags', (
      select coalesce(
        json_agg(distinct t order by t),
        '["Holiday","Birthday","Suspension","Deadline","Meeting","Assembly"]'::json
      )
      from public.school_events, unnest(tags) as t
    )
  );
$$;

grant execute on function public.list_school_event_tags() to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 2. NEWSLETTERS / ANNOUNCEMENTS — author + date overrides
-- ═══════════════════════════════════════════════════════════════════
-- display_author: optional free-text byline shown instead of the
-- posting admin's own name (posting on someone else's behalf, or
-- crediting a club officer who isn't the one at the keyboard).
-- display_date: optional backdate/forward-date shown instead of
-- created_at (e.g. entering a newsletter after the fact). Both are
-- purely cosmetic — created_at/author_id stay as the real audit
-- trail, nothing here changes who can post or when RLS-wise.
alter table public.announcements
  add column if not exists display_author text,
  add column if not exists display_date    timestamptz;

alter table public.club_announcements
  add column if not exists display_author text,
  add column if not exists display_date    timestamptz;

drop function if exists public.create_announcement(uuid, text, text, text, text);

create or replace function public.create_announcement(
  p_session_token  uuid,
  p_title          text,
  p_body           text,
  p_kind           text default 'announcement',
  p_cover_url      text default null,
  p_display_author text default null,
  p_display_date   timestamptz default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me   uuid := public._resolve_member_id(p_session_token);
  v_role text;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;
  select site_role into v_role from public.members where id = v_me;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  insert into public.announcements (title, body, kind, author_id, cover_url, display_author, display_date)
  values (
    trim(p_title),
    trim(p_body),
    coalesce(p_kind, 'announcement'),
    v_me,
    nullif(trim(coalesce(p_cover_url, '')), ''),
    nullif(trim(coalesce(p_display_author, '')), ''),
    p_display_date
  );

  return json_build_object('success', true);
end;
$$;

grant execute on function public.create_announcement(uuid, text, text, text, text, text, timestamptz) to anon, authenticated;


drop function if exists public.create_club_announcement(uuid, text, text, text);

create or replace function public.create_club_announcement(
  p_session_token  uuid,
  p_title          text,
  p_body           text,
  p_cover_url      text default null,
  p_display_author text default null,
  p_display_date   timestamptz default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me   uuid := public._resolve_member_id(p_session_token);
  v_role text;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;
  select site_role into v_role from public.members where id = v_me;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  insert into public.club_announcements (title, body, author_id, cover_url, display_author, display_date)
  values (
    trim(p_title),
    trim(p_body),
    v_me,
    nullif(trim(coalesce(p_cover_url, '')), ''),
    nullif(trim(coalesce(p_display_author, '')), ''),
    p_display_date
  );

  return json_build_object('success', true);
end;
$$;

grant execute on function public.create_club_announcement(uuid, text, text, text, text, timestamptz) to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 3. STORAGE — content-images bucket, backs the new upload-content-
--    image Edge Function (admin-only uploads for newsletter/
--    announcement covers).
-- ═══════════════════════════════════════════════════════════════════
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('content-images', 'content-images', true, 8388608, array['image/png','image/jpeg','image/webp','image/gif'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;
