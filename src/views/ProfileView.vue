<template>
  <main class="profile-page">
    <div class="page-section profile-shell reveal" v-reveal>
      <SecHead>Your Profile</SecHead>

      <p class="profile-intro">
        Keep your DMAC profile ready for recording, posting, and editing school events. Update the name members see, add a short bio, and shape the public card that represents your work.
      </p>

      <div v-if="!member" class="profile-loading">Loading…</div>

      <div v-else class="profile-layout">
        <aside class="profile-viewer">
          <!-- ══════════════ RANK CARD — public preview ══════════════
               Redesigned per the new mockup: a mountain-silhouette
               banner, identity + leaderboard rank, a radial diagram of
               the member's live Threads score and its 5 factors, and
               their badge collection. --rank-color is set here on the
               root element and cascades down through the CSS var
               system to both the rank pill and the radial diagram. -->
          <section class="rank-card" :style="{ '--rank-color': rankColor }">
            <div class="rank-card-banner">
              <svg class="rank-card-zigzag" viewBox="0 0 400 90" preserveAspectRatio="none" aria-hidden="true">
                <polygon :points="ZIGZAG_POINTS" :fill="rankColor" opacity="0.32" />
              </svg>

              <div class="rank-card-socials">
                <a
                  v-for="(link, i) in previewLinks"
                  :key="i"
                  class="rank-card-social"
                  :href="link.url"
                  target="_blank"
                  rel="noopener"
                >{{ link.label }}</a>
                <span v-if="!previewLinks.length" class="rank-card-social rank-card-social--ghost">No socials yet</span>
              </div>

              <div class="rank-card-avatar-wrap">
                <img v-if="avatarUrl" :src="avatarUrl" class="rank-card-avatar" alt="Avatar preview" />
                <span v-else class="rank-card-avatar-fallback">{{ avatarInitials }}</span>
              </div>
            </div>

            <div class="rank-card-identity">
              <div class="rank-card-name-block">
                <h3>{{ publicName }}</h3>
                <span class="rank-card-section">{{ member.club_role || 'DMAC member' }}</span>
                <p class="rank-card-bio">
                  {{ bio.trim() || 'Write a short bio about the events you cover, the edits you handle, or the tools you are best at using.' }}
                </p>
              </div>

              <div class="rank-card-meta">
                <div class="rank-card-meta-item">
                  <span>Position</span>
                  <strong>{{ member.site_role === 'admin' ? 'Admin' : 'Member' }}</strong>
                </div>
                <div class="rank-card-meta-item">
                  <span>Leaderboard</span>
                  <strong class="rank-card-rank-value">{{ threadsRank ? `#${threadsRank}` : '—' }}</strong>
                </div>
              </div>
            </div>

            <div class="rank-card-body">
              <!-- Radial diagram — Threads composite in the center, its
                   5 rolling factors around it, each idly floating. -->
              <div class="rank-card-radar">
                <svg class="rank-card-radar-lines" viewBox="0 0 260 260" aria-hidden="true">
                  <line
                    v-for="n in factorNodes"
                    :key="n.key"
                    x1="130" y1="130"
                    :x2="n.x" :y2="n.y"
                  />
                </svg>

                <div class="rank-node rank-node--threads">
                  <span>{{ threadsScore != null ? Math.round(threadsScore) : '—' }}</span>
                  <small>Threads</small>
                </div>

                <div
                  v-for="(n, i) in factorNodes"
                  :key="n.key"
                  class="rank-node rank-node--factor"
                  :style="{ left: `${n.x}px`, top: `${n.y}px`, animationDelay: `${i * 0.6}s` }"
                >
                  <span>{{ n.display }}</span>
                  <small>{{ n.label }}</small>
                </div>
              </div>

              <!-- Badge collection -->
              <div class="rank-card-badges">
                <div class="rank-card-badges-head">
                  <strong>{{ badges.length }}/{{ totalBadgeTypes }} badges</strong>
                  <span>{{ badgePercent }}%<template v-if="badgeRank"> · top {{ badgeRank }}/{{ rosterCount || '?' }}</template></span>
                </div>
                <div class="rank-card-badges-grid">
                  <div
                    v-for="b in badges"
                    :key="b.badge_id"
                    class="rank-badge-chip"
                    :style="{ '--tier-color': tierColorFor(b.tierKey) }"
                    :title="b.name"
                  >
                    <div v-if="badgeBgSvg(b.tierKey)" class="rank-badge-bg" v-html="badgeBgSvg(b.tierKey)"></div>
                    <span v-else class="rank-badge-diamond">◆</span>
                  </div>
                  <p v-if="!badges.length" class="rank-card-badges-empty">No badges yet — keep at it!</p>
                </div>
              </div>
            </div>
          </section>

          <p class="profile-viewer-note">
            This is the public-facing card people will use when checking who is available to cover school events.
          </p>
        </aside>

        <section class="profile-editor">
          <p v-if="statusMsg" class="profile-status" :class="statusType">{{ statusMsg }}</p>

          <div class="profile-grid">
            <section class="profile-panel">
              <div class="profile-panel-head">
                <h3>Identity</h3>
                <span>What your club sees first</span>
              </div>
              <label class="profile-field">
                <span>Nickname</span>
                <input class="profile-input" v-model="nickname" maxlength="40" placeholder="Choose a display nickname" />
              </label>
              <button class="profile-btn" v-sfx-hover @click="saveNickname">Save nickname</button>
            </section>

            <section class="profile-panel">
              <div class="profile-panel-head">
                <h3>Bio and links</h3>
                <span>Brief, clear, and public-facing</span>
              </div>
              <label class="profile-field">
                <span>Bio</span>
                <textarea class="profile-textarea" v-model="bio" maxlength="500" rows="6" placeholder="Share what you do for DMAC, what events you like covering, and what tools you use."></textarea>
              </label>

              <div class="profile-links-head">
                <h4>Social links</h4>
                <span>Max 3 links</span>
              </div>

              <div class="profile-link-stack">
                <div v-for="(link, i) in socialLinks" :key="i" class="profile-link-row">
                  <input class="profile-input" v-model="link.label" placeholder="Label (e.g. Instagram)" />
                  <input class="profile-input" v-model="link.url" placeholder="https://..." />
                  <button class="profile-btn profile-btn--danger" v-sfx-hover @click="removeLink(i)">Remove</button>
                </div>
              </div>

              <div class="profile-actions">
                <button v-if="socialLinks.length < 3" class="profile-btn profile-btn--ghost" v-sfx-hover @click="addLink">Add link</button>
                <button class="profile-btn" v-sfx-hover @click="saveBioAndLinks">Save bio and links</button>
              </div>
            </section>

            <section class="profile-panel">
              <div class="profile-panel-head">
                <h3>Media</h3>
                <span>Avatar and banner used on the public card</span>
              </div>

              <label class="profile-media-row">
                <span class="profile-media-preview profile-media-preview--avatar">
                  <img v-if="avatarUrl" :src="avatarUrl" alt="Avatar preview" />
                  <strong v-else>{{ avatarInitials }}</strong>
                </span>
                <span class="profile-media-copy">
                  <strong>Avatar</strong>
                  <small>Square image for the profile badge.</small>
                </span>
                <input class="profile-file" type="file" accept="image/*" @change="onAvatarChosen" />
              </label>

              <label class="profile-media-row profile-media-row--banner">
                <span class="profile-media-preview profile-media-preview--banner">
                  <img v-if="bannerUrl" :src="bannerUrl" alt="Banner preview" />
                  <strong v-else>Banner</strong>
                </span>
                <span class="profile-media-copy">
                  <strong>Banner</strong>
                  <small>Wide image for the top of your profile.</small>
                </span>
                <input class="profile-file" type="file" accept="image/*,.gif" @change="onBannerChosen" />
              </label>

              <div class="profile-banner-color">
                <span class="profile-media-copy">
                  <strong>Banner color</strong>
                  <small>Shown when no banner image is set.</small>
                </span>
                <div class="profile-color-row">
                  <button
                    v-for="c in BANNER_COLORS"
                    :key="c"
                    class="profile-color-swatch"
                    :class="{ selected: bannerColor === c }"
                    :style="{ background: c }"
                    :aria-label="`Banner color ${c}`"
                    v-sfx-hover
                    @click="bannerColor = c"
                  ></button>
                </div>
                <ColorWheelPicker :model-value="bannerColor || '#f97316'" @update:model-value="bannerColor = $event" />
                <div class="profile-hex-row">
                  <span class="profile-hex-swatch" :style="{ background: bannerColor || '#f97316' }" aria-hidden="true"></span>
                  <input
                    class="profile-input profile-hex-input"
                    :class="{ 'profile-hex-input--error': hexError }"
                    type="text"
                    v-model="hexDraft"
                    maxlength="7"
                    placeholder="#f97316"
                    aria-label="Banner color hex code"
                    @input="onHexInput"
                    @blur="onHexBlur"
                  />
                </div>
                <p v-if="hexError" class="profile-hex-error">{{ hexError }}</p>
                <button class="profile-btn" v-sfx-hover @click="saveBannerColor">Save banner color</button>
              </div>
            </section>

            <section class="profile-panel profile-panel--full">
              <div class="profile-panel-head">
                <h3>Password</h3>
                <span>Keep access current</span>
              </div>
              <div class="profile-password-grid">
                <label class="profile-field">
                  <span>Current password</span>
                  <input class="profile-input" type="password" v-model="oldPassword" placeholder="Current password" />
                </label>
                <label class="profile-field">
                  <span>New password</span>
                  <input class="profile-input" type="password" v-model="newPassword" placeholder="New password" />
                </label>
                <label class="profile-field">
                  <span>Confirm new password</span>
                  <input class="profile-input" type="password" v-model="confirmPassword" placeholder="Confirm new password" />
                </label>
              </div>
              <button class="profile-btn" v-sfx-hover @click="savePassword">Change password</button>
            </section>
          </div>
        </section>
      </div>
    </div>

    <AvatarCropModal
      v-if="pendingAvatarFile"
      :file="pendingAvatarFile"
      @cropped="onAvatarCropped"
      @cancel="onAvatarCropCancelled"
    />
  </main>
