/* ═══════════════════════════════════════════════════════════════════
   dmac-password-reset-scheme.sql
   Universal reset — every member, moderator, and admin gets a new,
   predictable password based on their alphabetical position within
   their tier:

     site_role = 'member'                → DMACMember1, DMACMember2, …
     site_role = 'moderator' or 'admin'  → DMACModerators1, DMACModerators2, …

   (Admins are bucketed in with moderators — both are "staff" tiers,
   as opposed to rank-and-file members. Say the word if you want admins
   split into their own DMACAdmins[n] scheme instead — one line to
   change.)

   Numbering is alphabetical by display_name, separately within each
   bucket, so "member #1" is whoever's display_name sorts first among
   members, not tied to signup order or anything else.

   This OVERWRITES every password_hash, no IS NULL condition — that's
   the point this time. Re-running it is safe/idempotent: same people,
   same alphabetical order in, same passwords out, every time.
   ═══════════════════════════════════════════════════════════════════ */

with numbered as (
  select
    id,
    site_role,
    row_number() over (
      partition by (site_role = 'member')   -- true bucket = members, false bucket = moderator+admin
      order by display_name
    ) as rn
  from public.members
),
passworded as (
  select
    id,
    case
      when site_role = 'member' then 'DMACMember' || rn
      else 'DMACModerators' || rn
    end as new_password
  from numbered
)
update public.members m
set password_hash = crypt(p.new_password, gen_salt('bf'))
from passworded p
where m.id = p.id
returning m.slug, m.display_name, m.site_role, p.new_password;

/* ── OPTIONAL BUT RECOMMENDED ─────────────────────────────────────
   Since every password just changed, any existing session tokens are
   still technically valid (sessions aren't tied to the password hash
   in this schema) — this forces literally everyone to log back in
   with their new password instead of coasting on an old session,
   which avoids confusing "wait, whose password is this again" testing
   later. Uncomment to run it: */

-- delete from public.member_sessions;
