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

const route = useRoute();
// Standalone pages (currently just /login) opt out of the shared
// nav/footer chrome via route meta — see router/index.js.
const showChrome = computed(() => !route.meta?.hideChrome);

const preloaderRef = ref(null);
const statusText = ref('Loading code…');

/* ── PRELOADER ─────────────────────────────────────
   Same staged messaging as the old global.js preloader, but now
   this only ever runs ONCE for the whole app session (App.vue
   mounts a single time) instead of on every full page load — one
   of the concrete wins of moving to an SPA. SFX sprites, once
   decoded here, stay warm for the entire visit; no more "first
   sound on each new page has to wait on a fetch + decode". */

function preloadImage(url) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = resolve;
    img.onerror = resolve; // one missing/renamed badge shouldn't stall the preloader
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

/* ── NOTIFICATIONS ──────────────────────────────────
   Starts immediately (guests still get maintenance toasts) and
   restarts under the new identity whenever login/logout happens —
   Notifications.startPolling() itself no-ops if it's already polling
   for the same slug, so this can fire on every sessionMember change
   without duplicating timers. */
onMounted(() => {
  Notifications.startPolling();
  startKonamiListener();
});
watch(MemberAuth.sessionMember, () => {
  Notifications.startPolling();
});
</script>