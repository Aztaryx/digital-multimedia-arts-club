/* ═══════════════════════════════════════════════════════════════════
   dmac-scores-members-link.sql
   THE actual "bug in badges" — not a front-end rendering bug at all.

   `scores.member_id` (dmac-social-schema-core.sql) has always pointed
   at `profiles.member_id`, a free-text field from the old Google-OAuth-
   only scheme, described in that file's own comment as a "placeholder;
   correct by hand in Table Editor once you know their real member_id."
   Nothing in the app was ever built to actually cross-reference that
   value against `members.slug` — the unified identity every other
   feature (forums, DMs, moderation, profiles) has used since
   dmac-member-auth-schema.sql. Two systems, never actually joined:

     scores.member_id → profiles.member_id → (nothing) → members.slug

   That's why the Members-page card overlay's `badges` array has
   always been the hardcoded `[]` sitting in MembersView.vue's EMPTY/
   MEMBERS objects, and why RightPanel.vue's Badges section has
   honestly said "not wired up yet" rather than faking a check — there
   was no live path from a logged-in member to a score row to check in
   the first place. This file builds that path:

     1. Renames the old text FK column to `legacy_member_id` (kept,
        not dropped — still real historical data, still fine to look
        at by hand in Table Editor).
     2. Adds a real `member_id uuid references members(id)` column.
     3. Best-effort, zero-risk auto-backfill: for any score row whose
        legacy_member_id happens to already equal a real members.slug
        (via the profiles row it's FK'd to) — which is exactly the
        "correct by hand" step that comment asked officers to do —
        link it automatically. Anything that doesn't match stays NULL;
        nothing is guessed or forced.
     4. Existing table-level `grant select on scores` already covers
        the new column — no new grants needed.

   WHAT YOU STILL NEED TO DO
   ------------------------------------------------------------------
   After running this, check how many rows actually got linked:

     select count(*) filter (where member_id is not null) as linked,
            count(*) filter (where member_id is null)     as unlinked
     from public.scores;

   Any `unlinked` rows are scores whose legacy_member_id never matched
   a real members.slug — those members just won't show badges until
   you fix it by hand, one time, in Table Editor:

     update public.scores set member_id = (select id from public.members where slug = '<their-slug>')
     where legacy_member_id = '<whatever their old profiles.member_id was>';

   Client-side changes (this same pass): lib/leaderboard.js now
   selects the embedded `members(slug)` relation this new FK enables,
   and returns `slug` on every leaderboard entry instead of only the
   opaque member_id. about/MembersView.vue now computes each opened
   member's `badges` array from a real `Leaderboard.getLeaderboard()`
   call matched by slug, instead of the static always-`[]` field.
   RightPanel.vue's Badges section is UNCHANGED in this pass — it
   still says "not wired up yet," because reading "did *I*, the
   logged-in member, earn anything new" needs a per-member identity
   check same as everything else here, and this file only builds the
   data link, not that check. Flag it if you want that section wired
   up next now that the link exists.

   NOT touched: the "Officers can insert/update/delete scores" RLS
   policies still key off `profiles.role = 'officer'` — a separate,
   still-live legacy scheme, since scores are managed by hand in Table
   Editor (service role, bypasses RLS anyway) rather than through the
   app. Flag it if you want score-writing moved into the app itself,
   gated by `members.site_role` the way everything else here is.

   Run this in the Supabase Dashboard → SQL Editor, after
   dmac-member-auth-schema.sql (needs `members`) and
   dmac-social-schema-core.sql (needs `scores`/`profiles`). Safe to
   re-run — every step below is idempotent.
   ═══════════════════════════════════════════════════════════════════ */

-- ── 1. RENAME THE OLD COLUMN (keeps the data, keeps its FK) ─────────
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'scores' and column_name = 'member_id'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'scores' and column_name = 'legacy_member_id'
  ) then
    alter table public.scores rename column member_id to legacy_member_id;
  end if;
end $$;

-- ── 2. ADD THE REAL, CURRENT-SCHEME COLUMN ──────────────────────────
alter table public.scores
  add column if not exists member_id uuid references public.members(id) on delete cascade;

-- ── 3. BEST-EFFORT AUTO-LINK ─────────────────────────────────────────
-- Only touches rows that are still unlinked, so this is safe to re-run
-- after someone's fixed a few by hand too — it won't stomp on those.
update public.scores s
set member_id = m.id
from public.profiles p
join public.members m on m.slug = p.member_id
where p.member_id = s.legacy_member_id
  and s.member_id is null;

create index if not exists scores_member_id_idx on public.scores (member_id);
