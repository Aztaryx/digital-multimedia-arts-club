/* ═══════════════════════════════════════════════════════════════════
   dmac-service-role-grants-fix.sql
   upload-profile-image runs as service_role on purpose — that's what
   lets it write Storage for password-only members who have no
   auth.uid() to satisfy normal Storage RLS. But service_role was
   never actually granted EXECUTE on the two RPCs it calls:
   _resolve_member_id and member_update_profile were only ever granted
   to anon/authenticated. Since this project revokes the default
   PUBLIC execute grant on every new function (that's why every RPC in
   every file here ends with its own explicit `grant execute` line),
   service_role never picked up access implicitly either — it needs
   its own explicit grant, same as anon/authenticated do.

   The Edge Function's own comments already flagged this exact
   requirement ("see the addendum SQL") — it just never actually got
   written down anywhere. This is that missing piece.

   Run any time after dmac-profile-sync-fix.sql and
   social-schema-addendum.sql.
   ═══════════════════════════════════════════════════════════════════ */

grant execute on function public._resolve_member_id(uuid) to service_role;
grant execute on function public.member_update_profile(uuid, text, text, text, text, jsonb) to service_role;
