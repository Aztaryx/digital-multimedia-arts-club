<template>
  <nav id="navbar">
    <router-link to="/home" class="nav-logo" @click="registerLogoTap">
      <img src="https://aztaryx.github.io/dmac-assets/logo.png" alt="DMAC" height="38" />
    </router-link>

    <ul class="nav-links">
      <li>
        <router-link to="/home" class="nav-icon-link" :class="{ active: isExact('/home') }" aria-label="Home" v-sfx-tap>
          <img :src="ICONS.home" alt="" />
        </router-link>
      </li>

      <li class="has-dropdown">
        <router-link to="/about" class="nav-icon-link" :class="{ active: isSection('/about') }" aria-label="About" v-sfx-tap>
          <img :src="ICONS.about" alt="" />
        </router-link>
        <ul class="dropdown">
          <li>
            <router-link to="/about" class="dropdown-link" :class="{ active: isExact('/about') }">
              <img class="dropdown-icon" :src="ICONS.aboutUs" alt="" /><span>about us</span>
            </router-link>
          </li>
          <li>
            <router-link to="/about/mission" class="dropdown-link" :class="{ active: isExact('/about/mission') }">
              <img class="dropdown-icon" :src="ICONS.mission" alt="" /><span>mission</span>
            </router-link>
          </li>
          <li>
            <router-link to="/about/members" class="dropdown-link" :class="{ active: isExact('/about/members') }">
              <img class="dropdown-icon" :src="ICONS.members" alt="" /><span>members</span>
            </router-link>
          </li>
        </ul>
      </li>

      <li>
        <router-link to="/projects" class="nav-icon-link" :class="{ active: isSection('/projects') }" aria-label="Projects" v-sfx-tap>
          <img :src="ICONS.projects" alt="" />
        </router-link>
      </li>

      <li class="has-dropdown">
        <router-link to="/info/newsletters" class="nav-icon-link" :class="{ active: isSection('/info') }" aria-label="Information" v-sfx-tap>
          <img :src="ICONS.information" alt="" />
        </router-link>
        <ul class="dropdown">
          <li>
            <router-link to="/info/newsletters" class="dropdown-link" :class="{ active: isExact('/info/newsletters') }">
              <img class="dropdown-icon" :src="ICONS.newsletters" alt="" /><span>newsletters</span>
            </router-link>
          </li>
          <li>
            <router-link to="/info/announcements" class="dropdown-link" :class="{ active: isExact('/info/announcements') }">
              <img class="dropdown-icon" :src="ICONS.announcements" alt="" /><span>announcements</span>
            </router-link>
          </li>
          <li>
            <router-link to="/info/school-events" class="dropdown-link" :class="{ active: isExact('/info/school-events') }">
              <img class="dropdown-icon" :src="ICONS.schoolEvents" alt="" /><span>school events</span>
            </router-link>
          </li>
          <li>
            <router-link to="/info/update-log" class="dropdown-link" :class="{ active: isExact('/info/update-log') }">
              <img class="dropdown-icon" :src="ICONS.updateLog" alt="" /><span>update log</span>
            </router-link>
          </li>
          <li>
            <router-link to="/info/faq" class="dropdown-link" :class="{ active: isExact('/info/faq') }">
              <img class="dropdown-icon" :src="ICONS.faq" alt="" /><span>faq</span>
            </router-link>
          </li>
        </ul>
      </li>

      <li>
        <router-link to="/join" class="nav-icon-link" :class="{ active: isSection('/join') }" aria-label="How to Join" v-sfx-tap>
          <img :src="ICONS.join" alt="" />
        </router-link>
      </li>

      <li>
        <router-link to="/leaderboard" class="nav-icon-link" :class="{ active: isSection('/leaderboard') }" aria-label="Leaderboard" v-sfx-tap>
          <img :src="ICONS.leaderboard" alt="" />
        </router-link>
      </li>

      <li>
        <router-link to="/branding" class="nav-icon-link" :class="{ active: isSection('/branding') }" aria-label="Branding" v-sfx-tap>
          <img :src="ICONS.branding" alt="" />
        </router-link>
      </li>

      <li v-if="isAdmin">
        <router-link to="/admin" class="nav-icon-link nav-admin-link" :class="{ active: isExact('/admin') }" aria-label="Admin Panel" v-sfx-tap>
          <img :src="ICONS.adminPanel" alt="" />
        </router-link>
      </li>

      <li class="has-dropdown">
        <span class="nav-icon-link" :class="{ active: isSection('/socials') }" aria-label="Socials" tabindex="0" v-sfx-tap>
          <img :src="ICONS.socials" alt="" />
        </span>
        <ul class="dropdown">
          <li>
            <a href="https://www.facebook.com/profile.php?id=61590594809333" target="_blank" rel="noopener" class="dropdown-link">
              <img class="dropdown-icon" :src="ICONS.facebook" alt="" /><span>facebook</span>
            </a>
          </li>
        </ul>
      </li>

      <li v-if="MemberAuth.sessionMember.value">
        <router-link to="/profile" class="nav-text-link" :class="{ active: isSection('/profile') }">profile</router-link>
      </li>
    </ul>

    <!-- ──────── NAV ACTIONS: profile / inline login ────────
         Logged out: clicking the circle opens this same dropdown,
         now with LoginPopover embedded directly in it — login happens
         right here, in the corner, instead of on a separate /login
         page (that route is gone; see router/index.js). -->
    <div class="nav-actions">
      <div
        class="nav-profile"
        role="button"
        tabindex="0"
        aria-label="Account menu"
        v-sfx-tap
        @click.stop="toggleProfile"
        @keydown.enter="toggleProfile"
      >
        <div class="nav-avatar" :class="roleClass">
          <svg v-if="!MemberAuth.sessionMember.value" viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="12" cy="8.5" r="3.4" stroke-width="1.6" />
            <path d="M5 19c1.2-3.4 4-5 7-5s5.8 1.6 7 5" stroke-width="1.6" stroke-linecap="round" />
          </svg>
          <img v-else-if="avatarUrl" class="nav-avatar-img" :src="avatarUrl" alt="" />
          <span v-else>{{ avatarLabel }}</span>
        </div>

        <div class="nav-dropdown nav-dropdown--profile" v-show="profileOpen" @click.stop>
          <div class="nav-dropdown-head">
            <strong>{{ MemberAuth.sessionMember.value?.display_name || 'Guest' }}</strong>
            <span class="nav-role-pill" :class="roleClass">{{ roleLabel }}</span>
          </div>

          <template v-if="MemberAuth.sessionMember.value">
            <router-link to="/profile" class="nav-dropdown-item" @click="closeDropdowns">Edit profile</router-link>
            <router-link v-if="isAdmin" to="/admin" class="nav-dropdown-item" @click="closeDropdowns">Admin panel</router-link>
            <button class="nav-dropdown-item nav-dropdown-item--danger" @click="signOut">Sign out</button>
          </template>
          <template v-else>
            <LoginPopover @logged-in="onLoggedIn" />
          </template>
        </div>
      </div>
    </div>

    <button id="hamburger" :class="{ open: mobileOpen }" aria-label="Open navigation menu" @click="toggleMobile">
      <span></span><span></span><span></span>
    </button>
  </nav>

  <nav id="mobile-nav" :class="{ open: mobileOpen }" aria-label="Mobile navigation">
    <router-link to="/home" class="mobile-link" @click="closeMobile">
      <img class="mobile-icon" :src="ICONS.home" alt="" /><span>home</span>
    </router-link>

    <div class="mobile-group">
      <span class="mobile-group-label"><img class="mobile-group-icon" :src="ICONS.about" alt="" />about</span>
      <router-link to="/about" class="mobile-link" @click="closeMobile"><img class="mobile-icon" :src="ICONS.aboutUs" alt="" /><span>about us</span></router-link>
      <router-link to="/about/mission" class="mobile-link" @click="closeMobile"><img class="mobile-icon" :src="ICONS.mission" alt="" /><span>mission</span></router-link>
      <router-link to="/about/members" class="mobile-link" @click="closeMobile"><img class="mobile-icon" :src="ICONS.members" alt="" /><span>members</span></router-link>
    </div>

    <router-link to="/projects" class="mobile-link" @click="closeMobile">
      <img class="mobile-icon" :src="ICONS.projects" alt="" /><span>projects</span>
    </router-link>

    <div class="mobile-group">
      <span class="mobile-group-label"><img class="mobile-group-icon" :src="ICONS.information" alt="" />information</span>
      <router-link to="/info/newsletters" class="mobile-link" @click="closeMobile"><img class="mobile-icon" :src="ICONS.newsletters" alt="" /><span>newsletters</span></router-link>
      <router-link to="/info/announcements" class="mobile-link" @click="closeMobile"><img class="mobile-icon" :src="ICONS.announcements" alt="" /><span>announcements</span></router-link>
      <router-link to="/info/school-events" class="mobile-link" @click="closeMobile"><img class="mobile-icon" :src="ICONS.schoolEvents" alt="" /><span>school events</span></router-link>
      <router-link to="/info/update-log" class="mobile-link" @click="closeMobile"><img class="mobile-icon" :src="ICONS.updateLog" alt="" /><span>update log</span></router-link>
      <router-link to="/info/faq" class="mobile-link" @click="closeMobile"><img class="mobile-icon" :src="ICONS.faq" alt="" /><span>faq</span></router-link>
    </div>

    <router-link to="/join" class="mobile-link" @click="closeMobile">
      <img class="mobile-icon" :src="ICONS.join" alt="" /><span>how to join</span>
    </router-link>

    <router-link to="/leaderboard" class="mobile-link" @click="closeMobile">
      <img class="mobile-icon" :src="ICONS.leaderboard" alt="" /><span>leaderboard</span>
    </router-link>

    <router-link to="/branding" class="mobile-link" @click="closeMobile">
      <img class="mobile-icon" :src="ICONS.branding" alt="" /><span>branding</span>
    </router-link>

    <router-link v-if="isAdmin" to="/admin" class="mobile-link nav-admin-link" @click="closeMobile">
      <img class="mobile-icon" :src="ICONS.adminPanel" alt="" /><span>admin panel</span>
    </router-link>

    <div class="mobile-group">
      <span class="mobile-group-label"><img class="mobile-group-icon" :src="ICONS.socials" alt="" />socials</span>
      <a href="https://www.facebook.com/profile.php?id=61590594809333" target="_blank" rel="noopener" class="mobile-link">
        <img class="mobile-icon" :src="ICONS.facebook" alt="" /><span>facebook</span>
      </a>
    </div>

    <router-link v-if="MemberAuth.sessionMember.value" to="/profile" class="mobile-link" @click="closeMobile">profile</router-link>

    <!-- Logged out, on mobile: same inline popover, just docked into
         the mobile menu sheet instead of a corner dropdown. -->
    <div v-else class="mobile-login">
      <LoginPopover @logged-in="onLoggedIn" />
    </div>
  </nav>
