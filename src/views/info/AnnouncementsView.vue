<template>
  <div class="view announcements-view">
    <SecHead title="Announcements" subtitle="Club news and updates" />

    <div class="announcements-content">
      <div class="announcements-list">
        <div v-if="announcements.length === 0" class="empty-state">
          <p>No announcements yet.</p>
        </div>

        <article v-for="announcement in announcements" :key="announcement.id" class="announcement-card">
          <div class="announcement-header">
            <h2>{{ announcement.title }}</h2>
            <time :datetime="announcement.created_at">{{ formatDate(announcement.created_at) }}</time>
          </div>
          <div class="announcement-body">
            {{ announcement.body }}
          </div>
          <div v-if="announcement.author_name" class="announcement-footer">
            by {{ announcement.author_name }}
          </div>
        </article>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import SecHead from '../components/SecHead.vue';
import { supabase } from '../lib/supabase-client.js';

const announcements = ref([]);

onMounted(async () => {
  // Load club announcements from Supabase
  const { data } = await supabase
    .from('club_announcements')
    .select(`
      id,
      title,
      body,
      created_at,
      author_id,
      members!inner(display_name)
    `)
    .order('created_at', { ascending: false });

  if (data) {
    announcements.value = data.map(a => ({
      ...a,
      author_name: a.members?.display_name || 'Anonymous',
    }));
  }
});

function formatDate(dateStr) {
  const date = new Date(dateStr);
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
}
</script>

<style scoped>
.announcements-view {
  padding: 2rem;
  max-width: 800px;
  margin: 0 auto;
}

.announcements-content {
  margin-top: 2rem;
}

.empty-state {
  text-align: center;
  padding: 3rem 1rem;
  color: var(--text-secondary);
}

.announcements-list {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.announcement-card {
  padding: 1.5rem;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--bg-secondary);
  transition: all 0.2s;
}

.announcement-card:hover {
  border-color: var(--primary);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.announcement-header {
  display: flex;
  justify-content: space-between;
  align-items: start;
  margin-bottom: 1rem;
  gap: 1rem;
}

.announcement-header h2 {
  margin: 0;
  font-size: 1.3rem;
}

.announcement-header time {
  font-size: 0.9rem;
  color: var(--text-secondary);
  white-space: nowrap;
}

.announcement-body {
  line-height: 1.6;
  margin-bottom: 1rem;
  color: var(--text);
}

.announcement-footer {
  font-size: 0.9rem;
  color: var(--text-secondary);
  border-top: 1px solid var(--border);
  padding-top: 1rem;
}
</style>
