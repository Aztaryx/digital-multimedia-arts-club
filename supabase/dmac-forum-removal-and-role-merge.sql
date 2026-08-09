/* ═══════════════════════════════════════════════════════════════════
   dmac-forum-removal-and-role-merge.sql
   ═══════════════════════════════════════════════════════════════════
   Covers three items from dmac-consolidated-plan.md that either never
   landed, or landed only partially because the ALTER/DROP statements
   that were run by hand against the live project were never saved
   back into a file:

     §1 — Forum system removed entirely (tables, RPCs, views).
     §2 — site_role collapses to ('member', 'admin') — 'moderator'
          dropped, existing moderators promoted to admin.
     §5 — Season Reset actually does what the plan describes (writes
          real legacy_records rows, actually wipes/resets/archives)
          instead of admin_start_new_season's old TODO-shaped body.

   IDEMPOTENT BY DESIGN — every statement below uses IF EXISTS / IF
   NOT EXISTS / CREATE OR REPLACE, specifically because you said the
   live database's exact current state isn't fully known (some of
   this may already be half-applied from the earlier hand-run ALTER/
   DROP). Safe to run against:
     - a database where none of this has been touched yet
     - a database where the forum tables are already gone
     - a database where site_role is already ('member','admin')
     - any mix of the above

   Run this AFTER schema.sql and schema-additions-v2-rework.sql have
   both been run at least once (this migration assumes members,
   scores, moderation_log, member_domain_ratings, threads,
   contributions, works, season_resets, and legacy_records already
   exist — it doesn't create any of those from scratch).
   ═══════════════════════════════════════════════════════════════════ */


-- ═══════════════════════════════════════════════════════════════════
-- 1. FORUM SYSTEM — DROP EVERYTHING
-- ═══════════════════════════════════════════════════════════════════
-- Order matters: views/functions before tables (they reference the
-- tables), tables in dependency order (posts/follows before threads).

drop view if exists public.forum_posts_feed;
drop view if exists public.forum_threads_feed;

drop function if exists public.create_forum_thread(uuid, text, text);
drop function if exists public.create_forum_post(uuid, bigint, text);
drop function if exists public.edit_forum_thread(uuid, bigint, text);
drop function if exists public.edit_forum_post(uuid, bigint, text);
drop function if exists public.set_forum_thread_pinned(uuid, bigint, boolean);
drop function if exists public.delete_forum_post(uuid, bigint);
drop function if exists public.delete_forum_thread(uuid, bigint);
drop function if exists public.follow_forum_thread(uuid, bigint);
drop function if exists public.unfollow_forum_thread(uuid, bigint);
drop function if exists public.list_my_followed_thread_ids(uuid);
drop function if exists public.list_my_followed_thread_activity(uuid, int);

drop table if exists public.forum_thread_follows;
drop table if exists public.forum_posts;
drop table if exists public.forum_threads;

-- list_unseen_notifications() had a `forum_replies` key sourced from
-- the now-dropped tables — re-create it without that key rather than
-- leaving a function that references a table that no longer exists.
-- Everything else in the payload (maintenance/announcements/warnings/
-- silences) is unchanged from schema.sql.
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
    ) end)
  );
end;
$$;

grant execute on function public.list_unseen_notifications(uuid, timestamptz) to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 2. ROLE MERGE — moderator folds into admin
-- ═══════════════════════════════════════════════════════════════════

