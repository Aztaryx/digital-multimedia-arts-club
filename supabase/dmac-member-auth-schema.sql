/* ═══════════════════════════════════════════════════════════════════
   dmac-member-auth-schema.sql
   Password-based member login — for members who don't want to
   link a Google account, sitting alongside the existing Google
   OAuth + profiles/scores setup (see js/supabase-client.js and
   dev/auth-test.html).
   ═══════════════════════════════════════════════════════════════════

   THE CORE PROBLEM THIS SOLVES
   ------------------------------------------------------------------
   Supabase Auth (auth.uid(), RLS policies keyed off it) only exists
   for people who complete Google OAuth. A member who never links
   Google has no auth.users row and no JWT — there's nothing for RLS
   to check. So a *plain password field* checked from the browser
   can't be the actual security boundary; anyone with the anon key
   could read every password hash directly, or just skip the check
   client-side entirely.

   The fix used below: password verification, session issuing, and
   every privileged write happen inside SECURITY DEFINER Postgres
   functions (RPCs). Those run with the function owner's privileges
   (normally `postgres`), not the caller's — so the anon key never
   gets direct table access to anything sensitive, RLS on the
   sensitive tables can stay fully locked down, and a member is
   "logged in" via a random session token instead of a Supabase Auth
   JWT. Google-linked members still get a real JWT on top of this and
   can be treated identically once linked (see member_link_google).

   TWO TIERS OF "LOGGED IN", BOTH VALID
   ------------------------------------------------------------------
   Tier A — password only (no Google): proven identity via
     member_login() → session token. Good enough for personalizing
     the UI and for the member's *own* self-service actions
     (change_own_password, edit their own display name, etc).
   Tier B — Google-linked: real Supabase Auth session (auth.uid()).
     profiles.member_id points at this member's row in `members`
     (below), set once via member_link_google() after they've proven
     Tier A first.
   Privileged actions that affect OTHER people (silence/warn a member,
   edit scores/badge values) should NOT trust "site_role" off a raw
   client claim — they must re-check role server-side, inside the
   same kind of SECURITY DEFINER function, using the session token
   (Tier A) or auth.uid() (Tier B). member_silence_member() below is
   a worked example of that pattern — extend it for other mod/admin
   actions rather than trusting anything the client sends about its
   own permissions.

   RUN THIS IN: Supabase Dashboard → SQL Editor → New query.
   I can't run this against your live project from here (no network
   access in this environment) — please read through it once before
   running, especially the seed data and the TODOs near the bottom.
   ═══════════════════════════════════════════════════════════════════ */

create extension if not exists pgcrypto;


/* ── 1. ROSTER TABLE ──────────────────────────────────────────────
   The source of truth for "who's allowed to log in as who." `slug`
   matches the keys already used in js/pages/members.js (e.g.
   'mark-patnon') so the two stay easy to cross-reference.

   site_role is the WEBSITE PERMISSION tier (member / moderator /
   admin) — separate from club_role, which is just the descriptive
   club title (President, Treasurer, etc.) and has no bearing on
   website permissions by itself. It's also separate from the
   pre-existing profiles.role ('member' / 'officer'), which only
   governs leaderboard score-writing — three different axes that
   happen to overlap in membership but aren't the same field. */

create table if not exists public.members (
  id            uuid primary key default gen_random_uuid(),
  slug          text unique not null,
  display_name  text not null,
  club_role     text,                      -- descriptive only, e.g. 'Vice President'
  site_role     text not null default 'member'
                  check (site_role in ('member', 'moderator', 'admin')),
  password_hash text,                      -- null until an admin sets one via member_set_password()
  created_at    timestamptz not null default now()
);

alter table public.members enable row level security;

-- Anyone (incl. guests) can see who exists, for the login dropdown.
create policy "members are readable" on public.members
  for select using (true);

-- But RLS only gates ROWS — column-level GRANTs gate which COLUMNS.
-- password_hash is deliberately never granted below, same pattern
-- this project already uses to protect profiles.role from self-edits.
revoke all on public.members from anon, authenticated;
grant select (id, slug, display_name, club_role, site_role) on public.members to anon, authenticated;
-- No insert/update/delete grants at all — every write goes through
-- a SECURITY DEFINER function further down.


/* ── 2. SESSIONS TABLE (Tier A) ───────────────────────────────────
   A logged-in-by-password member's "you are who you say you are"
   token. Deliberately has NO grants and NO policies for anon/
   authenticated — it's reachable only from inside SECURITY DEFINER
   functions, never queried directly by the client. */

