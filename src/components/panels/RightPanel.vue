<template>
  <Teleport to="body">
    <div class="side-overlay side-overlay--right" :class="{ open: Panels.rightOpen.value }" @click="onOverlayClick">
      <div class="side-panel side-panel--right" @click.stop>
        <div class="side-panel-head">
          <strong class="side-panel-title">Notifications</strong>
          <button class="side-panel-close" aria-label="Close" v-sfx-hover @click="Panels.closeAll">✕</button>
        </div>

        <div class="side-panel-body">
          <section class="notif-section">
            <p class="notif-section-label">Announcements</p>
            <template v-if="generalAnnouncements.length">
              <div v-for="a in generalAnnouncements" :key="a.id" class="notif-card">
                <strong class="notif-card-title">{{ a.title }}</strong>
                <p class="notif-card-body">{{ a.body }}</p>
                <span class="notif-card-time">{{ formatTime(a.created_at) }}</span>
              </div>
            </template>
            <p v-else class="forums-guest-note">No announcements.</p>
          </section>

          <section class="notif-section">
            <p class="notif-section-label">Friend requests</p>
            <template v-if="!isLoggedIn">
              <p class="forums-guest-note">Log in to send and receive friend requests.</p>
            </template>
            <template v-else-if="friendRequests.length">
              <div v-for="r in friendRequests" :key="r.slug" class="dm-request-row">
                <span>{{ r.display_name }}</span>
                <div class="dm-request-actions">
                  <button class="forum-link-btn" v-sfx-hover @click="respondRequest(r.slug, true)">Accept</button>
                  <button class="forum-link-btn forum-link-btn--danger" v-sfx-hover @click="respondRequest(r.slug, false)">Decline</button>
                </div>
              </div>
            </template>
            <p v-else class="forums-guest-note">No pending requests.</p>
          </section>

          <section class="notif-section">
            <p class="notif-section-label">Forum</p>
            <template v-if="!isLoggedIn">
              <p class="forums-guest-note">Log in and follow a thread to see replies here.</p>
            </template>
            <template v-else-if="forumActivity.length">
              <div v-for="f in forumActivity" :key="f.id" class="notif-card notif-card--forum">
                <strong class="notif-card-title">{{ f.author_name }} replied in "{{ f.thread_title }}"</strong>
                <p v-if="f.excerpt" class="notif-card-body">{{ f.excerpt }}</p>
                <span class="notif-card-time">{{ formatTime(f.created_at) }}</span>
              </div>
            </template>
            <p v-else class="forums-guest-note">No replies yet on threads you follow.</p>
          </section>

          <section class="notif-section">
            <p class="notif-section-label">Badges</p>
            <template v-if="!isLoggedIn">
              <p class="forums-guest-note">Log in to see your earned badges.</p>
            </template>
            <template v-else-if="badges.length">
              <div class="notif-badges-grid">
                <div
                  v-for="b in badges"
                  :key="b.badge_id"
                  class="notif-badge-chip"
                  :style="{ '--tier-color': tierColor(b.tierKey) }"
                >
                  <div class="notif-badge-icon-wrap">
                    <div v-if="badgeBgSvg(b.tierKey)" class="notif-badge-bg" v-html="badgeBgSvg(b.tierKey)"></div>
                    <div v-if="badgeIconSvg(b.file)" class="notif-badge-icon" :aria-label="badgeLabel(b)" v-html="badgeIconSvg(b.file)"></div>
                    <span v-else class="notif-badge-diamond" :style="{ color: tierColor(b.tierKey) }">◆</span>
                  </div>
                  <div class="notif-badge-copy">
                    <strong>{{ badgeLabel(b) }}</strong>
                    <span>{{ badgeSubtitle(b) }}</span>
                    <span v-if="b.flavor" class="notif-badge-flavor">{{ b.flavor }}</span>
                  </div>
                </div>
              </div>
            </template>
            <p v-else class="forums-guest-note">No badges yet — keep at it!</p>
          </section>

          <section class="notif-section">
            <p class="notif-section-label">Warnings</p>
            <template v-if="!isLoggedIn">
              <p class="forums-guest-note">Log in to see your moderation history.</p>
            </template>
            <template v-else-if="warnings.length">
              <div v-for="w in warnings" :key="w.created_at" class="notif-card">
                <strong class="notif-card-title">Warning from {{ w.actor_name }}</strong>
                <p v-if="w.reason" class="notif-card-body">{{ w.reason }}</p>
                <span class="notif-card-time">{{ formatTime(w.created_at) }}</span>
              </div>
            </template>
            <p v-else class="forums-guest-note">Nothing here — good.</p>
          </section>

          <section class="notif-section">
            <p class="notif-section-label">Silences</p>
            <template v-if="!isLoggedIn">
              <p class="forums-guest-note">Log in to see your moderation history.</p>
            </template>
            <template v-else-if="silences.length">
              <div v-for="s in silences" :key="s.created_at" class="notif-card notif-card--silence">
                <strong class="notif-card-title">
                  {{ s.action === 'unsilence' ? 'Silence lifted by' : 'Silenced by' }} {{ s.actor_name }}
                </strong>
                <p v-if="s.reason" class="notif-card-body">{{ s.reason }}</p>
                <span class="notif-card-time">{{ formatTime(s.created_at) }}</span>
              </div>
            </template>
            <p v-else class="forums-guest-note">Nothing here — good.</p>
          </section>

          <section class="notif-section">
            <p class="notif-section-label">Maintenance</p>
            <template v-if="maintenanceAnnouncements.length">
              <div v-for="a in maintenanceAnnouncements" :key="a.id" class="notif-card notif-card--maintenance">
                <strong class="notif-card-title">{{ a.title }}</strong>
                <p class="notif-card-body">{{ a.body }}</p>
                <span class="notif-card-time">{{ formatTime(a.created_at) }}</span>
              </div>
            </template>
            <p v-else class="forums-guest-note">No maintenance notices.</p>
          </section>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { sb } from '../../lib/supabase-client.js';
