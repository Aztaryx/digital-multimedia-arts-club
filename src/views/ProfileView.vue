<template>
  <main class="profile-page">
    <div class="page-section reveal" v-reveal>
      <SecHead>Your Profile</SecHead>

      <div v-if="!member" class="profile-loading">Loading…</div>

      <div v-else class="profile-content">

        <p v-if="statusMsg" class="profile-status" :class="statusType">{{ statusMsg }}</p>

        <!-- ── NICKNAME ── -->
        <section class="profile-block">
          <h3>Nickname</h3>
          <input class="profile-input" v-model="nickname" maxlength="40" />
          <button class="profile-btn" v-sfx-hover @click="saveNickname">save</button>
        </section>

        <!-- ── PASSWORD ── -->
        <section class="profile-block">
          <h3>Change Password</h3>
          <input class="profile-input" type="password" v-model="oldPassword" placeholder="current password" />
          <input class="profile-input" type="password" v-model="newPassword" placeholder="new password" />
          <input class="profile-input" type="password" v-model="confirmPassword" placeholder="confirm new password" />
          <button class="profile-btn" v-sfx-hover @click="savePassword">save</button>
        </section>

        <!-- ── BIO + SOCIAL LINKS ── -->
        <section class="profile-block">
          <h3>Bio</h3>
          <textarea class="profile-textarea" v-model="bio" maxlength="500" rows="4"></textarea>

          <h3>Social Links <span class="profile-hint">(max 3)</span></h3>
          <div v-for="(link, i) in socialLinks" :key="i" class="profile-link-row">
            <input class="profile-input" v-model="link.label" placeholder="label (e.g. Instagram)" />
            <input class="profile-input" v-model="link.url" placeholder="https://..." />
            <button class="profile-btn profile-btn--danger" v-sfx-hover @click="removeLink(i)">✕</button>
          </div>
          <button v-if="socialLinks.length < 3" class="profile-btn" v-sfx-hover @click="addLink">+ add link</button>

          <div>
            <button class="profile-btn" v-sfx-hover @click="saveBioAndLinks">save</button>
          </div>
        </section>

        <!-- ── AVATAR / BANNER ── -->
        <section class="profile-block">
          <h3>Avatar &amp; Banner</h3>

          <div class="profile-image-row">
            <img v-if="avatarUrl" :src="avatarUrl" class="profile-avatar-preview" alt="Avatar preview" />
            <span v-else class="profile-empty-preview">◆</span>
            <input class="profile-file" type="file" accept="image/*" @change="onAvatarChosen" />
          </div>

          <div class="profile-image-row">
            <img v-if="bannerUrl" :src="bannerUrl" class="profile-banner-preview" alt="Banner preview" />
            <span v-else class="profile-empty-preview profile-empty-preview--banner">no banner</span>
            <input class="profile-file" type="file" accept="image/*,.gif" @change="onBannerChosen" />
          </div>
        </section>

      </div>
    </div>
  </main>
</template>

<script setup>
/* ProfileView.vue — private self-service profile editor at /profile.
   Reachable only when logged in (see the requiresAuth guard in
   router/index.js). Deliberately undesigned — plain stacked sections,
   no attempt made yet to match the rest of the site's visual language.
   Wire up assets/css/pages/profile.css later if/when this needs a
   real look.

   Google-linking itself is NOT reimplemented here — that OAuth
   redirect/callback dance already lives in LoginView.vue. If someone
   isn't Google-linked yet, this page just points them back to /login
   to do it there, rather than duplicating that flow. (Worth factoring
   into a shared composable later if you want in-page linking.) */
import { ref, onMounted } from 'vue';
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

  const profile = await MemberProfile.fetchProfile(member.value.id);
  // nickname falls back to the official display_name until the member
  // picks their own — editing this field never touches display_name.
  nickname.value = profile.nickname || member.value.display_name || '';
  bio.value = profile.bio || '';
  socialLinks.value = Array.isArray(profile.social_links) ? profile.social_links.map(l => ({ ...l })) : [];
  avatarUrl.value = profile.avatar_url;
  bannerUrl.value = profile.banner_url;
});

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
/* Intentionally plain — functional layout only, per "undesigned/very
   simple" scope. Replace with a real assets/css/pages/profile.css
   pass whenever the visual design is ready. */
.profile-content {
  display: flex;
  flex-direction: column;
  gap: 28px;
  max-width: 560px;
}
.profile-block {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.profile-block h3 {
  margin: 0;
  font-size: 0.95rem;
  opacity: 0.85;
}
.profile-hint {
  font-weight: normal;
  opacity: 0.6;
  font-size: 0.8rem;
}
.profile-input,
.profile-textarea {
  font: inherit;
  padding: 8px 10px;
  border: 1px solid #444;
  background: #111;
  color: #eee;
  border-radius: 4px;
}
.profile-link-row {
  display: flex;
  gap: 8px;
}
.profile-link-row .profile-input {
  flex: 1;
}
.profile-btn {
  align-self: flex-start;
  font: inherit;
  padding: 6px 14px;
  border: 1px solid #666;
  background: #1a1a1a;
  color: #eee;
  border-radius: 4px;
  cursor: pointer;
  text-decoration: none;
}
.profile-btn--danger {
  border-color: #a33;
  color: #f88;
}
.profile-status {
  padding: 8px 12px;
  border-radius: 4px;
  font-size: 0.9rem;
}
.profile-status.success { background: #143d1f; color: #7fe89a; }
.profile-status.error { background: #3d1414; color: #f88; }
.profile-status.info { background: #1a2a3d; color: #8ac6f8; }
.profile-image-row {
  display: flex;
  align-items: center;
  gap: 14px;
}
.profile-avatar-preview {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  object-fit: cover;
}
.profile-banner-preview {
  width: 200px;
  height: 60px;
  object-fit: cover;
  border-radius: 4px;
}
.profile-empty-preview {
  width: 64px;
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px dashed #555;
  border-radius: 50%;
  opacity: 0.6;
}
.profile-empty-preview--banner {
  width: 200px;
  height: 60px;
  border-radius: 4px;
  font-size: 0.75rem;
}
</style>