</template>

<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { playSfx } from '../composables/useSfx.js';
import MemberAuth from '../lib/member-auth.js';
import MemberProfile from '../lib/member-profile.js';
import { sb } from '../lib/supabase-client.js';
import { registerLogoTap } from '../lib/secret-badges.js';
import { loginPromptRequested, clearLoginPrompt } from '../lib/login-prompt.js';
import LoginPopover from './LoginPopover.vue';

const ICON_BASE = `${import.meta.env.BASE_URL}icons/`;
const ICONS = {
  home: `${ICON_BASE}Home.png`,
  about: `${ICON_BASE}About.png`,
  aboutUs: `${ICON_BASE}About_Us.png`,
  mission: `${ICON_BASE}Mission.png`,
  members: `${ICON_BASE}Members.png`,
  projects: `${ICON_BASE}Projects.png`,
  information: `${ICON_BASE}Information.png`,
  newsletters: `${ICON_BASE}Newsletters.png`,
  announcements: `${ICON_BASE}Announcements.png`,
  schoolEvents: `${ICON_BASE}School_Events.png`,
  faq: `${ICON_BASE}FAQ.png`,
  updateLog: `${ICON_BASE}Update_Log.png`,
  join: `${ICON_BASE}How_to_Join.png`,
  leaderboard: `${ICON_BASE}Leaderboard.png`,
  branding: `${ICON_BASE}Branding.png`,
  socials: `${ICON_BASE}Socials.png`,
  facebook: `${ICON_BASE}Facebook.png`,
  adminPanel: `${ICON_BASE}Admin_Panel.png`,
  notifications: `${ICON_BASE}Notifications.png`,
};

