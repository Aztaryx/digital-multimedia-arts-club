/* ═══════════════════════════════════════════════════════════════════
   dmac-search-path-fix.sql
   Fixes a real bug: member_login(), member_change_own_password(), and
   member_set_password() are all declared with `set search_path =
   public`, but pgcrypto (crypt()/gen_salt()) lives in the `extensions`
   schema on Supabase, not `public`. Since these functions can't see
   outside their own restricted search_path, every call to crypt()
   inside them fails — which is why login comes back with the generic
   "Something went wrong" instead of either succeeding or saying
   "Incorrect name or password."

   This is the exact same three functions from
   dmac-member-auth-fixes.sql, unchanged except for one word each:
   `set search_path = public` → `set search_path = public, extensions`.

   Run this after dmac-member-auth-fixes.sql (i.e. last, for now).
   Safe to re-run — create or replace function just overwrites them.
   ═══════════════════════════════════════════════════════════════════ */

/* ── member_login ─────────────────────────────────────────────── */
create or replace function public.member_login(p_slug text, p_password text)
returns json
language plpgsql
security definer
set search_path = public, extensions
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

/* ── member_change_own_password ───────────────────────────────── */
create or replace function public.member_change_own_password(p_session_token uuid, p_old_password text, p_new_password text)
returns json
language plpgsql
security definer
set search_path = public, extensions
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

/* ── member_set_password ──────────────────────────────────────── */
create or replace function public.member_set_password(p_admin_token uuid, p_target_slug text, p_new_password text)
returns json
language plpgsql
security definer
set search_path = public, extensions
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
