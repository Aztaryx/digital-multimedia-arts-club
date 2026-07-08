/* ═══════════════════════════════════════════════════════════════════
   dmac-storage-buckets-fix.sql
   The one piece upload-profile-image/index.ts assumes but that no SQL
   file here ever creates: the `avatars` and `banners` Storage buckets
   themselves.

   admin.storage.from(bucket).getPublicUrl(path) ALWAYS returns a URL
   shaped like ".../object/public/<bucket>/<path>" — regardless of
   whether the bucket actually exists or is actually public. If either
   bucket is missing, or exists but was created by hand in the
   dashboard without "Public bucket" checked, the upload step still
   reports success (the URL string gets saved to members.avatar_url /
   banner_url just fine via member_update_profile), but the browser
   gets a permission error loading that URL — i.e. the exact "it saves
   but the image doesn't render" symptom, with no client-side error to
   point at since the failure happens on image load, not on upload.

   Making a bucket public is what lets its public URL actually serve
   files with no auth — that's the correct setting here, since profile
   avatars/banners are meant to be publicly visible on member cards
   anyway (no separate SELECT policy needed on top of it).

   file_size_limit / allowed_mime_types below just mirror the edge
   function's own MAX_BYTES / ALLOWED_TYPES as a second layer of
   defense at the Storage level, in case anything ever writes to these
   buckets outside that function.

   Safe to re-run.
   ═══════════════════════════════════════════════════════════════════ */

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 8388608, array['image/png','image/jpeg','image/webp','image/gif']),
  ('banners', 'banners', true, 8388608, array['image/png','image/jpeg','image/webp','image/gif'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;
