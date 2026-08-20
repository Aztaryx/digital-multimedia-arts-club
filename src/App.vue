<template>
  <div id="preloader" ref="preloaderRef">
    <img class="pre-logo" src="https://aztaryx.github.io/dmac-assets/logo.png" alt="DMAC" width="68" height="68" />
    <div class="pre-bar"><div class="pre-fill"></div></div>
    <p class="pre-status">{{ statusText }}</p>
  </div>

  <NavBar v-if="showChrome" />
  <NotificationToasts />
  <router-view />
  <FooterSection v-if="showChrome" />
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import NavBar from './components/NavBar.vue';
import FooterSection from './components/FooterSection.vue';
import NotificationToasts from './components/NotificationToasts.vue';
import SFX from './lib/sfx.js';
import { SFX_DATA } from './lib/sfx-data.js';
import { playSfx } from './composables/useSfx.js';
import { BADGE_URL_LIST } from './lib/badges.js';
import MemberAuth from './lib/member-auth.js';
import Notifications from './lib/notifications.js';
import { startKonamiListener } from './lib/secret-badges.js';
import { handleOAuthCallback } from './lib/oauth-link.js';

const route = useRoute();
// No standalone /login route left to opt out of chrome for — kept
// as a meta-driven switch in case a future route needs it.
const showChrome = computed(() => !route.meta?.hideChrome);

const preloaderRef = ref(null);
const statusText = ref('Loading code…');

function preloadImage(url) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = resolve;
    img.onerror = resolve;
    img.src = url;
  });
}

onMounted(() => {
  const badgesReady = Promise.all(BADGE_URL_LIST.map(preloadImage));

  const sfxReady = Promise.all(
    Object.keys(SFX_DATA).map((sprite) =>
      SFX.preload(sprite).catch((err) => {
        console.error(`SFX: preload failed for sprite "${sprite}" —`, err.message || err);
      })
    )
  );

  statusText.value = 'Loading images…';

  const fontsAndImagesReady = Promise.all([
    document.fonts.ready,
    new Promise((res) => {
      if (document.readyState === 'complete') res();
      else window.addEventListener('load', res, { once: true });
    }),
    badgesReady,
  ]);

  fontsAndImagesReady
    .then(() => {
      statusText.value = 'Loading audio…';
      return sfxReady;
    })
    .then(() => {
      statusText.value = 'Ready';
      document.body.classList.add('loaded');
      setTimeout(() => {
        preloaderRef.value?.classList.add('hidden');
        playSfx('menuback');
      }, 380);
    });
});

onMounted(() => {
  Notifications.startPolling();
  startKonamiListener();

  // Google's OAuth redirect can now land on any page (login is
  // inline, not a dedicated /login route anymore) — handle it here,
  // once, regardless of where the visitor ends up back at.
  handleOAuthCallback((msg, type) => {
    Notifications.push({ type: type === 'error' ? 'warn' : 'announcement', title: msg });
  });
});
watch(MemberAuth.sessionMember, () => {
  Notifications.startPolling();
});
</script>