const route = useRoute();
const router = useRouter();
const mobileOpen = ref(false);

onMounted(() => {
  if (!MemberAuth.current()) MemberAuth.restoreSession();
  document.addEventListener('click', onDocumentClick);
});
onBeforeUnmount(() => {
  document.removeEventListener('click', onDocumentClick);
});

const profileOpen = ref(false);

function toggleProfile() {
  profileOpen.value = !profileOpen.value;
}
function closeDropdowns() {
  profileOpen.value = false;
}
function onDocumentClick(e) {
  if (!e.target.closest('.nav-profile')) {
    closeDropdowns();
  }
}

// A protected route the visitor couldn't reach (router/index.js's
// beforeEach guard) sets this flag instead of redirecting to a
// /login page that no longer exists — pop the corner login open for
// them automatically, on both desktop (dropdown) and mobile (sheet).
watch(loginPromptRequested, (requested) => {
  if (!requested) return;
  if (window.innerWidth <= 768) {
    mobileOpen.value = true;
  } else {
    profileOpen.value = true;
  }
  clearLoginPrompt();
});

function onLoggedIn() {
  closeDropdowns();
  mobileOpen.value = false;
}

const roleLabel = computed(() => {
  const m = MemberAuth.sessionMember.value;
  if (!m) return 'Guest';
  return m.site_role === 'admin' ? 'Admin' : 'Member / Officer';
});
const roleClass = computed(() => {
  const m = MemberAuth.sessionMember.value;
  if (!m) return 'nav-avatar--guest';
  return m.site_role === 'admin' ? 'nav-avatar--admin' : 'nav-avatar--member';
});
const isAdmin = computed(() => MemberAuth.sessionMember.value?.site_role === 'admin');

