<template>
  <Teleport to="body">
    <div class="side-overlay side-overlay--right" :class="{ open: Panels.rightOpen.value }" @click="onOverlayClick">
      <div class="side-panel side-panel--right" @click.stop>
        <div class="side-panel-head">
          <strong class="side-panel-title">Notifications</strong>
          <button class="side-panel-close" aria-label="Close" v-sfx-hover @click="Panels.closeAll">✕</button>
        </div>

        <div class="side-panel-body">
          <!-- No notifications backend exists yet (no table/RPCs) — this
               is the categorized shape ready for it: badges awarded,
               moderation warnings, and site/maintenance notices are the
               three kinds called out, each its own section so they don't
               all blur into one flat list once real data lands. -->
          <section class="notif-section">
            <p class="notif-section-label">Badges</p>
            <p class="forums-guest-note">No new badges.</p>
          </section>

          <section class="notif-section">
            <p class="notif-section-label">Warnings</p>
            <p class="forums-guest-note">Nothing here — good.</p>
          </section>

          <section class="notif-section">
            <p class="notif-section-label">Maintenance</p>
            <p class="forums-guest-note">No maintenance notices.</p>
          </section>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import Panels from '../../composables/usePanels.js';

function onOverlayClick(e) {
  if (e.target === e.currentTarget) Panels.closeAll();
}
</script>
