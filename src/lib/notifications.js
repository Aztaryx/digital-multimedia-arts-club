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
   color: fixed hex, OR null when it's computed per-toast (DMs use
   the sender's own banner_color; badges use the tier they earned). */
export const NOTIF_TYPES = {
  maintenance:     { label: 'Maintenance',     color: '#f97316', sfx: 'notify' },
  dm:              { label: 'Message',         color: null,      sfx: 'socialdm' },
  warn:            { label: 'Warning',         color: '#eab308', sfx: 'staffwarning' },
  silence:         { label: 'Silence',         color: '#ef4444', sfx: 'staffsilence' },
  forum:           { label: 'Forum reply',     color: '#4ade80', sfx: 'socialnotifymajor' },
  friend_request:  { label: 'Friend request',  color: '#f472b6', sfx: 'socialdm' },
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

const DEFAULT_DM_COLOR = '#f97316'; // members.banner_color has this same default — see dmac-profile-sync-fix.sql

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
  // Not wired to any automatic trigger yet — the scores table still
  // keys off the old member_id, not members.slug (see the comment in
  // RightPanel.vue), so there's no reliable "this login = this score
  // row" link to poll for automatically. Call this by hand (or from
  // wherever an officer's admin action awards a badge) once that link
  // exists. Kept here now so the visual/audio side is ready to go.
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
const POLL_MS = 15000;
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

async function pollOnce() {
  const member = MemberAuth.sessionMember.value;
  const slug = member?.slug || null;
  const token = MemberAuth.getSessionToken();

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
  for (const w of data.warnings || []) {
    push({ type: 'warn', title: `Warning from ${w.actor_name}`, body: w.reason || undefined });
  }
  for (const s of data.silences || []) {
    push({ type: 'silence', title: `Silenced by ${s.actor_name}`, body: s.reason || undefined });
  }
  for (const r of data.friend_requests || []) {
    push({ type: 'friend_request', title: `${r.display_name} sent a friend request`, meta: { slug: r.slug } });
  }
  for (const m of data.direct_messages || []) {
    push({
      type: 'dm',
      title: m.from_name,
      body: m.body,
      color: m.from_banner_color || DEFAULT_DM_COLOR,
      meta: { slug: m.from_slug },
    });
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
