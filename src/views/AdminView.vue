<template>
  <main class="profile-page">
    <div class="page-section profile-shell reveal" v-reveal>
      <SecHead>Admin Panel</SecHead>

      <p class="profile-intro">
        Post global announcements and maintenance notices — everything published here shows up in everyone's notifications panel.
      </p>

      <p v-if="statusMsg" class="profile-status" :class="statusType">{{ statusMsg }}</p>

      <div class="profile-grid">
        <section class="profile-panel">
          <div class="profile-panel-head">
            <h3>New announcement</h3>
            <span>Visible to every visitor</span>
          </div>

          <div class="seg-toggle" role="group" aria-label="Announcement type">
            <button
              type="button"
              class="seg-btn"
              :class="{ active: kind === 'announcement' }"
              v-sfx-hover
              @click="kind = 'announcement'"
            >Announcement</button>
            <button
              type="button"
              class="seg-btn"
              :class="{ active: kind === 'maintenance' }"
              v-sfx-hover
              @click="kind = 'maintenance'"
            >Maintenance</button>
          </div>

          <label class="profile-field">
            <span>Title</span>
            <input class="profile-input" v-model="title" maxlength="120" placeholder="Short headline" />
          </label>

          <label class="profile-field">
            <span>Body</span>
            <textarea class="profile-textarea" v-model="body" maxlength="2000" rows="5" placeholder="What do people need to know?"></textarea>
          </label>

          <button class="profile-btn" v-sfx-hover :disabled="posting" @click="postAnnouncement">Publish</button>
        </section>

        <section class="profile-panel">
          <div class="profile-panel-head">
            <h3>Published</h3>
            <span>Latest first</span>
          </div>

          <template v-if="announcements.length">
            <div v-for="a in announcements" :key="a.id" class="admin-announcement-row">
              <div class="admin-announcement-copy">
                <strong>{{ a.title }}</strong>
                <small>{{ a.kind }} · {{ formatTime(a.created_at) }}</small>
                <p>{{ a.body }}</p>
              </div>
              <button class="profile-btn profile-btn--danger" v-sfx-hover @click="removeAnnouncement(a.id)">Delete</button>
            </div>
          </template>
          <p v-else class="forums-guest-note">Nothing published yet.</p>
        </section>
      </div>
    </div>
  </main>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import SecHead from '../components/SecHead.vue';
import MemberAuth from '../lib/member-auth.js';
import { sb } from '../lib/supabase-client.js';
import { playSfx } from '../composables/useSfx.js';

const kind = ref('announcement');
const title = ref('');
const body = ref('');
const posting = ref(false);
const announcements = ref([]);

const statusMsg = ref('');
const statusType = ref('info');

function status(msg, type = 'info') {
  statusMsg.value = msg;
  statusType.value = type;
}

onMounted(loadAnnouncements);

async function loadAnnouncements() {
  const { data, error } = await sb
    .from('announcements')
    .select('id, title, body, kind, created_at')
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) {
    status('Could not load announcements — has dmac-site-polish-schema.sql been run?', 'error');
    return;
  }
  announcements.value = data || [];
}

async function postAnnouncement() {
  playSfx('menuclick');
  if (!title.value.trim() || !body.value.trim()) {
    status('Both a title and a body are required.', 'error');
    return;
  }

  posting.value = true;
  const { data, error } = await sb.rpc('create_announcement', {
    p_session_token: MemberAuth.getSessionToken(),
    p_title: title.value.trim(),
    p_body: body.value.trim(),
    p_kind: kind.value,
  });
  posting.value = false;

  if (error || !data?.success) {
    status(data?.message || error?.message || 'Could not publish.', 'error');
    return;
  }

  title.value = '';
  body.value = '';
  status('Published.', 'success');
  loadAnnouncements();
}

async function removeAnnouncement(id) {
  playSfx('menuclick');
  const { data, error } = await sb.rpc('delete_announcement', {
    p_session_token: MemberAuth.getSessionToken(),
    p_announcement_id: id,
  });

  if (error || !data?.success) {
    status(data?.message || error?.message || 'Could not delete.', 'error');
    return;
  }
  status('Deleted.', 'success');
  loadAnnouncements();
}

