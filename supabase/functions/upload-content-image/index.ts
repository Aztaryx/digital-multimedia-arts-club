// supabase/functions/upload-content-image/index.ts
//
// Admin-only image upload for Newsletter/Announcement cover images.
// Same shape as upload-profile-image/index.ts (service-role client,
// same CORS_HEADERS/json() helpers, same _resolve_member_id()
// identity check) — the one difference is the extra site_role='admin'
// gate, since this bucket is for site content, not a member's own
// avatar/banner.
//
// DEPLOY: `supabase functions deploy upload-content-image`
//
// REQUEST: multipart/form-data with fields:
//   session_token — from MemberAuth.getSessionToken()
//   file          — the image (png/jpeg/webp/gif)
//
// RESPONSE: { success: true, url } or { success: false, message }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const MAX_BYTES = 8 * 1024 * 1024; // 8MB — matches the content-images bucket's own limit
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
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return json({ success: false, message: 'Method not allowed.' }, 405);

  let formData: FormData;
  try {
    formData = await req.formData();
  } catch {
    return json({ success: false, message: 'Expected multipart/form-data.' }, 400);
  }

  const sessionToken = formData.get('session_token');
  const file = formData.get('file');

  if (typeof sessionToken !== 'string' || !sessionToken) {
    return json({ success: false, message: 'Not logged in.' }, 401);
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

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: memberId, error: resolveError } = await admin.rpc('_resolve_member_id', {
    p_session_token: sessionToken,
  });
  if (resolveError || !memberId) {
    return json({ success: false, message: 'Not logged in.' }, 401);
  }

  // Admin-only, unlike upload-profile-image (any logged-in member can
  // set their own avatar/banner; only admins should be writing into
  // site-wide newsletter/announcement content).
  const { data: memberRow, error: roleError } = await admin
    .from('members')
    .select('site_role')
    .eq('id', memberId)
    .maybeSingle();
  if (roleError || memberRow?.site_role !== 'admin') {
    return json({ success: false, message: 'Admins only.' }, 403);
  }

  const ext = (file.name.split('.').pop() || 'png').toLowerCase();
  // Random-ish path per upload (not keyed to memberId like avatars/
  // banners) — a single admin can upload many different covers over
  // time, each needs its own stable URL rather than overwriting the
  // last one.
  const path = `${crypto.randomUUID()}.${ext}`;

  const arrayBuffer = await file.arrayBuffer();
  const { error: uploadError } = await admin.storage
    .from('content-images')
    .upload(path, arrayBuffer, { contentType: file.type, upsert: false });

  if (uploadError) {
    return json({ success: false, message: `Upload failed — ${uploadError.message}` }, 500);
  }

  const { data: urlData } = admin.storage.from('content-images').getPublicUrl(path);

  return json({ success: true, url: urlData.publicUrl });
});
