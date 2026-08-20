/* oauth-link.js — shared Google OAuth round-trip handler.
   Used to live entirely inside LoginView.vue, which made sense when
   login was its own route. Now that login happens inline (see
   LoginPopover.vue), Google's redirect can land the visitor back on
   ANY page — this has to be handled globally (App.vue's onMounted),
   not by a page that may not even be the one they started from. */

import { ref } from 'vue';
import { sb } from './supabase-client.js';
import MemberAuth from './member-auth.js';

// Set by LoginPopover.vue right before redirecting to Google, so the
// callback below knows whether this round-trip is "link my password
// account to Google" or a bare Google sign-in with no member context
// yet. Module-level singleton — same pattern member-auth.js's own
// cachedMember uses — since it has to survive the full-page redirect
// Supabase's OAuth flow performs.
export const pendingLinkSlug = ref(null);

/**
 * Call once, from App.vue's onMounted. No-ops immediately if the URL
 * doesn't carry an OAuth #access_token hash.
 * @param {(msg: string, type: 'success'|'error') => void} [onStatus]
 */
export async function handleOAuthCallback(onStatus) {
  const hashParams = new URLSearchParams(window.location.hash.substring(1));
  if (!hashParams.has('access_token')) return;

  const { data: { session }, error } = await sb.auth.getSession();
  if (error || !session) {
    console.error('oauth-link: getSession failed —', error?.message);
    onStatus?.('Google sign-in failed.', 'error');
    return;
  }

  if (pendingLinkSlug.value) {
    const result = await MemberAuth.linkGoogle();
    if (result.success) {
      onStatus?.('Google account linked.', 'success');
    } else {
      onStatus?.(result.message || 'Unable to link Google account.', 'error');
      await sb.auth.signOut();
    }
    pendingLinkSlug.value = null;
  } else {
    onStatus?.('Signed in with Google.', 'success');
  }

  // Strip the #access_token=... hash out of the address bar so it
  // doesn't linger or get reprocessed on a later refresh.
  history.replaceState(null, '', window.location.pathname + window.location.search);
}
