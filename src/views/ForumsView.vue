<template>
  <main>
    <div class="page-section forums-shell reveal" v-reveal>
      <div class="forums-head">
        <SecHead>Forums</SecHead>
        <span class="forums-beta">Beta</span>
      </div>

      <p class="forums-intro">
        A space to ask questions, share work, and coordinate as a club.
        Anyone can read a thread — logging in as a member unlocks
        starting new ones.
      </p>

      <!-- ── COMPOSER (members / officers / mods / admins only) ── -->
      <div v-if="isLoggedIn" class="forum-composer-row">
        <button class="forum-btn forum-btn--primary" v-sfx-hover @click="composerOpen = !composerOpen">
          {{ composerOpen ? 'Cancel' : '+ New thread' }}
        </button>
      </div>
      <p v-else class="forums-guest-note">
        <router-link to="/login">Log in</router-link> as a member to start a thread — guests can read, but can't post.
      </p>

      <section v-if="composerOpen" class="forum-composer">
        <label class="forum-field">
          <span>Title</span>
          <input class="forum-input" v-model="draftTitle" maxlength="120" placeholder="What's this thread about?" />
        </label>
        <label class="forum-field">
          <span>Message</span>
          <textarea class="forum-input forum-textarea" v-model="draftBody" maxlength="2000" rows="4" placeholder="Say more…"></textarea>
        </label>
        <div class="forum-composer-actions">
          <button class="forum-btn forum-btn--primary" v-sfx-hover @click="submitDraft">Post thread</button>
        </div>
        <p v-if="composerStatus" class="forums-guest-note">{{ composerStatus }}</p>
      </section>

      <!-- ── THREAD LIST ── -->
      <section class="forum-thread-list">
        <article v-for="thread in threads" :key="thread.id" class="forum-thread-card" v-sfx-hover>
          <div class="forum-thread-top">
            <span v-if="thread.pinned" class="forum-pin">Pinned</span>
            <h3 class="forum-thread-title">{{ thread.title }}</h3>
          </div>
          <p class="forum-thread-snippet">{{ thread.snippet }}</p>
          <div class="forum-thread-meta">
            <span>{{ thread.author }}</span>
            <span>·</span>
            <span>{{ thread.replies }} {{ thread.replies === 1 ? 'reply' : 'replies' }}</span>
            <span>·</span>
            <span>{{ thread.lastActive }}</span>
          </div>
        </article>
      </section>
    </div>
  </main>
</template>

<script setup>
import { ref, computed } from 'vue';
import SecHead from '../components/SecHead.vue';
import MemberAuth from '../lib/member-auth.js';
import '../assets/css/pages/forums.css';

/* ═══════════════════════════════════════════════════════════════
   FRONT-END SHELL ONLY — there is no forum schema/RPCs yet (no
   threads/posts tables, nothing in supabase/). The composer below
   is fully interactive but doesn't persist anywhere; submitting
   just confirms what would happen once a backend exists, the same
   way this project already documents other "shape's built, wiring
   comes next" gaps in PROGRESS.md. Swap MOCK_THREADS and
   submitDraft() for real Supabase calls once that schema lands.
   ═══════════════════════════════════════════════════════════════ */

const isLoggedIn = computed(() => !!MemberAuth.sessionMember.value);

const threads = ref([
  {
    id: 1,
    pinned: true,
    title: 'Welcome new members — introduce yourself!',
    snippet: 'New to DMAC? Drop your name, year, and what kind of media you want to make.',
    author: 'Richmond P. Causaren',
    replies: 21,
    lastActive: '2h ago',
  },
  {
    id: 2,
    pinned: true,
    title: 'Show off your latest edit!',
    snippet: 'Photo, video, motion graphics — whatever you\'ve been working on this week.',
    author: 'Mark James C. Patnon',
    replies: 12,
    lastActive: '5h ago',
  },
  {
    id: 3,
    pinned: false,
    title: 'Anyone free to help film the fair this weekend?',
    snippet: 'Looking for 2-3 people with a camera or a phone that shoots decent 4K.',
    author: 'Jaywin Elson Cambalon',
    replies: 4,
    lastActive: '1d ago',
  },
]);

const composerOpen = ref(false);
const draftTitle = ref('');
const draftBody = ref('');
const composerStatus = ref('');

function submitDraft() {
  if (!draftTitle.value.trim()) {
    composerStatus.value = 'Give it a title first.';
    return;
  }
  // No backend to post to yet — see the note above. This just gives
  // honest feedback instead of silently doing nothing.
  composerStatus.value = 'Forums aren\'t connected to a backend yet, so this wasn\'t actually posted — but the form works and is ready to wire up.';
  draftTitle.value = '';
  draftBody.value = '';
}
</script>
