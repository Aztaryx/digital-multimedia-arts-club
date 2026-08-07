/* ═══════════════════════════════════════════════════
   usePanels.js — shared state for the two side overlays
   ═══════════════════════════════════════════════════
   Singleton refs (module-level, not per-component) so NavBar's icon
   buttons and the panel components themselves agree on one shared
   state, the same pattern member-auth.js uses for sessionMember.

   Left panel  → Forums (tabbed with Rulebook)
   Right panel → Notifications

   Only one panel open at a time on purpose — opening one closes the
   other, so they don't fight for screen space on narrow viewports.
   ═══════════════════════════════════════════════════ */

import { ref } from 'vue';

const leftOpen = ref(false);
const rightOpen = ref(false);
const leftTab = ref('forums'); // 'forums' | 'rules'

function openLeft(tab) {
  if (tab) leftTab.value = tab;
  leftOpen.value = true;
  rightOpen.value = false;
}

function openRight() {
  rightOpen.value = true;
  leftOpen.value = false;
}

function closeAll() {
  leftOpen.value = false;
  rightOpen.value = false;
}

function toggleLeft(tab) {
  if (leftOpen.value && (!tab || leftTab.value === tab)) {
    leftOpen.value = false;
    return;
  }
  openLeft(tab);
}

function toggleRight() {
  if (rightOpen.value) {
    rightOpen.value = false;
    return;
  }
  openRight();
}

export default {
  leftOpen, rightOpen, leftTab,
  openLeft, openRight, closeAll, toggleLeft, toggleRight,
};
