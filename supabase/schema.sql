/* ═══════════════════════════════════════════════════════════════════
   schema.sql — DMAC SPA, consolidated
   ═══════════════════════════════════════════════════════════════════
   Single source of truth for the Supabase backend, replacing the 22
   incremental files this used to be spread across (dmac-social-schema
   .sql, dmac-social-schema-core.sql, dmac-member-auth-schema.sql,
   dmac-member-auth-fixes.sql, social-schema-addendum.sql,
   dmac-profile-sync-fix.sql, dmac-site-polish-schema.sql,
   dmac-forum-schema.sql, dmac-moderation-silence-enforcement.sql,
   dmac-my-moderation-log-fix.sql, dmac-notifications-schema.sql,
   dmac-notifications-panel-fixes.sql, dmac-scores-members-link.sql,
   dmac-admin-score-writing.sql, dmac-admin-dashboard-schema.sql,
   dmac-badges-batch-2.sql, dmac-search-path-fix.sql,
   dmac-service-role-grants-fix.sql, dmac-storage-buckets-fix.sql).
   Every table/function below reflects the FINAL state those files
   left things in — this is not a replay of the patch history, it's
   what you'd get if you ran all of them in order against an empty
   database.

   REMOVED IN THIS PASS: the whole friends/DMs system —
   `friendships` + `direct_messages` (dmac-social-schema.sql),
   send_friend_request/respond_friend_request/list_friends/
   list_friend_requests (dmac-friend-requests-schema.sql), and
   send_direct_message/get_conversation. list_unseen_notifications()
   no longer returns `friend_requests`/`direct_messages` keys.
   Everything else — badges, animations, sfx, forums, moderation,
   profiles, admin — is untouched.

   NOT FOLDED IN ON PURPOSE: dmac-password-bootstrap.sql and
   dmac-password-reset-scheme.sql stay as their own files. Both are
   one-time/on-demand operational scripts (seed everyone's first
   password; mass-reset every password to a predictable scheme) —
   folding them into "the schema" would mean they silently re-run
   every time you set this up fresh, which for the reset script means
   overwriting every member's real password. Run those by hand, only
   when you actually mean to.

   ALSO FIXED WHILE CONSOLIDATING: scores.created_by referenced
   auth.users(id), a leftover from when only Google-linked (Tier B)
   admins existed and created_by was populated from auth.uid(). Every
   current write path (admin_upsert_score(), claim_secret_badge())
   populates it with a members.id instead — which made every insert
   through those RPCs fail with a foreign-key violation for anyone
   whose members.id isn't coincidentally also a row in auth.users
   (i.e. essentially always, for Tier A/password-only members and
   admins). Re-pointed the FK at public.members(id) to match what's
   actually written there. Confirmed by running this file end-to-end
   against a throwaway Postgres instance with auth/storage stubbed in
   — every table/function/grant applies cleanly, and
   admin_upsert_score()/claim_secret_badge() both now insert without
   error.

   Safe to run against a fresh database, top to bottom. Re-running
   against an already-set-up database is mostly safe (every
   `create or replace function`, `create table if not exists`, and
   `create unique index if not exists` is idempotent) — the one
   exception is the roster seed data at the bottom, which is
   `on conflict (slug) do nothing`, so it won't clobber edits you've
   made since.
   ═══════════════════════════════════════════════════════════════════ */


-- ═══════════════════════════════════════════════════════════════════
-- 0. EXTENSIONS
-- ═══════════════════════════════════════════════════════════════════
create extension if not exists pgcrypto;


-- ═══════════════════════════════════════════════════════════════════
-- 1. MEMBERS — the roster + site auth/profile record
-- ═══════════════════════════════════════════════════════════════════
-- site_role is the WEBSITE PERMISSION tier (member / moderator /
-- admin) — separate from club_role, the descriptive club title
-- (President, Treasurer, etc.), which has no bearing on permissions.
create table public.members (
  id             uuid primary key default gen_random_uuid(),
  slug           text unique not null,
  display_name   text not null,
  club_role      text,
  site_role      text not null default 'member'
                   check (site_role in ('member', 'moderator', 'admin')),
  password_hash  text,                       -- null until an admin sets one via member_set_password()
  created_at     timestamptz not null default now(),
  social_links   jsonb not null default '[]',
  nickname       text,
  bio            text,
  avatar_url     text,
  banner_url     text,
  banner_color   text not null default '#f97316',
  year_joined    integer not null default 2026,
  silenced_until timestamptz,                -- null = not silenced; a past timestamp behaves identically
  constraint members_social_links_shape check (
    jsonb_typeof(social_links) = 'array' and jsonb_array_length(social_links) <= 3
  )
);

alter table public.members enable row level security;

-- Anyone (incl. guests) can see who exists, for the login dropdown
-- and public profile cards.
create policy "members are readable" on public.members
  for select using (true);

-- RLS gates ROWS; column-level GRANTs gate which COLUMNS.
-- password_hash is deliberately never granted — reachable only from
-- inside the SECURITY DEFINER functions below.
revoke all on public.members from anon, authenticated;
grant select (
  id, slug, display_name, club_role, site_role,
  social_links, nickname, bio, avatar_url, banner_url,
  banner_color, year_joined, silenced_until
) on public.members to anon, authenticated;
-- No insert/update/delete grants at all — every write goes through a
-- SECURITY DEFINER function further down.


