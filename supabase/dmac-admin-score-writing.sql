/* ═══════════════════════════════════════════════════════════════════
   dmac-admin-score-writing.sql
   Moves score-writing into the app itself, gated by members.site_role
   the same way every other privileged write here works (SECURITY
   DEFINER RPC keyed off p_session_token — see create_announcement()
   in dmac-site-polish-schema.sql for the pattern this copies).

   This was flagged, not done, in dmac-scores-members-link.sql's own
   header: the "Officers can insert/update/delete scores" RLS
   policies from dmac-social-schema-core.sql still key off the old
   Tier-B-only `profiles.role = 'officer'` / auth.uid() scheme, which
   a Tier A (password-only) admin can't satisfy — same root cause as
   every other "list/write my ___" gap this project's fixed the same
   way. Scores have otherwise only ever been edited by hand in the
   Supabase Table Editor (service role, bypasses RLS) until now.

   WHAT THIS DOES
   ------------------------------------------------------------------
   1. `scores.legacy_member_id` (the old text FK, renamed in
      dmac-scores-members-link.sql) loses its NOT NULL — a score
      written through this new RPC for a member who only ever existed
      in the new `members` scheme has no legacy `profiles` row to
      point at, and forcing one would mean inventing fake legacy data.
      The column, its data, and its FK to `profiles(member_id)` all
      stay exactly as they are for every pre-existing row.
   2. Two new partial unique indexes on the real `member_id` uuid
      column — one for ordinary badges (one row per member per badge),
      one for issue-tracked/secret badges (one row per member per
      badge per issue_number) — so admin_upsert_score() below can
      ON CONFLICT ... DO UPDATE cleanly instead of accumulating
      duplicate rows every time a value gets corrected. Mirrors the
      original `scores_member_badge_uniq` index (still in place,
      still covering `legacy_member_id`, untouched).
   3. `admin_upsert_score()` — insert a new score, or update the
      existing one for that exact (member, badge[, issue_number])
      combo. Admins only. Updating an existing row also bumps
      `created_at` to now() on purpose: RightPanel's badge-notification
      checkBadges() (lib/notifications.js) uses `created_at` as its
      "is this new?" signal, and a corrected value is exactly the kind
      of change worth re-surfacing to the member as a toast.
   4. `admin_delete_score()` — removes a single row by id. Admins only.

   Both RPCs return the plain `{ success, message? }` shape every
   other admin RPC here does. Listing/reading scores needs nothing
   new — `scores` has been publicly SELECT-able since
   dmac-social-schema-core.sql, so the admin panel just queries the
   table directly the same way lib/leaderboard.js's fetchScores() does.

   Run this in the Supabase Dashboard → SQL Editor, after
   dmac-scores-members-link.sql (needs the real `member_id` column)
   and dmac-site-polish-schema.sql (needs `_resolve_member_id`). Safe
   to re-run — every step below is idempotent.
   ═══════════════════════════════════════════════════════════════════ */

-- ── 1. LEGACY COLUMN NO LONGER REQUIRED ─────────────────────────────
alter table public.scores alter column legacy_member_id drop not null;

-- ── 2. REAL-SCHEME UNIQUE INDEXES ───────────────────────────────────
-- Ordinary badges: one row per (badge, member). NULLs in a partial
-- unique index are never considered equal to each other, so this
-- can't conflict with the still-unlinked (member_id is null) rows
-- dmac-scores-members-link.sql's auto-backfill left behind.
create unique index if not exists scores_member_id_badge_uniq
  on public.scores (badge_id, member_id)
  where issue_number is null;

-- Issue-tracked/secret badges: one row per (badge, member, issue).
create unique index if not exists scores_member_id_badge_issue_uniq
  on public.scores (badge_id, member_id, issue_number)
  where issue_number is not null;

-- ── 3. UPSERT ────────────────────────────────────────────────────────
create or replace function public.admin_upsert_score(
  p_session_token uuid,
  p_member_slug   text,
  p_badge_id      text,
  p_value         numeric,
  p_issue_number  int  default null,
  p_awarded_on    date default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     uuid := public._resolve_member_id(p_session_token);
  v_role   text;
  v_target uuid;
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

  if p_issue_number is null then
    insert into public.scores (badge_id, member_id, value, awarded_on, created_by)
    values (trim(p_badge_id), v_target, p_value, coalesce(p_awarded_on, current_date), v_me)
    on conflict (badge_id, member_id) where issue_number is null
    do update set
      value      = excluded.value,
      awarded_on = excluded.awarded_on,
      created_by = excluded.created_by,
      created_at = now();
  else
    insert into public.scores (badge_id, member_id, value, issue_number, awarded_on, created_by)
    values (trim(p_badge_id), v_target, p_value, p_issue_number, coalesce(p_awarded_on, current_date), v_me)
    on conflict (badge_id, member_id, issue_number) where issue_number is not null
    do update set
      value      = excluded.value,
      awarded_on = excluded.awarded_on,
      created_by = excluded.created_by,
      created_at = now();
  end if;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.admin_upsert_score(uuid, text, text, numeric, int, date) to anon, authenticated;

-- ── 4. DELETE ────────────────────────────────────────────────────────
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
