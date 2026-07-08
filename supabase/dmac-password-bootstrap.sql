/* ═══════════════════════════════════════════════════════════════════
   dmac-password-bootstrap.sql
   ONE-TIME script to give every member an initial password in a
   single run — instead of calling member_set_password() by hand,
   once per person, which needs an admin session token you don't have
   yet anyway (chicken-and-egg: that RPC requires being logged in,
   and nobody can log in until a password exists).

   This writes straight to public.members using the same pgcrypto
   hashing member_set_password() uses internally, so it's fully
   compatible — you're just doing in one statement what 26 individual
   RPC calls would otherwise do.

   Run this ONCE, after dmac-member-auth-schema.sql (+ fixes) has
   already been run. Safe to re-run — it only ever touches rows where
   password_hash IS NULL, so it will never overwrite a password
   someone has already changed.
   ═══════════════════════════════════════════════════════════════════ */


/* ── OPTION A — one shared temp password for everyone ─────────────
   Simplest possible option: everybody gets logged in with the same
   temporary password, which you announce once (Discord, group chat,
   meeting announcement, whatever). Each person is expected to change
   it immediately via Profile → Change Password (already wired up in
   ProfileView.vue / member_change_own_password).

   Trade-off: until someone changes it, anyone who knows the shared
   password could log in as them. Fine for a low-stakes club roster;
   not something to leave in place long-term.

   Uncomment the block below to use this option. -------------------

update public.members
set password_hash = crypt('ChangeMe-DMAC26', gen_salt('bf'))
where password_hash is null;

   ------------------------------------------------------------------- */


/* ── OPTION B — unique random password per member (recommended) ───
   One run, one query — but every member gets their own random 8-char
   temp password instead of sharing one. The RETURNING clause prints
   the slug → plaintext-password pairing back to you in the SQL
   Editor's result grid so you can copy it out and message each
   person individually.

   IMPORTANT: this is the ONLY moment the plaintext password is ever
   visible anywhere — only the bcrypt hash gets stored. Copy the
   result grid (or screenshot it) before closing the editor tab,
   because there's no way to retrieve it again afterward. If you lose
   it, just re-run this script — it'll generate a fresh batch only for
   whoever is still password_hash IS NULL (skips anyone already set). */

with generated as (
  select
    id,
    slug,
    substr(md5(random()::text || slug || clock_timestamp()::text), 1, 8) as temp_password
  from public.members
  where password_hash is null
)
update public.members m
set password_hash = crypt(generated.temp_password, gen_salt('bf'))
from generated
where m.id = generated.id
returning m.slug, m.display_name, generated.temp_password;

/* ------------------------------------------------------------------- */


/* ── AFTER RUNNING EITHER OPTION ────────────────────────────────────
   1. Log in as any of the now-password-protected members to confirm
      member_login() accepts the new hash (it uses the same crypt()
      comparison, so it will).
   2. Distribute temp passwords (Option B) or announce the shared one
      (Option A).
   3. Everyone changes their password on first login via
      Profile → Change Password — that flow is already live, nothing
      else to build for it.
   ═══════════════════════════════════════════════════════════════════ */
