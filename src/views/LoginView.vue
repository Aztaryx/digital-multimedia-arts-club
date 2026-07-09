<template>
  <main class="login-page">

    <!-- Zigzag checkerboard borders -->
    <div class="login-zigzag login-zigzag--top" aria-hidden="true"></div>
    <div class="login-zigzag login-zigzag--bottom" aria-hidden="true"></div>

    <!-- ──────── HEADER: DMAC + logo + socials ──────── -->
    <header class="login-header">
      <router-link to="/home" class="login-header-left">
        <span class="login-dmac-title">DMAC</span>
        <img class="login-header-logo" src="https://aztaryx.github.io/dmac-assets/logo.png" alt="DMAC Logo" />
      </router-link>
      <div class="login-header-ribbons">
        <a href="https://www.facebook.com/profile.php?id=61590594809333" target="_blank" rel="noopener" class="login-ribbon">Facebook</a>
        <a href="https://github.com/Aztaryx/digital-multimedia-arts-club" target="_blank" rel="noopener" class="login-ribbon">GitHub</a>
      </div>
    </header>

    <!-- BETA text -->
    <div class="login-beta" aria-hidden="true">BETA</div>

    <!-- ──────── LOGIN CARD ──────── -->
    <div class="login-body">
      <div class="login-card-wrap">
        <div class="login-card">

          <!-- ──────── ALREADY LOGGED IN: WELCOME BACK ──────── -->
          <div v-if="isReturning" class="login-panel login-welcome">
            <h2 class="panel-title">Welcome back,</h2>
            <h1 class="login-welcome-name">{{ welcomeName }}!</h1>
            <p class="login-notyou">
              Not you?
              <button class="login-notyou-btn" @click="signOut">Sign out</button>
            </p>
            <button class="login-submit login-open-btn" @click="openSite">Open</button>
            <p class="login-status" :class="statusType">{{ statusMsg }}</p>
          </div>

          <template v-else>
            <!-- ──────── STEP 1: ROLE SELECTION ──────── -->
            <div class="login-panel login-step1" :class="{ minimized: step === 2 }">
              <template v-if="step === 1">
                <h2 class="panel-title">Welcome</h2>
                <h3 class="step-label" style="margin-top: 24px;">Step 1 — Select your account type</h3>

                <button class="role-btn role-btn--guest" :class="{ selected: chosenRole === 'guest' }" @click="selectRole('guest')">Guest</button>

                <button class="role-btn role-btn--member" :class="{ selected: chosenRole === 'member' }" @click="selectRole('member')">Member / Officer</button>

                <button class="role-btn role-btn--moderator" :class="{ selected: chosenRole === 'moderator' }" @click="selectRole('moderator')">Moderator</button>
              </template>

              <div v-else class="login-step1-summary">
                <span class="login-step1-summary-label">Step 1 — {{ chosenRoleLabel }}</span>
                <button class="login-change-btn" @click="backToStep1">Change</button>
              </div>
            </div>

            <!-- ──────── STEP 2: CREDENTIALS ──────── -->
            <div v-if="step === 2" class="login-panel login-step2">
              <h2 class="panel-title">Step 2 — Identify yourself</h2>

              <!-- Name dropdown -->
              <select class="login-select" v-model="selectedSlug" :disabled="nameDisabled">
                <option value="" disabled>{{ namePlaceholder }}</option>
                <option v-for="m in rosterCache" :key="m.slug" :value="m.slug">{{ m.display_name }}</option>
              </select>

              <!-- Password -->
              <div id="pass-row" v-show="showPasswordField">
                <label class="login-field-label" for="login-password">Password</label>
                <input class="login-input" type="password" id="login-password" v-model="password" @keydown="onPasswordKeydown" />
              </div>

              <!-- OR divider -->
              <div class="login-or">Or</div>

              <!-- Google sign-in -->
              <div>
                <button class="login-google-btn" :disabled="googleDisabled" @click="handleGoogleLink">
                  Link Google
                </button>
              </div>

              <!-- Submit -->
              <button class="login-submit" :disabled="submitDisabled" @click="handleSubmit">{{ submitText }}</button>

              <!-- Status message -->
              <p class="login-status" :class="statusType">{{ statusMsg }}</p>
            </div>
          </template>

        </div>

      </div>
    </div>

    <!-- ──────── BOTTOM BAR ──────── -->
    <div class="login-bottom">
      <div class="login-bottom-logo">
        <a href="https://github.com/Aztaryx" target="_blank" rel="noopener">
          <img src="../assets/aztaryx logo.svg" alt="Aztaryx" />
        </a>
      </div>
      <div class="login-loading">
        <span class="login-loading-text">{{ loadingText }}</span>
      </div>
    </div>

  </main>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import MemberAuth from '../lib/member-auth.js';
