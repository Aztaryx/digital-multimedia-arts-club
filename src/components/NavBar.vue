<template>
  <nav id="navbar" :class="{ 'nav-hidden': Panels.leftOpen.value || Panels.rightOpen.value }">
    <router-link to="/home" class="nav-logo">
      <img src="https://aztaryx.github.io/dmac-assets/logo.png" alt="DMAC" height="38" />
    </router-link>
    <ul class="nav-links">
      <li>
        <router-link to="/home" :class="{ active: isExact('/home') }">home</router-link>
      </li>

      <li class="has-dropdown">
        <router-link to="/about" data-icon="down" :class="{ active: isSection('/about') }" v-sfx-tap>about</router-link>
        <ul class="dropdown">
          <li><router-link to="/about" :class="{ active: isExact('/about') }">about us</router-link></li>
          <li><router-link to="/about/mission" :class="{ active: isExact('/about/mission') }">mission</router-link></li>
          <li><router-link to="/about/members" :class="{ active: isExact('/about/members') }">members</router-link></li>
        </ul>
      </li>

      <li><router-link to="/projects" :class="{ active: isSection('/projects') }">projects</router-link></li>

      <li class="has-dropdown">
        <router-link to="/info/newsletters" data-icon="down" :class="{ active: isSection('/info') }" v-sfx-tap>information</router-link>
        <ul class="dropdown">
          <li><router-link to="/info/newsletters" :class="{ active: isExact('/info/newsletters') }">newsletters</router-link></li>
          <li><router-link to="/info/update-log" :class="{ active: isExact('/info/update-log') }">update log</router-link></li>
          <li><router-link to="/info/faq" :class="{ active: isExact('/info/faq') }">faq</router-link></li>
        </ul>
      </li>

      <li><router-link to="/join" :class="{ active: isSection('/join') }">how to join</router-link></li>

      <li v-if="isAdmin">
        <router-link to="/admin" class="nav-admin-link" :class="{ active: isExact('/admin') }">admin panel</router-link>
      </li>

      <li class="has-dropdown">
        <router-link to="/socials" data-icon="down" :class="{ active: isSection('/socials') }" v-sfx-tap>socials</router-link>
        <ul class="dropdown">
          <li><a href="https://www.facebook.com/profile.php?id=61590594809333" target="_blank" rel="noopener">facebook</a></li>
        </ul>
      </li>

      <!-- Only shown once logged in — sessionMember is the reactive
           mirror in member-auth.js, so this appears/disappears right
           after login/logout without needing a page reload. -->
      <li v-if="MemberAuth.sessionMember.value">
        <router-link to="/profile" :class="{ active: isSection('/profile') }">profile</router-link>
      </li>

      <!-- Admin panel — admins only. -->
      <li v-if="isAdmin">
        <router-link to="/admin" class="nav-admin-link" :class="{ active: isSection('/admin') }">admin</router-link>
      </li>
    </ul>

    <!-- ──────── NAV ACTIONS: forums / notifications / profile ────────
         Always visible (desktop AND mobile) — these sit next to the
         hamburger rather than collapsing into it, since they're
         account-state controls, not page navigation. -->
    <div class="nav-actions">
      <!-- Forums: opens the left side panel (Forums + DMs tabs) rather
           than navigating anywhere — open to guests too (read-only,
           enforced inside LeftPanel, not here). -->
      <div
        class="nav-icon-btn"
        :class="{ active: Panels.leftOpen.value }"
        role="button"
        tabindex="0"
        aria-label="Open forums"
        v-sfx-tap
        @click.stop="Panels.toggleLeft('forums')"
        @keydown.enter="Panels.toggleLeft('forums')"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M4 5.5h16a1 1 0 0 1 1 1V15a1 1 0 0 1-1 1H9l-4 4v-4H4a1 1 0 0 1-1-1V6.5a1 1 0 0 1 1-1Z" stroke-width="1.6" stroke-linejoin="round" />
        </svg>
      </div>

      <!-- Notifications: opens the right side panel — only meaningful
           once logged in. -->
      <div
        v-if="MemberAuth.sessionMember.value"
        class="nav-icon-btn"
        :class="{ active: Panels.rightOpen.value }"
        role="button"
        tabindex="0"
        aria-label="Notifications"
        v-sfx-tap
        @click.stop="Panels.toggleRight()"
        @keydown.enter="Panels.toggleRight()"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M6 9a6 6 0 1 1 12 0c0 4 1.5 5.5 2 6H4c.5-.5 2-2 2-6Z" stroke-width="1.6" stroke-linejoin="round" />
          <path d="M9.5 18a2.5 2.5 0 0 0 5 0" stroke-width="1.6" stroke-linecap="round" />
        </svg>
      </div>

      <!-- Profile circle: guest / member / moderator / admin. -->
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
          <img v-else-if="avatarUrl" :src="avatarUrl" alt="" class="nav-avatar-image" />
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
            <router-link v-if="isAdmin" to="/admin" class="nav-dropdown-item" @click="closeDropdowns">Admin panel</router-link>
            <button class="nav-dropdown-item nav-dropdown-item--danger" @click="signOut">Sign out</button>
          </template>
          <template v-else>
            <p class="nav-dropdown-note">Log in to edit your profile and unlock member features.</p>
            <router-link to="/login" class="nav-dropdown-item" @click="closeDropdowns">Log in</router-link>
          </template>
        </div>
      </div>
    </div>

    <button id="hamburger" :class="{ open: mobileOpen }" aria-label="Open navigation menu" @click="toggleMobile">
      <span></span><span></span><span></span>
    </button>
  </nav>

  <nav id="mobile-nav" :class="{ open: mobileOpen }" aria-label="Mobile navigation">
    <router-link to="/home" @click="closeMobile">home</router-link>

    <div class="mobile-group">
      <span class="mobile-group-label">◆ about</span>
      <router-link to="/about" @click="closeMobile">about us</router-link>
      <router-link to="/about/mission" @click="closeMobile">mission</router-link>
      <router-link to="/about/members" @click="closeMobile">members</router-link>
    </div>

    <router-link to="/projects" @click="closeMobile">projects</router-link>

    <div class="mobile-group">
      <span class="mobile-group-label">◆ information</span>
      <router-link to="/info/newsletters" @click="closeMobile">newsletters</router-link>
      <router-link to="/info/update-log" @click="closeMobile">update log</router-link>
      <router-link to="/info/faq" @click="closeMobile">faq</router-link>
    </div>

    <router-link to="/join" @click="closeMobile">how to join</router-link>

    <router-link v-if="isAdmin" to="/admin" class="nav-admin-link" @click="closeMobile">admin panel</router-link>

    <div class="mobile-group">
      <span class="mobile-group-label">◆ socials</span>
      <a href="https://www.facebook.com/profile.php?id=61590594809333" target="_blank" rel="noopener">facebook</a>
    </div>

    <a href="#" @click.prevent="Panels.toggleLeft('forums'); closeMobile()">forums</a>

    <router-link v-if="MemberAuth.sessionMember.value" to="/profile" @click="closeMobile">profile</router-link>
    <router-link v-if="isAdmin" to="/admin" @click="closeMobile">admin panel</router-link>
  </nav>
