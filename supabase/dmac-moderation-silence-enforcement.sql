/* ═══════════════════════════════════════════════════════════════════
   dmac-moderation-silence-enforcement.sql
   Makes "silence" actually do something.

   dmac-member-auth-schema.sql's own comment on member_moderate() says
   it straight out: "Not a full moderation feature, just the
   enforcement shape." Right now action='silence' only writes a row
   to moderation_log — a silenced member could still post threads and
   replies exactly like anyone else. This file closes that gap:

   1. members gets a `silenced_until` timestamp.
   2. member_moderate() gains a duration (in hours, default 24) and
      now actually sets/clears that column for 'silence'/'unsilence'.
   3. create_forum_thread / create_forum_post re-check that column
      and refuse to post while it's in the future — same
      re-check-server-side-inside-the-RPC pattern as everything else
      here, not a client-side flag that could be skipped.

   Silence only blocks NEW threads/replies, not edits or deletes of
   already-posted content — same scope as an actual forum "timeout".

   Run this AFTER dmac-member-auth-schema.sql and dmac-forum-schema.sql,
   in the Supabase Dashboard → SQL Editor. Safe to re-run.
   ═══════════════════════════════════════════════════════════════════ */

-- ── 1. THE COLUMN ─────────────────────────────────────────────────
-- null = not silenced. A timestamp in the past is just an expired
-- silence that hasn't been cleaned up yet — treated identically to
-- null by every check below, so there's no separate cleanup job to
-- maintain.
alter table public.members add column if not exists silenced_until timestamptz;

-- Members can already read their own/others' site_role etc. via the
-- existing column grant; silenced_until needs the same treatment so
-- the UI can show "you're silenced until ..." if you build that later.
grant select (silenced_until) on public.members to anon, authenticated;


-- ── 2. LET THE LOG RECORD LIFTING A SILENCE TOO ───────────────────
-- The inline check on moderation_log.action was 'warn'/'silence'
-- only; add 'unsilence' so mods have an audit trail for early lifts,
-- not just for imposing one.
alter table public.moderation_log drop constraint if exists moderation_log_action_check;
alter table public.moderation_log
  add constraint moderation_log_action_check
  check (action in ('warn', 'silence', 'unsilence'));


-- ── 3. member_moderate() — now with teeth ─────────────────────────
-- Adding p_duration_hours changes the function's signature, so the
-- old 4-arg version needs dropping first — otherwise Postgres keeps
-- both overloads around, and a call with only 4 named params becomes
-- ambiguous between them.
drop function if exists public.member_moderate(uuid, text, text, text);

create or replace function public.member_moderate(
  p_session_token uuid,
  p_target_slug text,
  p_action text,
  p_reason text default null,
  p_duration_hours integer default 24
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor  public.members%rowtype;
  v_target public.members%rowtype;
  v_until  timestamptz;
begin
  select m.* into v_actor
    from public.member_sessions s
    join public.members m on m.id = s.member_id
   where s.token = p_session_token and s.expires_at > now();

  if v_actor.id is null or v_actor.site_role not in ('moderator', 'admin') then
    return json_build_object('success', false, 'message', 'Moderators or admins only.');
  end if;

  if p_action not in ('warn', 'silence', 'unsilence') then
    return json_build_object('success', false, 'message', 'Unknown moderation action.');
  end if;

  select * into v_target from public.members where slug = p_target_slug;
  if v_target.id is null then
    return json_build_object('success', false, 'message', 'No member with that slug.');
  end if;

  if p_action = 'silence' then
    -- Floor of 1 hour so a stray 0/negative duration can't silently
    -- no-op the action while still logging it as if it worked.
    v_until := now() + make_interval(hours => greatest(coalesce(p_duration_hours, 24), 1));
    update public.members set silenced_until = v_until where id = v_target.id;
  elsif p_action = 'unsilence' then
    update public.members set silenced_until = null where id = v_target.id;
  end if;
  -- 'warn' falls through with no column update — log-only, unchanged.

  insert into public.moderation_log (actor_id, target_id, action, reason)
  values (v_actor.id, v_target.id, p_action, p_reason);

  return json_build_object('success', true, 'silenced_until', v_until);
end;
$$;

grant execute on function public.member_moderate(uuid, text, text, text, integer) to anon, authenticated;


-- ── 4. ENFORCEMENT — re-checked inside the write path itself ─────
-- Same shape as create_forum_thread/create_forum_post already had;
-- just inserting the silence check right after the existing
-- "logged in?" check, before any of the validation below it runs.

create or replace function public.create_forum_thread(p_session_token uuid, p_title text, p_body text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := public._resolve_member_id(p_session_token);
  v_silenced_until timestamptz;
  v_thread_id bigint;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Log in to start a thread.');
  end if;

  select silenced_until into v_silenced_until from public.members where id = v_me;
  if v_silenced_until is not null and v_silenced_until > now() then
    return json_build_object(
      'success', false,
      'message', 'You''re temporarily restricted from posting until ' || to_char(v_silenced_until, 'Mon DD, HH24:MI') || '.'
    );
  end if;

  if p_title is null or char_length(trim(p_title)) = 0 then
    return json_build_object('success', false, 'message', 'Give the thread a title.');
  end if;
  if char_length(p_title) > 120 then
    return json_build_object('success', false, 'message', 'Title is too long (120 characters max).');
  end if;
  if p_body is null or char_length(trim(p_body)) = 0 then
    return json_build_object('success', false, 'message', 'Say something in the first post.');
  end if;
  if char_length(p_body) > 4000 then
    return json_build_object('success', false, 'message', 'That post is too long (4000 characters max).');
  end if;

  insert into public.forum_threads (author_id, title)
  values (v_me, trim(p_title))
  returning id into v_thread_id;

  insert into public.forum_posts (thread_id, author_id, body)
  values (v_thread_id, v_me, trim(p_body));

  return json_build_object('success', true, 'thread_id', v_thread_id);
end;
$$;

grant execute on function public.create_forum_thread(uuid, text, text) to anon, authenticated;

create or replace function public.create_forum_post(p_session_token uuid, p_thread_id bigint, p_body text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := public._resolve_member_id(p_session_token);
  v_silenced_until timestamptz;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Log in to reply.');
  end if;

  select silenced_until into v_silenced_until from public.members where id = v_me;
  if v_silenced_until is not null and v_silenced_until > now() then
    return json_build_object(
      'success', false,
      'message', 'You''re temporarily restricted from posting until ' || to_char(v_silenced_until, 'Mon DD, HH24:MI') || '.'
    );
  end if;

  if not exists (select 1 from public.forum_threads where id = p_thread_id) then
    return json_build_object('success', false, 'message', 'That thread no longer exists.');
  end if;

  if p_body is null or char_length(trim(p_body)) = 0 then
    return json_build_object('success', false, 'message', 'Message cannot be empty.');
  end if;
  if char_length(p_body) > 4000 then
    return json_build_object('success', false, 'message', 'That post is too long (4000 characters max).');
  end if;

  insert into public.forum_posts (thread_id, author_id, body)
  values (p_thread_id, v_me, trim(p_body));

  return json_build_object('success', true);
end;
$$;

grant execute on function public.create_forum_post(uuid, bigint, text) to anon, authenticated;

-- NOT touched: edit_forum_thread, edit_forum_post, delete_forum_thread,
-- delete_forum_post. A silence stops someone from posting NEW content;
-- it deliberately doesn't retroactively lock them out of managing
-- their own existing posts. Flag it if you want that scope widened.
