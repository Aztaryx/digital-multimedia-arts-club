/* ═══════════════════════════════════════════════════════════════════
   dmac-notifications-panel-fixes.sql
   Two admin-reported gaps in the notifications system:

   1. "Announcement Notif no sfx and popup" — list_unseen_notifications()
      only ever returned `kind = 'maintenance'` rows (under the
      `maintenance` key). Regular (`kind = 'announcement'`) posts were
      never part of the poll payload at all, so they could never
      become a toast — no popup, no sfx, nothing — even though they've
      always shown up fine in the Notifications panel itself
      (RightPanel.vue queries the `announcements` table directly,
      kind-agnostic, so the panel was never the problem). This adds a
      second `announcements` key alongside the existing `maintenance`
      one, carrying the same shape. Client wiring is in
      src/lib/notifications.js (new `announcement` NOTIF_TYPES entry +
      a poll loop for it) and needs no further schema work.

   2. "Forum Update Notifs not saving" — unlike warnings/silences/
      friend-requests (all backed by a real table RightPanel.vue can
      re-query any time), a forum-reply toast had nothing behind it:
      dismiss it, or miss it while the tab was closed, and it was gone
      for good — no way to review "what did I miss" on a followed
      thread. list_my_followed_thread_activity() below is a real,
      re-queryable read over forum_thread_follows + forum_posts (same
      session-token RPC pattern as everything else here), so
      RightPanel.vue can show a persistent "Forum" section instead of
      only ever showing whatever toast happened to still be on screen.

   Run this after dmac-notifications-schema.sql (needs
   forum_thread_follows, _resolve_member_id). Safe to re-run.
   ═══════════════════════════════════════════════════════════════════ */

-- ── 1. ANNOUNCEMENTS IN THE POLL PAYLOAD ────────────────────────────
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

    -- Public — no login required, guests get these toasts too.
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

    -- NEW — same story as maintenance above, just the other `kind`.
    -- Previously missing entirely, which is why regular announcements
    -- never got a toast/sfx (see file header, item 1).
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
    ) end),

    'friend_requests', (case when v_me is null then '[]'::json else (
      select coalesce(
        json_agg(json_build_object(
          'slug', req.slug, 'display_name', req.display_name, 'created_at', f.created_at
        ) order by f.created_at),
        '[]'::json
      )
      from public.friendships f
      join public.members req on req.id = f.requester_id
      where f.addressee_id = v_me and f.status = 'pending' and f.created_at > v_since
    ) end),

    'direct_messages', (case when v_me is null then '[]'::json else (
      select coalesce(
        json_agg(json_build_object(
          'from_slug', sender.slug,
          'from_name', sender.display_name,
          'from_banner_color', sender.banner_color,
          'body', dm.body,
          'created_at', dm.created_at
        ) order by dm.created_at),
        '[]'::json
      )
      from public.direct_messages dm
      join public.members sender on sender.id = dm.sender_id
      where dm.recipient_id = v_me and dm.created_at > v_since
    ) end),

    'forum_replies', (case when v_me is null then '[]'::json else (
      select coalesce(
        json_agg(json_build_object(
          'thread_id', p.thread_id,
          'thread_title', t.title,
          'author_name', author.display_name,
          'created_at', p.created_at
        ) order by p.created_at),
        '[]'::json
      )
      from public.forum_posts p
      join public.forum_thread_follows fol on fol.thread_id = p.thread_id and fol.member_id = v_me
      join public.forum_threads t on t.id = p.thread_id
      join public.members author on author.id = p.author_id
      where p.created_at > v_since and p.author_id != v_me
    ) end)
  );
end;
$$;

grant execute on function public.list_unseen_notifications(uuid, timestamptz) to anon, authenticated;

-- ── 2. PERSISTENT "FORUM" NOTIFICATIONS-PANEL SECTION ───────────────
-- Deliberately NOT filtered by "since a checkpoint" — this is meant to
-- be re-readable any time, same as list_my_moderation_log, not a
-- one-shot unseen-only poll. Capped at p_limit (default 20) newest
-- first.
create or replace function public.list_my_followed_thread_activity(
  p_session_token uuid,
  p_limit         int default 20
)
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
        json_agg(row_to_json(x) order by x.created_at desc),
        '[]'::json
      )
      from (
        select
          p.id,
          p.thread_id,
          t.title              as thread_title,
          author.display_name  as author_name,
          left(p.body, 140)    as excerpt,
          p.created_at
        from public.forum_posts p
        join public.forum_thread_follows fol on fol.thread_id = p.thread_id and fol.member_id = v_me
        join public.forum_threads t on t.id = p.thread_id
        join public.members author on author.id = p.author_id
        where p.author_id != v_me
        order by p.created_at desc
        limit greatest(coalesce(p_limit, 20), 1)
      ) x
    )
  );
end;
$$;

grant execute on function public.list_my_followed_thread_activity(uuid, int) to anon, authenticated;