const avatarLabel = computed(() => {
  const name = MemberAuth.sessionMember.value?.display_name;
  if (!name) return '?';
  return name.trim().split(/\s+/).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
});

const avatarUrl = ref(null);
watch(
  () => MemberAuth.sessionMember.value?.slug,
  async (slug) => {
    avatarUrl.value = null;
    if (!slug) return;
    try {
      const profile = await MemberProfile.fetchProfile(slug);
      avatarUrl.value = profile?.avatar_url || null;
    } catch (_) {}
  },
  { immediate: true },
);

async function signOut() {
  closeDropdowns();
  try { await MemberAuth.logout(); } catch (_) {}
  try { await sb.auth.signOut(); } catch (_) {}
  router.push('/home');
}

function isSection(prefix) {
  return route.path === prefix || route.path.startsWith(prefix + '/');
}
function isExact(path) {
  return route.path === path;
}

function toggleMobile() {
  mobileOpen.value = !mobileOpen.value;
  playSfx('menutap');
}
function closeMobile() {
  mobileOpen.value = false;
}
</script>

<style scoped>
/* Only additive to global.css's own nav rules — the mobile login
   dock needs a bit of padding the plain .mobile-link rows don't. */
.mobile-login {
  padding: 14px 28px 20px;
}
</style>