import Panels from '../../composables/usePanels.js';
import MemberAuth from '../../lib/member-auth.js';
import { playSfx } from '../../composables/useSfx.js';
import Leaderboard from '../../lib/leaderboard.js';
import { BADGE_SVG } from '../../lib/badges.js';

const announcements = ref([]);
const warnings = ref([]);
const silences = ref([]);
const friendRequests = ref([]);
const forumActivity = ref([]);
const badges = ref([]);

const isLoggedIn = computed(() => !!MemberAuth.sessionMember.value);

const generalAnnouncements = computed(() => announcements.value.filter((a) => a.kind !== 'maintenance'));
const maintenanceAnnouncements = computed(() => announcements.value.filter((a) => a.kind === 'maintenance'));

// Refresh every time the panel opens — the announcements table only
// exists once dmac-site-polish-schema.sql has run, so a query error
// just leaves the empty placeholders in place.
watch(Panels.rightOpen, async (open) => {
  if (!open) return;
  const { data, error } = await sb
    .from('announcements')
    .select('id, title, body, kind, created_at')
    .order('created_at', { ascending: false })
    .limit(20);
  if (!error) announcements.value = data || [];

  if (isLoggedIn.value) {
    await Promise.all([loadModerationLog(), loadFriendRequests(), loadForumActivity(), loadBadges()]);
  }
});

// Requires dmac-my-moderation-log-fix.sql — before that RPC existed,
// this section had no way to read moderation_log at all (see that
// file's header for why), so it just showed a hardcoded "good" state
// unconditionally, warned or not. Backs both Warnings and Silences —
// one fetch, split client-side by `action` — since it's the same
// underlying log either way.
async function loadModerationLog() {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('list_my_moderation_log', { p_session_token: token });
  if (error || !data?.success) {
    console.error('RightPanel: could not load moderation log —', error?.message || data?.message);
    return;
  }
  const entries = data.entries || [];
  warnings.value = entries.filter((e) => e.action === 'warn');
  silences.value = entries.filter((e) => e.action === 'silence' || e.action === 'unsilence');
}