import { sb } from '../lib/supabase-client.js';
import { playSfx } from '../composables/useSfx.js';
import '../assets/css/pages/login.css';

/* Sequential two-step flow: Step 1 (pick a role) shows alone first;
   choosing a role minimizes it to a summary strip and reveals Step 2
   (credentials). A restored session skips both steps and shows the
   "Welcome back" panel instead. This is a standalone route (see
   router meta.hideChrome / App.vue) so it doesn't get the shared
   NavBar/FooterSection. */

const router = useRouter();

const chosenRole = ref(null);
const step = ref(1);
const isReturning = ref(false);
const rosterCache = ref([]);
const namePlaceholder = ref('— Select Your Name —');
const selectedSlug = ref('');
const nameDisabled = ref(false);
const password = ref('');
const showPasswordField = ref(true);
const submitText = ref('Log In');
const submitDisabled = ref(false);
const googleDisabled = ref(false);
const statusMsg = ref('');
const statusType = ref('info');
const loadingText = ref('Loading _');

let pendingLinkSlug = null;

const ROLE_LABELS = { guest: 'Guest', member: 'Member / Officer', moderator: 'Moderator' };
const chosenRoleLabel = computed(() => ROLE_LABELS[chosenRole.value] || '');

/* Proper capitalization for the big welcome name — each word starts
   uppercase, rest lowercase (handles ALL-CAPS or lowercase roster
   entries the same way). */
const welcomeName = computed(() => {
  const name = MemberAuth.sessionMember.value?.display_name || '';
  return name
    .trim()
    .split(/\s+/)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ');
});

function status(msg, type = 'info') {
  statusMsg.value = msg;
  statusType.value = type;
}

function setLoadingText(text) {
  loadingText.value = text;
}

/* ── RESTORE SESSION ON LOAD ────────────────── */
async function init() {
  setLoadingText('Checking session…');

  try {
    const member = await MemberAuth.restoreSession();
    if (member) {
      isReturning.value = true;
      setLoadingText('Ready');
      return;
    }
  } catch (_) {
    // no session — continue
  }

  setLoadingText('Ready');
}

/* ── ROLE SELECTION (Step 1) ────────────────── */
async function selectRole(role) {
  chosenRole.value = role;
  playSfx('menutap');

  if (role === 'guest') {
    status('Entering as Guest…', 'success');

    setTimeout(() => {
      status('Welcome, Guest. Redirecting…', 'success');
      setLoadingText('Redirecting…');
      setTimeout(() => { router.push('/home'); }, 800);
    }, 400);
    return;
  }

  // Minimize Step 1 and reveal Step 2
  step.value = 2;
  showPasswordField.value = true;
  nameDisabled.value = false;
  submitText.value = 'Log In';
  status('');

  setLoadingText('Loading roster…');
  try {
    const bucket = role === 'moderator' ? 'moderator' : 'member';
    rosterCache.value = await MemberAuth.fetchRoster(bucket);
    selectedSlug.value = '';
    namePlaceholder.value = rosterCache.value.length === 0
      ? 'No Members Found'
      : '— Select Your Name —';
  } catch (e) {
    status('Could not load names. Please try again.', 'error');
  }
  setLoadingText('Ready');
}

function backToStep1() {
  playSfx('menuback');
  step.value = 1;
  chosenRole.value = null;
  selectedSlug.value = '';
  password.value = '';
  status('');
}

function openSite() {
  playSfx('menuconfirm');
  status('Welcome back. Redirecting…', 'success');
  setLoadingText('Redirecting…');
  setTimeout(() => { router.push('/home'); }, 400);
}

