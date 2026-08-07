/* ═══════════════════════════════════════════════════
   notifications.js — pop-up toast engine
   ═══════════════════════════════════════════════════
   Singleton (module-level state, same pattern as usePanels.js /
   member-auth.js) so any component can push a toast or read the
   current stack. NotificationToasts.vue is the only thing that
   renders them; NavBar/App.vue etc. don't need to know it exists.

   Two ways toasts get created:
     1. Polling list_unseen_notifications() every POLL_MS while a
        member is logged in (see startPolling() / stopPolling(),
        wired from App.vue). See dmac-notifications-schema.sql for
        why this is polling and not Supabase Realtime.
     2. Direct calls — Notifications.push({...}) — for anything that
        already knows it just happened client-side and doesn't need
        to wait for the next poll (e.g. AdminView could call this the
        instant it posts a maintenance notice).

   TYPE CONFIG lives here as the single source of truth for each
   notification kind's color + sound, mirroring how leaderboard.js
   owns TIER_COLORS so nothing else has to keep its own copy.
   ═══════════════════════════════════════════════════ */

import { ref } from 'vue';
import { sb } from './supabase-client.js';
import MemberAuth from './member-auth.js';
import Leaderboard from './leaderboard.js';
import { playSfx } from '../composables/useSfx.js';

/* ── TYPE CONFIG ────────────────────────────────────
   color: fixed hex, OR null when it's computed per-toast (badges use
   the tier they earned). */
export const NOTIF_TYPES = {
  maintenance:     { label: 'Maintenance',     color: '#f97316', sfx: 'notify' },
  announcement:    { label: 'Announcement',    color: '#38bdf8', sfx: 'notify' },
  warn:            { label: 'Warning',         color: '#eab308', sfx: 'staffwarning' },
  silence:         { label: 'Silence',         color: '#ef4444', sfx: 'staffsilence' },
  forum:           { label: 'Forum reply',     color: '#4ade80', sfx: 'socialnotifymajor' },
  badge:           { label: 'Badge earned',    color: null,      sfx: null }, // resolved per-tier, see badgeSfxFor()
};

/* Badge tiers group into the three achievement stingers + the one
   #1-only fanfare, in the same low→high order Leaderboard.TIER_CONFIG
   already defines (copper..gold / diamond..ruby / amethyst..prism /
   allomorphite). Kept as ranges rather than a flat map so any tier
   Leaderboard adds later between existing ones still falls somewhere
   sane instead of silently matching nothing. */
function badgeSfxFor(tierName) {
  const order = Leaderboard.TIER_CONFIG.map((t) => t.name);
  const i = order.indexOf(tierName);
  if (tierName === 'allomorphite' || i === order.length - 1) return 'worldrecord';
  if (i <= 2) return 'ach1';   // copper, silver, gold
  if (i <= 5) return 'ach2';   // diamond, orichalcum, ruby
  return 'ach3';               // amethyst, prism
}

/* ── TOAST STATE ────────────────────────────────────
   Newest first — NotificationToasts.vue just renders this array in
   order, no sorting done at render time. */
const toasts = ref([]);
let toastSeq = 0;

function push({ type, title, body, color, sfx, meta = {}, duration = 8000 }) {
  const cfg = NOTIF_TYPES[type] || {};
  const id = ++toastSeq;
  const resolvedColor = color || cfg.color || '#888888';
  const resolvedSfx = sfx !== undefined ? sfx : cfg.sfx;

  toasts.value.unshift({
    id, type, title, body, color: resolvedColor, meta, createdAt: Date.now(),
  });

  if (resolvedSfx) playSfx(resolvedSfx);

  if (duration) {
    setTimeout(() => dismiss(id), duration);
  }
  return id;
}

function dismiss(id) {
  const i = toasts.value.findIndex((t) => t.id === id);
  if (i !== -1) toasts.value.splice(i, 1);
}

function notifyBadgeEarned({ badgeName, tierName, memberSlug } = {}) {
  // Automatic trigger: checkBadges() below, run every poll tick (see
  // pollOnce()) once dmac-scores-members-link.sql's member_id link
  // exists. Still safe to call by hand too (e.g. from a future
  // "award this badge right now" admin action) — this function itself
  // doesn't care who called it.
  const color = Leaderboard.TIER_COLORS[tierName] || '#ffffff';
  return push({
    type: 'badge',
    title: `${tierName?.[0]?.toUpperCase()}${tierName?.slice(1)} badge earned!`,
    body: badgeName ? `Awarded: ${badgeName}` : undefined,
    color,
    sfx: badgeSfxFor(tierName),
    meta: { memberSlug, tierName },
  });
}

