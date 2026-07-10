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
            <!-- Genuinely nothing to query yet: the scores table this would
                 read from (see lib/leaderboard.js) still keys off the old
                 Google-OAuth `profiles.member_id`, never migrated to match
                 `members.slug` the way forums/DMs/moderation all did — so
                 there's no real link from a logged-in member to a score
                 row today. Saying "checked, none new" here would be a lie;
                 this says plainly that the check itself isn't wired up. -->
            <p class="forums-guest-note">Badge tracking isn't wired up yet.</p>
          </section>

          <section class="notif-section">
            <p class="notif-section-label">Warnings</p>
            <template v-if="!isLoggedIn">
              <p class="forums-guest-note">Log in to see your moderation history.</p>
            </template>
            <template v-else-if="warnings.length">
              <div v-for="w in warnings" :key="w.created_at" class="notif-card">
                <strong class="notif-card-title">Warning from {{ w.actor_name }}</strong>
                <p v-if="w.reason" class="notif-card-body">{{ w.reason }}</p>
                <span class="notif-card-time">{{ formatTime(w.created_at) }}</span>
              </div>
            </template>
            <p v-else class="forums-guest-note">Nothing here — good.</p>
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
import MemberAuth from '../../lib/member-auth.js';

const announcements = ref([]);
const warnings = ref([]);

const isLoggedIn = computed(() => !!MemberAuth.sessionMember.value);

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

  if (isLoggedIn.value) await loadWarnings();
});

// Requires dmac-my-moderation-log-fix.sql — before that RPC existed,
// this section had no way to read moderation_log at all (see that
// file's header for why), so it just showed a hardcoded "good" state
// unconditionally, warned or not.
async function loadWarnings() {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('list_my_moderation_log', { p_session_token: token });
  if (error || !data?.success) {
    console.error('RightPanel: could not load moderation log —', error?.message || data?.message);
    return;
  }
  warnings.value = (data.entries || []).filter((e) => e.action === 'warn');
}

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
