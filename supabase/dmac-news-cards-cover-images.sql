/* ═══════════════════════════════════════════════════════════════════
   dmac-news-cards-cover-images.sql
   ═══════════════════════════════════════════════════════════════════
   The new home-page news cards (HomeView.vue) and ArticleModal.vue
   show Title → Author → Date → Cover → Body. Author (`author_id`,
   already a FK to `members`) and Date (`created_at`) already existed
   on both `announcements` (Newsletters) and `club_announcements`
   (Announcements) — the one column genuinely missing is the cover
   image. This adds it, plus updates the two admin write RPCs to
   accept an optional cover URL.

   IDEMPOTENT — every statement below is `if not exists` / a
   `drop ... if exists` immediately followed by `create or replace`,
   so this is safe to run against a fresh database, one that's already
   had this applied, or anything in between.

   Run this AFTER schema.sql (both tables + both RPCs are defined
   there) and dmac-forum-removal-and-role-merge.sql (which also
   touches club_announcements, but only its table/select policy, not
   its RPC or announcements' RPC — no conflict either way).
   ═══════════════════════════════════════════════════════════════════ */


-- ═══════════════════════════════════════════════════════════════════
-- 1. cover_url — one new nullable column on each table
-- ═══════════════════════════════════════════════════════════════════
alter table public.announcements
  add column if not exists cover_url text;

alter table public.club_announcements
  add column if not exists cover_url text;


-- ═══════════════════════════════════════════════════════════════════
-- 2. WRITE RPCs — add an optional p_cover_url param
-- ═══════════════════════════════════════════════════════════════════
-- Both functions are dropped by their OLD signature first: adding a
-- new parameter changes a function's identity in Postgres, so a bare
-- `create or replace` here would create a second overload sitting
-- alongside the old one instead of replacing it — and since
-- supabase-js always calls RPCs with named arguments, having both the
-- 4-arg and 5-arg (or 3-arg/4-arg) versions of the same name around
-- at once is exactly the kind of ambiguity Postgres will refuse to
-- resolve ("function is not unique"). Dropping the old signature
-- first avoids that outright. Existing callers that don't pass
-- p_cover_url (AdminView.vue's two "New entry" forms, as they stand
-- today) keep working unchanged — it defaults to null.

drop function if exists public.create_announcement(uuid, text, text, text);

create or replace function public.create_announcement(
  p_session_token uuid,
  p_title         text,
  p_body          text,
  p_kind          text default 'announcement',
  p_cover_url     text default null
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

  insert into public.announcements (title, body, kind, author_id, cover_url)
  values (
    trim(p_title),
    trim(p_body),
    coalesce(p_kind, 'announcement'),
    v_me,
    nullif(trim(coalesce(p_cover_url, '')), '')
  );

  return json_build_object('success', true);
end;
$$;

grant execute on function public.create_announcement(uuid, text, text, text, text) to anon, authenticated;


drop function if exists public.create_club_announcement(uuid, text, text);

create or replace function public.create_club_announcement(
  p_session_token uuid,
  p_title         text,
  p_body          text,
  p_cover_url     text default null
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

  insert into public.club_announcements (title, body, author_id, cover_url)
  values (
    trim(p_title),
    trim(p_body),
    v_me,
    nullif(trim(coalesce(p_cover_url, '')), '')
  );

  return json_build_object('success', true);
end;
$$;

grant execute on function public.create_club_announcement(uuid, text, text, text) to anon, authenticated;


/* ── NOT INCLUDED HERE ──────────────────────────────────────────────
   AdminView.vue's "New entry" forms (Newsletters tab) and the club
   announcements authoring flow don't have a cover-image field/upload
   yet — this migration only adds the column and RPC support for it.
   Wiring an actual upload (same upload-profile-image Edge Function
   pattern member-profile.js already uses, or a plain URL text field)
   into those forms is a separate, small frontend task once you want
   admins to actually attach covers. */
