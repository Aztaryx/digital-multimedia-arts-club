/* ═══════════════════════════════════════════════════════════════════
   schema-additions-v2-rework.sql — DMAC Rework Phase 2
   ═══════════════════════════════════════════════════════════════════
   New tables and functions for Bits/Threads/Contributions/Works system.
   Run AFTER base schema.sql, before launching the rework.
   
   CHANGES TO EXISTING TABLES:
   - members.site_role: ('member', 'moderator', 'admin') → ('member', 'admin')
   - Remove all forum-related tables/functions (§1–2)
   - Remove moderator-specific RPC gating (§3)
   
   NEW TABLES:
   - member_domain_ratings (Bits system, §4)
   - threads (Threads score, §5)
   - contributions (logged contributions, §6)
   - works (member portfolio, §7)
   - events (club events calendar, §8)
   - club_announcements (club news, separate from newsletters, §9)
   - school_events (calendar events, §10)
   - season_resets (history of season resets, §11)
   - legacy_records (preserved best badges/works per member, §11)
   ═══════════════════════════════════════════════════════════════════ */


-- ═══════════════════════════════════════════════════════════════════
-- STEP 1: UPDATE EXISTING members TABLE
-- ═══════════════════════════════════════════════════════════════════
-- Remove forum tables and functions (they will be replaced)
-- and update site_role constraint

-- 1a. First, convert any moderator roles to admin (required before adding new constraint)
UPDATE public.members SET site_role = 'admin' WHERE site_role = 'moderator';

-- 1b. Drop the old constraint that allows moderator
ALTER TABLE public.members DROP CONSTRAINT members_site_role_check;

-- 1c. Add new constraint that only allows member and admin
ALTER TABLE public.members ADD CONSTRAINT members_site_role_check
  CHECK (site_role in ('member', 'admin'));


-- ═══════════════════════════════════════════════════════════════════
-- 2. MEMBER_DOMAIN_RATINGS — Bits system (Glicko-2)
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.member_domain_ratings (
  id              uuid primary key default gen_random_uuid(),
  member_id       uuid not null unique references public.members(id) on delete cascade,
  domain_arts     numeric not null default 1500,        -- Arts Bits
  domain_tech     numeric not null default 1500,        -- Tech Bits
  domain_digital  numeric not null default 1500,        -- Digital Bits
  deviation_arts    numeric not null default 350,
  deviation_tech    numeric not null default 350,
  deviation_digital numeric not null default 350,
  volatility_arts    numeric not null default 0.06,
  volatility_tech    numeric not null default 0.06,
  volatility_digital numeric not null default 0.06,
  updated_at      timestamptz not null default now()
);

alter table public.member_domain_ratings enable row level security;
create policy "member_domain_ratings are readable" on public.member_domain_ratings
  for select using (true);
grant select on public.member_domain_ratings to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 3. THREADS — member's rolling 90-day composite score
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.threads (
  id              uuid primary key default gen_random_uuid(),
  member_id       uuid not null unique references public.members(id) on delete cascade,
  score           numeric not null default 1500,        -- composite, 0–3000
  ping_factor     numeric not null default 0.2,        -- weighted components
  bandwidth_factor numeric not null default 0.2,
  flops_factor    numeric not null default 0.2,
  commits_factor  numeric not null default 0.2,
  hertz_factor    numeric not null default 0.2,
  last_updated    timestamptz not null default now()
);

alter table public.threads enable row level security;
create policy "threads are readable" on public.threads
  for select using (true);
grant select on public.threads to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 4. CONTRIBUTIONS — logged by staff, queued as drafts, submitted in batch
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.contributions (
  id              uuid primary key default gen_random_uuid(),
  member_id       uuid not null references public.members(id) on delete cascade,
  domain          text not null check (domain in ('Arts', 'Tech', 'Digital')),
  weight          numeric not null default 1.0,         -- multiplier
  quality         text not null check (quality in ('low', 'medium', 'high')),
  description     text,
  contributor_splits jsonb not null default '{}',      -- {member_id: percent, ...}
  status          text not null default 'draft' check (status in ('draft', 'submitted', 'archived')),
  created_at      timestamptz not null default now(),
  submitted_at    timestamptz,
  created_by      uuid references public.members(id) on delete set null
);

create index contributions_member_idx on public.contributions (member_id);
create index contributions_status_idx on public.contributions (status);

alter table public.contributions enable row level security;
create policy "contributions readable by admins" on public.contributions
  for select using (exists(select 1 from public.members where id = auth.uid() and site_role = 'admin'));
grant select on public.contributions to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 5. WORKS — member portfolio entries (cleared each season except legacy)
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.works (
  id              uuid primary key default gen_random_uuid(),
  member_id       uuid not null references public.members(id) on delete cascade,
  title           text not null,
  description     text,
  link            text,                                 -- portfolio link / GitHub / Figma / etc.
  image_url       text,
  is_legacy       boolean not null default false,       -- survives season resets if true
  created_at      timestamptz not null default now()
);

create index works_member_idx on public.works (member_id);
create index works_is_legacy_idx on public.works (is_legacy);

alter table public.works enable row level security;
create policy "works readable by all" on public.works
  for select using (true);
grant select on public.works to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 6. EVENTS — club events / competitions / assemblies
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.events (
  id              uuid primary key default gen_random_uuid(),
  title           text not null,
  description     text,
  event_date      date not null,
  location        text,
  event_type      text check (event_type in ('competition', 'assembly', 'meeting', 'showcase', 'other')),
  created_at      timestamptz not null default now(),
  created_by      uuid references public.members(id) on delete set null
);

create index events_event_date_idx on public.events (event_date);