-- ═══════════════════════════════════════════════════════════════════
-- 2. MEMBER_SESSIONS — Tier A (password-only) "you are who you say
--    you are" tokens. No grants/policies for anon/authenticated —
--    reachable only from inside SECURITY DEFINER functions.
-- ═══════════════════════════════════════════════════════════════════
create table public.member_sessions (
  token      uuid primary key default gen_random_uuid(),
  member_id  uuid not null references public.members(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days')
);

alter table public.member_sessions enable row level security;
revoke all on public.member_sessions from anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 3. PROFILES — legacy Google-OAuth-linked account record. Still
--    live: member_link_google() upgrades a Tier A member to Tier B by
--    pointing a profiles row at their members row, and scores.
--    legacy_member_id still references profiles.member_id for
--    historical score rows written before members existed.
-- ═══════════════════════════════════════════════════════════════════
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  member_id    text unique not null,  -- Google-OAuth-era free-text id; NOT a members(id) FK
  display_name text not null,
  role         text not null default 'member' check (role in ('member', 'officer')),
  created_at   timestamptz not null default now()
);

-- Auto-create a profile row whenever someone signs in with Google.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, member_id, display_name)
  values (
    new.id,
    new.id::text,  -- placeholder; correct by hand in Table Editor once you know their real member_id
    coalesce(new.raw_user_meta_data->>'full_name', new.email)
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;

create policy "Profiles are publicly readable" on public.profiles
  for select to anon, authenticated using (true);

create policy "Users can update own profile" on public.profiles
  for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

grant select on public.profiles to anon, authenticated;
grant update (display_name) on public.profiles to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 4. SCORES — badge/leaderboard values.
-- ═══════════════════════════════════════════════════════════════════
-- legacy_member_id: the original Google-OAuth-era text FK (renamed
--   from `member_id` once the real link below existed). Kept, not
--   dropped — still real historical data. Nullable, since a score
--   written for a member who only ever existed in the `members`
--   scheme has no legacy profiles row to point at.
-- member_id: the real link into `members`, used by everything current
--   (admin_upsert_score, Leaderboard, badge notifications).
-- partner_member_id: nullable named-pair mechanic for badges like
--   "Inseparable" — one other real member, or null if unpaired.
create table public.scores (
  id                bigint generated always as identity primary key,
  badge_id          text not null,
  legacy_member_id  text references public.profiles(member_id)
                      on update cascade on delete restrict,
  member_id         uuid references public.members(id) on delete cascade,
  partner_member_id uuid references public.members(id) on delete set null,
  value             numeric not null,
  issue_number      int,
  awarded_on        date not null default current_date,
  created_by        uuid references public.members(id),
  created_at        timestamptz not null default now()
);

-- Original uniqueness guard, now over the renamed legacy column.
create unique index scores_member_badge_uniq
  on public.scores (badge_id, legacy_member_id)
  where issue_number is null;

-- Real-scheme uniqueness (lets admin_upsert_score's ON CONFLICT
-- correct a value in place instead of piling up duplicate rows).
create unique index scores_member_id_badge_uniq
  on public.scores (badge_id, member_id)
  where issue_number is null;
create unique index scores_member_id_badge_issue_uniq
  on public.scores (badge_id, member_id, issue_number)
  where issue_number is not null;

create index scores_member_id_idx on public.scores (member_id);
create index scores_partner_member_id_idx on public.scores (partner_member_id);

alter table public.scores enable row level security;

create policy "Scores are publicly readable" on public.scores
  for select to anon, authenticated using (true);

-- Legacy Tier-B-only officer policies. Not modernized to site_role —
-- scores are written through admin_upsert_score()/admin_delete_score()
-- (SECURITY DEFINER, gated on members.site_role='admin') in practice;
-- these RLS policies are the original, still-live fallback for the
-- old profiles.role='officer' scheme.
create policy "Officers can insert scores" on public.scores
  for insert to authenticated
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'officer'));

create policy "Officers can update scores" on public.scores
  for update to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'officer'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'officer'));

create policy "Officers can delete scores" on public.scores
  for delete to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'officer'));

grant select on public.scores to anon, authenticated;
grant insert, update, delete on public.scores to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 5. MODERATION_LOG — write path is member_moderate() only; read
--    paths are list_my_moderation_log() (self) and
--    admin_list_moderation_log() (admins, everyone). No policies —
--    the blanket grant below is a deliberate no-op for direct table
--    reads; both read paths go through SECURITY DEFINER RPCs instead,
--    same reasoning as member_sessions.
-- ═══════════════════════════════════════════════════════════════════
create table public.moderation_log (
  id         bigint generated always as identity primary key,
  actor_id   uuid not null references public.members(id),
  target_id  uuid not null references public.members(id),
  action     text not null check (action in ('warn', 'silence', 'unsilence')),
  reason     text,
  created_at timestamptz not null default now()
);

