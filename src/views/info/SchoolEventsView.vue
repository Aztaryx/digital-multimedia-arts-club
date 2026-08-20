<template>
  <main>
    <PageHero title="School Events" />
    <div class="page-section reveal" v-reveal>
      <p class="se-subtitle">Assemblies, competitions, and activities DMAC covers or plans to cover.</p>

      <div v-if="loading" class="se-empty">Loading…</div>

      <div v-else class="se-list">
        <p v-if="!events.length" class="se-empty">No upcoming school events.</p>

        <article v-for="event in events" :key="event.id" class="se-card" v-sfx-hover>
          <div class="se-date">
            <span class="se-month">{{ formatMonth(event.event_date) }}</span>
            <span class="se-day">{{ formatDay(event.event_date) }}</span>
          </div>
          <div class="se-details">
            <h2 class="se-title">{{ event.title }}</h2>
            <p v-if="event.location" class="se-location">{{ event.location }}</p>
            <p v-if="event.description" class="se-description">{{ event.description }}</p>
          </div>
        </article>
      </div>
    </div>
  </main>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import PageHero from '../../components/PageHero.vue';
import { sb } from '../../lib/supabase-client.js';
import '../../assets/css/pages/school-events.css';

const events = ref([]);
const loading = ref(true);

onMounted(async () => {
  const { data, error } = await sb
    .from('school_events')
    .select('id, title, description, event_date, location')
    .gte('event_date', new Date().toISOString().split('T')[0])
    .order('event_date', { ascending: true });

  loading.value = false;

  if (error) {
    console.error('SchoolEventsView: could not load school events —', error.message);
    return;
  }

  events.value = data || [];
});

function formatMonth(dateStr) {
  return new Date(`${dateStr}T00:00:00Z`).toLocaleDateString('en-US', { month: 'short', timeZone: 'UTC' }).toUpperCase();
}

function formatDay(dateStr) {
  return new Date(`${dateStr}T00:00:00Z`).getUTCDate();
}
</script>
