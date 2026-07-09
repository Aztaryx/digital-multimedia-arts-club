/* ═══════════════════════════════════════════════════════════════════
   dmac-profile-sync-fix.sql
   Two real bugs found while wiring the Members tab up to live profile
   edits:

   1. public._resolve_member_id(uuid) is CALLED by member_update_profile,
      send_direct_message, and get_conversation (dmac-social-schema.sql
      + social-schema-addendum.sql) but is never actually CREATEd
      anywhere in any of the SQL files. Every one of those three RPCs
      currently throws "function _resolve_member_id(uuid) does not
      exist" the moment it runs — meaning profile saves (and DMs) may
      be failing outright, not just failing to sync to the Members tab.

   2. nickname / bio / avatar_url / banner_url / banner_color /
      year_joined are referenced by
      member_update_profile as if they're columns on public.members,
      but no SQL file here ever ADDs them or GRANTs SELECT on them —
      only social_links got that treatment, in social-schema-addendum.
      If these were added by hand via the Table Editor at some point,
      the `add column if not exists` calls below are harmless no-ops.
      If they weren't, this is what's been silently missing. Either
      way, the explicit `grant select` at the end is the part that
      actually matters for MembersView to be able to read OTHER
      people's nicknames/bios/avatars, not just your own — RLS already
      allows reading every row (see "members are readable" policy),
      but column-level grants gate it further, same pattern as
      password_hash being deliberately withheld.

   Run this after social-schema-addendum.sql. Safe to re-run.
   ═══════════════════════════════════════════════════════════════════ */

-- ── 1. THE MISSING HELPER ──────────────────────────────────────────
-- Same session-token → member_id lookup member_change_own_password
-- and member_set_password already do inline via a join — just
-- factored out, which is clearly what the later files assumed existed.
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

grant execute on function public._resolve_member_id(uuid) to anon, authenticated;

-- ── 2. PROFILE COLUMNS + GRANTS ────────────────────────────────────
alter table public.members add column if not exists nickname   text;
alter table public.members add column if not exists bio        text;
alter table public.members add column if not exists avatar_url text;
alter table public.members add column if not exists banner_url text;
alter table public.members add column if not exists banner_color text not null default '#f97316';
alter table public.members add column if not exists year_joined  integer not null default 2026;

grant select (nickname, bio, avatar_url, banner_url, banner_color, year_joined)
  on public.members to anon, authenticated;
