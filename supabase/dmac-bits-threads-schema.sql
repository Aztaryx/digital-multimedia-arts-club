/* ═══════════════════════════════════════════════════════════════════
   dmac-bits-threads-schema.sql
   ═══════════════════════════════════════════════════════════════════
   Bits & Threads build — Phase 0 (domain tags), plus a prerequisite
   fix this phase surfaced: the club identity and bits-threads-spec.md
   both use three domains — Digital / Multimedia / Arts — but the
   already-live `member_domain_ratings` table (schema-additions-v2-
   rework.sql) and `contributions.domain` check constraint were built
   with Digital / Tech / Arts instead. This file renames Tech →
   Multimedia everywhere it's baked into the live schema, THEN adds
   Phase 0's `badge_domains` table on top of the corrected names.

   Corresponding frontend patches (not in this file, apply by hand):
     - src/lib/leaderboard.js       — add BADGE_DOMAINS export
     - src/views/LeaderboardView.vue — Factors tab reads domain_tech
       directly; must become domain_multimedia or it breaks the
       moment this migration runs
     - src/views/AdminView.vue      — Contribution Logging domain
       <select> still offers "Tech"
     - src/lib/contribution-logging.js — JSDoc says 'Tech'
   See the chat response this shipped with for the exact diffs.

   IDEMPOTENT BY DESIGN, same convention as
   dmac-forum-removal-and-role-merge.sql — every step checks the
   current state before acting, so this is safe to run against:
     - a database where domain_tech/contributions.domain still say
       "Tech" (the expected starting state)
     - a database where this file has already been run once
     - a database where the rename was already done by hand

   Run this AFTER schema.sql, schema-additions-v2-rework.sql, and
   dmac-forum-removal-and-role-merge.sql have all been run at least
   once — this migration assumes member_domain_ratings, contributions,
   threads, works, legacy_records, season_resets, and
   admin_start_new_season() already exist in their documented shapes.
   ═══════════════════════════════════════════════════════════════════ */


-- ═══════════════════════════════════════════════════════════════════
-- 1. RENAME member_domain_ratings' *_tech columns → *_multimedia
-- ═══════════════════════════════════════════════════════════════════
do $$
begin
  if to_regclass('public.member_domain_ratings') is not null then

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'member_domain_ratings'
        and column_name = 'domain_tech'
    ) then
      alter table public.member_domain_ratings rename column domain_tech to domain_multimedia;
    end if;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'member_domain_ratings'
        and column_name = 'deviation_tech'
    ) then
      alter table public.member_domain_ratings rename column deviation_tech to deviation_multimedia;
    end if;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'member_domain_ratings'
        and column_name = 'volatility_tech'
    ) then
      alter table public.member_domain_ratings rename column volatility_tech to volatility_multimedia;
    end if;

  end if;
end $$;


-- ═══════════════════════════════════════════════════════════════════
-- 2. contributions.domain — migrate data, then swap the check
--    constraint. Data migrated BEFORE the constraint swap so any
--    existing 'Tech' rows aren't left violating the new rule.
-- ═══════════════════════════════════════════════════════════════════
do $$
declare
  v_conname text;
begin
  if to_regclass('public.contributions') is not null then

    update public.contributions set domain = 'Multimedia' where domain = 'Tech';

    select conname into v_conname
    from pg_constraint
    where conrelid = 'public.contributions'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%Tech%';

    if v_conname is not null then
      execute format('alter table public.contributions drop constraint %I', v_conname);
      alter table public.contributions
        add constraint contributions_domain_check check (domain in ('Arts', 'Multimedia', 'Digital'));
    end if;

  end if;
end $$;


-- ═══════════════════════════════════════════════════════════════════
-- 3. RE-POINT FUNCTIONS THAT REFERENCE THE OLD NAMES
-- ═══════════════════════════════════════════════════════════════════

/* admin_log_contribution() — schema-additions-v2-rework.sql's domain
   validation still checked against 'Tech'. */