</template>

<script setup>
/* ProfileView.vue — private self-service profile editor at /profile.
   Reachable only when logged in (see the requiresAuth guard in
   router/index.js). This page mirrors the public profile card and
   gives members a cleaner place to maintain the name, bio, links, and
   media used when they are assigned to cover school events.

   Google-linking itself is NOT reimplemented here — that OAuth
   redirect/callback dance already lives in LoginView.vue. If someone
   isn't Google-linked yet, this page just points them back to /login
   to do it there, rather than duplicating that flow.

   RANK CARD — the public-preview aside now surfaces live Bits/Threads
   data (per bits-threads-spec.md / dmac-consolidated-plan.md §6–§8):
   the member's Threads composite + its 5 rolling factors laid out
   radially, their leaderboard rank, and their badge collection
   (reusing the same Leaderboard helpers about/MembersView.vue and
   RightPanel.vue already use). Everything here degrades gracefully —
   a brand-new member with no Threads/badge rows yet just shows '—'
   and empty states, not an error. */
import { ref, onMounted, computed, watch } from 'vue';
import { useRouter } from 'vue-router';
import SecHead from '../components/SecHead.vue';
import AvatarCropModal from '../components/AvatarCropModal.vue';
import ColorWheelPicker from '../components/ColorWheelPicker.vue';
import MemberAuth from '../lib/member-auth.js';
import MemberProfile from '../lib/member-profile.js';
import { sb } from '../lib/supabase-client.js';
import Leaderboard from '../lib/leaderboard.js';
import { BADGE_SVG } from '../lib/badges.js';
import { playSfx } from '../composables/useSfx.js';