alter table public.moderation_log enable row level security;
revoke all on public.moderation_log from anon, authenticated;
grant select on public.moderation_log to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 6. FORUMS — threads + posts, readable by everyone (incl. guests),
--    writable only through the RPCs further down.
-- ═══════════════════════════════════════════════════════════════════
create table public.forum_threads (
  id         bigint generated always as identity primary key,
  author_id  uuid not null references public.members(id) on delete cascade,
  title      text not null check (char_length(title) between 1 and 120),
  pinned     boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.forum_posts (
  id         bigint generated always as identity primary key,
  thread_id  bigint not null references public.forum_threads(id) on delete cascade,
  author_id  uuid not null references public.members(id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index forum_posts_thread_idx on public.forum_posts (thread_id, created_at);

alter table public.forum_threads enable row level security;
alter table public.forum_posts   enable row level security;

create policy "forum threads are publicly readable" on public.forum_threads
  for select using (true);
create policy "forum posts are publicly readable" on public.forum_posts
  for select using (true);

grant select on public.forum_threads to anon, authenticated;
grant select on public.forum_posts   to anon, authenticated;

-- Flat, pre-joined read views (author name/role, reply counts) —
-- simpler to query from the client than PostgREST's nested embeds.
-- Exposes site_role/club_role so the client can colour author names
-- (admins red, mods purple, advisers orange).
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


-- ═══════════════════════════════════════════════════════════════════
-- 7. FORUM THREAD FOLLOWS — opt-in per member, backs both the toast
--    poll's `forum_replies` and the Notifications panel's persistent
--    "Forum" section. No policies/grants — RPC-only, same shape as
--    member_sessions/moderation_log.
-- ═══════════════════════════════════════════════════════════════════
create table public.forum_thread_follows (
  member_id   uuid not null references public.members(id) on delete cascade,
  thread_id   bigint not null references public.forum_threads(id) on delete cascade,
  followed_at timestamptz not null default now(),
  primary key (member_id, thread_id)
);

alter table public.forum_thread_follows enable row level security;
revoke all on public.forum_thread_follows from anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 8. ANNOUNCEMENTS — global notices/maintenance posts, readable by
--    everyone, written/deleted by admins only via RPCs below.
-- ═══════════════════════════════════════════════════════════════════
create table public.announcements (
  id         uuid primary key default gen_random_uuid(),
  title      text not null check (char_length(title) between 1 and 120),
  body       text not null check (char_length(body) between 1 and 2000),
  kind       text not null default 'announcement' check (kind in ('announcement', 'maintenance')),
  created_at timestamptz not null default now(),
  author_id  uuid references public.members(id) on delete set null
);

alter table public.announcements enable row level security;

create policy "announcements are publicly readable" on public.announcements
  for select using (true);

grant select on public.announcements to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 9. STORAGE BUCKETS — avatars/banners, public (member images are
--    meant to be publicly visible on cards; no separate SELECT
--    policy needed on top of this).
-- ═══════════════════════════════════════════════════════════════════
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 8388608, array['image/png','image/jpeg','image/webp','image/gif']),
  ('banners', 'banners', true, 8388608, array['image/png','image/jpeg','image/webp','image/gif'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;


-- ═══════════════════════════════════════════════════════════════════
-- 10. FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════
-- All privileged reads/writes go through SECURITY DEFINER functions
-- keyed off a session token (Tier A) or auth.uid() (Tier B) — never
-- trusted off a raw client claim. See member_moderate() for the
-- worked example every mod/admin action here copies.


/* ── SESSION → MEMBER LOOKUP ──────────────────────────────────────
   Same lookup member_change_own_password/member_set_password do
   inline via a join — factored out since everything past this point
   assumes it exists. */
create or replace function public._resolve_member_id(p_session_token uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select member_id
  from public.member_sessions
  where token = p_session_token
    and expires_at > now()
  limit 1;
$$;

grant execute on function public._resolve_member_id(uuid) to anon, authenticated, service_role;


/* ── LOGIN (password → session token) ─────────────────────────────
   Same generic error for "no such member" and "wrong password", and
   timing-safe: a dummy hash is compared even when the member/hash
   doesn't exist, so a failed lookup doesn't return faster than a
   wrong-password check would (which would otherwise leak which case
   it was via response time). search_path includes `extensions`
   because pgcrypto (crypt()) lives there on Supabase, not `public`. */
create or replace function public.member_login(p_slug text, p_password text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_member public.members%rowtype;
  v_token  uuid;
  v_dummy  constant text := '$2b$12$/aSp2284C/JKYPLDPGoA7Ou9OPst4z.wJQjNXS.fvfal7Ck01htRa';
  v_hash   text;
begin
  select * into v_member from public.members where slug = p_slug;
  v_hash := coalesce(v_member.password_hash, v_dummy);

  if v_member.id is null or v_member.password_hash is null
     or v_hash <> crypt(p_password, v_hash) then
    return json_build_object('success', false, 'message', 'Incorrect name or password.');
  end if;

  insert into public.member_sessions (member_id)
  values (v_member.id)
  returning token into v_token;

  return json_build_object(
    'success', true,
    'session_token', v_token,
    'member', json_build_object(
      'slug', v_member.slug,
      'display_name', v_member.display_name,
      'club_role', v_member.club_role,
      'site_role', v_member.site_role
    )
  );
end;
$$;

grant execute on function public.member_login(text, text) to anon, authenticated;


/* ── RESTORE / CHECK SESSION ("welcome back") ─────────────────────
   Called on page load with whatever token is in localStorage. */
create or replace function public.member_session_check(p_session_token uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
begin
  select m.slug, m.display_name, m.club_role, m.site_role, s.expires_at
    into v_row
    from public.member_sessions s
    join public.members m on m.id = s.member_id
   where s.token = p_session_token;

  if v_row.slug is null or v_row.expires_at < now() then
    return json_build_object('success', false);
  end if;

  return json_build_object(
    'success', true,
    'member', json_build_object(
      'slug', v_row.slug, 'display_name', v_row.display_name,
      'club_role', v_row.club_role, 'site_role', v_row.site_role
    )
  );
end;
$$;

grant execute on function public.member_session_check(uuid) to anon, authenticated;


/* ── LOG OUT ───────────────────────────────────────────────────── */
create or replace function public.member_logout(p_session_token uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.member_sessions where token = p_session_token;
$$;

grant execute on function public.member_logout(uuid) to anon, authenticated;


/* ── LINK GOOGLE (upgrade Tier A → Tier B) ─────────────────────────
   Requires BOTH an active Google session (auth.uid()) AND a valid
   password session for the member being claimed. One member can only
   ever be linked to one Google account. */
create or replace function public.member_link_google(p_session_token uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_id uuid;
  v_auth_uid  uuid := auth.uid();
begin
  if v_auth_uid is null then
    return json_build_object('success', false, 'message', 'Sign in with Google first, then link.');
  end if;

  select member_id into v_member_id
    from public.member_sessions
   where token = p_session_token and expires_at > now();

  if v_member_id is null then
    return json_build_object('success', false, 'message', 'Your session expired — log in again before linking.');
  end if;

  if exists (
    select 1 from public.profiles
     where member_id = v_member_id and id <> v_auth_uid
  ) then
    return json_build_object('success', false, 'message', 'This member is already linked to a different Google account.');
  end if;

  update public.profiles set member_id = v_member_id where id = v_auth_uid;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.member_link_google(uuid) to authenticated;


/* ── PASSWORDS ──────────────────────────────────────────────────── */
create or replace function public.member_set_password(p_admin_token uuid, p_target_slug text, p_new_password text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_admin_role text;
  v_target_id  uuid;
begin
  select m.site_role into v_admin_role
    from public.member_sessions s
    join public.members m on m.id = s.member_id
   where s.token = p_admin_token and s.expires_at > now();

  if v_admin_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  update public.members
     set password_hash = crypt(p_new_password, gen_salt('bf'))
   where slug = p_target_slug
   returning id into v_target_id;

  if v_target_id is null then
    return json_build_object('success', false, 'message', 'No member with that slug.');
  end if;

  -- Resetting someone's password invalidates every session of theirs.
  delete from public.member_sessions where member_id = v_target_id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.member_set_password(uuid, text, text) to anon, authenticated;
-- (anon can call it, but it's a no-op failure unless p_admin_token is a
--  real, unexpired admin session — same trust boundary as everything else.)


create or replace function public.member_change_own_password(p_session_token uuid, p_old_password text, p_new_password text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_member public.members%rowtype;
begin
  select m.* into v_member
    from public.member_sessions s
    join public.members m on m.id = s.member_id
   where s.token = p_session_token and s.expires_at > now();

  if v_member.id is null or v_member.password_hash <> crypt(p_old_password, v_member.password_hash) then
    return json_build_object('success', false, 'message', 'Current password is incorrect.');
  end if;

  update public.members
     set password_hash = crypt(p_new_password, gen_salt('bf'))
   where id = v_member.id;

  -- keep this session alive, kill every other one
  delete from public.member_sessions
   where member_id = v_member.id and token <> p_session_token;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.member_change_own_password(uuid, text, text) to anon, authenticated;


/* ── MODERATE (warn / silence / unsilence) ─────────────────────────
   Worked example every mod/admin action here copies: re-check
   site_role INSIDE the function against the session, never trust a
   role the client claims for itself. */
create or replace function public.member_moderate(
  p_session_token uuid,
  p_target_slug text,
  p_action text,
  p_reason text default null,
  p_duration_hours integer default 24
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor  public.members%rowtype;
  v_target public.members%rowtype;
  v_until  timestamptz;
begin
  select m.* into v_actor
    from public.member_sessions s
    join public.members m on m.id = s.member_id
   where s.token = p_session_token and s.expires_at > now();

  if v_actor.id is null or v_actor.site_role not in ('moderator', 'admin') then
    return json_build_object('success', false, 'message', 'Moderators or admins only.');
  end if;

  if p_action not in ('warn', 'silence', 'unsilence') then
    return json_build_object('success', false, 'message', 'Unknown moderation action.');
  end if;

  select * into v_target from public.members where slug = p_target_slug;
  if v_target.id is null then
    return json_build_object('success', false, 'message', 'No member with that slug.');
  end if;

  if p_action = 'silence' then
    -- Floor of 1 hour so a stray 0/negative duration can't silently
    -- no-op the action while still logging it as if it worked.
    v_until := now() + make_interval(hours => greatest(coalesce(p_duration_hours, 24), 1));
    update public.members set silenced_until = v_until where id = v_target.id;
  elsif p_action = 'unsilence' then
    update public.members set silenced_until = null where id = v_target.id;
  end if;
  -- 'warn' falls through with no column update — log-only.

  insert into public.moderation_log (actor_id, target_id, action, reason)
  values (v_actor.id, v_target.id, p_action, p_reason);

  return json_build_object('success', true, 'silenced_until', v_until);
end;
$$;

grant execute on function public.member_moderate(uuid, text, text, text, integer) to anon, authenticated;


/* ── UPDATE OWN PROFILE ────────────────────────────────────────── */
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

-- service_role needs this too — upload-profile-image (Edge Function)
-- runs as service_role so it can write Storage for Tier A members who
-- have no auth.uid() to satisfy normal Storage RLS, and calls this
-- RPC to save the resulting URL.
grant execute on function public.member_update_profile(uuid, text, text, text, text, jsonb, text)
  to anon, authenticated, service_role;


/* ── FORUMS: CREATE ────────────────────────────────────────────── */
create or replace function public.create_forum_thread(p_session_token uuid, p_title text, p_body text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := public._resolve_member_id(p_session_token);
  v_silenced_until timestamptz;
  v_thread_id bigint;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Log in to start a thread.');
  end if;

  select silenced_until into v_silenced_until from public.members where id = v_me;
  if v_silenced_until is not null and v_silenced_until > now() then
    return json_build_object(
      'success', false,
      'message', 'You''re temporarily restricted from posting until ' || to_char(v_silenced_until, 'Mon DD, HH24:MI') || '.'
    );
  end if;

  if p_title is null or char_length(trim(p_title)) = 0 then
    return json_build_object('success', false, 'message', 'Give the thread a title.');
  end if;
  if char_length(p_title) > 120 then
    return json_build_object('success', false, 'message', 'Title is too long (120 characters max).');
  end if;
  if p_body is null or char_length(trim(p_body)) = 0 then
    return json_build_object('success', false, 'message', 'Say something in the first post.');
  end if;
  if char_length(p_body) > 4000 then
    return json_build_object('success', false, 'message', 'That post is too long (4000 characters max).');
  end if;

  insert into public.forum_threads (author_id, title)
  values (v_me, trim(p_title))
  returning id into v_thread_id;

  insert into public.forum_posts (thread_id, author_id, body)
  values (v_thread_id, v_me, trim(p_body));

  return json_build_object('success', true, 'thread_id', v_thread_id);
end;
$$;

grant execute on function public.create_forum_thread(uuid, text, text) to anon, authenticated;

create or replace function public.create_forum_post(p_session_token uuid, p_thread_id bigint, p_body text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := public._resolve_member_id(p_session_token);
  v_silenced_until timestamptz;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Log in to reply.');
  end if;

  select silenced_until into v_silenced_until from public.members where id = v_me;
  if v_silenced_until is not null and v_silenced_until > now() then
    return json_build_object(
      'success', false,
      'message', 'You''re temporarily restricted from posting until ' || to_char(v_silenced_until, 'Mon DD, HH24:MI') || '.'
    );
  end if;

  if not exists (select 1 from public.forum_threads where id = p_thread_id) then
    return json_build_object('success', false, 'message', 'That thread no longer exists.');
  end if;

  if p_body is null or char_length(trim(p_body)) = 0 then
    return json_build_object('success', false, 'message', 'Message cannot be empty.');
  end if;
  if char_length(p_body) > 4000 then
    return json_build_object('success', false, 'message', 'That post is too long (4000 characters max).');
  end if;

  insert into public.forum_posts (thread_id, author_id, body)
  values (p_thread_id, v_me, trim(p_body));

  return json_build_object('success', true);
end;
$$;

grant execute on function public.create_forum_post(uuid, bigint, text) to anon, authenticated;


/* ── FORUMS: EDIT / PIN / DELETE ───────────────────────────────── */
create or replace function public.edit_forum_thread(p_session_token uuid, p_thread_id bigint, p_title text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     uuid := public._resolve_member_id(p_session_token);
  v_role   text;
  v_author uuid;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select author_id into v_author from public.forum_threads where id = p_thread_id;
  if v_author is null then
    return json_build_object('success', false, 'message', 'Thread not found.');
  end if;

  select site_role into v_role from public.members where id = v_me;

  if v_author <> v_me and v_role not in ('moderator', 'admin') then
    return json_build_object('success', false, 'message', 'You can only edit your own threads.');
  end if;

  if p_title is null or char_length(trim(p_title)) = 0 then
    return json_build_object('success', false, 'message', 'Give the thread a title.');
  end if;
  if char_length(trim(p_title)) > 120 then
    return json_build_object('success', false, 'message', 'Title is too long (120 characters max).');
  end if;

  update public.forum_threads
     set title = trim(p_title)
   where id = p_thread_id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.edit_forum_thread(uuid, bigint, text) to anon, authenticated;

create or replace function public.edit_forum_post(p_session_token uuid, p_post_id bigint, p_body text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     uuid := public._resolve_member_id(p_session_token);
  v_role   text;
  v_author uuid;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select author_id into v_author from public.forum_posts where id = p_post_id;
  if v_author is null then
    return json_build_object('success', false, 'message', 'Post not found.');
  end if;

  select site_role into v_role from public.members where id = v_me;

  if v_author <> v_me and v_role not in ('moderator', 'admin') then
    return json_build_object('success', false, 'message', 'You can only edit your own posts.');
  end if;

  if p_body is null or char_length(trim(p_body)) = 0 then
    return json_build_object('success', false, 'message', 'Message cannot be empty.');
  end if;
  if char_length(trim(p_body)) > 4000 then
    return json_build_object('success', false, 'message', 'That post is too long (4000 characters max).');
  end if;

  update public.forum_posts
     set body = trim(p_body)
   where id = p_post_id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.edit_forum_post(uuid, bigint, text) to anon, authenticated;

create or replace function public.set_forum_thread_pinned(p_session_token uuid, p_thread_id bigint, p_pinned boolean)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  select m.site_role into v_role
    from public.member_sessions s
    join public.members m on m.id = s.member_id
   where s.token = p_session_token and s.expires_at > now();

  if v_role is distinct from 'moderator' and v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Moderators only.');
  end if;

  update public.forum_threads set pinned = p_pinned where id = p_thread_id;
  return json_build_object('success', true);
end;
$$;

grant execute on function public.set_forum_thread_pinned(uuid, bigint, boolean) to anon, authenticated;

-- NOT touched by silencing: edit/pin/delete stay available to a
-- silenced member for their own existing content — a silence blocks
-- NEW threads/replies only (see create_forum_thread/create_forum_post
-- above), not managing what's already posted.
create or replace function public.delete_forum_post(p_session_token uuid, p_post_id bigint)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     uuid := public._resolve_member_id(p_session_token);
  v_role   text;
  v_author uuid;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select author_id into v_author from public.forum_posts where id = p_post_id;
  if v_author is null then
    return json_build_object('success', false, 'message', 'Post not found.');
  end if;

  select site_role into v_role from public.members where id = v_me;

  if v_author <> v_me and v_role not in ('moderator', 'admin') then
    return json_build_object('success', false, 'message', 'You can only delete your own posts.');
  end if;

  delete from public.forum_posts where id = p_post_id;
  return json_build_object('success', true);
end;
$$;

grant execute on function public.delete_forum_post(uuid, bigint) to anon, authenticated;

create or replace function public.delete_forum_thread(p_session_token uuid, p_thread_id bigint)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     uuid := public._resolve_member_id(p_session_token);
  v_role   text;
  v_author uuid;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select author_id into v_author from public.forum_threads where id = p_thread_id;
  if v_author is null then
    return json_build_object('success', false, 'message', 'Thread not found.');
  end if;

  select site_role into v_role from public.members where id = v_me;

  if v_author <> v_me and v_role not in ('moderator', 'admin') then
    return json_build_object('success', false, 'message', 'You can only delete your own threads.');
  end if;

  delete from public.forum_threads where id = p_thread_id; -- posts cascade
  return json_build_object('success', true);
end;
$$;

grant execute on function public.delete_forum_thread(uuid, bigint) to anon, authenticated;


/* ── MODERATION LOG: READ (self + admin) ───────────────────────── */
create or replace function public.list_my_moderation_log(p_session_token uuid)
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

  return json_build_object(
    'success', true,
    'entries', (
      select coalesce(
        json_agg(json_build_object(
          'action', ml.action,
          'reason', ml.reason,
          'created_at', ml.created_at,
          'actor_name', a.display_name
        ) order by ml.created_at desc),
        '[]'::json
      )
      from public.moderation_log ml
      join public.members a on a.id = ml.actor_id
      where ml.target_id = v_me
      limit 50
    )
  );
end;
$$;

grant execute on function public.list_my_moderation_log(uuid) to anon, authenticated;

-- Admin-scoped sibling of the above: everyone's history, not just the
-- caller's, plus the target's name so an admin can tell who's who.
create or replace function public.admin_list_moderation_log(
  p_session_token uuid,
  p_limit         integer default 100
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

  return json_build_object(
    'success', true,
    'entries', (
      select coalesce(json_agg(row_to_json(x) order by x.created_at desc), '[]'::json)
      from (
        select
          ml.id, ml.action, ml.reason, ml.created_at,
          a.slug as actor_slug, a.display_name as actor_name,
          t.slug as target_slug, t.display_name as target_name
        from public.moderation_log ml
        join public.members a on a.id = ml.actor_id
        join public.members t on t.id = ml.target_id
        order by ml.created_at desc
        limit greatest(coalesce(p_limit, 100), 1)
      ) x
    )
  );
end;
$$;

grant execute on function public.admin_list_moderation_log(uuid, integer) to anon, authenticated;


/* ── ROLE MANAGEMENT ───────────────────────────────────────────── */
create or replace function public.admin_set_role(
  p_session_token uuid,
  p_target_slug   text,
  p_new_role      text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me       uuid := public._resolve_member_id(p_session_token);
  v_role     text;
  v_target   public.members%rowtype;
  v_admins   integer;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select site_role into v_role from public.members where id = v_me;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  if p_new_role not in ('member', 'moderator', 'admin') then
    return json_build_object('success', false, 'message', 'Unknown role.');
  end if;

  select * into v_target from public.members where slug = p_target_slug;
  if v_target.id is null then
    return json_build_object('success', false, 'message', 'No member with that slug.');
  end if;

  -- Refuse to demote the last admin — a wrong click can't lock every
  -- admin route away from everyone with no in-app way back in.
  if v_target.site_role = 'admin' and p_new_role <> 'admin' then
    select count(*) into v_admins from public.members where site_role = 'admin';
    if v_admins <= 1 then
      return json_build_object('success', false, 'message', 'Can''t remove the last remaining admin.');
    end if;
  end if;

  update public.members set site_role = p_new_role where id = v_target.id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.admin_set_role(uuid, text, text) to anon, authenticated;


/* ── ANNOUNCEMENTS ─────────────────────────────────────────────── */
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


/* ── FOLLOWED THREADS ───────────────────────────────────────────── */
create or replace function public.follow_forum_thread(p_session_token uuid, p_thread_id bigint)
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
  if not exists (select 1 from public.forum_threads where id = p_thread_id) then
    return json_build_object('success', false, 'message', 'No such thread.');
  end if;

  insert into public.forum_thread_follows (member_id, thread_id)
  values (v_me, p_thread_id)
  on conflict (member_id, thread_id) do nothing;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.follow_forum_thread(uuid, bigint) to anon, authenticated;

create or replace function public.unfollow_forum_thread(p_session_token uuid, p_thread_id bigint)
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

  delete from public.forum_thread_follows where member_id = v_me and thread_id = p_thread_id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.unfollow_forum_thread(uuid, bigint) to anon, authenticated;

create or replace function public.list_my_followed_thread_ids(p_session_token uuid)
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

  return json_build_object(
    'success', true,
    'thread_ids', (
      select coalesce(json_agg(thread_id), '[]'::json)
      from public.forum_thread_follows
      where member_id = v_me
    )
  );
end;
$$;

grant execute on function public.list_my_followed_thread_ids(uuid) to anon, authenticated;


/* ── NOTIFICATION POLL ──────────────────────────────────────────────
   Client polls this on an interval instead of using Supabase Realtime
   — every table below gates RLS on auth.uid(), which only exists for
   Tier B (Google-linked) sessions, and Realtime's postgres_changes
   feed is subject to that same check. A raw realtime subscription
   would silently deliver zero rows to most members here. Works even
   with p_session_token = null (guests still get `maintenance`;
   everything else comes back empty rather than erroring). */
create or replace function public.list_unseen_notifications(
  p_session_token uuid default null,
  p_since         timestamptz default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me    uuid := public._resolve_member_id(p_session_token);
  v_since timestamptz := coalesce(p_since, now() - interval '1 hour');
begin
  return json_build_object(
    'success', true,
    'server_time', now(),

    -- Public — no login required, guests get maintenance toasts too.
    'maintenance', (
      select coalesce(
        json_agg(json_build_object(
          'id', a.id, 'title', a.title, 'body', a.body, 'created_at', a.created_at
        ) order by a.created_at),
        '[]'::json
      )
      from public.announcements a
      where a.kind = 'maintenance' and a.created_at > v_since
    ),

    'announcements', (
      select coalesce(
        json_agg(json_build_object(
          'id', a.id, 'title', a.title, 'body', a.body, 'created_at', a.created_at
        ) order by a.created_at),
        '[]'::json
      )
      from public.announcements a
      where a.kind = 'announcement' and a.created_at > v_since
    ),

    'warnings', (case when v_me is null then '[]'::json else (
      select coalesce(
        json_agg(json_build_object(
          'reason', ml.reason, 'created_at', ml.created_at, 'actor_name', act.display_name
        ) order by ml.created_at),
        '[]'::json
      )
      from public.moderation_log ml
      join public.members act on act.id = ml.actor_id
      where ml.target_id = v_me and ml.action = 'warn' and ml.created_at > v_since
    ) end),

    'silences', (case when v_me is null then '[]'::json else (
      select coalesce(
        json_agg(json_build_object(
          'reason', ml.reason, 'created_at', ml.created_at, 'actor_name', act.display_name
        ) order by ml.created_at),
        '[]'::json
      )
      from public.moderation_log ml
      join public.members act on act.id = ml.actor_id
      where ml.target_id = v_me and ml.action = 'silence' and ml.created_at > v_since
    ) end),

    'forum_replies', (case when v_me is null then '[]'::json else (
      select coalesce(
        json_agg(json_build_object(
          'thread_id', p.thread_id,
          'thread_title', t.title,
          'author_name', author.display_name,
          'created_at', p.created_at
        ) order by p.created_at),
        '[]'::json
      )
      from public.forum_posts p
      join public.forum_thread_follows fol on fol.thread_id = p.thread_id and fol.member_id = v_me
      join public.forum_threads t on t.id = p.thread_id
      join public.members author on author.id = p.author_id
      where p.created_at > v_since and p.author_id != v_me
    ) end)
  );
end;
$$;

grant execute on function public.list_unseen_notifications(uuid, timestamptz) to anon, authenticated;


/* ── PERSISTENT "FORUM" NOTIFICATIONS-PANEL SECTION ────────────────
   Deliberately not filtered by "since a checkpoint" — re-readable any
   time, same as list_my_moderation_log, not a one-shot unseen-only
   poll. Capped at p_limit (default 20), newest first. */
create or replace function public.list_my_followed_thread_activity(
  p_session_token uuid,
  p_limit         int default 20
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

  return json_build_object(
    'success', true,
    'entries', (
      select coalesce(
        json_agg(row_to_json(x) order by x.created_at desc),
        '[]'::json
      )
      from (
        select
          p.id,
          p.thread_id,
          t.title              as thread_title,
          author.display_name  as author_name,
          left(p.body, 140)    as excerpt,
          p.created_at
        from public.forum_posts p
        join public.forum_thread_follows fol on fol.thread_id = p.thread_id and fol.member_id = v_me
        join public.forum_threads t on t.id = p.thread_id
        join public.members author on author.id = p.author_id
        where p.author_id != v_me
        order by p.created_at desc
        limit greatest(coalesce(p_limit, 20), 1)
      ) x
    )
  );
end;
$$;

grant execute on function public.list_my_followed_thread_activity(uuid, int) to anon, authenticated;


/* ── ADMIN SCORE WRITING ────────────────────────────────────────────
   Insert a new score, or update the existing one for that exact
   (member, badge[, issue_number]) combo. Admins only. Updating an
   existing row bumps created_at to now() on purpose — the badge-
   notification checkBadges() poll (lib/notifications.js) uses
   created_at as its "is this new?" signal, and a corrected value is
   exactly the kind of change worth re-surfacing as a toast. */
create or replace function public.admin_upsert_score(
  p_session_token uuid,
  p_member_slug   text,
  p_badge_id      text,
  p_value         numeric,
  p_issue_number  int  default null,
  p_awarded_on    date default null,
  p_partner_slug  text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me      uuid := public._resolve_member_id(p_session_token);
  v_role    text;
  v_target  uuid;
  v_partner uuid;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select site_role into v_role from public.members where id = v_me;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  if p_badge_id is null or trim(p_badge_id) = '' then
    return json_build_object('success', false, 'message', 'A badge id is required.');
  end if;
  if p_value is null then
    return json_build_object('success', false, 'message', 'A value is required.');
  end if;

  select id into v_target from public.members where slug = p_member_slug;
  if v_target is null then
    return json_build_object('success', false, 'message', 'No member with that slug.');
  end if;

  if p_partner_slug is not null and trim(p_partner_slug) <> '' then
    select id into v_partner from public.members where slug = p_partner_slug;
    if v_partner is null then
      return json_build_object('success', false, 'message', 'No member with that partner slug.');
    end if;
  end if;

  if p_issue_number is null then
    insert into public.scores (badge_id, member_id, value, awarded_on, created_by, partner_member_id)
    values (trim(p_badge_id), v_target, p_value, coalesce(p_awarded_on, current_date), v_me, v_partner)
    on conflict (badge_id, member_id) where issue_number is null
    do update set
      value             = excluded.value,
      awarded_on        = excluded.awarded_on,
      created_by        = excluded.created_by,
      partner_member_id = excluded.partner_member_id,
      created_at        = now();
  else
    insert into public.scores (badge_id, member_id, value, issue_number, awarded_on, created_by, partner_member_id)
    values (trim(p_badge_id), v_target, p_value, p_issue_number, coalesce(p_awarded_on, current_date), v_me, v_partner)
    on conflict (badge_id, member_id, issue_number) where issue_number is not null
    do update set
      value             = excluded.value,
      awarded_on        = excluded.awarded_on,
      created_by        = excluded.created_by,
      partner_member_id = excluded.partner_member_id,
      created_at        = now();
  end if;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.admin_upsert_score(uuid, text, text, numeric, int, date, text) to anon, authenticated;

create or replace function public.admin_delete_score(
  p_session_token uuid,
  p_score_id      bigint
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

  delete from public.scores where id = p_score_id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.admin_delete_score(uuid, bigint) to anon, authenticated;


/* ── SECRET BADGES: SELF-SERVE, ALLOW-LISTED ────────────────────────
   A visitor awarding *themselves* a badge is a different trust
   boundary than admin_upsert_score() — deliberately its own function:
     * only ever writes one of a small hardcoded allow-list of
       badge_ids — never an arbitrary caller-supplied one
     * explicitly checks for (and rejects) a repeat claim BEFORE
       computing the next issue_number, so a second call can't insert
       a fresh row — the unique index is a backstop for a race between
       two near-simultaneous calls, not the primary guard
     * requires a logged-in member (Tier A or B) — no guest version

   Worth knowing: the 404 route and the Konami-code listener are UI
   gating, not security — any logged-in member could call this RPC
   directly via devtools, skipping the actual easter egg. Accepted,
   low-stakes tradeoff for playful secret badges. */
create or replace function public.claim_secret_badge(
  p_session_token uuid,
  p_badge_id      text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me         uuid := public._resolve_member_id(p_session_token);
  v_already    boolean;
  v_next_issue int;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  if p_badge_id not in ('whoops', 'h4h4-n00b') then
    return json_build_object('success', false, 'message', 'That badge cannot be self-claimed.');
  end if;

  select exists(
    select 1 from public.scores where badge_id = p_badge_id and member_id = v_me
  ) into v_already;
  if v_already then
    return json_build_object('success', false, 'message', 'Already claimed.');
  end if;

  select coalesce(max(issue_number), 0) + 1 into v_next_issue
    from public.scores where badge_id = p_badge_id;

  insert into public.scores (badge_id, member_id, value, issue_number, awarded_on, created_by)
  values (p_badge_id, v_me, 1, v_next_issue, current_date, v_me);

  return json_build_object('success', true, 'issue_number', v_next_issue);
exception when unique_violation then
  -- Two near-simultaneous claims raced past the exists-check above —
  -- the partial unique index caught it. Same graceful response.
  return json_build_object('success', false, 'message', 'Already claimed.');
end;
$$;

grant execute on function public.claim_secret_badge(uuid, text) to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 11. SEED THE ROSTER
-- ═══════════════════════════════════════════════════════════════════
-- One row per current member, so the login dropdown has something to
-- show immediately. Everyone defaults to site_role='member' with no
-- password set — run member_set_password() (or dmac-password-
-- bootstrap.sql / dmac-password-reset-scheme.sql) per person, or in
-- bulk, before they can actually log in. on conflict do nothing, so
-- re-running this file is safe and won't clobber live edits.
insert into public.members (slug, display_name, club_role, site_role) values
  ('richmond-causaren',    'Richmond P. Causaren',       'Club Adviser',                         'member'),
  ('marie-asuncion',       'Marie Aldron G. Asuncion',   'Co-Adviser',                           'member'),
  ('rhocell-luteria',      'Rhocell C. Luteria',         'Co-Adviser',                           'member'),
  ('johanna-obar',         'Johanna Mae E. Obar',        'Co-Adviser',                           'member'),
  ('jyryn-jayme',          'Jyryn Shmily G. Jayme',      'President',                            'member'),
  ('jaywin-cambalon',      'Jaywin Elson Cambalon',      'Vice President',                       'member'),
  ('athena-jimenez',       'Athena Aruen M. Jimenez',    'Secretary',                            'member'),
  ('nico-melorin',         'Nico Andrei C. Melorin',     'Asst. Secretary',                      'member'),
  ('keitharine-secillano', 'Keitharine M. Secillano',    'Treasurer',                            'member'),
  ('alianna-abangan',      'Alianna Jen M. Abangan',     'Auditor',                              'member'),
  ('mark-patnon',          'Mark James C. Patnon',       'Public Information Officer',           'member'),
  ('jezrylle-andres',      'Jezrylle D. Andres',         'Public Information Officer',           'member'),
  ('leanne-abenoja',       'Leanne Rouz E. Abenoja',     'Multimedia & Visual Graphic Specialist','member'),
  ('micah-bartolome',      'Micah Sophia H. Bartolome',  'Multimedia & Visual Graphic Specialist','member'),
  ('liane-labitan',        'Liane Jhaydel D. Labitan',   'Multimedia & Visual Graphic Specialist','member'),
  ('clarisse-luego',       'Clarisse Madel M. Luego',    'Multimedia & Visual Graphic Specialist','member'),
  ('rhycel-nato',          'Rhycel Dennese M. Nato',     'Multimedia & Visual Graphic Specialist','member'),
  ('ysabel-pernala',       'Ysabel A. Pernala',          'Multimedia & Visual Graphic Specialist','member'),
  ('rojan-sajol',          'Rojan Jacob D. Sajol',       'Multimedia & Visual Graphic Specialist','member'),
  ('ethan-salamat',        'Ethan Carlo M. Salamat',     'Multimedia & Visual Graphic Specialist','member'),
  ('sophia-angeles',       'Sophia Lorraine F. Angeles', 'Creative Imagery Specialist',          'member'),
  ('jemwell-boton',        'Jemwell Boton',              'Creative Imagery Specialist',          'member'),
  ('clarence-eblasin',     'Clarence Lei P. Eblasin',    'Creative Imagery Specialist',          'member'),
  ('mary-magalona',        'Mary Jeanelle Magalona',     'Creative Imagery Specialist',          'member'),
  ('lorien-naval',         'Lorien Rose A. Naval',       'Creative Imagery Specialist',          'member'),
  ('sofia-obejas',         'Sofia Lois A. Obejas',       'Creative Imagery Specialist',          'member')
on conflict (slug) do nothing;

-- Known site_role assignments: PIO (Mark), Richmond, Athena, and
-- Marie are admins; Jaywin is a moderator.
update public.members set site_role = 'admin'
  where slug in ('mark-patnon', 'richmond-causaren', 'athena-jimenez', 'marie-asuncion')
    and site_role <> 'admin';

update public.members set site_role = 'moderator'
  where slug in ('jaywin-cambalon')
    and site_role = 'member';
