/* ═══════════════════════════════════════════════════
   member-profile.js — self-service profile editing
   ═══════════════════════════════════════════════════
   Sibling to member-auth.js, same pattern. Wraps ONE RPC —
   member_update_profile() from dmac-social-schema.sql (+ the
   social_links addendum) — which does partial updates via coalesce(),
   so passing null/undefined for a field leaves it untouched.

   All profile fields (nickname, bio, social_links, avatar_url,
   banner_url) live directly on `members`, NOT a separate table —
   `profiles` in this schema is just the auth.uid() ↔ member_id link
   for Google-linked accounts, unrelated to profile content.

   Note: `nickname` is deliberately separate from `members.display_name`.
   display_name stays the official/roster name; nickname is the
   member's own self-chosen one, shown alongside or instead of it —
   whichever the public card ends up doing. Editing nickname here
   never touches display_name.

   LOAD ORDER — same as member-auth.js:
     1. supabase-js CDN script
     2. js/supabase-client.js   (creates sb)
     3. js/member-auth.js       (session/token management)
     4. js/member-profile.js    (this file)

   USAGE
   ------------------------------------------------------
   MemberProfile.fetchProfile(memberId)
     → { nickname, bio, social_links, avatar_url, banner_url }

   MemberProfile.updateNickname(newNickname)
     → { success, message? }

   MemberProfile.updateProfile({ bio, socialLinks })
     → { success, message? }         (socialLinks: [{ label, url }, ...], max 3)

   MemberProfile.uploadAvatar(file)
   MemberProfile.uploadBanner(file)
     → { success, url?, message? }
     Goes through the upload-profile-image Edge Function rather than
     writing to Storage directly — that's what lets this work for
     password-only members too, not just Google-linked ones. No
     auth.uid()/Google session required.
   ═══════════════════════════════════════════════════ */

import { sb } from './supabase-client.js';
import MemberAuth from './member-auth.js';

const MemberProfile = (() => {

  const EMPTY_PROFILE = { nickname: '', bio: '', social_links: [], avatar_url: null, banner_url: null };

  async function fetchProfile(memberId) {
    const { data, error } = await sb
      .from('members')
      .select('nickname, bio, social_links, avatar_url, banner_url')
      .eq('id', memberId)
      .maybeSingle();

    if (error) {
      console.error('MemberProfile.fetchProfile:', error.message);
      return EMPTY_PROFILE;
    }
    return data || EMPTY_PROFILE;
  }

  /* Low-level: pass only the fields you want to change. Every RPC
     param defaults to null server-side, and the function's coalesce()
     leaves anything you don't pass untouched — so callers only ever
     need to send what actually changed. */
  async function saveFields({ nickname, bio, socialLinks, avatarUrl, bannerUrl } = {}) {
    const token = MemberAuth.getSessionToken();
    if (!token) return { success: false, message: 'Not logged in.' };

    const { data, error } = await sb.rpc('member_update_profile', {
      p_session_token: token,
      p_nickname: nickname ?? null,
      p_bio: bio ?? null,
      p_avatar_url: avatarUrl ?? null,
      p_banner_url: bannerUrl ?? null,
      p_social_links: socialLinks ?? null,
    });

    if (error) {
      // Constraint violations (nickname too long, bad social_links
      // shape, etc.) surface here as a raw Postgres error rather than
      // a friendly { success:false, message } payload, since this
      // schema validates via table CHECK constraints, not in-function
      // branching. Fine for now — swap in explicit pre-checks in this
      // function later if the raw messages turn out to be too rough.
      return { success: false, message: 'Something went wrong — try again.' };
    }
    return data;
  }

  function updateNickname(newNickname) {
    return saveFields({ nickname: newNickname });
  }

  function updateProfile({ bio, socialLinks }) {
    return saveFields({ bio, socialLinks });
  }

  function uploadAvatar(file) {
    return uploadImage('avatar', file);
  }

  function uploadBanner(file) {
    return uploadImage('banner', file);
  }

  /* Both avatar and banner go through the same Edge Function — it
     figures out identity from the session token itself (works for
     either login tier) and writes to Storage with the service-role
     key, so no client-side Storage permissions are involved at all. */
  async function uploadImage(kind, file) {
    const token = MemberAuth.getSessionToken();
    if (!token) return { success: false, message: 'Not logged in.' };

    const formData = new FormData();
    formData.append('session_token', token);
    formData.append('kind', kind);
    formData.append('file', file);

    const { data, error } = await sb.functions.invoke('upload-profile-image', { body: formData });

    if (error) {
      // supabase-js only fills in `data` on a 2xx response — every
      // documented failure case in upload-profile-image responds with
      // 401/400/500 instead, so the real { success:false, message }
      // body lands in error.context (a Response object) rather than
      // in `data`. Unwrap it so the person actually sees "File too
      // large", "Not logged in", etc. instead of a generic catch-all
      // that hides which of those it actually was.
      try {
        const body = await error.context.json();
        if (body?.message) return { success: false, message: body.message };
      } catch (_) {
        // response wasn't JSON (network failure, function not deployed,
        // etc.) — fall through to the generic message below
      }
      return { success: false, message: 'Upload failed — try again.' };
    }
    return data; // { success, url } or { success: false, message }
  }

  return { fetchProfile, updateNickname, updateProfile, uploadAvatar, uploadBanner };
})();

export default MemberProfile;