const router = useRouter();

const member = ref(null);

const nickname = ref('');
const oldPassword = ref('');
const newPassword = ref('');
const confirmPassword = ref('');
const bio = ref('');
const socialLinks = ref([]); // [{ label, url }]
const avatarUrl = ref(null);
const bannerUrl = ref(null);
const bannerColor = ref(null);
const yearJoined = ref('2026');

const BANNER_COLORS = ['#f97316', '#a855f7', '#38bdf8', '#22c55e', '#ef4444', '#eab308', '#0f172a'];

/* ── HEX CODE INPUT ─────────────────────────────────
   The swatches + native <input type="color"> (a full OS color-picker
   dialog) were the whole "card color switcher" story before this —
   there was no way to just type a code you already know. bannerColor
   stays the single source of truth; hexDraft is a synced text mirror
   that only writes back once it's actually a valid hex string, so a
   half-typed value doesn't blow away the real color while you're
   still typing it. */
const HEX_RE = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i;
const hexDraft = ref(bannerColor.value || '#f97316');
const hexError = ref('');

watch(bannerColor, (val) => {
  hexDraft.value = val || '#f97316';
});

function normalizeHex(v) {
  const body = v.slice(1);
  const expanded = body.length === 3 ? body.split('').map((c) => c + c).join('') : body;
  return `#${expanded.toLowerCase()}`;
}

function onHexInput() {
  let v = hexDraft.value.trim();
  if (v && !v.startsWith('#')) v = `#${v}`;
  if (v !== hexDraft.value) hexDraft.value = v;

  if (v === '' || v === '#') {
    hexError.value = '';
    return;
  }
  if (HEX_RE.test(v)) {
    hexError.value = '';
    bannerColor.value = normalizeHex(v);
  } else {
    hexError.value = 'Needs to be a hex code, like #f97316 or #f73.';
  }
}

function onHexBlur() {
  // Leaving the field with something incomplete/invalid still on
  // screen — snap the visible text back to the last real color rather
  // than leaving a red, unsaved-looking box behind.
  if (hexDraft.value && !HEX_RE.test(hexDraft.value)) {
    hexDraft.value = bannerColor.value || '#f97316';
    hexError.value = '';
  }
}

