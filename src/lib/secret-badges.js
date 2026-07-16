/* ═══════════════════════════════════════════════════
   secret-badges.js — self-serve claim for Whoops. and h4h4 n00b!
   ═══════════════════════════════════════════════════
   Everything else in this codebase writes to `scores` through
   admin_upsert_score() — admin-only by design. These two badges are
   different: a visitor awards the badge to *themselves* by finding
   the 404 page or entering the Konami code, which is why they go
   through their own RPC, claim_secret_badge() (see
   dmac-badges-batch-2.sql), not a relaxed version of the admin path.

   The 404 route and the input listener below are UI gating, not
   security — see that RPC's own header for why that's an accepted
   tradeoff for playful, low-stakes badges like these.

   No client-side toast logic needed here on a successful claim —
   notifications.js's poll loop already surfaces any new badge the
   next time it runs (created_at is the "is this new?" signal it
   already uses for every other badge), so a genuine first claim just
   shows up as a normal "Badge earned!" toast on its own. */

import { sb } from './supabase-client.js';
import MemberAuth from './member-auth.js';

async function claim(badgeId) {
  if (!MemberAuth.current()) return; // there's no guest version of a badge
  try {
    await sb.rpc('claim_secret_badge', {
      p_session_token: MemberAuth.getSessionToken(),
      p_badge_id: badgeId,
    });
    // A repeat claim comes back as an ordinary { success: false,
    // message: 'Already claimed.' } response, not a thrown error —
    // nothing to react to either way here.
  } catch (err) {
    console.error(`secret-badges: claim(${badgeId}) failed —`, err.message || err);
  }
}

/* ── WHOOPS. ────────────────────────────────────────
   Called once from the 404 view on mount. Safe to call on every
   visit to the page — claim_secret_badge() itself is the guard
   against duplicate rows, not this call site. */
export function claimWhoops() {
  return claim('whoops');
}

/* ── H4H4 N00B! — DESKTOP (KONAMI CODE) ────────────
   ↑ ↑ ↓ ↓ ← → ← → B A on keydown, anywhere in the app. Case-
   insensitive for the letter keys; arrow keys match by e.key
   directly. A wrong key doesn't just reset to zero — it re-checks
   against the sequence's first key, so mashing arrow keys near the
   start doesn't force a full restart on every miss. */
const KONAMI_SEQUENCE = [
  'ArrowUp', 'ArrowUp', 'ArrowDown', 'ArrowDown',
  'ArrowLeft', 'ArrowRight', 'ArrowLeft', 'ArrowRight',
  'b', 'a',
];

let konamiProgress = 0;

function onKeydown(e) {
  const key = e.key.length === 1 ? e.key.toLowerCase() : e.key;
  const expected = KONAMI_SEQUENCE[konamiProgress];

  if (key === expected) {
    konamiProgress++;
    if (konamiProgress === KONAMI_SEQUENCE.length) {
      konamiProgress = 0;
      claim('h4h4-n00b');
    }
  } else {
    konamiProgress = (key === KONAMI_SEQUENCE[0]) ? 1 : 0;
  }
}

let listening = false;

// Idempotent — App.vue calls this once on mount, but a guard here
// means it's harmless if that ever changes to run more than once
// (e.g. under HMR during development).
export function startKonamiListener() {
  if (listening) return;
  listening = true;
  window.addEventListener('keydown', onKeydown);
}

/* ── H4H4 N00B! — MOBILE (TAP SEQUENCE) ────────────
   No keyboard on mobile, so the equivalent trigger is tapping the
   nav logo 5 times within 2 seconds. This is the implementation plan's
   own "current lead idea" for the mobile equivalent, picked here as
   the concrete choice — a swipe pattern or shake gesture would work
   just as well and can replace this later without touching anything
   else, since this function is the only place that knows the
   detection mechanism. NavBar.vue just calls registerLogoTap() on
   every tap/click of the logo; normal navigation to /home is
   untouched either way. */
const TAP_TARGET = 5;
const TAP_WINDOW_MS = 2000;

let tapCount = 0;
let tapTimer = null;

export function registerLogoTap() {
  tapCount++;
  if (tapTimer) clearTimeout(tapTimer);
  tapTimer = setTimeout(() => { tapCount = 0; }, TAP_WINDOW_MS);

  if (tapCount >= TAP_TARGET) {
    tapCount = 0;
    clearTimeout(tapTimer);
    claim('h4h4-n00b');
  }
}
