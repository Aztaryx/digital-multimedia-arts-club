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
          <section class="profile-card profile-card--viewer">
            <div class="profile-banner" :style="bannerStyle">
              <div class="profile-banner-overlay"></div>
              <div class="profile-avatar-badge">
                <img v-if="avatarUrl" :src="avatarUrl" class="profile-avatar-preview" alt="Avatar preview" />
                <span v-else class="profile-avatar-fallback">{{ avatarInitials }}</span>
              </div>
            </div>

            <div class="profile-card-body">
              <p class="profile-kicker">Public preview</p>
              <h3>{{ publicName }}</h3>
              <p class="profile-role">{{ member.club_role || 'DMAC member' }} · {{ member.site_role || 'member' }}</p>
              <p class="profile-bio-preview">
                {{ bio.trim() || 'Write a short bio about the events you cover, the edits you handle, or the tools you are best at using.' }}
              </p>

              <div class="profile-link-chips">
                <a
                  v-for="(link, i) in previewLinks"
                  :key="i"
                  class="profile-chip"
                  :href="link.url"
                  target="_blank"
                  rel="noopener"
                >
                  {{ link.label }}
                </a>
                <span v-if="!previewLinks.length" class="profile-chip profile-chip--ghost">No social links yet.</span>
              </div>

              <div class="profile-stat-grid">
                <div class="profile-stat">
                  <span class="profile-stat-label">Year joined</span>
                  <strong>{{ yearJoined }}</strong>
                </div>
                <div class="profile-stat">
                  <span class="profile-stat-label">Site role</span>
                  <strong>{{ member.site_role || 'member' }}</strong>
                </div>
                <div class="profile-stat">
                  <span class="profile-stat-label">Profile complete</span>
                  <strong>{{ profileScore }}</strong>
                </div>
                <div class="profile-stat">
                  <span class="profile-stat-label">Avatar</span>
                  <strong>{{ avatarUrl ? 'Custom' : 'Default' }}</strong>
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
                  <input class="profile-color-input" type="color" :value="bannerColor || '#f97316'" @input="bannerColor = $event.target.value" aria-label="Custom banner color" />
                </div>
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
   to do it there, rather than duplicating that flow. */
