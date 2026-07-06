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

   MemberProfile.uploadAvatar(file, authUid)
   MemberProfile.uploadBanner(file, authUid)
     → { success, url?, message? }
     authUid is auth.uid() from a Google-linked Supabase session (sb.auth.getUser()).
     STILL PENDING: whether uploads stay gated to Google-linked sessions
     (current behavior, direct-to-Storage) or move to the Edge Function
     proxy your own schema's TODO hints at (works for either login tier).
     This function assumes the former until that's decided.
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

  function uploadAvatar(file, authUid) {
    return uploadImage({ bucket: 'avatars', file, authUid, field: 'avatarUrl' });
  }

  function uploadBanner(file, authUid) {
    return uploadImage({ bucket: 'banners', file, authUid, field: 'bannerUrl' });
  }

  /* Shared upload path for avatar/banner. Two steps: (1) file goes
     straight to Storage using the Google-linked auth.uid() session,
     since that's the only thing Storage RLS can check; (2) the
     resulting public URL is saved through the normal RPC, same as
     every other field. The check constraint on avatar_url/banner_url
     in the SQL already restricts these to your own Storage project's
     domain, so a query-string cache-buster on the URL is fine — it
     doesn't break the `like 'prefix%'` match. */
  async function uploadImage({ bucket, file, authUid, field }) {
    if (!authUid) {
      return { success: false, message: 'Link your Google account first — image uploads need it.' };
    }

    const ext = (file.name.split('.').pop() || 'png').toLowerCase();
    const path = `${authUid}/${bucket === 'avatars' ? 'avatar' : 'banner'}.${ext}`;

    const { error: uploadError } = await sb.storage.from(bucket).upload(path, file, { upsert: true });
    if (uploadError) return { success: false, message: `Upload failed — ${uploadError.message}` };

    const { data: urlData } = sb.storage.from(bucket).getPublicUrl(path);
    const bustedUrl = `${urlData.publicUrl}?t=${Date.now()}`; // path is stable across re-uploads, so bust the cache

    const result = await saveFields({ [field]: bustedUrl });
    if (!result.success) return { success: false, message: 'Uploaded, but saving it failed — try again.' };
    return { success: true, url: bustedUrl };
  }

  return { fetchProfile, updateNickname, updateProfile, uploadAvatar, uploadBanner };
})();

export default MemberProfile;
