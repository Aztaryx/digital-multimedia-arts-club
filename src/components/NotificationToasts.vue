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
import Panels from '../composables/usePanels.js';

function typeLabel(type) {
  return NOTIF_TYPES[type]?.label || type;
}

/* Simple line-icon set matching NavBar's inline-SVG style (viewBox
   0 0 24 24, stroke-width 1.6, no fill) — one per notification type,
   rendered via v-html so `currentColor` (set from --accent below)
   tints the stroke to match that toast's outline. */
const ICONS = {
  maintenance: '<svg viewBox="0 0 24 24"><path d="M14.7 6.3a4 4 0 0 1-5.4 5.4L4 17l3 3 5.3-5.3a4 4 0 0 1 5.4-5.4l-2.6 2.6-2-2 2.6-2.6Z" stroke-width="1.6" stroke-linejoin="round"/></svg>',
  dm: '<svg viewBox="0 0 24 24"><path d="M4 5.5h16a1 1 0 0 1 1 1V15a1 1 0 0 1-1 1H9l-4 4v-4H4a1 1 0 0 1-1-1V6.5a1 1 0 0 1 1-1Z" stroke-width="1.6" stroke-linejoin="round"/></svg>',
  warn: '<svg viewBox="0 0 24 24"><path d="M12 4 2 20h20L12 4Z" stroke-width="1.6" stroke-linejoin="round"/><path d="M12 10v4M12 17.2v.1" stroke-width="1.8" stroke-linecap="round"/></svg>',
  silence: '<svg viewBox="0 0 24 24"><path d="M6 9a6 6 0 1 1 12 0c0 4 1.5 5.5 2 6H4c.5-.5 2-2 2-6Z" stroke-width="1.6" stroke-linejoin="round"/><path d="M3 3l18 18" stroke-width="1.6" stroke-linecap="round"/></svg>',
  forum: '<svg viewBox="0 0 24 24"><path d="M4 5.5h16a1 1 0 0 1 1 1V15a1 1 0 0 1-1 1H9l-4 4v-4H4a1 1 0 0 1-1-1V6.5a1 1 0 0 1 1-1Z" stroke-width="1.6" stroke-linejoin="round"/><path d="M8 9.5h8M8 12.5h5" stroke-width="1.3" stroke-linecap="round"/></svg>',
  friend_request: '<svg viewBox="0 0 24 24"><circle cx="9" cy="8.5" r="3.2" stroke-width="1.6"/><path d="M3 19c1-3.2 3.6-4.8 6-4.8s5 1.6 6 4.8" stroke-width="1.6" stroke-linecap="round"/><path d="M18 8v5M15.5 10.5h5" stroke-width="1.6" stroke-linecap="round"/></svg>',
  badge: '<svg viewBox="0 0 24 24"><circle cx="12" cy="9" r="5" stroke-width="1.6"/><path d="M9 13.5 7.5 20 12 17.5 16.5 20 15 13.5" stroke-width="1.6" stroke-linejoin="round"/></svg>',
};

function iconFor(type) {
  return ICONS[type] || ICONS.dm;
}

/* Clicking a toast jumps to the panel where you'd actually act on it,
   then clears it — doesn't try to deep-link into e.g. one specific
   DM thread or forum post (those live in LeftPanel's own local
   state), just gets you to the right tab fast. */
function onToastClick(t) {
  if (t.type === 'dm' || t.type === 'friend_request') {
    Panels.openLeft('dms');
  } else if (t.type === 'forum') {
    Panels.openLeft('forums');
  } else {
    Panels.openRight();
  }
  Notifications.dismiss(t.id);
}
</script>
