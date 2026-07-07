/* ═══════════════════════════════════════════════════════════════════
    dmac-social-schema.sql
    Base profile / score / message schema used by the club site.
    This is the file that social-schema-addendum.sql extends.
    ═══════════════════════════════════════════════════════════════════ */

-- Comment this block out if you want to keep existing test data
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop table if exists public.direct_messages;
drop table if exists public.friendships;
drop table if exists public.scores;
drop table if exists public.profiles;

-- Profile row, one per logged-in user
create table public.profiles (
   id uuid primary key references auth.users(id) on delete cascade,
   member_id text unique not null,
   display_name text not null,
   role text not null default 'member' check (role in ('member','officer')),
   created_at timestamptz not null default now()
);

-- Auto-create a profile row whenever someone signs up
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
   insert into public.profiles (id, member_id, display_name)
   values (
      new.id,
      new.id::text,  -- placeholder; correct by hand in Table Editor once you know their real member_id
      coalesce(new.raw_user_meta_data->>'full_name', new.email)
   );
   return new;
end;
$$;

create trigger on_auth_user_created
   after insert on auth.users
   for each row execute function public.handle_new_user();

-- Scores table — same shape as your old Scores sheet
create table public.scores (
   id bigint generated always as identity primary key,
   badge_id text not null,
   member_id text not null references public.profiles(member_id)
      on update cascade on delete restrict,
   value numeric not null,
   issue_number int,
   awarded_on date not null default current_date,
   created_by uuid references auth.users(id),
   created_at timestamptz not null default now()
);

create unique index scores_member_badge_uniq
   on public.scores (badge_id, member_id)
   where issue_number is null;

create table public.friendships (
   id bigint generated always as identity primary key,
   requester_id uuid not null references public.members(id) on delete cascade,
   addressee_id uuid not null references public.members(id) on delete cascade,
   status text not null check (status in ('pending', 'accepted', 'blocked')),
   created_at timestamptz not null default now()
);

create table public.direct_messages (
   id bigint generated always as identity primary key,
   sender_id uuid not null references public.members(id) on delete cascade,
   recipient_id uuid not null references public.members(id) on delete cascade,
   body text not null,
   created_at timestamptz not null default now()
);

-- Enable RLS on all tables
alter table public.profiles enable row level security;
alter table public.scores enable row level security;
alter table public.friendships enable row level security;
alter table public.direct_messages enable row level security;

grant select on public.profiles to anon, authenticated;
grant update (display_name) on public.profiles to authenticated;
grant select on public.scores to anon, authenticated;
grant insert, update, delete on public.scores to authenticated;
grant select, insert, update, delete on public.friendships to authenticated;
grant select, insert, update, delete on public.direct_messages to authenticated;

create policy "Profiles are publicly readable" on public.profiles
   for select to anon, authenticated using (true);

create policy "Scores are publicly readable" on public.scores
   for select to anon, authenticated using (true);

create policy "Users can update own profile" on public.profiles
   for update to authenticated
   using (auth.uid() = id) with check (auth.uid() = id);

create policy "Officers can insert scores" on public.scores
   for insert to authenticated
   with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'officer'));

create policy "Officers can update scores" on public.scores
   for update to authenticated
   using (exists (select 1 from public.profiles where id = auth.uid() and role = 'officer'))
   with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'officer'));

create policy "Officers can delete scores" on public.scores
   for delete to authenticated
   using (exists (select 1 from public.profiles where id = auth.uid() and role = 'officer'));

create policy "Friends can read friendships" on public.friendships
   for select to authenticated
   using (auth.uid() = requester_id or auth.uid() = addressee_id);

create policy "Friends can insert friendships" on public.friendships
   for insert to authenticated
   with check (auth.uid() = requester_id);

create policy "Friends can update friendships" on public.friendships
   for update to authenticated
   using (auth.uid() = requester_id or auth.uid() = addressee_id)
   with check (auth.uid() = requester_id or auth.uid() = addressee_id);

create policy "Friends can read direct messages" on public.direct_messages
   for select to authenticated
   using (auth.uid() = sender_id or auth.uid() = recipient_id);

create policy "Friends can send direct messages" on public.direct_messages
   for insert to authenticated
   with check (auth.uid() = sender_id);

-- One-direction send RPC; the client should only use this after checking friendship.
create or replace function public.send_direct_message(p_session_token uuid, p_to_slug text, p_body text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
   v_me uuid := public._resolve_member_id(p_session_token);
   v_to uuid;
begin
   if v_me is null then
      return json_build_object('success', false, 'message', 'Not logged in.');
   end if;

   select id into v_to from public.members where slug = p_to_slug;
   if v_to is null then
      return json_build_object('success', false, 'message', 'No such member.');
   end if;

   if not exists (
      select 1 from public.friendships
       where status = 'accepted'
          and ((requester_id = v_me and addressee_id = v_to)
             or (requester_id = v_to and addressee_id = v_me))
   ) then
      return json_build_object('success', false, 'message', 'You can only message friends.');
   end if;

   if p_body = '' or char_length(p_body) > 1000 then
      return json_build_object('success', false, 'message', 'Message must be 1-1000 characters.');
   end if;

   insert into public.direct_messages (sender_id, recipient_id, body)
   values (v_me, v_to, p_body);

   return json_build_object('success', true);
end;
$$;

grant execute on function public.send_direct_message(uuid, text, text) to anon, authenticated;

create or replace function public.get_conversation(p_session_token uuid, p_with_slug text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
   v_me   uuid := public._resolve_member_id(p_session_token);
   v_them uuid;
begin
   if v_me is null then
      return json_build_object('success', false, 'message', 'Not logged in.');
   end if;

   select id into v_them from public.members where slug = p_with_slug;
   if v_them is null then
      return json_build_object('success', false, 'message', 'No such member.');
   end if;

   return json_build_object(
      'success', true,
      'messages', (
         select coalesce(
            json_agg(json_build_object(
               'id', dm.id,
               'from_me', dm.sender_id = v_me,
               'body', dm.body,
               'created_at', dm.created_at
            ) order by dm.created_at),
            '[]'::json
         )
         from public.direct_messages dm
         where (dm.sender_id = v_me and dm.recipient_id = v_them)
             or (dm.sender_id = v_them and dm.recipient_id = v_me)
      )
   );
end;
$$;

grant execute on function public.get_conversation(uuid, text) to anon, authenticated;

-- TODO before this goes live (see chat for full detail):
-- 1. revoke update (member_id) on public.profiles from anon, authenticated;
-- 2. apply the timing-fix + session-invalidation fixes to member_login /
--    member_change_own_password / member_set_password
-- 3. decide on the avatar/banner upload path (Edge Function proxy)
