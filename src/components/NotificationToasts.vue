<template>
  <Teleport to="body">
    <div class="notif-toast-stack" aria-live="polite">
      <TransitionGroup name="notif-toast">
        <div
          v-for="t in Notifications.toasts.value"
          :key="t.id"
          class="notif-toast"
          :style="{ '--accent': t.color }"
          role="alert"
          @click="onToastClick(t)"
        >
          <div class="notif-toast-icon" v-html="iconFor(t.type)"></div>
          <div class="notif-toast-body">
            <div class="notif-toast-head">
              <strong class="notif-toast-title">{{ t.title }}</strong>
              <span class="notif-toast-type">{{ typeLabel(t.type) }}</span>
            </div>
            <p v-if="t.body" class="notif-toast-text">{{ t.body }}</p>
          </div>
          <button class="notif-toast-close" aria-label="Dismiss" @click.stop="Notifications.dismiss(t.id)">✕</button>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<script setup>
import Notifications, { NOTIF_TYPES } from '../lib/notifications.js';

function typeLabel(type) {
  return NOTIF_TYPES[type]?.label || type;
}

/* Simple line-icon set matching NavBar's inline-SVG style (viewBox
   0 0 24 24, stroke-width 1.6, no fill) — one per notification type,
   rendered via v-html so `currentColor` (set from --accent below)
   tints the stroke to match that toast's outline. The old `forum`
   entry is gone along with forum notifications themselves (see
   lib/notifications.js's own header) — `announcement`'s icon is now
   the generic fallback. */
const ICONS = {
  maintenance: '<svg viewBox="0 0 24 24"><path d="M14.7 6.3a4 4 0 0 1-5.4 5.4L4 17l3 3 5.3-5.3a4 4 0 0 1 5.4-5.4l-2.6 2.6-2-2 2.6-2.6Z" stroke-width="1.6" stroke-linejoin="round"/></svg>',
  announcement: '<svg viewBox="0 0 24 24"><path d="M4 10v4a1 1 0 0 0 1 1h2l7 4V5L7 9H5a1 1 0 0 0-1 1Z" stroke-width="1.6" stroke-linejoin="round"/><path d="M18 9.5a3.5 3.5 0 0 1 0 5" stroke-width="1.6" stroke-linecap="round"/></svg>',
  warn: '<svg viewBox="0 0 24 24"><path d="M12 4 2 20h20L12 4Z" stroke-width="1.6" stroke-linejoin="round"/><path d="M12 10v4M12 17.2v.1" stroke-width="1.8" stroke-linecap="round"/></svg>',
  silence: '<svg viewBox="0 0 24 24"><path d="M6 9a6 6 0 1 1 12 0c0 4 1.5 5.5 2 6H4c.5-.5 2-2 2-6Z" stroke-width="1.6" stroke-linejoin="round"/><path d="M3 3l18 18" stroke-width="1.6" stroke-linecap="round"/></svg>',
  badge: '<svg viewBox="0 0 24 24"><circle cx="12" cy="9" r="5" stroke-width="1.6"/><path d="M9 13.5 7.5 20 12 17.5 16.5 20 15 13.5" stroke-width="1.6" stroke-linejoin="round"/></svg>',
};

function iconFor(type) {
  return ICONS[type] || ICONS.announcement;
}

/* The left/right side overlays (Rulebook, Notifications panel) are
   gone — Forums was removed entirely, and the two panels that
   accompanied/replaced it were dropped as unneeded once it was gone
   (see App.vue/NavBar.vue and the deleted usePanels.js/LeftPanel.vue/
   RightPanel.vue). Clicking a toast now just dismisses it, same as
   the explicit ✕ button — there's nowhere left for a click-through
   to send you. */
function onToastClick(t) {
  Notifications.dismiss(t.id);
}
</script>