const publicName = computed(() => nickname.value.trim() || member.value?.display_name || 'DMAC member');
const avatarInitials = computed(() => {
  const source = publicName.value || member.value?.display_name || 'DMAC';
  return source
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || '')
    .join('') || 'DMAC';
});
const previewLinks = computed(() => socialLinks.value.filter((link) => link.label.trim() && link.url.trim()).slice(0, 3));
const joinedYear = computed(() => member.value?.year_joined || '2026');

const statusMsg = ref('');
const statusType = ref('info'); // 'info' | 'success' | 'error'

function status(msg, type = 'info') {
  statusMsg.value = msg;
  statusType.value = type;
}

/* ── RANK CARD DATA ──────────────────────────────────────────────── */
const FACTOR_DEFS = [
  { key: 'ping', label: 'Ping' },
  { key: 'bandwidth', label: 'Bandwidth' },
  { key: 'flops', label: 'FLOPS' },
  { key: 'commits', label: 'Commits' },
  { key: 'hertz', label: 'Hertz' },
];

// Static mountain-range silhouette for the rank card's banner —
// same triangle-strip idea as FooterSection.vue/MembersView.vue's
// zigzag dividers, just a fixed set of points rather than an
// animated one (this banner is small and behind other content, so a
// static shape reads cleaner than a moving one competing for
// attention with the radial diagram below it).
const ZIGZAG_POINTS = '0,90 0,52 40,16 80,54 120,10 160,50 200,20 240,58 280,14 320,52 360,18 400,50 400,90';

const threadsScore = ref(null);
const threadsFactors = ref({});
const threadsRank = ref(null);
const rosterCount = ref(0);
const rankColor = ref('#f0f0f0');

const badges = ref([]);
const badgeRank = ref(null);
const totalBadgeTypes = Object.keys(Leaderboard.BADGE_LABELS).length;
const badgePercent = computed(() => (totalBadgeTypes ? Math.round((badges.value.length / totalBadgeTypes) * 100) : 0));

// Pentagon layout around a 260x260 diagram, Threads sitting dead
// center — same idea as the mockup's "the higher you are the more
// the color shifts" note, applied here to every node's line color
// via the shared --rank-color custom property rather than per-node.
const factorNodes = computed(() => {
  const cx = 130, cy = 130, r = 92;
  return FACTOR_DEFS.map((f, i) => {
    const angle = (-90 + (360 / FACTOR_DEFS.length) * i) * (Math.PI / 180);
    const raw = threadsFactors.value[f.key];
    return {
      ...f,
      x: cx + r * Math.cos(angle),
      y: cy + r * Math.sin(angle),
      display: raw != null ? `${Math.round(raw * 100)}%` : '—',
    };
  });
});

// white (rank floor) -> orange (mid pack) -> gold (top of the board)
function colorForPercentile(p) {
  const clamp = Math.max(0, Math.min(1, p));
  const stops = [
    { at: 0, c: [176, 176, 176] },
    { at: 0.5, c: [249, 115, 22] },
    { at: 1, c: [255, 215, 0] },
  ];
  const [a, b] = clamp > 0.5 ? [stops[1], stops[2]] : [stops[0], stops[1]];
  const t = a.at === b.at ? 0 : (clamp - a.at) / (b.at - a.at);
  const mix = a.c.map((v, i) => Math.round(v + (b.c[i] - v) * t));
  return `rgb(${mix[0]}, ${mix[1]}, ${mix[2]})`;
}

function tierColorFor(tierKey) {
  return Leaderboard.TIER_COLORS[tierKey] || '#888';
}
function badgeBgSvg(tierKey) {
  return BADGE_SVG[`${tierKey}-badge`] || null;
}