create or replace function public.admin_log_contribution(
  p_session_token uuid,
  p_member_id uuid,
  p_domain text,
  p_weight numeric default 1.0,
  p_quality text default 'medium',
  p_description text default null,
  p_contributor_splits jsonb default '{}'
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := public._resolve_member_id(p_session_token);
  v_role text;
  v_contribution_id uuid;
begin
  if v_admin_id is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select site_role into v_role from public.members where id = v_admin_id;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  if p_domain not in ('Arts', 'Multimedia', 'Digital') then
    return json_build_object('success', false, 'message', 'Invalid domain.');
  end if;

  insert into public.contributions (member_id, domain, weight, quality, description, contributor_splits, created_by)
  values (p_member_id, p_domain, p_weight, p_quality, p_description, p_contributor_splits, v_admin_id)
  returning id into v_contribution_id;

  return json_build_object('success', true, 'contribution_id', v_contribution_id);
end;
$$;

grant execute on function public.admin_log_contribution(uuid, uuid, text, numeric, text, text, jsonb) to anon, authenticated;


/* admin_start_new_season() — the "real" version from
   dmac-forum-removal-and-role-merge.sql §4 wrote directly to
   domain_tech/deviation_tech/volatility_tech during the Bits reset
   step. Re-created here, otherwise unchanged, against the renamed
   columns. */
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
      domain_multimedia = 1500, deviation_multimedia = 350, volatility_multimedia = 0.06,
      domain_digital = 1500, deviation_digital = 350, volatility_digital = 0.06,
      updated_at = now();

  -- 3b. Threads composite resets alongside Bits.
  update public.threads
  set score = 1500,
      ping_factor = 0.2, bandwidth_factor = 0.2, flops_factor = 0.2,
      commits_factor = 0.2, hertz_factor = 0.2,
      last_updated = now();

  -- 4. Clear Works, except legacy-flagged ones.
  delete from public.works where is_legacy = false;

  -- 5. Archive Contributions.
  update public.contributions set status = 'archived' where status <> 'archived';

  insert into public.season_resets (season_number, reset_by, notes)
  values (p_season_number, v_admin_id, format('%s legacy record(s) preserved', jsonb_array_length(coalesce(p_legacy_data, '[]'::jsonb))));

  return json_build_object('success', true, 'message', 'Season reset complete.');
end;
$$;

grant execute on function public.admin_start_new_season(uuid, integer, jsonb) to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 4. PHASE 0 — badge_domains
-- ═══════════════════════════════════════════════════════════════════
-- Backend's copy of the BADGE_DOMAINS constant that also needs adding
-- to src/lib/leaderboard.js — the Bits Edge Function (Phase 2) can't
-- import that file, so this table is the source of truth server-side.
-- domain is nullable — no-domain badges (social/meta/easter-egg) just
-- have a row with domain = null, same "exists but empty" convention
-- BADGE_FLAVOR already uses for entries with no flavor text.
create table if not exists public.badge_domains (
  badge_id text primary key,
  domain   text check (domain in ('Digital', 'Multimedia', 'Arts'))
);

alter table public.badge_domains enable row level security;

drop policy if exists "badge_domains are readable" on public.badge_domains;
create policy "badge_domains are readable" on public.badge_domains
  for select using (true);

-- Publicly readable, same as badge_labels-style metadata elsewhere —
-- no write grant at all; only ever seeded here, never client-written.
grant select on public.badge_domains to anon, authenticated;

-- Seed values per bits-threads-spec.md §3, with the corrections from
-- bits-threads-implementation-plan.md §0:
--   2fast4u      → no domain   (spec had guessed Multimedia, low confidence)
--   shakespeare  → Digital     (spec had guessed Multimedia, low confidence)
--   brick-placer → no domain   (spec had guessed Digital, low confidence)
-- Every other badge below matches the spec's table as originally
-- written. on conflict do nothing — idempotent, same convention
-- schema.sql's roster seed at the bottom uses.
insert into public.badge_domains (badge_id, domain) values
  ('speedtypist',      'Digital'),
  ('2fast4u',           null),
  ('shakespeare',       'Digital'),
  ('frame-by-frame',   'Multimedia'),
  ('reel-deal',         'Multimedia'),
  ('thumbnail-titan',  'Arts'),
  ('archivist',         'Digital'),
  ('initiate',          'Digital'),
  ('beta-tester',      'Digital'),
  ('brick-placer',      null),
  ('showed-up',        null),
  ('inseparable',       null),
  ('hive-mind',        null),
  ('whoops',            null),
  ('h4h4-n00b',        null),
  ('superstar',         null),
  ('day-one',          null),
  ('dethroned',         null),
  ('growth-spurt',     null),
  ('new-game',         null)
on conflict (badge_id) do nothing;