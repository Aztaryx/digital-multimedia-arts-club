/* ═══════════════════════════════════════════════════════════════════
   dmac-site-polish-schema.sql
   Schema pieces for the site-polish pass:

   1. members.year_joined  — tracked stat, defaults to 2026 for everyone.
   2. members.banner_color — member-chosen banner colour (used when no
      banner image is set). Hex string like '#f97316'.
   3. member_update_profile() gains p_banner_color (7-arg version; the
      old 6-arg one is dropped explicitly to avoid overload ambiguity).
   4. forum_threads_feed / forum_posts_feed now expose the author's
      site_role + club_role so the client can colour names (admins red,
      mods purple, advisers orange).
   5. announcements — global announcements / maintenance notices,
      readable by everyone, written/deleted by admins only via RPCs.

   RUN THIS AFTER dmac-profile-sync-fix.sql. Safe to re-run.
   ═══════════════════════════════════════════════════════════════════ */

-- ── 1 + 2. PROFILE COLUMNS ──────────────────────────────────────────
alter table public.members add column if not exists year_joined  int  not null default 2026;
alter table public.members add column if not exists banner_color text;

grant select (year_joined, banner_color) on public.members to anon, authenticated;

-- ── 3. EXTEND member_update_profile() ──────────────────────────────
drop function if exists public.member_update_profile(uuid, text, text, text, text, jsonb);

create or replace function public.member_update_profile(
  p_session_token uuid  default null,
  p_nickname      text  default null,
  p_bio           text  default null,
  p_avatar_url    text  default null,
  p_banner_url    text  default null,
  p_social_links  jsonb default null,
  p_banner_color  text  default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := public._resolve_member_id(p_session_token);
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  update public.members
     set nickname     = coalesce(p_nickname, nickname),
         bio          = coalesce(p_bio, bio),
         avatar_url   = coalesce(p_avatar_url, avatar_url),
         banner_url   = coalesce(p_banner_url, banner_url),
         social_links = coalesce(p_social_links, social_links),
         banner_color = coalesce(p_banner_color, banner_color)
   where id = v_me;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.member_update_profile(uuid, text, text, text, text, jsonb, text) to anon, authenticated, service_role;

-- ── 4. FORUM FEEDS WITH AUTHOR ROLES ────────────────────────────────
-- These views must be dropped first: the new columns land in the
-- middle of the column list, and `create or replace view` refuses to
-- rename/reorder existing view columns (error 42P16).
drop view if exists public.forum_threads_feed;
create view public.forum_threads_feed as
select
  t.id,
  t.title,
  t.pinned,
  t.created_at,
  m.slug         as author_slug,
  m.display_name as author_name,
  m.site_role    as author_site_role,
  m.club_role    as author_club_role,
  (select count(*) from public.forum_posts p where p.thread_id = t.id)          as reply_count,
  (select max(p.created_at) from public.forum_posts p where p.thread_id = t.id) as last_activity
from public.forum_threads t
join public.members m on m.id = t.author_id;

grant select on public.forum_threads_feed to anon, authenticated;

drop view if exists public.forum_posts_feed;
create view public.forum_posts_feed as
select
  p.id,
  p.thread_id,
  p.body,
  p.created_at,
  m.slug         as author_slug,
  m.display_name as author_name,
  m.site_role    as author_site_role,
  m.club_role    as author_club_role
from public.forum_posts p
join public.members m on m.id = p.author_id;

grant select on public.forum_posts_feed to anon, authenticated;

-- ── 5. ANNOUNCEMENTS ────────────────────────────────────────────────
create table if not exists public.announcements (
  id         uuid primary key default gen_random_uuid(),
  title      text not null check (char_length(title) between 1 and 120),
  body       text not null check (char_length(body) between 1 and 2000),
  kind       text not null default 'announcement' check (kind in ('announcement', 'maintenance')),
  created_at timestamptz not null default now(),
  author_id  uuid references public.members(id) on delete set null
);

alter table public.announcements enable row level security;

drop policy if exists "announcements are publicly readable" on public.announcements;
create policy "announcements are publicly readable" on public.announcements
  for select using (true);

grant select on public.announcements to anon, authenticated;

-- Writing only ever happens through the admin-checked RPCs below —
-- no insert/update/delete grants on the table itself.
create or replace function public.create_announcement(
  p_session_token uuid,
  p_title         text,
  p_body          text,
  p_kind          text default 'announcement'
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

  insert into public.announcements (title, body, kind, author_id)
  values (trim(p_title), trim(p_body), coalesce(p_kind, 'announcement'), v_me);

  return json_build_object('success', true);
end;
$$;

grant execute on function public.create_announcement(uuid, text, text, text) to anon, authenticated;

create or replace function public.delete_announcement(
  p_session_token uuid,
  p_announcement_id uuid
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

  delete from public.announcements where id = p_announcement_id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.delete_announcement(uuid, uuid) to anon, authenticated;

-- ── ONE-TIME RESET (optional) ───────────────────────────────────────
-- "Reset all the names": clears every self-chosen nickname so cards
-- fall back to the official roster display_name. Uncomment and run
-- once if wanted — deliberately not run automatically.
-- update public.members set nickname = null;

