// supabase/functions/upload-profile-image/index.ts
//
// Proxies avatar/banner uploads so BOTH login tiers can use them —
// that's the whole reason this exists instead of a direct-to-Storage
// client upload, which can only be gated by auth.uid() (Google-linked
// only). This function authenticates the request itself (via the same
// session token every other RPC in dmac-social-schema.sql uses), then
// writes to Storage using the service-role key, which bypasses Storage
// RLS entirely — so it works identically for password-only members.
//
// DEPLOY: `supabase functions deploy upload-profile-image`
// (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are already available as
// built-in env vars inside every Edge Function — no manual secrets
// setup needed for those two.)
//
// REQUEST: multipart/form-data with fields:
//   session_token  — from MemberAuth.getSessionToken()
//   kind           — 'avatar' | 'banner'
//   file           — the image (png/jpeg/webp/gif)
//
// RESPONSE: { success: true, url } or { success: false, message }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Conservative cap — Supabase's exact runtime request-body ceiling
// isn't clearly documented as of this writing; community reports put
// function payload limits around 10MB. If gif banners start getting
// rejected in practice, check Supabase's current Edge Functions limits
// page before just raising this number.
const MAX_BYTES = 8 * 1024 * 1024; // 8MB
const ALLOWED_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return json({ success: false, message: 'Method not allowed.' }, 405);
  }

  let formData: FormData;
  try {
    formData = await req.formData();
  } catch {
    return json({ success: false, message: 'Expected multipart/form-data.' }, 400);
  }

  const sessionToken = formData.get('session_token');
  const kind = formData.get('kind');
  const file = formData.get('file');

  if (typeof sessionToken !== 'string' || !sessionToken) {
    return json({ success: false, message: 'Not logged in.' }, 401);
  }
  if (kind !== 'avatar' && kind !== 'banner') {
    return json({ success: false, message: 'Invalid upload kind.' }, 400);
  }
  if (!(file instanceof File)) {
    return json({ success: false, message: 'No file provided.' }, 400);
  }
  if (!ALLOWED_TYPES.includes(file.type)) {
    return json({ success: false, message: 'Only PNG, JPEG, WEBP, or GIF images are allowed.' }, 400);
  }
  if (file.size > MAX_BYTES) {
    return json({ success: false, message: `File too large — ${MAX_BYTES / (1024 * 1024)}MB max.` }, 400);
  }

  // Service-role client — bypasses RLS entirely, which is the whole
  // point: this is the one place in the system allowed to write
  // Storage objects for someone who has no auth.uid() of their own.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // Same identity check every other RPC in the schema uses. Requires
  // `grant execute on function public._resolve_member_id(uuid) to
  // service_role;` — see the addendum SQL — since the original file's
  // `revoke all ... from public` would otherwise leave service_role
  // without it too.
  const { data: memberId, error: resolveError } = await admin.rpc('_resolve_member_id', {
    p_session_token: sessionToken,
  });
  if (resolveError || !memberId) {
    return json({ success: false, message: 'Not logged in.' }, 401);
  }

  const bucket = kind === 'avatar' ? 'avatars' : 'banners';
  const ext = (file.name.split('.').pop() || 'png').toLowerCase();
  const path = `${memberId}/${kind}.${ext}`;

  const arrayBuffer = await file.arrayBuffer();
  const { error: uploadError } = await admin.storage
    .from(bucket)
    .upload(path, arrayBuffer, { contentType: file.type, upsert: true });

  if (uploadError) {
    return json({ success: false, message: `Upload failed — ${uploadError.message}` }, 500);
  }

  const { data: urlData } = admin.storage.from(bucket).getPublicUrl(path);
  const bustedUrl = `${urlData.publicUrl}?t=${Date.now()}`; // path is stable across re-uploads — bust the cache

  const fieldParam = kind === 'avatar' ? { p_avatar_url: bustedUrl } : { p_banner_url: bustedUrl };
  const { data: saveData, error: saveError } = await admin.rpc('member_update_profile', {
    p_session_token: sessionToken,
    p_nickname: null,
    p_bio: null,
    p_social_links: null,
    ...fieldParam,
  });

  if (saveError || !saveData?.success) {
    return json({ success: false, message: 'Uploaded, but saving it failed — try again.' }, 500);
  }

  return json({ success: true, url: bustedUrl });
});