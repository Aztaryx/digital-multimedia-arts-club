/* ═══════════════════════════════════════════════════════════════════
   dmac-forum-schema.sql
   Real forum backend — threads + posts, readable by everyone
   (including guests), writable only through the RPCs below.

   Run this after dmac-profile-sync-fix.sql (needs _resolve_member_id).
   ═══════════════════════════════════════════════════════════════════ */

-- ── TABLES ──────────────────────────────────────────────────────────
create table public.forum_threads (
  id         bigint generated always as identity primary key,
  author_id  uuid not null references public.members(id) on delete cascade,
  title      text not null check (char_length(title) between 1 and 120),
  pinned     boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.forum_posts (
  id         bigint generated always as identity primary key,
  thread_id  bigint not null references public.forum_threads(id) on delete cascade,
  author_id  uuid not null references public.members(id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index forum_posts_thread_idx on public.forum_posts (thread_id, created_at);

alter table public.forum_threads enable row level security;
alter table public.forum_posts   enable row level security;

-- Read access is fully public — guests can browse, same as the rest
-- of the roster. Writing only ever happens through the RPCs further
-- down, so there are deliberately no insert/update/delete grants here.
create policy "forum threads are publicly readable" on public.forum_threads
  for select using (true);
create policy "forum posts are publicly readable" on public.forum_posts
  for select using (true);

grant select on public.forum_threads to anon, authenticated;
grant select on public.forum_posts   to anon, authenticated;

-- ── READ VIEWS ──────────────────────────────────────────────────────
-- Flat, pre-joined views instead of relying on PostgREST's nested
-- embed syntax for author name + reply count — simpler to query from
-- the client and nothing to get subtly wrong across supabase-js
-- versions.
create or replace view public.forum_threads_feed as
select
  t.id,
  t.title,
  t.pinned,
  t.created_at,
  m.slug         as author_slug,
  m.display_name as author_name,
  (select count(*) from public.forum_posts p where p.thread_id = t.id)     as reply_count,
  (select max(p.created_at) from public.forum_posts p where p.thread_id = t.id) as last_activity
from public.forum_threads t
join public.members m on m.id = t.author_id;

grant select on public.forum_threads_feed to anon, authenticated;

create or replace view public.forum_posts_feed as
select
  p.id,
  p.thread_id,
  p.body,
  p.created_at,
  m.slug         as author_slug,
  m.display_name as author_name
from public.forum_posts p
join public.members m on m.id = p.author_id;

grant select on public.forum_posts_feed to anon, authenticated;

-- ── WRITE RPCs ──────────────────────────────────────────────────────
create or replace function public.create_forum_thread(p_session_token uuid, p_title text, p_body text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := public._resolve_member_id(p_session_token);
  v_thread_id bigint;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Log in to start a thread.');
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
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Log in to reply.');
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

create or replace function public.set_forum_thread_pinned(p_session_token uuid, p_thread_id bigint, p_pinned boolean)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  select m.site_role into v_role
    from public.member_sessions s
    join public.members m on m.id = s.member_id
   where s.token = p_session_token and s.expires_at > now();

  if v_role is distinct from 'moderator' and v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Moderators only.');
  end if;

  update public.forum_threads set pinned = p_pinned where id = p_thread_id;
  return json_build_object('success', true);
end;
$$;

grant execute on function public.set_forum_thread_pinned(uuid, bigint, boolean) to anon, authenticated;

create or replace function public.delete_forum_post(p_session_token uuid, p_post_id bigint)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     uuid := public._resolve_member_id(p_session_token);
  v_role   text;
  v_author uuid;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select author_id into v_author from public.forum_posts where id = p_post_id;
  if v_author is null then
    return json_build_object('success', false, 'message', 'Post not found.');
  end if;

  select site_role into v_role from public.members where id = v_me;

  if v_author <> v_me and v_role not in ('moderator', 'admin') then
    return json_build_object('success', false, 'message', 'You can only delete your own posts.');
  end if;

  delete from public.forum_posts where id = p_post_id;
  return json_build_object('success', true);
end;
$$;

grant execute on function public.delete_forum_post(uuid, bigint) to anon, authenticated;

create or replace function public.delete_forum_thread(p_session_token uuid, p_thread_id bigint)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     uuid := public._resolve_member_id(p_session_token);
  v_role   text;
  v_author uuid;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select author_id into v_author from public.forum_threads where id = p_thread_id;
  if v_author is null then
    return json_build_object('success', false, 'message', 'Thread not found.');
  end if;

  select site_role into v_role from public.members where id = v_me;

  if v_author <> v_me and v_role not in ('moderator', 'admin') then
    return json_build_object('success', false, 'message', 'You can only delete your own threads.');
  end if;

  delete from public.forum_threads where id = p_thread_id; -- posts cascade
  return json_build_object('success', true);
end;
$$;

grant execute on function public.delete_forum_thread(uuid, bigint) to anon, authenticated;
