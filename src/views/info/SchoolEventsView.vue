<template>
  <div class="view school-events-view">
    <SecHead title="School Events" subtitle="Assemblies, competitions & more" />

    <div class="school-events-content">
      <div class="events-list">
        <div v-if="events.length === 0" class="empty-state">
          <p>No upcoming school events.</p>
        </div>

        <article v-for="event in events" :key="event.id" class="event-card">
          <div class="event-date">
            <span class="month">{{ formatMonth(event.event_date) }}</span>
            <span class="day">{{ formatDay(event.event_date) }}</span>
          </div>
          <div class="event-details">
            <h2>{{ event.title }}</h2>
            <p v-if="event.location" class="event-location">📍 {{ event.location }}</p>
            <p v-if="event.description" class="event-description">{{ event.description }}</p>
          </div>
        </article>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import SecHead from '../../components/SecHead.vue';
import { supabase } from '../../lib/supabase-client.js';

const events = ref([]);

onMounted(async () => {
  // Load school events from Supabase
  const { data } = await supabase
    .from('school_events')
    .select('*')
    .gte('event_date', new Date().toISOString().split('T')[0])
    .order('event_date', { ascending: true });

  if (data) {
    events.value = data;
  }
});

function formatMonth(dateStr) {
  const date = new Date(dateStr + 'T00:00:00Z');
  return date.toLocaleDateString('en-US', { month: 'short' }).toUpperCase();
}

function formatDay(dateStr) {
  const date = new Date(dateStr + 'T00:00:00Z');
  return date.getDate();
}
</script>

<style scoped>
.school-events-view {
  padding: 2rem;
  max-width: 800px;
  margin: 0 auto;
}

.school-events-content {
  margin-top: 2rem;
}

.empty-state {
  text-align: center;
  padding: 3rem 1rem;
  color: var(--text-secondary);
}

.events-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.event-card {
  display: flex;
  gap: 1.5rem;
  padding: 1.5rem;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--bg-secondary);
  transition: all 0.2s;
}

.event-card:hover {
  border-color: var(--primary);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.event-date {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 70px;
  height: 70px;
  background: var(--primary);
  color: white;
  border-radius: 8px;
  flex-shrink: 0;
  font-weight: bold;
}

.event-date .month {
  font-size: 0.8rem;
  opacity: 0.9;
}

.event-date .day {
  font-size: 1.8rem;
}

.event-details {
  flex: 1;
}

.event-details h2 {
  margin: 0 0 0.5rem 0;
  font-size: 1.2rem;
}

.event-location {
  margin: 0.5rem 0;
  color: var(--text-secondary);
  font-size: 0.95rem;
}

.event-description {
  margin: 0.5rem 0 0 0;
  color: var(--text-secondary);
  line-height: 1.5;
}
</style>