/* ── FOLLOWED THREADS ───────────────────────────────
   Thin wrappers around the RPCs in dmac-notifications-schema.sql,
   plus a reactive Set so LeftPanel.vue can light up a "Following"
   state on the currently-open thread without a separate fetch. */
const followedThreadIds = ref(new Set());

async function loadFollowedThreads() {
  const token = MemberAuth.getSessionToken();
  if (!token) {
    followedThreadIds.value = new Set();
    return;
  }
  const { data, error } = await sb.rpc('list_my_followed_thread_ids', { p_session_token: token });
  if (error || !data?.success) return;
  followedThreadIds.value = new Set(data.thread_ids || []);
}

async function followThread(threadId) {
  const token = MemberAuth.getSessionToken();
  if (!token) return { success: false, message: 'Not logged in.' };
  const { data, error } = await sb.rpc('follow_forum_thread', { p_session_token: token, p_thread_id: threadId });
  if (!error && data?.success) {
    followedThreadIds.value = new Set([...followedThreadIds.value, threadId]);
  }
  return error ? { success: false, message: error.message } : data;
}

async function unfollowThread(threadId) {
  const token = MemberAuth.getSessionToken();
  if (!token) return { success: false, message: 'Not logged in.' };
  const { data, error } = await sb.rpc('unfollow_forum_thread', { p_session_token: token, p_thread_id: threadId });
  if (!error && data?.success) {
    const next = new Set(followedThreadIds.value);
    next.delete(threadId);
    followedThreadIds.value = next;
  }
  return error ? { success: false, message: error.message } : data;
}

function isFollowing(threadId) {
  return followedThreadIds.value.has(threadId);
}

/* ── POLLING ─────────────────────────────────────────
   `since` persists per-member in localStorage so a page refresh
   doesn't replay every warning/DM/etc from your entire history as a
   fresh toast storm — only things that happened after the last time
   this browser actually checked. First-ever poll for a given member
   has no stored checkpoint; rather than dump their whole backlog as
   toasts, it silently sets the checkpoint to "now" and starts fresh
   from there (still see everything old in the panels themselves). */
// Was 15000 — the most common complaint behind "notif latency" wasn't
// really the interval itself, it was coming back to an already-open tab
// (laptop woke up, alt-tabbed back, etc.) and waiting up to a full
// interval for the next tick. Dropping the interval helps some, but the
// visibilitychange listener below (fires an immediate poll the moment
// the tab becomes visible again) is what actually fixes that case —
// the two together get "just happened" notifications a lot closer to
// actually-just-happened.
const POLL_MS = 6000;
let pollTimer = null;
let pollingSlug = null; // guards against a stale timer surviving a login/logout swap

function sinceKey(slug) {
  return `dmac_notif_since_${slug || 'guest'}`;
}

function getSince(slug) {
  try {
    return localStorage.getItem(sinceKey(slug));
  } catch (_) {
    return null;
  }
}

function setSince(slug, iso) {
  try {
    localStorage.setItem(sinceKey(slug), iso);
  } catch (_) {
    /* storage blocked — same fallback story as member-auth.js; just
       means this browser may re-show a batch after a hard refresh */
  }
}

/* ── BADGE CHECK ─────────────────────────────────────
   Own checkpoint, own key — badges come from the `scores` table via
   Leaderboard.fetchScores(), a completely different read path from
   list_unseen_notifications() above, so they get their own
   `dmac_badge_since_*` checkpoint rather than sharing sinceKey().
   Same "first-ever check sets the checkpoint silently, doesn't dump
   the whole backlog as toasts" rule as the rest of this file. */
function badgeSinceKey(slug) {
  return `dmac_badge_since_${slug}`;
}

function getBadgeSince(slug) {
  try {
    return localStorage.getItem(badgeSinceKey(slug));
  } catch (_) {
    return null;
  }
}

function setBadgeSince(slug, iso) {
  try {
    localStorage.setItem(badgeSinceKey(slug), iso);
  } catch (_) {
    /* storage blocked — same fallback as everywhere else here */
  }
}

