/* ═══════════════════════════════════════════════════════════════════
   dmac-friend-requests-schema.sql
   Fills a real gap: dmac-social-schema.sql's `friendships` table only
   has RLS policies gated on auth.uid() — which means only Google-
   linked sessions could ever insert a row into it directly. A
   password-only (Tier A) member has no auth.uid() at all, so there
   was never any way for them to become friends with anyone, which
   means send_direct_message()/get_conversation() (both already built,
   both already session-token aware) had no path to ever succeed for
   that entire tier of members. These four RPCs are that missing path.

   Run this after dmac-profile-sync-fix.sql (needs _resolve_member_id).
   ═══════════════════════════════════════════════════════════════════ */

create or replace function public.send_friend_request(p_session_token uuid, p_to_slug text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me       uuid := public._resolve_member_id(p_session_token);
  v_to       uuid;
  v_existing text;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select id into v_to from public.members where slug = p_to_slug;
  if v_to is null then
    return json_build_object('success', false, 'message', 'No such member.');
  end if;
  if v_to = v_me then
    return json_build_object('success', false, 'message', 'You can''t friend yourself.');
  end if;

  select status into v_existing
    from public.friendships
   where (requester_id = v_me and addressee_id = v_to)
      or (requester_id = v_to and addressee_id = v_me)
   limit 1;

  if v_existing = 'accepted' then
    return json_build_object('success', false, 'message', 'You''re already friends.');
  elsif v_existing = 'pending' then
    return json_build_object('success', false, 'message', 'A request is already pending.');
  elsif v_existing = 'blocked' then
    return json_build_object('success', false, 'message', 'Can''t send a request right now.');
  end if;

  insert into public.friendships (requester_id, addressee_id, status)
  values (v_me, v_to, 'pending');

  return json_build_object('success', true);
end;
$$;

grant execute on function public.send_friend_request(uuid, text) to anon, authenticated;

create or replace function public.respond_friend_request(p_session_token uuid, p_from_slug text, p_accept boolean)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     uuid := public._resolve_member_id(p_session_token);
  v_from   uuid;
  v_row_id bigint;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;

  select id into v_from from public.members where slug = p_from_slug;
  if v_from is null then
    return json_build_object('success', false, 'message', 'No such member.');
  end if;

  select id into v_row_id
    from public.friendships
   where requester_id = v_from and addressee_id = v_me and status = 'pending';

  if v_row_id is null then
    return json_build_object('success', false, 'message', 'No pending request from that person.');
  end if;

  if p_accept then
    update public.friendships set status = 'accepted' where id = v_row_id;
  else
    delete from public.friendships where id = v_row_id;
  end if;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.respond_friend_request(uuid, text, boolean) to anon, authenticated;

create or replace function public.list_friends(p_session_token uuid)
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
    'friends', (
      select coalesce(
        json_agg(json_build_object('slug', m.slug, 'display_name', m.display_name) order by m.display_name),
        '[]'::json
      )
      from public.friendships f
      join public.members m
        on m.id = (case when f.requester_id = v_me then f.addressee_id else f.requester_id end)
      where f.status = 'accepted' and (f.requester_id = v_me or f.addressee_id = v_me)
    )
  );
end;
$$;

grant execute on function public.list_friends(uuid) to anon, authenticated;

create or replace function public.list_friend_requests(p_session_token uuid)
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
    'incoming', (
      select coalesce(
        json_agg(json_build_object('slug', m.slug, 'display_name', m.display_name) order by m.display_name),
        '[]'::json
      )
      from public.friendships f
      join public.members m on m.id = f.requester_id
      where f.status = 'pending' and f.addressee_id = v_me
    )
  );
end;
$$;

grant execute on function public.list_friend_requests(uuid) to anon, authenticated;