import { ref, onMounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import SecHead from '../components/SecHead.vue';
import MemberAuth from '../lib/member-auth.js';
import MemberProfile from '../lib/member-profile.js';
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
const bioLength = computed(() => bio.value.trim().length);
const joinedYear = computed(() => member.value?.year_joined || '2026');
// Was computed but never actually rendered anywhere — the stat grid
// had two copy-pasted "Badges: Unknown" tiles instead. Now backs the
// "Profile complete" tile there.
const profileScore = computed(() => {
  let score = 0;
  if (nickname.value.trim()) score += 1;
  if (bio.value.trim()) score += 1;
  if (previewLinks.value.length) score += 1;
  if (avatarUrl.value) score += 1;
  if (bannerUrl.value) score += 1;
  return `${score}/5`;
});
const bannerStyle = computed(() => {
  if (bannerUrl.value) {
    return { backgroundImage: `linear-gradient(180deg, rgba(10, 10, 16, 0.08), rgba(10, 10, 16, 0.72)), url("${bannerUrl.value}")` };
  }
  if (bannerColor.value) {
    return { background: bannerColor.value };
  }
  return { backgroundImage: 'linear-gradient(135deg, rgba(249, 115, 22, 0.95), rgba(76, 29, 149, 0.95))' };
});

const statusMsg = ref('');
const statusType = ref('info'); // 'info' | 'success' | 'error'

function status(msg, type = 'info') {
  statusMsg.value = msg;
  statusType.value = type;
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

async function saveAppearance() {
  playSfx('menuclick');
  const result = await MemberProfile.updateAppearance({ bannerColor: bannerColor.value });
  if (result.success) {
    status('Appearance updated.', 'success');
  } else {
    status(result.message || 'Could not update appearance.', 'error');
  }
}

async function onAvatarChosen(e) {
  const file = e.target.files[0];
  if (!file) return;
  status('Uploading avatar…', 'info');
  const result = await MemberProfile.uploadAvatar(file);
  if (result.success) {
    avatarUrl.value = result.url;
    status('Avatar updated.', 'success');
  } else {
    status(result.message || 'Avatar upload failed.', 'error');
  }
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
  grid-template-columns: minmax(290px, 390px) minmax(0, 1fr);
  gap: 24px;
  align-items: start;
}

.profile-viewer {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.profile-card {
  overflow: hidden;
  border-radius: 28px;
  border: 1px solid rgba(255, 255, 255, 0.09);
  background: rgba(13, 13, 13, 0.78);
  box-shadow: 0 20px 48px rgba(0, 0, 0, 0.34);
}

.profile-banner {
  position: relative;
  min-height: 260px;
  padding: 20px;
  background-size: cover;
  background-position: center;
  display: flex;
  align-items: flex-end;
  justify-content: flex-start;
}

.profile-banner-overlay {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(circle at 18% 18%, rgba(255, 255, 255, 0.18), transparent 34%),
    radial-gradient(circle at 78% 12%, rgba(255, 255, 255, 0.1), transparent 22%),
    linear-gradient(180deg, rgba(9, 9, 15, 0.14), rgba(9, 9, 15, 0.76));
}

.profile-avatar-badge {
  position: relative;
  z-index: 1;
  width: 108px;
  height: 108px;
  border-radius: 28px;
  padding: 6px;
  background: linear-gradient(135deg, rgba(249, 115, 22, 0.9), rgba(76, 29, 149, 0.9));
  box-shadow: 0 14px 30px rgba(0, 0, 0, 0.34);
}

.profile-avatar-preview,
.profile-media-preview img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.profile-avatar-preview {
  border-radius: 22px;
}

.profile-avatar-fallback {
  width: 100%;
  height: 100%;
  border-radius: 22px;
  display: grid;
  place-items: center;
  background: rgba(13, 13, 13, 0.7);
  color: #fff;
  font-size: 1.4rem;
  letter-spacing: 0.12em;
}

.profile-card-body {
  padding: 22px 22px 24px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.profile-kicker,
.profile-role,
.profile-viewer-note,
.profile-panel-head span,
.profile-media-copy small,
.profile-links-head span,
.profile-stat-label {
  color: rgba(240, 240, 240, 0.58);
}

.profile-card-body h3,
.profile-panel-head h3,
.profile-links-head h4 {
  margin: 0;
  line-height: 1.1;
}

.profile-role {
  font-size: 0.82rem;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.profile-bio-preview {
  color: rgba(240, 240, 240, 0.82);
  line-height: 1.65;
}

.profile-link-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.profile-chip {
  padding: 7px 11px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.08);
  font-size: 0.78rem;
  letter-spacing: 0.05em;
}

.profile-chip--ghost {
  color: rgba(240, 240, 240, 0.56);
}

.profile-stat-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.profile-stat {
  padding: 12px 13px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.06);
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.profile-stat strong {
  font-size: 1rem;
}

.profile-viewer-note {
  padding: 0 6px;
  line-height: 1.5;
  font-size: 0.88rem;
}

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

/* The file input gets its own full-width row instead of sharing a
   column with the copy text. A native <input type="file">'s button +
   filename renders at whatever width the browser/OS gives it (this
   varies a lot and can be quite wide) — if it shares an `auto` grid
   column next to a `minmax(0, 1fr)` text column, that text column gets
   squeezed toward 0 on narrower viewports, wrapping one word per line.
   Giving it its own row sidesteps that entirely, on any screen size. */
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

.profile-media-copy small {
  line-height: 1.45;
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

.profile-color-input {
  width: 34px;
  height: 34px;
  padding: 0;
  border: 1px solid rgba(255, 255, 255, 0.16);
  border-radius: 8px;
  background: transparent;
  cursor: pointer;
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
  .profile-banner {
    min-height: 220px;
  }

  .profile-avatar-badge {
    width: 92px;
    height: 92px;
  }

  .profile-stat-grid {
    grid-template-columns: 1fr;
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