function formatTime(ts) {
  try {
    return new Date(ts).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' });
  } catch (_) {
    return '';
  }
}
</script>

<style scoped>
.profile-shell {
  gap: 22px;
}

.profile-intro {
  max-width: 820px;
  color: rgba(240, 240, 240, 0.72);
  line-height: 1.7;
  font-size: 1rem;
}

.profile-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 18px;
}

.profile-panel {
  border-radius: 24px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.04);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.03);
  padding: 18px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.profile-panel-head {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 12px;
}

.profile-panel-head h3 {
  margin: 0;
  line-height: 1.1;
  font-size: 1rem;
}

.profile-panel-head span {
  color: rgba(240, 240, 240, 0.58);
}

.profile-field {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.profile-field span {
  font-size: 0.76rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: rgba(240, 240, 240, 0.55);
}

/* Segmented button toggle — swapped in for the old "Type" label +
   <select>, since a two-option dropdown is just two buttons wearing a
   trenchcoat: one click either way instead of open-menu-then-click. */
.seg-toggle {
  display: flex;
  gap: 8px;
}

.seg-btn {
  flex: 1;
  font: inherit;
  font-size: 0.85rem;
  color: rgba(240, 240, 240, 0.7);
  background: rgba(8, 8, 12, 0.58);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 16px;
  padding: 10px 14px;
  cursor: pointer;
  transition: border-color 0.2s ease, color 0.2s ease, background 0.2s ease;
}

.seg-btn:hover {
  border-color: rgba(249, 115, 22, 0.5);
  color: #fff;
}

.seg-btn.active {
  background: linear-gradient(135deg, var(--orange), var(--purple));
  border-color: transparent;
  color: #fff;
}

.profile-input,
.profile-textarea {
  width: 100%;
  font: inherit;
  color: #f7f4ee;
  border-radius: 16px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  background: rgba(8, 8, 12, 0.58);
  padding: 12px 14px;
  outline: none;
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}

.profile-textarea {
  resize: vertical;
  min-height: 120px;
}

.profile-input:focus,
.profile-textarea:focus {
  border-color: rgba(249, 115, 22, 0.7);
  box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.18);
}

select.profile-input option {
  background: #16161c;
}

.profile-btn {
  align-self: flex-start;
  font: inherit;
  border: none;
  cursor: pointer;
  color: #fff;
  border-radius: 999px;
  padding: 11px 18px;
  background: linear-gradient(135deg, var(--orange), var(--purple));
  box-shadow: 0 10px 24px rgba(76, 29, 149, 0.22);
}

.profile-btn:disabled {
  opacity: 0.6;
  cursor: default;
}

.profile-btn--danger {
  background: rgba(184, 61, 61, 0.16);
  color: #ffb0b0;
  border: 1px solid rgba(255, 130, 130, 0.2);
  box-shadow: none;
}

.profile-status {
  padding: 11px 14px;
  border-radius: 18px;
  font-size: 0.9rem;
  border: 1px solid transparent;
}

.profile-status.success {
  background: rgba(20, 61, 31, 0.76);
  color: #9ff0b4;
  border-color: rgba(159, 240, 180, 0.16);
}

.profile-status.error {
  background: rgba(61, 20, 20, 0.78);
  color: #ffb0b0;
  border-color: rgba(255, 176, 176, 0.16);
}

.profile-status.info {
  background: rgba(26, 42, 61, 0.78);
  color: #aed7ff;
  border-color: rgba(174, 215, 255, 0.16);
}

.admin-announcement-row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  padding: 14px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
}

.admin-announcement-copy {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.admin-announcement-copy small {
  color: rgba(240, 240, 240, 0.55);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-size: 0.68rem;
}

.admin-announcement-copy p {
  margin: 0;
  color: rgba(240, 240, 240, 0.78);
  line-height: 1.5;
  font-size: 0.9rem;
  white-space: pre-wrap;
}

@media (max-width: 1040px) {
  .profile-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .admin-announcement-row {
    flex-direction: column;
  }
}
</style>
