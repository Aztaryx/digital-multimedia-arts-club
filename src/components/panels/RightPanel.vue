<template>
  <Teleport to="body">
    <div class="side-overlay side-overlay--right" :class="{ open: Panels.rightOpen.value }" @click="onOverlayClick">
      <div class="side-panel side-panel--right" @click.stop>
        <div class="side-panel-head">
          <strong class="side-panel-title">Notifications</strong>
          <button class="side-panel-close" aria-label="Close" v-sfx-hover @click="Panels.closeAll">✕</button>
        </div>

        <div class="side-panel-body">
          <section class="notif-section">
            <p class="notif-section-label">Announcements</p>
            <template v-if="generalAnnouncements.length">
              <div v-for="a in generalAnnouncements" :key="a.id" class="notif-card">
                <strong class="notif-card-title">{{ a.title }}</strong>
                <p class="notif-card-body">{{ a.body }}</p>
                <span class="notif-card-time">{{ formatTime(a.created_at) }}</span>
              </div>
            </template>
            <p v-else class="forums-guest-note">No announcements.</p>
          </section>

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
            <template v-if="maintenanceAnnouncements.length">
              <div v-for="a in maintenanceAnnouncements" :key="a.id" class="notif-card notif-card--maintenance">
                <strong class="notif-card-title">{{ a.title }}</strong>
                <p class="notif-card-body">{{ a.body }}</p>
                <span class="notif-card-time">{{ formatTime(a.created_at) }}</span>
              </div>
            </template>
            <p v-else class="forums-guest-note">No maintenance notices.</p>
          </section>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { sb } from '../../lib/supabase-client.js';
import Panels from '../../composables/usePanels.js';

const announcements = ref([]);

const generalAnnouncements = computed(() => announcements.value.filter((a) => a.kind !== 'maintenance'));
const maintenanceAnnouncements = computed(() => announcements.value.filter((a) => a.kind === 'maintenance'));

// Refresh every time the panel opens — the announcements table only
// exists once dmac-site-polish-schema.sql has run, so a query error
// just leaves the empty placeholders in place.
watch(Panels.rightOpen, async (open) => {
  if (!open) return;
  const { data, error } = await sb
    .from('announcements')
    .select('id, title, body, kind, created_at')
    .order('created_at', { ascending: false })
    .limit(20);
  if (!error) announcements.value = data || [];
});

function formatTime(ts) {
  try {
    return new Date(ts).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' });
  } catch (_) {
    return '';
  }
}

function onOverlayClick(e) {
  if (e.target === e.currentTarget) Panels.closeAll();
}
</script>
