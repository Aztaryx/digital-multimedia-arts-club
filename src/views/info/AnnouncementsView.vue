<template>
  <main>
    <PageHero title="Announcements" />
    <div class="page-section reveal" v-reveal>
      <p class="ann-subtitle">Club news, meeting recaps, and shout-outs — not to be confused with Newsletters (the site's own dev journal), see the FAQ if that's ever unclear.</p>

      <div v-if="loading" class="ann-empty">Loading…</div>

      <div v-else class="ann-list">
        <p v-if="!announcements.length" class="ann-empty">No announcements yet.</p>

        <article v-for="a in announcements" :key="a.id" class="ann-card" v-sfx-hover>
          <div class="ann-card-head">
            <h2 class="ann-title">{{ a.title }}</h2>
            <time class="ann-time" :datetime="a.created_at">{{ formatDate(a.created_at) }}</time>
          </div>
          <p class="ann-body">{{ a.body }}</p>
          <p v-if="a.author_name" class="ann-footer">— {{ a.author_name }}</p>
        </article>
      </div>
    </div>
  </main>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import PageHero from '../../components/PageHero.vue';
import { sb } from '../../lib/supabase-client.js';
import '../../assets/css/pages/club-announcements.css';

const announcements = ref([]);
const loading = ref(true);

onMounted(async () => {
  const { data, error } = await sb
    .from('club_announcements')
    .select('id, title, body, created_at, author_id, members!author_id(display_name)')
    .order('created_at', { ascending: false });

  loading.value = false;

  if (error) {
    console.error('AnnouncementsView: could not load club announcements —', error.message);
    return;
  }

  announcements.value = (data || []).map((a) => ({
    ...a,
    author_name: a.members?.display_name || null,
  }));
});

function formatDate(dateStr) {
  return new Date(dateStr).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
}
</script>