-- 2a. Promote any remaining moderators BEFORE the constraint changes
--     (the constraint would otherwise reject the existing 'moderator'
--     rows the instant it's tightened).
update public.members set site_role = 'admin' where site_role = 'moderator';

-- 2b. Drop whichever constraint currently exists (its exact name can
--     differ if it's already been dropped/re-added by hand once).
--     Postgres doesn't support "drop constraint if exists" by a
--     pattern match, so look it up and drop by its real name.
do $$
declare
  v_conname text;
begin
  select conname into v_conname
  from pg_constraint
  where conrelid = 'public.members'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%site_role%';

  if v_conname is not null then
    execute format('alter table public.members drop constraint %I', v_conname);
  end if;
end $$;

alter table public.members
  add constraint members_site_role_check check (site_role in ('member', 'admin'));

-- 2c. member_moderate() — same RPC, tightened gate. 'moderator' was
--     never a real value moderate-able down to nothing here, just the
--     role that used to be allowed to call this alongside admin.
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

  if v_actor.id is null or v_actor.site_role <> 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  if p_action not in ('warn', 'silence', 'unsilence') then
    return json_build_object('success', false, 'message', 'Unknown moderation action.');
  end if;

  select * into v_target from public.members where slug = p_target_slug;
  if v_target.id is null then
    return json_build_object('success', false, 'message', 'No member with that slug.');
  end if;

  if p_action = 'silence' then
    v_until := now() + make_interval(hours => greatest(coalesce(p_duration_hours, 24), 1));
    update public.members set silenced_until = v_until where id = v_target.id;
  elsif p_action = 'unsilence' then
    update public.members set silenced_until = null where id = v_target.id;
  end if;

  insert into public.moderation_log (actor_id, target_id, action, reason)
  values (v_actor.id, v_target.id, p_action, p_reason);

  return json_build_object('success', true, 'silenced_until', v_until);
end;
$$;

grant execute on function public.member_moderate(uuid, text, text, text, integer) to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 3. CONTENT TABLES — ensure club_announcements / school_events exist
-- ═══════════════════════════════════════════════════════════════════
-- These match what AnnouncementsView.vue / SchoolEventsView.vue
-- already query. schema-additions-v2-rework.sql defines them too —
-- repeated here as `if not exists` so this file is a complete,
-- standalone "get to the target state" script on its own.

create table if not exists public.club_announcements (
  id         uuid primary key default gen_random_uuid(),
  title      text not null check (char_length(title) between 1 and 120),
  body       text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  author_id  uuid references public.members(id) on delete set null
);

alter table public.club_announcements enable row level security;

drop policy if exists "club_announcements readable" on public.club_announcements;
create policy "club_announcements readable" on public.club_announcements
  for select using (true);

grant select on public.club_announcements to anon, authenticated;

create or replace function public.create_club_announcement(
  p_session_token uuid,
  p_title text,
  p_body text
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
  insert into public.club_announcements (title, body, author_id)
  values (trim(p_title), trim(p_body), v_me);
  return json_build_object('success', true);
end;
$$;

grant execute on function public.create_club_announcement(uuid, text, text) to anon, authenticated;

create or replace function public.delete_club_announcement(
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
  delete from public.club_announcements where id = p_announcement_id;
  return json_build_object('success', true);
end;
$$;

grant execute on function public.delete_club_announcement(uuid, uuid) to anon, authenticated;


create table if not exists public.school_events (
  id          uuid primary key default gen_random_uuid(),
  title       text not null check (char_length(title) between 1 and 120),
  description text,
  event_date  date not null,
  location    text,
  created_at  timestamptz not null default now(),
  created_by  uuid references public.members(id) on delete set null
);

create index if not exists school_events_date_idx on public.school_events (event_date);

alter table public.school_events enable row level security;

drop policy if exists "school_events readable" on public.school_events;
create policy "school_events readable" on public.school_events
  for select using (true);

grant select on public.school_events to anon, authenticated;

create or replace function public.create_school_event(
  p_session_token uuid,
  p_title text,
  p_event_date date,
  p_description text default null,
  p_location text default null
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
  insert into public.school_events (title, description, event_date, location, created_by)
  values (trim(p_title), nullif(trim(coalesce(p_description, '')), ''), p_event_date, nullif(trim(coalesce(p_location, '')), ''), v_me);
  return json_build_object('success', true);
end;
$$;

grant execute on function public.create_school_event(uuid, text, date, text, text) to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 4. SEASON RESET — make it real
-- ═══════════════════════════════════════════════════════════════════
-- Replaces schema-additions-v2-rework.sql's admin_start_new_season,
-- which only ever inserted the season_resets row and left every
-- other step (§5 of the plan) as a bare SQL comment. This version
-- actually does all five steps, in order, in one transaction (a
-- function body IS the transaction — if any step raises, everything
-- rolls back).
--
-- p_legacy_data shape (built client-side in AdminView.vue):
--   [
--     {
--       "member_id": "<uuid>",
--       "final_threads_score": 1734.2,
--       "best_badges": [{ "badge_id": "shakespeare", "value": 42 }, ...],  -- up to 3
--       "best_works": [{ "work_id": "<uuid>", "title": "..." }, ...]        -- up to 2
--     },
--     ...
--   ]
create or replace function public.admin_start_new_season(
  p_session_token uuid,
  p_season_number integer,
  p_legacy_data jsonb default '[]'
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := public._resolve_member_id(p_session_token);
  v_role     text;
  v_entry    jsonb;
begin
  if v_admin_id is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select site_role into v_role from public.members where id = v_admin_id;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  if p_season_number is null or p_season_number < 1 then
    return json_build_object('success', false, 'message', 'Season number must be a positive integer.');
  end if;

  -- 1. Legacy records — written BEFORE anything is wiped.
  for v_entry in select * from jsonb_array_elements(coalesce(p_legacy_data, '[]'::jsonb))
  loop
    insert into public.legacy_records (member_id, season_number, final_threads_score, best_badges, best_works)
    values (
      (v_entry->>'member_id')::uuid,
      p_season_number,
      nullif(v_entry->>'final_threads_score', '')::numeric,
      coalesce(v_entry->'best_badges', '[]'::jsonb),
      coalesce(v_entry->'best_works', '[]'::jsonb)
    )
    on conflict (member_id, season_number) do update
      set final_threads_score = excluded.final_threads_score,
          best_badges         = excluded.best_badges,
          best_works          = excluded.best_works;
  end loop;

  -- 2. Wipe scores (every badge).
  delete from public.scores;

  -- 3. Reset Bits ratings to the documented defaults.
  update public.member_domain_ratings
  set domain_arts = 1500, deviation_arts = 350, volatility_arts = 0.06,
      domain_tech = 1500, deviation_tech = 350, volatility_tech = 0.06,
      domain_digital = 1500, deviation_digital = 350, volatility_digital = 0.06,
      updated_at = now();

  -- 3b. Threads composite resets alongside Bits — a fresh season
  -- starts everyone back at the same baseline score the table's own
  -- default already documents.
  update public.threads
  set score = 1500,
      ping_factor = 0.2, bandwidth_factor = 0.2, flops_factor = 0.2,
      commits_factor = 0.2, hertz_factor = 0.2,
      last_updated = now();

  -- 4. Clear Works, except the ones already flagged as legacy.
  delete from public.works where is_legacy = false;

  -- 5. Archive Contributions. Per the plan's own §5 judgment call:
  -- every Contribution is also a Work, and Works don't survive the
  -- reset, so this pass also archives everything that isn't already
  -- archived rather than leaving orphaned rows behind.
  update public.contributions set status = 'archived' where status <> 'archived';

  -- Record the reset itself, now that every step above succeeded.
  insert into public.season_resets (season_number, reset_by, notes)
  values (p_season_number, v_admin_id, format('%s legacy record(s) preserved', jsonb_array_length(coalesce(p_legacy_data, '[]'::jsonb))));

  return json_build_object('success', true, 'message', 'Season reset complete.');
end;
$$;

grant execute on function public.admin_start_new_season(uuid, integer, jsonb) to anon, authenticated;


/* ── RESET PREVIEW — real counts for the "will affect" panel ────────
   AdminView.vue's resetPreview was hardcoded to zeros. This gives it
   something real to show before the admin confirms. */
create or replace function public.admin_get_reset_preview(p_session_token uuid)
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
    'scores_wiped', (select count(*) from public.scores),
    'works_wiped', (select count(*) from public.works where is_legacy = false),
    'contributions_archived', (select count(*) from public.contributions where status <> 'archived')
  );
end;
$$;

grant execute on function public.admin_get_reset_preview(uuid) to anon, authenticated;
