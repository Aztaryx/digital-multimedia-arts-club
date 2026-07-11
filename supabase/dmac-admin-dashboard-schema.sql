/* ═══════════════════════════════════════════════════════════════════
   dmac-admin-dashboard-schema.sql
   Turns the Admin Panel from "announcements + maintenance" into an
   actual dashboard: sitewide moderation visibility + role management.
   No table changes — everything below is new RPCs on tables that
   already exist.

   Two real gaps this closes:

   1. moderation_log has been write-only from the app's side. Same
      root cause dmac-my-moderation-log-fix.sql already documented for
      a member reading their OWN log (RLS on, zero policies, and the
      blanket `grant select ... to authenticated` is a no-op for Tier A
      sessions anyway) — except admins need to see EVERYONE's history,
      not just their own, which list_my_moderation_log deliberately
      doesn't do (it hard-scopes to the caller via target_id = v_me).
      `admin_list_moderation_log()` is the admin-scoped sibling: same
      shape, no target_id filter, plus the target's name so an admin
      can tell who each entry is about.

   2. site_role (member / moderator / admin) has had no write path at
      all since it was introduced in dmac-member-auth-schema.sql —
      every promotion/demotion has been a hand-edit in the Supabase
      Table Editor. `admin_set_role()` follows the exact
      _resolve_member_id() + site_role='admin' gate every other admin
      RPC here uses (see admin_upsert_score in
      dmac-admin-score-writing.sql), with one extra safety check: it
      refuses to demote the last remaining admin, so a slip of the
      dropdown can't lock everyone out of the admin panel at once.

   Stats for the new Overview tab need nothing new — members, scores,
   announcements, forum_threads, and forum_posts have all been
   publicly SELECT-able since their respective schema files, so the
   client just runs head-count queries against them directly.

   Run this in the Supabase Dashboard → SQL Editor, after
   dmac-moderation-silence-enforcement.sql (needs member_moderate's
   silence columns/shape) and dmac-admin-score-writing.sql (same
   admin-gate pattern). Safe to re-run.
   ═══════════════════════════════════════════════════════════════════ */

-- ── 1. ADMIN-WIDE MODERATION LOG ────────────────────────────────────
create or replace function public.admin_list_moderation_log(
  p_session_token uuid,
  p_limit         integer default 100
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

  -- LIMIT on a bare aggregate query (no GROUP BY) doesn't actually
  -- cap how many rows feed json_agg — the aggregate always collapses
  -- to one output row, so LIMIT n≥1 is a no-op there. Capping for
  -- real means limiting an inner row set first, then aggregating that.
  return json_build_object(
    'success', true,
    'entries', (
      select coalesce(json_agg(row_to_json(x) order by x.created_at desc), '[]'::json)
      from (
        select
          ml.id, ml.action, ml.reason, ml.created_at,
          a.slug as actor_slug, a.display_name as actor_name,
          t.slug as target_slug, t.display_name as target_name
        from public.moderation_log ml
        join public.members a on a.id = ml.actor_id
        join public.members t on t.id = ml.target_id
        order by ml.created_at desc
        limit greatest(coalesce(p_limit, 100), 1)
      ) x
    )
  );
end;
$$;

grant execute on function public.admin_list_moderation_log(uuid, integer) to anon, authenticated;


-- ── 2. ROLE MANAGEMENT ──────────────────────────────────────────────
create or replace function public.admin_set_role(
  p_session_token uuid,
  p_target_slug   text,
  p_new_role      text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me       uuid := public._resolve_member_id(p_session_token);
  v_role     text;
  v_target   public.members%rowtype;
  v_admins   integer;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select site_role into v_role from public.members where id = v_me;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  if p_new_role not in ('member', 'moderator', 'admin') then
    return json_build_object('success', false, 'message', 'Unknown role.');
  end if;

  select * into v_target from public.members where slug = p_target_slug;
  if v_target.id is null then
    return json_build_object('success', false, 'message', 'No member with that slug.');
  end if;

  -- Refuse to demote the last admin — otherwise a single wrong click
  -- locks every admin route (requiresAdmin in router/index.js) away
  -- from everyone, with no in-app way back in.
  if v_target.site_role = 'admin' and p_new_role <> 'admin' then
    select count(*) into v_admins from public.members where site_role = 'admin';
    if v_admins <= 1 then
      return json_build_object('success', false, 'message', 'Can''t remove the last remaining admin.');
    end if;
  end if;

  update public.members set site_role = p_new_role where id = v_target.id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.admin_set_role(uuid, text, text) to anon, authenticated;