/* ── SIGN OUT ───────────────────────────────── */
async function signOut() {
  setLoadingText('Signing out…');
  try { await MemberAuth.logout(); } catch (_) {}
  try { await sb.auth.signOut(); } catch (_) {}
  isReturning.value = false;
  step.value = 1;
  chosenRole.value = null;
  rosterCache.value = [];
  namePlaceholder.value = '— Select Your Name —';
  selectedSlug.value = '';
  nameDisabled.value = false;
  password.value = '';
  showPasswordField.value = true;
  submitText.value = 'Log In';
  submitDisabled.value = false;
  status('Signed out.', 'info');
  setLoadingText('Ready');
  playSfx('menuback');
}

/* ── PASSWORD LOGIN (submit) ────────────────── */
async function handleSubmit() {
  const slug = selectedSlug.value;
  const pass = password.value.trim();

  if (!slug) {
    status('Please select your name first.', 'error');
    return;
  }
  if (!pass) {
    status('Please enter your password.', 'error');
    return;
  }

  submitDisabled.value = true;
  setLoadingText('Logging in…');
  status('');

  try {
    const result = await MemberAuth.login(slug, pass);
    if (result.success) {
      status(`Welcome, ${result.member.display_name}!`, 'success');
      setLoadingText('Redirecting…');
      playSfx('menuback');
      setTimeout(() => { router.push('/home'); }, 900);
    } else {
      status(result.message || 'Incorrect password. Please try again.', 'error');
      submitDisabled.value = false;
      setLoadingText('Ready');
    }
  } catch (e) {
    console.error('handleSubmit error:', e);
    status(`Something went wrong. Please try again. (${e?.message || 'unknown error'})`, 'error');
    submitDisabled.value = false;
    setLoadingText('Ready');
  }
}

/* ── GOOGLE OAUTH ───────────────────────────── */
async function handleGoogleLink() {
  playSfx('menutap');

  const slug = selectedSlug.value;
  const pass = password.value.trim();

  if (!slug) {
    status('Please select your name before linking Google.', 'error');
    return;
  }
  if (!pass) {
    status('Please enter your password before linking Google.', 'error');
    return;
  }

  setLoadingText('Verifying credentials…');
  googleDisabled.value = true;

  try {
    const result = await MemberAuth.login(slug, pass);
    if (!result.success) {
      status(result.message || 'Incorrect password. Google cannot be linked.', 'error');
      setLoadingText('Ready');
      googleDisabled.value = false;
      return;
    }

    pendingLinkSlug = slug;
    setLoadingText('Redirecting to Google…');
    status('Credentials verified. Connecting to Google…', 'info');

    sb.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.href },
    });
  } catch (e) {
    console.error('handleGoogleLink error:', e);
    status(`Something went wrong. Please try again. (${e?.message || 'unknown error'})`, 'error');
    setLoadingText('Ready');
    googleDisabled.value = false;
  }
}

function onPasswordKeydown(e) {
  if (e.key === 'Enter') handleSubmit();
}

/* ── HANDLE OAUTH CALLBACK (for Google linking) ───── */
async function handleOAuthCallback() {
  const hashParams = new URLSearchParams(window.location.hash.substring(1));
  if (hashParams.has('access_token')) {
    setLoadingText('Processing Google sign-in…');

    try {
      const { data: { session }, error } = await sb.auth.getSession();
      if (error || !session) {
        console.error('handleOAuthCallback getSession error:', error);
        status(`Google sign-in failed. (${error?.message || 'no session'})`, 'error');
        setLoadingText('Ready');
        return;
      }

      if (pendingLinkSlug) {
        const linkResult = await MemberAuth.linkGoogle();
        if (linkResult.success) {
          status('Google account linked successfully. Redirecting…', 'success');
          setLoadingText('Redirecting…');
            setTimeout(() => { router.push('/home'); }, 1000);
        } else {
          status(linkResult.message || 'Unable to link Google account.', 'error');
          setLoadingText('Ready');
          await sb.auth.signOut();
        }
        pendingLinkSlug = null;
      } else {
        status('Signed in with Google. Redirecting…', 'success');
        setLoadingText('Redirecting…');
        setTimeout(() => { router.push('/home'); }, 1000);
      }
    } catch (e) {
      console.error('handleOAuthCallback error:', e);
      status(`Something went wrong with Google sign-in. (${e?.message || 'unknown error'})`, 'error');
      setLoadingText('Ready');
    }
  }
}

onMounted(() => {
  init();
  handleOAuthCallback();
});
</script>