// Reuses the same list_friend_requests RPC LeftPanel's DMs tab already
// calls — this just surfaces it here too, with Accept/Decline right on
// the card, so a request doesn't only ever show up as a toast that's
// gone the moment you miss it or refresh.
async function loadFriendRequests() {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('list_friend_requests', { p_session_token: token });
  if (error || !data?.success) return;
  friendRequests.value = data.incoming || [];
}

async function respondRequest(slug, accept) {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('respond_friend_request', {
    p_session_token: token,
    p_from_slug: slug,
    p_accept: accept,
  });
  if (error || !data?.success) return;
  playSfx(accept ? 'socialnotifyminor' : 'menuback');
  await loadFriendRequests();
}

// Requires dmac-notifications-panel-fixes.sql. Unlike the toast-only
// forum-reply notifications (see lib/notifications.js), this is a
// persistent, re-queryable list — replies on threads you follow don't
// just vanish once the toast times out or you miss it.
async function loadForumActivity() {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('list_my_followed_thread_activity', { p_session_token: token, p_limit: 20 });
  if (error || !data?.success) {
    console.error('RightPanel: could not load forum activity —', error?.message || data?.message);
    return;
  }
  forumActivity.value = data.entries || [];
}

// Requires dmac-scores-members-link.sql (the real member_id → members.id
// link on scores). Same Leaderboard.getBadgesForSlug() helper the
// automatic toast check (lib/notifications.js's checkBadges()) and
// about/MembersView.vue's card overlay both use — one source of truth
// for "what badges does this member currently have."
async function loadBadges() {
  try {
    const scores = await Leaderboard.fetchScores();
    const member = MemberAuth.sessionMember.value;
    const stored = Leaderboard.getBadgesForSlug(scores, member?.slug);
    const computed = Leaderboard.getCompletionStatus(scores, member?.slug);
    badges.value = [...stored, ...computed];
  } catch (err) {
    console.error('RightPanel: could not load badges —', err.message);
  }
}

function tierColor(tierKey) {
  return Leaderboard.TIER_COLORS[tierKey] || '#888';
}
function badgeLabel(badge) {
  const name = badge?.name || 'Badge';
  return badge?.level ? `${badge.level} ${name}` : name;
}
// Tiered badges rank by percent-of-floor; issue-tracked (one-off)
// badges rank by "which number holder you were" instead — see
// getBadgesForSlug() in leaderboard.js for why percent doesn't mean
// anything for those. Computed badges (Completionist) aren't ranked
// against other people at all, so they get their own line entirely.
function badgeSubtitle(badge) {
  if (badge?.mode === 'computed') return `${badge.qualifying}/${badge.eligibleTotal} badges at ruby+`;
  if (badge?.mode === 'issue') return `#${badge.rank} to earn this`;
  return `Rank #${badge?.rank} · ${badge?.percent}%`;
}
function badgeBgSvg(tierKey) {
  return BADGE_SVG[`${tierKey}-badge`] || null;
}
// Same missing-`file` guard as about/MembersView.vue's badgeIconSvg —
// falls back to the ◆ glyph rather than throwing.
function badgeIconSvg(file) {
  if (typeof file !== 'string' || !file) return null;
  const base = file.replace(/\.[^.]+$/, '');
  return BADGE_SVG[base] || null;
}

function formatTime(ts) {
  try {
    return new Date(ts).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' });
  } catch (_) {
    return '';
  }
}

function onOverlayClick(e) {
  if (e.target === e.currentTarget) Panels.closeAll();
}
</script>
