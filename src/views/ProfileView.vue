<template>
  <main class="profile-page">
    <PageHero title="Your Profile" />
    <div class="page-section profile-shell reveal" v-reveal>
      <p class="profile-intro">
        Keep your DMAC profile ready for recording, posting, and editing school events. Update the name members see, add a short bio, and shape the public card that represents your work.
      </p>

      <div v-if="!member" class="profile-loading">Loading…</div>

      <div v-else class="profile-layout">
        <aside class="profile-viewer">
          <MemberCard
            :name="publicName"
            :section="member.club_role || 'DMAC member'"
            :position="member.site_role === 'admin' ? 'Admin' : 'Member'"
            :bio="bio.trim() || 'Write a short bio about the events you cover, the edits you handle, or the tools you are best at using.'"
            :initials="avatarInitials"
            :avatar-url="avatarUrl"
            :banner-url="bannerUrl"
            :banner-color="bannerColor"
            :socials="previewLinks"
            :rank="threadsRank"
            :rank-color="rankColor"
            :threads-score="threadsScore"
            :threads-factors="threadsFactors"
            :badges="badges"
            :badge-rank="badgeRank"
            :roster-count="rosterCount"
          />
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
   The public-preview aside is now just a thin wrapper around the
   shared MemberCard.vue (see that file's header) — this view's own
   job is resolving the data MemberCard needs (profile fields, live
   Threads rank/factors, badges) and handing them down as props,
   plus the actual editor form below it, which is unchanged. */
import { ref, onMounted, computed, watch } from 'vue';
import { useRouter } from 'vue-router';
import PageHero from '../components/PageHero.vue';
import AvatarCropModal from '../components/AvatarCropModal.vue';
import ColorWheelPicker from '../components/ColorWheelPicker.vue';
import MemberCard from '../components/MemberCard.vue';
import MemberAuth from '../lib/member-auth.js';
import MemberProfile from '../lib/member-profile.js';
import Leaderboard from '../lib/leaderboard.js';
import { fetchThreadsBoard, rankByBadgeCount } from '../lib/threads-board.js';
import { colorForPercentile } from '../lib/rank-color.js';
import { playSfx } from '../composables/useSfx.js';

const router = useRouter();

const member = ref(null);

const nickname = ref('');
const oldPassword = ref('');
const newPassword = ref('');
const confirmPassword = ref('');
const bio = ref('');
const socialLinks = ref([]);
const avatarUrl = ref(null);
const bannerUrl = ref(null);
const bannerColor = ref(null);

const BANNER_COLORS = ['#f97316', '#a855f7', '#38bdf8', '#22c55e', '#ef4444', '#eab308', '#0f172a'];

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
  if (hexDraft.value && !HEX_RE.test(hexDraft.value)) {
    hexDraft.value = bannerColor.value || '#f97316';
    hexError.value = '';
  }
}

const publicName = computed(() => nickname.value.trim() || member.value?.display_name || 'DMAC member');
const avatarInitials = computed(() => {
  const source = publicName.value || member.value?.display_name || 'DMAC';
  return source.trim().split(/\s+/).filter(Boolean).slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || '').join('') || 'DMAC';
});
const previewLinks = computed(() => socialLinks.value.filter((link) => link.label.trim() && link.url.trim()).slice(0, 3));

const statusMsg = ref('');
const statusType = ref('info');

function status(msg, type = 'info') {
  statusMsg.value = msg;
  statusType.value = type;
}

/* ── RANK CARD DATA (fed into MemberCard) ─────────────────────── */
const threadsScore = ref(null);
const threadsFactors = ref({});
const threadsRank = ref(null);
const rosterCount = ref(0);
const rankColor = ref('#b0b0b0');
const badges = ref([]);
const badgeRank = ref(null);

async function loadRankData(slug) {
  if (!slug) return;

  try {
    const board = await fetchThreadsBoard();
    rosterCount.value = board.length;
    const mine = board.find((r) => r.slug === slug);
    if (mine) {
      threadsScore.value = mine.score;
      threadsFactors.value = mine.factors;
      threadsRank.value = mine.rank;
      const percentile = board.length > 1 ? 1 - (mine.rank - 1) / (board.length - 1) : 1;
      rankColor.value = colorForPercentile(percentile);
    }
  } catch (err) {
    console.error('ProfileView: could not load Threads board —', err.message);
  }

  try {
    const scores = await Leaderboard.fetchScores();
    badges.value = [...Leaderboard.getBadgesForSlug(scores, slug), ...Leaderboard.getCompletionStatus(scores, slug)];
    badgeRank.value = rankByBadgeCount(scores, slug).rank;
  } catch (err) {
    console.error('ProfileView: could not load badges —', err.message);
  }
}

onMounted(async () => {
  member.value = MemberAuth.current();
  if (!member.value) {
    router.replace('/home');
    return;
  }

  const profile = await MemberProfile.fetchProfile(member.value.slug);
  nickname.value = profile.nickname || member.value.display_name || '';
  bio.value = profile.bio || '';
  socialLinks.value = Array.isArray(profile.social_links)
    ? profile.social_links.map((link) => ({ label: link?.label || '', url: link?.url || '' }))
    : [];
  avatarUrl.value = profile.avatar_url;
  bannerUrl.value = profile.banner_url;
  bannerColor.value = profile.banner_color || null;

  loadRankData(member.value.slug);
});