create table if not exists public.member_sessions (
  token       uuid primary key default gen_random_uuid(),
  member_id   uuid not null references public.members(id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default (now() + interval '30 days')
);

alter table public.member_sessions enable row level security;
revoke all on public.member_sessions from anon, authenticated;


/* ── 3. LINK profiles → members ───────────────────────────────────
   profiles already gets a row per Google-linked account (via your
   existing auth.users trigger) and already has a member_id column
   used when inserting scores (see dev/auth-test.html). This just
   makes sure it points at this new members table. If member_id
   already exists with a different type/target in your live DB,
   STOP and reconcile that first instead of running this line blind. */

alter table public.profiles
  add column if not exists member_id uuid references public.members(id);


/* ── 4. LOGIN (password → session token) ──────────────────────────
   Same generic error for "no such member" and "wrong password" —
   don't give away which one it was. */

create or replace function public.member_login(p_slug text, p_password text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member public.members%rowtype;
  v_token  uuid;
begin
  select * into v_member from public.members where slug = p_slug;

  if v_member.id is null
     or v_member.password_hash is null
     or v_member.password_hash <> crypt(p_password, v_member.password_hash) then
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

revoke all on function public.member_login(text, text) from public;
grant execute on function public.member_login(text, text) to anon, authenticated;


/* ── 5. RESTORE / CHECK SESSION ("welcome back") ──────────────────
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


/* ── 6. LOG OUT ────────────────────────────────────────────────── */

create or replace function public.member_logout(p_session_token uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.member_sessions where token = p_session_token;
$$;

grant execute on function public.member_logout(uuid) to anon, authenticated;


/* ── 7. LINK GOOGLE (upgrade Tier A → Tier B) ─────────────────────
   Requires BOTH an active Google session (auth.uid()) AND a valid
   password session for the member being claimed — matches the
   wireframe's "must have filled dropdown + password, check correct,
   THEN allow to link" rule. One member can only ever be linked to
   one Google account. */

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


/* ── 8. PASSWORDS ─────────────────────────────────────────────────
   No self-registration — an admin sets each member's first password
   (matches how this project already hands out access: officers
   control the data, e.g. the leaderboard Sheet). Members can change
   their own afterwards. */

create or replace function public.member_set_password(p_admin_token uuid, p_target_slug text, p_new_password text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_role text;
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
   where slug = p_target_slug;

  if not found then
    return json_build_object('success', false, 'message', 'No member with that slug.');
  end if;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.member_set_password(uuid, text, text) to authenticated, anon;
-- (anon can call it, but it's a no-op failure unless p_admin_token is a
--  real, unexpired admin session — same trust boundary as everything else.)


create or replace function public.member_change_own_password(p_session_token uuid, p_old_password text, p_new_password text)
returns json
language plpgsql
security definer
set search_path = public
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

  return json_build_object('success', true);
end;
$$;

grant execute on function public.member_change_own_password(uuid, text, text) to anon, authenticated;


/* ── 9. WORKED EXAMPLE: a moderator/admin-only action ─────────────
   "Both can silence/warn members, but only Admins can edit values."
   This is the pattern to copy for that and for any future mod/admin
   feature — re-check site_role INSIDE the function, never trust a
   role the client claims for itself. Not a full moderation feature,
   just the enforcement shape. */

create table if not exists public.moderation_log (
  id          bigint generated always as identity primary key,
  actor_id    uuid not null references public.members(id),
  target_id   uuid not null references public.members(id),
  action      text not null check (action in ('warn', 'silence')),
  reason      text,
  created_at  timestamptz not null default now()
);

alter table public.moderation_log enable row level security;
revoke all on public.moderation_log from anon, authenticated;
grant select on public.moderation_log to authenticated; -- read-only visibility; writes are RPC-only

create or replace function public.member_moderate(
  p_session_token uuid, p_target_slug text, p_action text, p_reason text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor  public.members%rowtype;
  v_target public.members%rowtype;
begin
  select m.* into v_actor
    from public.member_sessions s
    join public.members m on m.id = s.member_id
   where s.token = p_session_token and s.expires_at > now();

  if v_actor.id is null or v_actor.site_role not in ('moderator', 'admin') then
    return json_build_object('success', false, 'message', 'Moderators or admins only.');
  end if;

  select * into v_target from public.members where slug = p_target_slug;
  if v_target.id is null then
    return json_build_object('success', false, 'message', 'No member with that slug.');
  end if;

  insert into public.moderation_log (actor_id, target_id, action, reason)
  values (v_actor.id, v_target.id, p_action, p_reason);

  return json_build_object('success', true);
end;
$$;

grant execute on function public.member_moderate(uuid, text, text, text) to anon, authenticated;

-- "Edit values" (scores/badges) already has its own enforcement via
-- profiles.role='officer' on the scores table (see js/leaderboard.js).
-- If that needs to become admin-only per the new site_role instead,
-- that's a change to the scores table's existing RLS policy, not to
-- anything above — flag if you want a hand with that one specifically.


/* ── 10. SEED THE ROSTER ──────────────────────────────────────────
   One row per person in js/pages/members.js, so the login dropdown
   has something to show immediately. Everyone defaults to
   site_role='member'. No passwords are set yet — run
   member_set_password() (or a Table Editor edit, same effect since
   pgcrypto's crypt() has to be called either way) per person before
   they can actually log in. */

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


/* ── 11. KNOWN site_role ASSIGNMENTS ──────────────────────────────
   From what you told me: PIO (Mark), Richmond, Athena, and Marie
   are admins; Jaywin is a moderator. */

update public.members set site_role = 'admin'
  where slug in ('mark-patnon', 'richmond-causaren', 'athena-jimenez', 'marie-asuncion');

update public.members set site_role = 'moderator'
  where slug in ('jaywin-cambalon');

-- TODO — you said there are more moderators ("the rest of the higher
-- ups") you couldn't recall. Likely candidates still sitting at the
-- 'member' default: jyryn-jayme (President), nico-melorin (Asst.
-- Secretary), keitharine-secillano (Treasurer), alianna-abangan
-- (Auditor), rhocell-luteria / johanna-obar (Co-Advisers), jezrylle-andres
-- (2nd PIO). Once you remember, promote them with:
--   update public.members set site_role = 'moderator' where slug = '...';
