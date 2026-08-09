<template>
  <main>
    <div class="page-section reveal" v-reveal>
      <SecHead>Newsletters</SecHead>
      <p class="nl-subtitle">
        The site's own dev journal — roadmap updates, sneak peeks, the occasional joke. For club news
        (meetings, results, shout-outs) see <router-link to="/info/announcements">Announcements</router-link>;
        for what we're actually covering see <router-link to="/info/school-events">School Events</router-link>.
      </p>

      <div v-if="loading" class="nl-empty" v-sfx-protected>
        <span class="stub-label">loading…</span>
      </div>

      <div v-else class="nl-list">
        <div v-if="!entries.length" class="nl-empty" v-sfx-protected>
          <span class="stub-label">no newsletters yet</span>
        </div>

        <article v-for="entry in entries" :key="entry.id" class="nl-card" v-sfx-hover>
          <div class="nl-card-head">
            <span class="nl-kind" :class="`nl-kind--${entry.kind}`">{{ entry.kind === 'maintenance' ? 'Maintenance' : 'Update' }}</span>
            <time class="nl-time" :datetime="entry.created_at">{{ formatDate(entry.created_at) }}</time>
          </div>
          <h3 class="nl-title">{{ entry.title }}</h3>
          <p class="nl-body">{{ entry.body }}</p>
        </article>
      </div>
    </div>
  </main>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import SecHead from '../../components/SecHead.vue';
import { sb } from '../../lib/supabase-client.js';
import '../../assets/css/pages/newsletters.css';

/* Newsletters = the site/dev journal — what used to live in this
   page's static "no announcements yet" stub is now a real read from
   the `announcements` table (kind: 'announcement' | 'maintenance'),
   the same table AdminView.vue's Newsletters tab writes to. Club
   news and School Events both moved to their own tables/pages — see
   dmac-consolidated-plan.md §4 for why those three are kept apart. */

const entries = ref([]);
const loading = ref(true);

onMounted(async () => {
  const { data, error } = await sb
    .from('announcements')
    .select('id, title, body, kind, created_at')
    .order('created_at', { ascending: false })
    .limit(50);

  loading.value = false;

  if (error) {
    console.error('NewslettersView: could not load newsletters —', error.message);
    return;
  }

  entries.value = data || [];
});

function formatDate(dateStr) {
  return new Date(dateStr).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
}
</script>