async function loadRankData(slug) {
  if (!slug) return;

  // Threads composite + rank — requires schema-additions-v2-rework.sql's
  // `threads` table + members FK. A query error here (missing
  // migration, RLS not applied yet) just leaves the radar at its
  // '—' empty state rather than throwing.
  const { data: threadsRows, error: threadsError } = await sb
    .from('threads')
    .select('member_id, score, ping_factor, bandwidth_factor, flops_factor, commits_factor, hertz_factor, members!inner(slug)')
    .order('score', { ascending: false });

  if (!threadsError && threadsRows) {
    rosterCount.value = threadsRows.length;
    const idx = threadsRows.findIndex((r) => r.members?.slug === slug);
    if (idx !== -1) {
      const row = threadsRows[idx];
      threadsScore.value = row.score;
      threadsFactors.value = {
        ping: row.ping_factor,
        bandwidth: row.bandwidth_factor,
        flops: row.flops_factor,
        commits: row.commits_factor,
        hertz: row.hertz_factor,
      };
      threadsRank.value = idx + 1;
      const percentile = threadsRows.length > 1 ? 1 - idx / (threadsRows.length - 1) : 1;
      rankColor.value = colorForPercentile(percentile);
    }
  } else if (threadsError) {
    console.error('ProfileView: could not load Threads data —', threadsError.message);
  }

  // Badges — same Leaderboard helpers about/MembersView.vue and
  // RightPanel.vue already use, so this stays in sync with how
  // badges render everywhere else on the site.
  try {
    const scores = await Leaderboard.fetchScores();
    const stored = Leaderboard.getBadgesForSlug(scores, slug);
    const computed = Leaderboard.getCompletionStatus(scores, slug);
    badges.value = [...stored, ...computed];

    const bySlug = {};
    for (const s of scores) {
      if (!s.slug) continue;
      if (!bySlug[s.slug]) bySlug[s.slug] = new Set();
      bySlug[s.slug].add(s.badge_id);
    }
    const counts = Object.entries(bySlug)
      .map(([s, set]) => ({ slug: s, count: set.size }))
      .sort((a, b) => b.count - a.count);
    const myIdx = counts.findIndex((c) => c.slug === slug);
    badgeRank.value = myIdx !== -1 ? myIdx + 1 : null;
  } catch (err) {
    console.error('ProfileView: could not load badges —', err.message);
  }
}

onMounted(async () => {
  // The route guard already keeps logged-out visitors from reaching
  // this page, but on a hard refresh its own restoreSession() call
  // may only just have finished — read the reactive ref rather than
  // assuming MemberAuth.current() is populated by the time this
  // component's very first tick runs.
  member.value = MemberAuth.current();
  if (!member.value) {
    router.replace('/login');
    return;
  }

  const profile = await MemberProfile.fetchProfile(member.value.slug);
  // nickname falls back to the official display_name until the member
  // picks their own — editing this field never touches display_name.
  nickname.value = profile.nickname || member.value.display_name || '';
  bio.value = profile.bio || '';
  socialLinks.value = Array.isArray(profile.social_links)
    ? profile.social_links.map((link) => ({ label: link?.label || '', url: link?.url || '' }))
    : [];
  avatarUrl.value = profile.avatar_url;
  bannerUrl.value = profile.banner_url;
  bannerColor.value = profile.banner_color || null;
  yearJoined.value = profile.year_joined || '2026';

  loadRankData(member.value.slug);
});

async function saveBannerColor() {
  playSfx('menuclick');
  if (!bannerColor.value) {
    status('Pick a banner color first.', 'error');
    return;
  }
  const result = await MemberProfile.updateBannerColor(bannerColor.value);
  if (result.success) {
    status('Banner color saved.', 'success');
  } else {
    status(result.message || 'Could not save banner color.', 'error');
  }
}

async function saveNickname() {
  playSfx('menuclick');
  const result = await MemberProfile.updateNickname(nickname.value);
  if (result.success) {
    status('Nickname updated.', 'success');
    // Deliberately NOT touching member.value.display_name — nickname
    // and display_name are separate fields, editing one never renames
    // the other.
  } else {
    status(result.message || 'Could not update nickname.', 'error');
  }
}

async function savePassword() {
  playSfx('menuclick');
  if (!oldPassword.value || !newPassword.value) {
    status('Fill in both password fields.', 'error');
    return;
  }
  if (newPassword.value !== confirmPassword.value) {
    status("New passwords don't match.", 'error');
    return;
  }
  const result = await MemberAuth.changeOwnPassword(oldPassword.value, newPassword.value);
  if (result.success) {
    status('Password changed.', 'success');
    oldPassword.value = '';
    newPassword.value = '';
    confirmPassword.value = '';
  } else {
    status(result.message || 'Could not change password.', 'error');
  }
}

function addLink() {
  if (socialLinks.value.length >= 3) return;
  socialLinks.value.push({ label: '', url: '' });
}

function removeLink(i) {
  socialLinks.value.splice(i, 1);
}

async function saveBioAndLinks() {
  playSfx('menuclick');
  const cleanedLinks = socialLinks.value
    .filter((l) => l.label.trim() && l.url.trim())
    .slice(0, 3);

  const result = await MemberProfile.updateProfile({ bio: bio.value, socialLinks: cleanedLinks });
  if (result.success) {
    status('Profile updated.', 'success');
    socialLinks.value = cleanedLinks;
  } else {
    status(result.message || 'Could not update profile.', 'error');
  }
}

// Picking a file opens the crop modal instead of uploading straight
// away — pendingAvatarFile holding a File is what mounts it (see
// template). The actual upload only happens once a crop is confirmed.
const pendingAvatarFile = ref(null);