let badgeCheckInFlight = false;

// Compares the logged-in member's current badges (via the real
// member_id → members.slug link dmac-scores-members-link.sql added)
// against their own last-checked checkpoint, and toasts anything new
// — a badge awarded for the first time, or an existing one whose row
// got touched again (admin_upsert_score bumps created_at on update,
// so correcting a value re-surfaces it too, which is the point: a
// changed score is exactly the kind of thing worth re-notifying).
async function checkBadges(slug) {
  if (!slug || badgeCheckInFlight) return;
  badgeCheckInFlight = true;
  try {
    const since = getBadgeSince(slug);
    const scores = await Leaderboard.fetchScores();
    const badges = Leaderboard.getBadgesForSlug(scores, slug);

    if (!since) {
      // No checkpoint yet for this member — baseline silently instead
      // of toasting every badge they already hold.
      setBadgeSince(slug, new Date().toISOString());
      return;
    }

    const newBadges = badges.filter((b) => b.created_at && b.created_at > since);
    for (const b of newBadges) {
      notifyBadgeEarned({ badgeName: b.name, tierName: b.tierKey, memberSlug: slug });
    }

    const latest = badges.reduce(
      (max, b) => (b.created_at && b.created_at > max ? b.created_at : max),
      since
    );
    setBadgeSince(slug, latest);
  } catch (err) {
    console.error('Notifications: badge check failed —', err.message || err);
  } finally {
    badgeCheckInFlight = false;
  }
}

async function pollOnce() {
  const member = MemberAuth.sessionMember.value;
  const slug = member?.slug || null;
  const token = MemberAuth.getSessionToken();

  // Fire-and-forget: independent data source + checkpoint from the
  // announcements/DM poll below, so it shouldn't block (or be blocked
  // by) that RPC round-trip. No-ops for guests (slug is null).
  checkBadges(slug);

  let since = getSince(slug);
  if (!since) {
    since = new Date().toISOString();
    setSince(slug, since);
    return; // establish the checkpoint silently, nothing to show yet
  }

  const { data, error } = await sb.rpc('list_unseen_notifications', {
    p_session_token: token || null,
    p_since: since,
  });
  if (error || !data?.success) {
    if (error) console.error('Notifications: poll failed —', error.message);
    return;
  }

  for (const a of data.maintenance || []) {
    push({ type: 'maintenance', title: a.title, body: a.body, meta: { id: a.id } });
  }
  // Regular announcements — previously only `maintenance`-kind posts made
  // it into the poll payload at all, so a plain announcement never got a
  // popup or sfx even though it always showed up fine in the panel itself.
  for (const a of data.announcements || []) {
    push({ type: 'announcement', title: a.title, body: a.body, meta: { id: a.id } });
  }
  for (const w of data.warnings || []) {
    push({ type: 'warn', title: `Warning from ${w.actor_name}`, body: w.reason || undefined });
  }
  for (const s of data.silences || []) {
    push({ type: 'silence', title: `Silenced by ${s.actor_name}`, body: s.reason || undefined });
  }
  for (const f of data.forum_replies || []) {
    push({
      type: 'forum',
      title: `New reply in "${f.thread_title}"`,
      body: `${f.author_name} replied`,
      meta: { threadId: f.thread_id },
    });
  }

  setSince(slug, data.server_time);
}

// Fires an out-of-schedule poll the instant the tab becomes visible
// again, rather than making a person wait out whatever's left of the
// current interval — registered once at module load, no-ops via the
// `pollTimer` guard whenever nothing is actually polling.
function onVisibilityChange() {
  if (document.visibilityState === 'visible' && pollTimer) pollOnce();
}
if (typeof document !== 'undefined') {
  document.addEventListener('visibilitychange', onVisibilityChange);
}

function startPolling() {
  const member = MemberAuth.sessionMember.value;
  const slug = member?.slug || null;
  if (pollTimer && pollingSlug === slug) return; // already polling for this identity
  stopPolling();
  pollingSlug = slug;
  pollOnce();
  pollTimer = setInterval(pollOnce, POLL_MS);
  if (slug) loadFollowedThreads();
}

function stopPolling() {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
  pollingSlug = null;
}

export default {
  toasts, push, dismiss, notifyBadgeEarned,
  followedThreadIds, followThread, unfollowThread, isFollowing, loadFollowedThreads,
  startPolling, stopPolling,
};
