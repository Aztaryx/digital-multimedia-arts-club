<template>
  <nav id="navbar">
    <router-link to="/" class="nav-logo">
      <img src="https://aztaryx.github.io/dmac-assets/logo.png" alt="DMAC" height="38" />
    </router-link>
    <ul class="nav-links">
      <li>
        <router-link to="/" :class="{ active: isExact('/') }">home</router-link>
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
    </ul>
    <button id="hamburger" :class="{ open: mobileOpen }" aria-label="Open navigation menu" @click="toggleMobile">
      <span></span><span></span><span></span>
    </button>
  </nav>

  <nav id="mobile-nav" :class="{ open: mobileOpen }" aria-label="Mobile navigation">
    <router-link to="/" @click="closeMobile">home</router-link>

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

    <div class="mobile-group">
      <span class="mobile-group-label">◆ socials</span>
      <a href="https://www.facebook.com/profile.php?id=61590594809333" target="_blank" rel="noopener">facebook</a>
    </div>

    <router-link v-if="MemberAuth.sessionMember.value" to="/profile" @click="closeMobile">profile</router-link>
  </nav>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { playSfx } from '../composables/useSfx.js';
import MemberAuth from '../lib/member-auth.js';

const route = useRoute();
const mobileOpen = ref(false);

// Populate the reactive session mirror on first paint so the "profile"
// link is correct immediately after a hard refresh, not just after the
// next login/logout call. Cheap no-op if nobody's logged in.
onMounted(() => {
  if (!MemberAuth.current()) MemberAuth.restoreSession();
});

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
