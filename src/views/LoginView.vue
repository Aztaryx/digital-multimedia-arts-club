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
      <div>
        <div class="login-card">

          <!-- ──────── STEP 1: ROLE SELECTION ──────── -->
          <div class="login-panel login-step1">
            <h2 class="panel-title">Welcome</h2>

            <h3 class="step-label" style="margin-top: 24px;">Select your account type</h3>

            <button class="role-btn role-btn--guest" :class="{ selected: chosenRole === 'guest' }" @click="selectRole('guest')">Guest</button>

            <button class="role-btn role-btn--member" :class="{ selected: chosenRole === 'member' }" @click="selectRole('member')">Member / Officer</button>

            <button class="role-btn role-btn--moderator" :class="{ selected: chosenRole === 'moderator' }" @click="selectRole('moderator')">Moderator</button>
          </div>

          <!-- ──────── STEP 2: CREDENTIALS ──────── -->
          <div class="login-panel login-step2" :class="{ disabled: step2Disabled }">
            <h2 class="panel-title">{{ step2Title }}</h2>
            <h3 class="panel-title-sub">Please identify yourself</h3>

            <button class="login-signout" @click="signOut">Sign Out</button>

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
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import MemberAuth from '../lib/member-auth.js';
import { sb } from '../lib/supabase-client.js';
import { playSfx } from '../composables/useSfx.js';
import '../assets/css/pages/login.css';

/* Ported from login/index.html + js/pages/login.js. Two-step flow
   (pick a role, then credentials) — same as the original, just
   driven by refs/v-model instead of getElementById + classList.
   This is a standalone route (see router meta.hideChrome / App.vue)
   so it doesn't get the shared NavBar/FooterSection. */

const router = useRouter();

const chosenRole = ref(null);
const step2Disabled = ref(true);
const step2Title = ref('Welcome Back');
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

let isReturning = false;
let pendingLinkSlug = null;

function status(msg, type = 'info') {
  statusMsg.value = msg;
  statusType.value = type;
}

function setLoadingText(text) {
  loadingText.value = text;
}

function clearSelection() {
  // chosenRole itself drives the .selected class via template
  // binding, so "clearing" it just means selectRole() overwrites it.
}

/* ── RESTORE SESSION ON LOAD ────────────────── */
async function init() {
  setLoadingText('Checking session…');

  try {
    const member = await MemberAuth.restoreSession();
    if (member) {
      isReturning = true;
      const r = member.site_role;
      if (r === 'moderator' || r === 'admin') {
        await selectRole('moderator', true);
      } else {
        await selectRole('member', true);
      }
      setLoadingText('Ready');
      return;
    }
  } catch (_) {
    // no session — continue
  }

  setLoadingText('Ready');
}

/* ── ROLE SELECTION (Step 1) ────────────────── */
async function selectRole(role, autoRestore = false) {
  chosenRole.value = role;
  clearSelection();
  playSfx('menutap');

  if (role === 'guest') {
    step2Disabled.value = true;
    status('Entering as Guest…', 'success');

    setTimeout(() => {
      status('Welcome, Guest. Redirecting…', 'success');
      setLoadingText('Redirecting…');
      setTimeout(() => { router.push('/home'); }, 800);
    }, 400);
    return;
  }

  // If returning user from restoreSession, skip straight to logged-in
  if (autoRestore && isReturning) {
    const member = MemberAuth.current();
    step2Disabled.value = false;
    step2Title.value = 'Welcome Back';
    status(`Signed in as ${member.display_name}`, 'success');
    rosterCache.value = [{ slug: member.slug, display_name: member.display_name }];
    selectedSlug.value = member.slug;
    nameDisabled.value = true;
    showPasswordField.value = false;
    submitText.value = 'Continue';
    submitDisabled.value = false;
    return;
  }

  // Load roster for dropdown
  step2Disabled.value = false;
  step2Title.value = 'Please Identify Yourself';
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

/* ── SIGN OUT ───────────────────────────────── */
async function signOut() {
  setLoadingText('Signing out…');
  try { await MemberAuth.logout(); } catch (_) {}
  try { await sb.auth.signOut(); } catch (_) {}
  isReturning = false;
  chosenRole.value = null;
  step2Disabled.value = true;
  step2Title.value = 'Please Identify Yourself';
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
  if (isReturning && MemberAuth.current()) {
    status('Welcome back. Redirecting…', 'success');
    setLoadingText('Redirecting…');
    setTimeout(() => { router.push('/home'); }, 600);
    return;
  }

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