function onAvatarChosen(e) {
  const file = e.target.files[0];
  // Clears the input so choosing the exact same file again after a
  // Cancel still fires `change` — browsers only fire it on a value
  // change, and re-picking an identical file wouldn't otherwise count.
  e.target.value = '';
  if (!file) return;
  pendingAvatarFile.value = file;
}

async function onAvatarCropped(croppedFile) {
  pendingAvatarFile.value = null;
  status('Uploading avatar…', 'info');
  const result = await MemberProfile.uploadAvatar(croppedFile);
  if (result.success) {
    avatarUrl.value = result.url;
    status('Avatar updated.', 'success');
  } else {
    status(result.message || 'Avatar upload failed.', 'error');
  }
}

function onAvatarCropCancelled() {
  pendingAvatarFile.value = null;
}

async function onBannerChosen(e) {
  const file = e.target.files[0];
  if (!file) return;
  status('Uploading banner…', 'info');
  const result = await MemberProfile.uploadBanner(file);
  if (result.success) {
    bannerUrl.value = result.url;
    status('Banner updated.', 'success');
  } else {
    status(result.message || 'Banner upload failed.', 'error');
  }
}
</script>

<style scoped>
.profile-shell {
  gap: 22px;
}

.profile-intro {
  max-width: 820px;
  color: rgba(240, 240, 240, 0.72);
  line-height: 1.7;
  font-size: 1rem;
}

.profile-loading {
  min-height: 180px;
  display: grid;
  place-items: center;
  border-radius: 20px;
  border: 1px solid rgba(255, 255, 255, 0.07);
  background: rgba(255, 255, 255, 0.03);
  color: rgba(240, 240, 240, 0.68);
}

.profile-layout {
  display: grid;
  grid-template-columns: minmax(300px, 420px) minmax(0, 1fr);
  gap: 24px;
  align-items: start;
}

.profile-viewer {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.profile-viewer-note {
  padding: 0 6px;
  line-height: 1.5;
  font-size: 0.88rem;
  color: rgba(240, 240, 240, 0.58);
}

/* ── RANK CARD ─────────────────────────────────────────────────────── */
.rank-card {
  border-radius: 28px;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.09);
  background: rgba(13, 13, 13, 0.82);
  box-shadow: 0 20px 48px rgba(0, 0, 0, 0.34);
}

.rank-card-banner {
  position: relative;
  height: 116px;
  background: linear-gradient(160deg, #1c1c22, #0d0d0d);
  overflow: hidden;
}
.rank-card-zigzag {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}
.rank-card-socials {
  position: absolute;
  top: 12px;
  right: 14px;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 8px;
  max-width: 65%;
}
.rank-card-social {
  font-size: 0.7rem;
  color: rgba(240, 240, 240, 0.78);
  background: rgba(0, 0, 0, 0.4);
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: 999px;
  padding: 4px 10px;
  text-decoration: none;
  white-space: nowrap;
}
.rank-card-social--ghost {
  color: rgba(240, 240, 240, 0.42);
}

.rank-card-avatar-wrap {
  position: absolute;
  left: 20px;
  bottom: -34px;
  z-index: 2;
  width: 88px;
  height: 88px;
  border-radius: 24px;
  padding: 5px;
  background: linear-gradient(135deg, rgba(249, 115, 22, 0.9), rgba(76, 29, 149, 0.9));
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.4);
}
.rank-card-avatar {
  width: 100%;
  height: 100%;
  border-radius: 19px;
  object-fit: cover;
  display: block;
}
.rank-card-avatar-fallback {
  width: 100%;
  height: 100%;
  border-radius: 19px;
  display: grid;
  place-items: center;
  background: #111;
  color: #fff;
  font-size: 1.15rem;
  letter-spacing: 0.08em;
}