async function saveBannerColor() {
  playSfx('menuclick');
  if (!bannerColor.value) {
    status('Pick a banner color first.', 'error');
    return;
  }
  const result = await MemberProfile.updateBannerColor(bannerColor.value);
  status(result.success ? 'Banner color saved.' : (result.message || 'Could not save banner color.'), result.success ? 'success' : 'error');
}

async function saveNickname() {
  playSfx('menuclick');
  const result = await MemberProfile.updateNickname(nickname.value);
  status(result.success ? 'Nickname updated.' : (result.message || 'Could not update nickname.'), result.success ? 'success' : 'error');
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
  const cleanedLinks = socialLinks.value.filter((l) => l.label.trim() && l.url.trim()).slice(0, 3);
  const result = await MemberProfile.updateProfile({ bio: bio.value, socialLinks: cleanedLinks });
  if (result.success) {
    status('Profile updated.', 'success');
    socialLinks.value = cleanedLinks;
  } else {
    status(result.message || 'Could not update profile.', 'error');
  }
}

const pendingAvatarFile = ref(null);

function onAvatarChosen(e) {
  const file = e.target.files[0];
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
.profile-shell { gap: 22px; }

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

.profile-viewer { display: flex; flex-direction: column; gap: 12px; }
.profile-viewer-note {
  padding: 0 6px;
  line-height: 1.5;
  font-size: 0.88rem;
  color: rgba(240, 240, 240, 0.58);
}

.profile-editor { min-width: 0; }

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
.profile-panel--full { grid-column: 1 / -1; }

.profile-panel-head,
.profile-links-head {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 12px;
}
.profile-panel-head h3,
.profile-links-head h4 { font-size: 1rem; color: rgba(240, 240, 240, 0.9); }
.profile-panel-head span,
.profile-links-head span,
.profile-media-copy small { color: rgba(240, 240, 240, 0.58); }

.profile-field { display: flex; flex-direction: column; gap: 8px; }
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
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}
.profile-textarea { resize: vertical; min-height: 156px; }
.profile-input:focus,
.profile-textarea:focus {
  border-color: rgba(249, 115, 22, 0.7);
  box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.18);
}

.profile-link-stack { display: flex; flex-direction: column; gap: 10px; }
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
.profile-btn--ghost { background: rgba(255, 255, 255, 0.06); box-shadow: none; }
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
.profile-status.success { background: rgba(20, 61, 31, 0.76); color: #9ff0b4; border-color: rgba(159, 240, 180, 0.16); }
.profile-status.error   { background: rgba(61, 20, 20, 0.78); color: #ffb0b0; border-color: rgba(255, 176, 176, 0.16); }
.profile-status.info    { background: rgba(26, 42, 61, 0.78); color: #aed7ff; border-color: rgba(174, 215, 255, 0.16); }

.profile-media-row {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  grid-template-areas: "preview copy" "file file";
  gap: 6px 14px;
  padding: 14px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
}
.profile-media-row .profile-file { grid-area: file; width: 100%; max-width: 100%; }
.profile-media-row .profile-media-preview { grid-area: preview; }
.profile-media-row .profile-media-copy { grid-area: copy; }

.profile-media-preview {
  display: grid;
  place-items: center;
  overflow: hidden;
  background: rgba(8, 8, 12, 0.58);
  border: 1px solid rgba(255, 255, 255, 0.1);
}
.profile-media-preview--avatar { width: 72px; height: 72px; border-radius: 20px; }
.profile-media-preview--banner { width: 180px; min-height: 72px; border-radius: 16px; }
.profile-media-preview img { width: 100%; height: 100%; object-fit: cover; }
.profile-media-preview strong {
  color: rgba(240, 240, 240, 0.55);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  font-size: 0.72rem;
}

.profile-media-copy { display: flex; flex-direction: column; gap: 4px; }
.profile-media-copy strong { font-size: 0.92rem; }
.profile-file { font: inherit; color: rgba(240, 240, 240, 0.8); }

.profile-banner-color {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 14px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
}
.profile-color-row { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
.profile-color-swatch {
  width: 30px; height: 30px; border-radius: 50%;
  border: 2px solid rgba(255, 255, 255, 0.16);
  cursor: pointer;
  transition: transform 0.15s ease, border-color 0.15s ease;
}
.profile-color-swatch:hover { transform: scale(1.12); }
.profile-color-swatch.selected { border-color: #fff; transform: scale(1.12); }

.profile-hex-row { display: flex; align-items: center; gap: 10px; }
.profile-hex-swatch {
  flex-shrink: 0; width: 30px; height: 30px; border-radius: 50%;
  border: 2px solid rgba(255, 255, 255, 0.16);
}
.profile-hex-input { max-width: 160px; font-family: 'Rajdhani', monospace; letter-spacing: 0.06em; text-transform: lowercase; }
.profile-hex-input--error { border-color: rgba(239, 68, 68, 0.6); }
.profile-hex-error { font-size: 0.78rem; color: #ffb0b0; margin-top: -4px; }

.profile-password-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
.profile-panel--full .profile-btn { margin-top: 2px; }

@media (max-width: 1040px) {
  .profile-layout { grid-template-columns: 1fr; }
  .profile-grid { grid-template-columns: 1fr; }
  .profile-password-grid { grid-template-columns: 1fr; }
}

@media (max-width: 640px) {
  .profile-link-row { grid-template-columns: 1fr; }
  .profile-media-row {
    grid-template-columns: 1fr;
    grid-template-areas: "preview" "copy" "file";
    justify-items: start;
  }
  .profile-media-preview--banner { width: 100%; }
  .profile-actions { flex-direction: column; }
}
</style>
