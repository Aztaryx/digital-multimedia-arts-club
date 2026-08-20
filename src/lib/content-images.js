/* content-images.js — admin-only cover-image upload for Newsletters
   and Announcements. Same shape as member-profile.js's uploadImage(),
   just pointed at the new upload-content-image Edge Function and with
   no memberSlug-keyed path (an admin can upload many different covers
   over time — see that function's own comment). */

import { sb } from './supabase-client.js';
import MemberAuth from './member-auth.js';

export async function uploadContentImage(file) {
  const token = MemberAuth.getSessionToken();
  if (!token) return { success: false, message: 'Not logged in.' };

  const formData = new FormData();
  formData.append('session_token', token);
  formData.append('file', file);

  const { data, error } = await sb.functions.invoke('upload-content-image', { body: formData });

  if (error) {
    // Same unwrap as member-profile.js's uploadImage() — supabase-js
    // only populates `data` on a 2xx; every documented failure here
    // (401/400/403/500) puts the real { success:false, message } body
    // in error.context instead.
    try {
      const body = await error.context.json();
      if (body?.message) return { success: false, message: body.message };
    } catch (_) {
      // not JSON — network failure, function not deployed, etc.
    }
    return { success: false, message: 'Upload failed — try again.' };
  }
  return data; // { success, url } or { success: false, message }
}

export default { uploadContentImage };
