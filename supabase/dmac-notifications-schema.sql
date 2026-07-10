/* ═══════════════════════════════════════════════════════════════════
   dmac-notifications-schema.sql
   Backend for the pop-up toast notifications (bottom-left, see
   src/composables/useNotifications.js on the client).

   WHY POLLING, NOT SUPABASE REALTIME
   ------------------------------------------------------------------
   direct_messages / friendships / moderation_log all gate their RLS
   policies on auth.uid() (see dmac-social-schema.sql,
   dmac-member-auth-schema.sql). auth.uid() only exists for Tier B
   (Google-linked) sessions — Tier A (password-only) members have no
   Postgres/Supabase-Auth session at all, just a session_token they
   pass by hand. That's exactly why list_friends/list_friend_requests/
   list_my_moderation_log exist as SECURITY DEFINER RPCs instead of
   plain table reads (see dmac-friend-requests-schema.sql and
   dmac-my-moderation-log-fix.sql for the same story). Supabase
   Realtime's postgres_changes feed is subject to the SAME RLS check
   as a normal select — so a raw realtime subscription to any of those
   tables would silently deliver zero rows to most members here, the
   same way a raw `.from(...).select()` would. Rather than add a
   second, differently-broken code path, notifications reuse the
   session-token RPC pattern this project already relies on: the
   client polls list_unseen_notifications() on an interval and gets
   everything relevant in one round trip.

   `announcements` (maintenance) IS publicly readable (`for select
   using (true)`, see dmac-site-polish-schema.sql) so it could use
   real Realtime — it's folded into the same RPC anyway so the client
   only has to run one poll loop instead of two.

   ADDS
   ------------------------------------------------------------------
   1. forum_thread_follows table — lets a member "follow" a thread so
      they get a toast when someone else replies to it. RPC-only, same
      access shape as member_sessions/moderation_log (RLS on, zero
      client-facing policies, all reads/writes go through the
      functions below).
   2. follow_forum_thread(p_session_token, p_thread_id)
   3. unfollow_forum_thread(p_session_token, p_thread_id)
   4. list_my_followed_thread_ids(p_session_token) → { success, thread_ids: [...] }
   5. list_unseen_notifications(p_session_token, p_since) → everything
      newer than p_since in one payload: maintenance posts, warnings,
      silences, incoming friend requests, direct messages (with the
      sender's banner_color for the DM toast outline), and replies on
      followed threads. Works even with p_session_token = null (guests
      still get `maintenance`; everything else comes back empty rather
      than erroring, since guests can't be warned/DMed/etc anyway).

   Run this after dmac-site-polish-schema.sql (needs `announcements`,
   `members.banner_color`) and dmac-friend-requests-schema.sql (needs
   `_resolve_member_id`). Safe to re-run.
   ═══════════════════════════════════════════════════════════════════ */

-- ── 1. FOLLOWED THREADS ─────────────────────────────────────────────
create table if not exists public.forum_thread_follows (
  member_id   uuid not null references public.members(id) on delete cascade,
  thread_id   bigint not null references public.forum_threads(id) on delete cascade,
  followed_at timestamptz not null default now(),
  primary key (member_id, thread_id)
);

alter table public.forum_thread_follows enable row level security;
-- No policies, no grants — same as member_sessions/moderation_log.
-- Reachable only from inside the SECURITY DEFINER functions below.
revoke all on public.forum_thread_follows from anon, authenticated;

create or replace function public.follow_forum_thread(p_session_token uuid, p_thread_id bigint)
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
  if not exists (select 1 from public.forum_threads where id = p_thread_id) then
    return json_build_object('success', false, 'message', 'No such thread.');
  end if;

  insert into public.forum_thread_follows (member_id, thread_id)
  values (v_me, p_thread_id)
  on conflict (member_id, thread_id) do nothing;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.follow_forum_thread(uuid, bigint) to anon, authenticated;

create or replace function public.unfollow_forum_thread(p_session_token uuid, p_thread_id bigint)
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

  delete from public.forum_thread_follows where member_id = v_me and thread_id = p_thread_id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.unfollow_forum_thread(uuid, bigint) to anon, authenticated;

create or replace function public.list_my_followed_thread_ids(p_session_token uuid)
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
    'thread_ids', (
      select coalesce(json_agg(thread_id), '[]'::json)
      from public.forum_thread_follows
      where member_id = v_me
    )
  );
end;
$$;

grant execute on function public.list_my_followed_thread_ids(uuid) to anon, authenticated;

-- ── 2. THE POLL ──────────────────────────────────────────────────────
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

    -- Public — no login required, guests get maintenance toasts too.
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
