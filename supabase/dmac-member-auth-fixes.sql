/* ═══════════════════════════════════════════════════════════════════
   dmac-member-auth-fixes.sql
   Follow-up fixes for the member auth / profile schema.
   Run this after dmac-social-schema.sql and dmac-member-auth-schema.sql.
   ═══════════════════════════════════════════════════════════════════ */

/* ── CRITICAL: close the member_id impersonation gap ────────────── */
revoke update (member_id) on public.profiles from anon, authenticated;

create unique index if not exists profiles_member_id_unique
  on public.profiles(member_id) where member_id is not null;

/* ── member_login: timing-safe (always pays the bcrypt cost) ─────── */
create or replace function public.member_login(p_slug text, p_password text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member    public.members%rowtype;
  v_token     uuid;
  v_dummy     constant text := '$2b$12$/aSp2284C/JKYPLDPGoA7Ou9OPst4z.wJQjNXS.fvfal7Ck01htRa';
  v_hash      text;
begin
  select * into v_member from public.members where slug = p_slug;
  v_hash := coalesce(v_member.password_hash, v_dummy);

  if v_member.id is null or v_member.password_hash is null
     or v_hash <> crypt(p_password, v_hash) then
    return json_build_object('success', false, 'message', 'Incorrect name or password.');
  end if;

  insert into public.member_sessions (member_id)
  values (v_member.id)
  returning token into v_token;

  return json_build_object(
    'success', true,
    'session_token', v_token,
    'member', json_build_object(
      'slug', v_member.slug,
      'display_name', v_member.display_name,
      'club_role', v_member.club_role,
      'site_role', v_member.site_role
    )
  );
end;
$$;

grant execute on function public.member_login(text, text) to anon, authenticated;

/* ── member_change_own_password: kill other sessions on change ──── */
create or replace function public.member_change_own_password(p_session_token uuid, p_old_password text, p_new_password text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member public.members%rowtype;
begin
  select m.* into v_member
    from public.member_sessions s
    join public.members m on m.id = s.member_id
   where s.token = p_session_token and s.expires_at > now();

  if v_member.id is null or v_member.password_hash <> crypt(p_old_password, v_member.password_hash) then
    return json_build_object('success', false, 'message', 'Current password is incorrect.');
  end if;

  update public.members
     set password_hash = crypt(p_new_password, gen_salt('bf'))
   where id = v_member.id;

  -- keep this session alive, kill every other one
  delete from public.member_sessions
   where member_id = v_member.id and token <> p_session_token;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.member_change_own_password(uuid, text, text) to anon, authenticated;

/* ── member_set_password: kill ALL sessions on admin reset ───────── */
create or replace function public.member_set_password(p_admin_token uuid, p_target_slug text, p_new_password text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_role text;
  v_target_id  uuid;
begin
  select m.site_role into v_admin_role
    from public.member_sessions s
    join public.members m on m.id = s.member_id
   where s.token = p_admin_token and s.expires_at > now();

  if v_admin_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;

  update public.members
     set password_hash = crypt(p_new_password, gen_salt('bf'))
   where slug = p_target_slug
   returning id into v_target_id;

  if v_target_id is null then
    return json_build_object('success', false, 'message', 'No member with that slug.');
  end if;

  delete from public.member_sessions where member_id = v_target_id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.member_set_password(uuid, text, text) to anon, authenticated;
