/* ═══════════════════════════════════════════════════════════════════
   social-schema-addendum.sql
   Adds the one thing genuinely missing from dmac-social-schema.sql:
   social links. (Password is already handled by the auth schema's
   member_change_own_password — nothing to add there. GIF support for
   banners needs no schema change at all — see note at the bottom.)

   RUN THIS AFTER dmac-social-schema.sql.
   ═══════════════════════════════════════════════════════════════════ */

-- ── SOCIAL LINKS COLUMN ────────────────────────────────────────────
alter table public.members
  add column if not exists social_links jsonb not null default '[]';

alter table public.members
  add constraint members_social_links_shape check (
    jsonb_typeof(social_links) = 'array' and jsonb_array_length(social_links) <= 3
  );

-- Same public-read treatment as nickname/bio/avatar_url/banner_url —
-- readable by everyone, writable only through member_update_profile().
grant select (social_links) on public.members to anon, authenticated;

-- ── EXTEND member_update_profile() TO ACCEPT IT ───────────────────
-- Adding a parameter changes the function's signature, so the old
-- 5-arg version needs to be dropped explicitly first — otherwise you
-- end up with two overloaded member_update_profile()s coexisting.
drop function if exists public.member_update_profile(uuid, text, text, text, text, text, jsonb);

create or replace function public.member_update_profile(
  p_session_token uuid default null,
  p_nickname      text default null,
  p_bio           text default null,
  p_avatar_url    text default null,
  p_banner_url    text default null,
  p_banner_color  text default null,
  p_social_links  jsonb default null
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

  update public.members
     set nickname     = coalesce(p_nickname, nickname),
         bio          = coalesce(p_bio, bio),
         avatar_url   = coalesce(p_avatar_url, avatar_url),
         banner_url   = coalesce(p_banner_url, banner_url),
       banner_color = coalesce(p_banner_color, banner_color),
         social_links = coalesce(p_social_links, social_links)
   where id = v_me;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.member_update_profile(uuid, text, text, text, text, text, jsonb) to anon, authenticated;

-- ── NOTE ON GIF BANNERS ────────────────────────────────────────────
-- The existing banner_url check constraint only restricts the DOMAIN
-- (must be your own Supabase Storage project) — it never restricted
-- file type or extension, so a .gif URL already passes it as-is. The
-- actual gap isn't schema, it's the still-open TODO in the original
-- file: "decide on the avatar/banner upload path (Edge Function
-- proxy)". That decision changes real code (frontend + possibly a new
-- Edge Function), not this SQL file