alter table public.events enable row level security;
create policy "events readable by all" on public.events
  for select using (true);
grant select on public.events to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 7. CLUB_ANNOUNCEMENTS — separate from newsletters (site/dev journal)
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.club_announcements (
  id              uuid primary key default gen_random_uuid(),
  title           text not null check (char_length(title) between 1 and 120),
  body            text not null check (char_length(body) between 1 and 2000),
  created_at      timestamptz not null default now(),
  author_id       uuid references public.members(id) on delete set null
);

alter table public.club_announcements enable row level security;
create policy "club_announcements readable" on public.club_announcements
  for select using (true);
grant select on public.club_announcements to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 8. SCHOOL_EVENTS — listing of actual school events the club covers
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.school_events (
  id              uuid primary key default gen_random_uuid(),
  title           text not null check (char_length(title) between 1 and 120),
  description     text,
  event_date      date not null,
  location        text,
  created_at      timestamptz not null default now(),
  created_by      uuid references public.members(id) on delete set null
);

create index school_events_date_idx on public.school_events (event_date);

alter table public.school_events enable row level security;
create policy "school_events readable" on public.school_events
  for select using (true);
grant select on public.school_events to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 9. SEASON_RESETS — history of season resets with metadata
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.season_resets (
  id              uuid primary key default gen_random_uuid(),
  season_number   integer not null,
  reset_at        timestamptz not null default now(),
  reset_by        uuid not null references public.members(id) on delete restrict,
  notes           text
);

alter table public.season_resets enable row level security;
create policy "season_resets readable by admins" on public.season_resets
  for select using (exists(select 1 from public.members where id = auth.uid() and site_role = 'admin'));
grant select on public.season_resets to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 10. LEGACY_RECORDS — best badges/works per member, preserved across resets
-- ═══════════════════════════════════════════════════════════════════
create table if not exists public.legacy_records (
  id                  uuid primary key default gen_random_uuid(),
  member_id           uuid not null references public.members(id) on delete cascade,
  season_number       integer not null,
  final_threads_score numeric,                          -- their Threads standing at reset time
  best_badges         jsonb not null default '[]',      -- [{badge_id, value}, ...]
  best_works          jsonb not null default '[]',      -- [{work_id, title}, ...]
  created_at          timestamptz not null default now(),
  constraint legacy_one_per_member_season unique(member_id, season_number)
);

alter table public.legacy_records enable row level security;
create policy "legacy_records readable" on public.legacy_records
  for select using (true);
grant select on public.legacy_records to anon, authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- 11. NEW FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

/* ── LOG CONTRIBUTION (admin/staff only) ──────────────────────────── */
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

  if p_domain not in ('Arts', 'Tech', 'Digital') then
    return json_build_object('success', false, 'message', 'Invalid domain.');
  end if;

  insert into public.contributions (member_id, domain, weight, quality, description, contributor_splits, created_by)
  values (p_member_id, p_domain, p_weight, p_quality, p_description, p_contributor_splits, v_admin_id)
  returning id into v_contribution_id;

  return json_build_object('success', true, 'contribution_id', v_contribution_id);
end;
$$;

grant execute on function public.admin_log_contribution(uuid, uuid, text, numeric, text, text, jsonb) to anon, authenticated;


/* ── START NEW SEASON (admin only) ───────────────────────────────── */
create or replace function public.admin_start_new_season(
  p_session_token uuid,
  p_season_number integer,
  p_legacy_data jsonb default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := public._resolve_member_id(p_session_token);
  v_role text;
begin
  if v_admin_id is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select site_role into v_role from public.members where id = v_admin_id;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  -- 1. Create season reset record
  insert into public.season_resets (season_number, reset_by)
  values (p_season_number, v_admin_id);

  -- 2. Save legacy records (should be passed as JSON from admin panel)
  -- INSERT INTO legacy_records from p_legacy_data...

  -- 3. Clear scores (wipe scores table)
  delete from public.scores;

  -- 4. Reset Bits ratings
  update public.member_domain_ratings
  set domain_arts = 1500, deviation_arts = 350, volatility_arts = 0.06,
      domain_tech = 1500, deviation_tech = 350, volatility_tech = 0.06,
      domain_digital = 1500, deviation_digital = 350, volatility_digital = 0.06,
      updated_at = now();

  -- 5. Clear Works (keep legacy ones)
  delete from public.works where is_legacy = false;

  -- 6. Archive Contributions
  update public.contributions set status = 'archived' where status != 'archived';

  return json_build_object('success', true, 'message', 'Season reset complete.');
end;
$$;

grant execute on function public.admin_start_new_season(uuid, integer, jsonb) to anon, authenticated;


/* ── LIST CONTRIBUTIONS (admin + filtering) ───────────────────────── */
create or replace function public.admin_list_contributions(
  p_session_token uuid,
  p_status text default null,
  p_limit integer default 100
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := public._resolve_member_id(p_session_token);
  v_role text;
begin
  if v_admin_id is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select site_role into v_role from public.members where id = v_admin_id;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  return json_build_object(
    'success', true,
    'contributions', (
      select coalesce(
        json_agg(row_to_json(x) order by x.created_at desc),
        '[]'::json
      )
      from (
        select
          c.id, c.member_id, m.display_name, c.domain, c.weight, c.quality,
          c.description, c.status, c.created_at
        from public.contributions c
        join public.members m on m.id = c.member_id
        where (p_status is null or c.status = p_status)
        order by c.created_at desc
        limit greatest(coalesce(p_limit, 100), 1)
      ) x
    )
  );
end;
$$;

grant execute on function public.admin_list_contributions(uuid, text, integer) to anon, authenticated;
