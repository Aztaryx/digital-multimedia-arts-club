/* ═══════════════════════════════════════════════════════════════════
   dmac-badges-batch-2.sql
   Schema + RPC changes for the 20-badge rollout (see
   dmac-badge-implementation-plan.md, Part 4). Everything else about
   that rollout — the other 18 badge_ids, art, flavor text — is
   content/client-code, not schema; this file only covers the three
   pieces that actually need new SQL:

     1. Inseparable's named-pair mechanic — one new column, one
        updated RPC.
     2. Whoops. and h4h4 n00b!'s self-serve award path — a brand new
        RPC, since a visitor awarding *themselves* a badge is a
        different trust boundary than admin_upsert_score().

   Completionist / The True Completionist! need NO schema at all —
   they're computed client-side off existing scores rows (see
   getCompletionStatus() in lib/leaderboard.js). New Game needs no
   schema either — it's awarded through the existing admin_upsert_score()
   as an ordinary issue-tracked badge, issue_number = join order.

   Run this in the Supabase Dashboard → SQL Editor, after
   dmac-admin-score-writing.sql (this replaces admin_upsert_score(),
   so that file must have run first) and dmac-profile-sync-fix.sql
   (needs _resolve_member_id). Safe to re-run — every step below is
   idempotent.
   ═══════════════════════════════════════════════════════════════════ */

-- ── 1. PARTNER COLUMN ────────────────────────────────────────────────
-- Nullable, only used by badges that want a named-pair mechanic
-- (Inseparable today, possibly others later). A member can only be
-- paired with one other real member per row — set null (unpaired) if
-- that member ever leaves; deleting them shouldn't take the badge
-- itself down with it, hence `on delete set null` rather than cascade.
alter table public.scores
  add column if not exists partner_member_id uuid references public.members(id) on delete set null;

create index if not exists scores_partner_member_id_idx on public.scores (partner_member_id);

-- ── 2. ADMIN_UPSERT_SCORE() — ADD p_partner_slug ─────────────────────
-- CREATE OR REPLACE can't just add a parameter to the existing 6-arg
-- function without leaving two overloads behind (Postgres treats a
-- different argument list as a distinct function) — drop the old
-- signature explicitly first so there's only ever one
-- admin_upsert_score() in the schema, matching every other RPC here.
drop function if exists public.admin_upsert_score(uuid, text, text, numeric, int, date);

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

-- ── 3. CLAIM_SECRET_BADGE() — SELF-SERVE, ALLOW-LISTED ───────────────
-- A visitor awarding *themselves* a badge is a different trust
-- boundary than admin_upsert_score() — this is deliberately its own
-- function, not a relaxed version of that one:
--   * only ever writes one of a small hardcoded allow-list of
--     badge_ids — never an arbitrary caller-supplied one
--   * explicitly checks for (and rejects) a repeat claim BEFORE
--     computing the next issue_number, so a second call can't insert
--     a new row with a fresh issue_number — the unique index below is
--     a backstop for a race between two near-simultaneous calls, not
--     the primary guard
--   * requires a logged-in member (Tier A or B) — there's no guest
--     version of a badge
--
-- Worth knowing: the 404 route and the Konami-code listener are UI
-- gating, not security. Any logged-in member could open devtools and
-- call this RPC directly, skipping the actual easter egg entirely.
-- That's an accepted, low-stakes tradeoff for playful secret badges —
-- not something this function tries to prevent.
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
  -- the partial unique index (badge_id, member_id, issue_number)
  -- from dmac-admin-score-writing.sql caught it. Same graceful
  -- response as the ordinary "already claimed" path.
  return json_build_object('success', false, 'message', 'Already claimed.');
end;
$$;

grant execute on function public.claim_secret_badge(uuid, text) to anon, authenticated;
