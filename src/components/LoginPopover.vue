<!-- LoginPopover.vue — login now happens right where you clicked,
     inside NavBar's profile dropdown, instead of on a dedicated
     /login page. Guest browsing needs no action at all (that's the
     default), so the old "Guest" button from LoginView.vue's step 1
     is gone — this is just roster + password, plus Google linking. -->
<template>
  <div class="login-pop">
    <label class="login-pop-field">
      <span>Name</span>
      <select class="login-pop-select" v-model="selectedSlug" :disabled="loadingRoster">
        <option value="" disabled>{{ loadingRoster ? 'Loading names…' : '— Select your name —' }}</option>
        <option v-for="m in roster" :key="m.slug" :value="m.slug">{{ m.display_name }}</option>
      </select>
    </label>

    <label class="login-pop-field">
      <span>Password</span>
      <input
        class="login-pop-input"
        type="password"
        v-model="password"
        placeholder="Password"
        @keydown.enter="submit"
      />
    </label>

    <button class="login-pop-btn" :disabled="submitting" @click="submit">
      {{ submitting ? 'Logging in…' : 'Log in' }}
    </button>

    <div class="login-pop-divider"><span>or</span></div>

    <button class="login-pop-btn login-pop-btn--ghost" :disabled="!selectedSlug || !password || googleBusy" @click="linkGoogle">
      Continue with Google
    </button>

    <p v-if="statusMsg" class="login-pop-status" :class="statusType">{{ statusMsg }}</p>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { sb } from '../lib/supabase-client.js';
import MemberAuth from '../lib/member-auth.js';
import { pendingLinkSlug } from '../lib/oauth-link.js';
import { playSfx } from '../composables/useSfx.js';

const emit = defineEmits(['logged-in']);

const roster = ref([]);
const loadingRoster = ref(true);
const selectedSlug = ref('');
const password = ref('');
const submitting = ref(false);
const googleBusy = ref(false);
const statusMsg = ref('');
const statusType = ref('info');

function status(msg, type = 'info') {
  statusMsg.value = msg;
  statusType.value = type;
}

onMounted(async () => {
  try {
    roster.value = await MemberAuth.fetchRoster();
  } catch (e) {
    status('Could not load the member list.', 'error');
  }
  loadingRoster.value = false;
});

async function submit() {
  if (!selectedSlug.value) {
    status('Select your name first.', 'error');
    return;
  }
  if (!password.value) {
    status('Enter your password.', 'error');
    return;
  }

  submitting.value = true;
  status('');
  const result = await MemberAuth.login(selectedSlug.value, password.value);
  submitting.value = false;

  if (result.success) {
    playSfx('menuback');
    password.value = '';
    emit('logged-in');
  } else {
    status(result.message || 'Incorrect password.', 'error');
  }
}

async function linkGoogle() {
  if (!selectedSlug.value || !password.value) {
    status('Select your name and enter your password before linking Google.', 'error');
    return;
  }

  googleBusy.value = true;
  status('Verifying credentials…', 'info');

  const result = await MemberAuth.login(selectedSlug.value, password.value);
  if (!result.success) {
    status(result.message || 'Incorrect password — Google was not linked.', 'error');
    googleBusy.value = false;
    return;
  }

  pendingLinkSlug.value = selectedSlug.value;
  status('Redirecting to Google…', 'info');
  sb.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: window.location.href },
  });
  // No need to clear googleBusy — the page is about to navigate away.
}
</script>

<style scoped>
.login-pop {
  display: flex;
  flex-direction: column;
  gap: 10px;
  min-width: 220px;
}
.login-pop-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.login-pop-field span {
  font-size: 0.66rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: rgba(240, 240, 240, 0.5);
}
.login-pop-select,
.login-pop-input {
  width: 100%;
  font: inherit;
  font-size: 0.82rem;
  color: #f0f0f0;
  background: rgba(8, 8, 12, 0.6);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 10px;
  padding: 8px 10px;
  outline: none;
}
.login-pop-select:focus,
.login-pop-input:focus { border-color: rgba(249, 115, 22, 0.6); }

.login-pop-btn {
  font: inherit;
  font-size: 0.82rem;
  border: none;
  cursor: pointer;
  color: #fff;
  border-radius: 10px;
  padding: 9px 12px;
  background: linear-gradient(135deg, var(--orange), var(--purple));
}
.login-pop-btn:disabled { opacity: 0.55; cursor: default; }
.login-pop-btn--ghost {
  background: rgba(255, 255, 255, 0.06);
  color: rgba(240, 240, 240, 0.85);
}

.login-pop-divider {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 0.65rem;
  color: rgba(240, 240, 240, 0.4);
}
.login-pop-divider::before,
.login-pop-divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: rgba(255, 255, 255, 0.08);
}

.login-pop-status {
  font-size: 0.75rem;
  line-height: 1.4;
}
.login-pop-status.error   { color: #ffb0b0; }
.login-pop-status.success { color: #9ff0b4; }
.login-pop-status.info    { color: #aed7ff; }
</style>
