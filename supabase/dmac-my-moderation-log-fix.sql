/* ═══════════════════════════════════════════════════════════════════
   dmac-my-moderation-log-fix.sql
   Gives a member a way to read their OWN moderation history.

   moderation_log has existed since dmac-member-auth-schema.sql and
   member_moderate() has been writing to it the whole time (warn /
   silence / unsilence), but nothing was ever built to read it back:

   1. RLS is enabled on moderation_log with a blanket
      `grant select ... to authenticated` and NO policy at all — with
      RLS on and zero permissive policies, that grant is a no-op and
      every select returns zero rows for everyone, Tier B (Google/
      auth.uid()) included.
   2. Even if a policy existed, "authenticated" only ever covers Tier B
      (real Supabase Auth JWT / auth.uid()). Tier A members (password-
      only, session_token in localStorage) have no auth.uid() at all,
      so a policy keyed off it wouldn't help them either — same
      reason every other privileged read/write in this app goes
      through a SECURITY DEFINER RPC keyed off p_session_token instead
      of raw table grants (see member_moderate itself, or
      list_friends/list_friend_requests for the same shape).

   This is exactly why the Notifications panel's "Warnings" section
   in RightPanel.vue has been a hardcoded "Nothing here — good" the
   whole time — there was no way to ask the database, so it just
   never asked.

   Adds ONE new function, no table/column changes:
     list_my_moderation_log(p_session_token uuid)
       → { success, entries: [{ action, reason, created_at,
            actor_name }, ...] }, newest first, capped at 50.
   Returns entries targeting the CALLING member only (matched via
   their own session token, same as every other "list my ___" RPC
   here) — there is no way to pass someone else's slug in and read
   their log through this function.

   Run this in the Supabase Dashboard → SQL Editor, after
   dmac-moderation-silence-enforcement.sql. Safe to re-run.
   ═══════════════════════════════════════════════════════════════════ */

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