</template>

<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { playSfx } from '../composables/useSfx.js';
import MemberAuth from '../lib/member-auth.js';
import MemberProfile from '../lib/member-profile.js';
import { sb } from '../lib/supabase-client.js';
import Panels from '../composables/usePanels.js';

const route = useRoute();
const router = useRouter();
const mobileOpen = ref(false);

// Populate the reactive session mirror on first paint so the "profile"
// link (and the account-circle role state) is correct immediately after
// a hard refresh, not just after the next login/logout call. Cheap
// no-op if nobody's logged in.
onMounted(() => {
  if (!MemberAuth.current()) MemberAuth.restoreSession();
  document.addEventListener('click', onDocumentClick);
});
onBeforeUnmount(() => {
  document.removeEventListener('click', onDocumentClick);
});

/* ── PROFILE DROPDOWN ─────────────────────────────────
   Forums/Notifications now open the full side panels (usePanels.js)
   instead of a small dropdown — this is the only dropdown left in
   the navbar itself. A document-level click listener closes it when
   the click lands outside (@click.stop on the trigger + panel itself
   keeps clicks *inside* from bubbling up first). */
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

/* ── ROLE DISPLAY ──────────────────────────────────────
   site_role is the only permission tier this project actually tracks
   ('member' | 'moderator' | 'admin' — see dmac-member-auth-schema.sql).
   Not-logged-in is treated as "Guest" throughout. */
const roleLabel = computed(() => {
  const m = MemberAuth.sessionMember.value;
  if (!m) return 'Guest';
  if (m.site_role === 'admin') return 'Admin';
  if (m.site_role === 'moderator') return 'Moderator';
  return 'Member / Officer';
});
const isAdmin = computed(() => MemberAuth.sessionMember.value?.site_role === 'admin');
const roleClass = computed(() => {
  const m = MemberAuth.sessionMember.value;
  if (!m) return 'nav-avatar--guest';
  if (m.site_role === 'admin') return 'nav-avatar--admin';
  if (m.site_role === 'moderator') return 'nav-avatar--moderator';
  return 'nav-avatar--member';
});
const avatarUrl = computed(() => MemberAuth.sessionMember.value?.avatar_url || null);
// Initials only, not a real avatar image — swap this for a real <img>
// using MemberProfile.fetchProfile(MemberAuth.sessionMember.value?.slug)
// if a NavBar avatar is wanted later (avatar_url is looked up by slug,
// same as ProfileView does — no RPC changes needed for that).
const isAdmin = computed(() => MemberAuth.sessionMember.value?.site_role === 'admin');

// Initials fallback when no custom avatar image is set.
const avatarLabel = computed(() => {
  const name = MemberAuth.sessionMember.value?.display_name;
  if (!name) return '?';
  return name.trim().split(/\s+/).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
});

// Custom avatar image — looked up by slug the same way ProfileView
// does, so the circle shows the member's uploaded picture.
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
  router.push('/login');
}

/* Top-level section links stay highlighted while browsing any
   sub-page in that section (mirrors resolvePath()/startsWith()
   logic from the old global.js). */
function isSection(prefix) {
  return route.path === prefix || route.path.startsWith(prefix + '/');
}

/* Dropdown / mobile-group sub-links only light up on an exact match. */
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