.rank-card-identity {
  padding: 44px 20px 18px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.rank-card-name-block h3 {
  margin: 0 0 2px;
  font-size: 1.14rem;
  line-height: 1.2;
}
.rank-card-section {
  font-size: 0.76rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: rgba(240, 240, 240, 0.55);
}
.rank-card-bio {
  margin: 8px 0 0;
  font-size: 0.85rem;
  line-height: 1.6;
  color: rgba(240, 240, 240, 0.78);
}

.rank-card-meta {
  display: flex;
  gap: 12px;
}
.rank-card-meta-item {
  flex: 1;
  padding: 10px 12px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.06);
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.rank-card-meta-item span {
  font-size: 0.66rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: rgba(240, 240, 240, 0.5);
}
.rank-card-meta-item strong {
  font-size: 1rem;
}
.rank-card-rank-value {
  color: var(--rank-color, #f0f0f0);
}

.rank-card-body {
  display: flex;
  flex-wrap: wrap;
  gap: 18px;
  padding: 0 20px 22px;
}

/* ── RADIAL DIAGRAM ─────────────────────────────────────────────────
   260x260 stage, Threads centered, 5 factor nodes pentagon-arranged
   around it (see factorNodes computed). Lines + node fills key off
   --rank-color, set on .rank-card above, so the whole diagram warms
   from white toward gold the higher the member's Threads rank is. */
.rank-card-radar {
  position: relative;
  width: 260px;
  height: 260px;
  margin: 0 auto;
  flex-shrink: 0;
}
.rank-card-radar-lines {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}
.rank-card-radar-lines line {
  stroke: color-mix(in srgb, var(--rank-color, #888) 35%, rgba(255, 255, 255, 0.12));
  stroke-width: 1;
}

.rank-node {
  position: absolute;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  text-align: center;
  line-height: 1.15;
}

.rank-node--threads {
  left: 130px;
  top: 130px;
  transform: translate(-50%, -50%);
  width: 84px;
  height: 84px;
  z-index: 2;
  background: radial-gradient(circle, color-mix(in srgb, var(--rank-color, #f97316) 32%, #111) 0%, #111 78%);
  border: 2px solid var(--rank-color, #f97316);
  box-shadow: 0 0 22px color-mix(in srgb, var(--rank-color, #f97316) 40%, transparent);
}
.rank-node--threads span {
  font-family: var(--font);
  font-weight: 700;
  font-size: 1.05rem;
  color: #fff;
}
.rank-node--threads small {
  font-size: 0.58rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: rgba(240, 240, 240, 0.62);
}

.rank-node--factor {
  transform: translate(-50%, -50%);
  width: 56px;
  height: 56px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid color-mix(in srgb, var(--rank-color, #888) 45%, rgba(255, 255, 255, 0.14));
  animation: rank-float 4.6s ease-in-out infinite;
}
.rank-node--factor span {
  font-size: 0.74rem;
  font-weight: 600;
  color: #fff;
}
.rank-node--factor small {
  font-size: 0.52rem;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: rgba(240, 240, 240, 0.55);
}

@keyframes rank-float {
  0%, 100% { transform: translate(-50%, -50%) translateY(0); }
  50%      { transform: translate(-50%, -50%) translateY(-6px); }
}

@media (prefers-reduced-motion: reduce) {
  .rank-node--factor { animation: none; }
}

/* ── BADGE COLLECTION ────────────────────────────────────────────── */
.rank-card-badges {
  flex: 1;
  min-width: 200px;
}
.rank-card-badges-head {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 10px;
  font-size: 0.8rem;
  color: rgba(240, 240, 240, 0.6);
}
.rank-card-badges-head strong {
  color: #fff;
  font-size: 0.94rem;
}
.rank-card-badges-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(40px, 1fr));
  gap: 8px;
}
.rank-badge-chip {
  position: relative;
  aspect-ratio: 1;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--tier-color, rgba(255, 255, 255, 0.14));
  display: grid;
  place-items: center;
  overflow: hidden;
}
.rank-badge-bg :deep(svg) {
  width: 100%;
  height: 100%;
}
.rank-badge-diamond {
  color: var(--tier-color, #888);
  font-size: 1.1rem;
}
.rank-card-badges-empty {
  grid-column: 1 / -1;
  margin: 0;
  color: rgba(240, 240, 240, 0.5);
  font-size: 0.84rem;
}

/* ── EDITOR (unchanged from before) ─────────────────────────────── */
.profile-editor {
  min-width: 0;
}

.profile-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 18px;
}

.profile-panel,
.profile-panel--full {
  border-radius: 24px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.04);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.03);
  padding: 18px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.profile-panel--full {
  grid-column: 1 / -1;
}

.profile-panel-head,
.profile-links-head {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 12px;
}

.profile-panel-head h3,
.profile-links-head h4 {
  font-size: 1rem;
  color: rgba(240, 240, 240, 0.9);
}

.profile-panel-head span,
.profile-links-head span,
.profile-media-copy small {
  color: rgba(240, 240, 240, 0.58);
}

.profile-field {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.profile-field span {
  font-size: 0.76rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: rgba(240, 240, 240, 0.55);
}

.profile-input,
.profile-textarea {
  width: 100%;
  font: inherit;
  color: #f7f4ee;
  border-radius: 16px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  background: rgba(8, 8, 12, 0.58);
  padding: 12px 14px;
  outline: none;
  transition: border-color 0.2s ease, box-shadow 0.2s ease, transform 0.2s ease;
}

.profile-textarea {
  resize: vertical;
  min-height: 156px;
}

.profile-input:focus,
.profile-textarea:focus {
  border-color: rgba(249, 115, 22, 0.7);
  box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.18);
}

.profile-link-stack {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.profile-link-row {
  display: grid;
  grid-template-columns: minmax(0, 0.8fr) minmax(0, 1.2fr) auto;
  gap: 10px;
  align-items: start;
}

.profile-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 12px;
  margin-top: 2px;
}

.profile-btn {
  align-self: flex-start;
  font: inherit;
  border: none;
  cursor: pointer;
  color: #fff;
  border-radius: 999px;
  padding: 11px 18px;
  background: linear-gradient(135deg, var(--orange), var(--purple));
  box-shadow: 0 10px 24px rgba(76, 29, 149, 0.22);
  text-decoration: none;
}

.profile-btn--ghost {
  background: rgba(255, 255, 255, 0.06);
  box-shadow: none;
}

.profile-btn--danger {
  background: rgba(184, 61, 61, 0.16);
  color: #ffb0b0;
  border: 1px solid rgba(255, 130, 130, 0.2);
}

.profile-status {
  padding: 11px 14px;
  border-radius: 18px;
  font-size: 0.9rem;
  border: 1px solid transparent;
}

.profile-status.success {
  background: rgba(20, 61, 31, 0.76);
  color: #9ff0b4;
  border-color: rgba(159, 240, 180, 0.16);
}

.profile-status.error {
  background: rgba(61, 20, 20, 0.78);
  color: #ffb0b0;
  border-color: rgba(255, 176, 176, 0.16);
}

.profile-status.info {
  background: rgba(26, 42, 61, 0.78);
  color: #aed7ff;
  border-color: rgba(174, 215, 255, 0.16);
}

.profile-media-row {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  grid-template-areas:
    "preview copy"
    "file    file";
  gap: 6px 14px;
  padding: 14px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
}

.profile-media-row .profile-file {
  grid-area: file;
  width: 100%;
  max-width: 100%;
}

.profile-media-row .profile-media-preview {
  grid-area: preview;
}

.profile-media-row .profile-media-copy {
  grid-area: copy;
}

.profile-media-preview {
  display: grid;
  place-items: center;
  overflow: hidden;
  background: rgba(8, 8, 12, 0.58);
  border: 1px solid rgba(255, 255, 255, 0.1);
}

.profile-media-preview--avatar {
  width: 72px;
  height: 72px;
  border-radius: 20px;
}

.profile-media-preview--banner {
  width: 180px;
  min-height: 72px;
  border-radius: 16px;
}

.profile-media-preview img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.profile-media-preview strong {
  color: rgba(240, 240, 240, 0.55);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  font-size: 0.72rem;
}

.profile-media-copy {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.profile-media-copy strong {
  font-size: 0.92rem;
}

.profile-file {
  font: inherit;
  color: rgba(240, 240, 240, 0.8);
}

.profile-banner-color {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 14px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
}

.profile-color-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.profile-color-swatch {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  border: 2px solid rgba(255, 255, 255, 0.16);
  cursor: pointer;
  transition: transform 0.15s ease, border-color 0.15s ease;
}

.profile-color-swatch:hover {
  transform: scale(1.12);
}

.profile-color-swatch.selected {
  border-color: #fff;
  transform: scale(1.12);
}

.profile-hex-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.profile-hex-swatch {
  flex-shrink: 0;
  width: 30px;
  height: 30px;
  border-radius: 50%;
  border: 2px solid rgba(255, 255, 255, 0.16);
}

.profile-hex-input {
  max-width: 160px;
  font-family: 'Rajdhani', monospace;
  letter-spacing: 0.06em;
  text-transform: lowercase;
}

.profile-hex-input--error {
  border-color: rgba(239, 68, 68, 0.6);
}

.profile-hex-error {
  font-size: 0.78rem;
  color: #ffb0b0;
  margin-top: -4px;
}

.profile-password-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.profile-panel--full .profile-btn {
  margin-top: 2px;
}

@media (max-width: 1040px) {
  .profile-layout {
    grid-template-columns: 1fr;
  }

  .profile-grid {
    grid-template-columns: 1fr;
  }

  .profile-password-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .rank-card-avatar-wrap {
    width: 76px;
    height: 76px;
  }

  .rank-card-radar {
    width: 230px;
    height: 230px;
  }

  .profile-link-row {
    grid-template-columns: 1fr;
  }

  .profile-media-row {
    grid-template-columns: 1fr;
    grid-template-areas:
      "preview"
      "copy"
      "file";
    justify-items: start;
  }

  .profile-media-preview--banner {
    width: 100%;
  }

  .profile-actions {
    flex-direction: column;
  }
}
</style>

<style scoped>
.profile-field--color {
  max-width: 240px;
}

.profile-color-input {
  width: 100%;
  min-height: 44px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 14px;
  background: transparent;
  padding: 4px;
}
</style>