<template>
  <!-- ════════════════════════════════ HERO ════════════════════════════════════ -->
  <!-- Photo slot up top, fading down into the DMAC name/logo banner, then into
       the rest of the page. Replaces the old 3-panel D/M/A split hero. The slot
       below is intentionally empty — drop a real <img> (or a background-image)
       into .hero-image-slot once a landscape photo has a home in dmac-assets;
       tile-dark (global.css) is just a neutral placeholder texture until then. -->
  <section id="hero" class="hero-v2">
    <div class="hero-image-slot tile-dark" aria-hidden="true">
      <div class="hero-fade"></div>
    </div>

    <div class="hero-banner animate-in">
      <img class="hero-banner-logo" src="https://aztaryx.github.io/dmac-assets/logo.png" alt="DMAC" />
      <div class="hero-banner-copy">
        <GradWrap class="hero-banner-title">Digital Multimedia Arts Club</GradWrap>
        <p class="hero-banner-tag">Coverage &bull; Creativity &bull; Community</p>
      </div>
    </div>
  </section>

  <!-- ════════════════════════════════ WELCOME ════════════════════════════════ -->
  <section class="home-section" v-reveal>
    <SecHead>Welcome to DMAC</SecHead>
    <p class="home-lead">
      Welcome to DMAC! We're the team behind the camera and the caption — the
      students who show up at school events to record them, edit the footage
      and photos, and post the finished coverage for everyone to see. No
      experience needed, no pressure to be "good" yet. We meet regularly to
      cover events together, learn from each other, and share what we've made.
      If you've ever wondered who's filming at assemblies or editing the recap
      videos afterward, that's us — and we're looking for more people to join in.
    </p>
  </section>

  <!-- ════════════════════════════════ WHAT WE DO ═══════════════════════════════ -->
  <section class="home-section" v-reveal>
    <SecHead>What We Do</SecHead>
    <div class="wwd-grid">
      <div class="wwd-card" v-sfx-hover>
        <h3>Event Coverage</h3>
        <p>Filming and shooting photos at assemblies, competitions, and school activities.</p>
      </div>
      <div class="wwd-card" v-sfx-hover>
        <h3>Video Editing</h3>
        <p>Turning raw footage into recap videos, highlight reels, and clips worth posting.</p>
      </div>
      <div class="wwd-card" v-sfx-hover>
        <h3>Graphic Design</h3>
        <p>Posters, announcement graphics, and thumbnails for everything we post.</p>
      </div>
      <div class="wwd-card" v-sfx-hover>
        <h3>Photography</h3>
        <p>Photo walks during events and picking the shots that tell the story.</p>
      </div>
      <div class="wwd-card" v-sfx-hover>
        <h3>Posting &amp; Socials</h3>
        <p>Getting the finished coverage out on our Facebook page — and eventually this website.</p>
      </div>
    </div>
  </section>

  <!-- ════════════════════════════════ WHY JOIN ═════════════════════════════════ -->
  <section class="home-section" v-reveal>
    <SecHead>Why Join DMAC</SecHead>
    <div class="why-grid">
      <div class="why-item">
        <h3>No experience required</h3>
        <p>We teach the tools as we go — camera work, editing software, or design programs. Show up curious, leave with skills.</p>
      </div>
      <div class="why-item">
        <h3>Build a real portfolio</h3>
        <p>Work on coverage you can point to later, for college applications, job applications, or just to have something to show for your time.</p>
      </div>
      <div class="why-item">
        <h3>Shared tools &amp; resources</h3>
        <p>Members pitch in cameras, drives, cables, and software tips so everyone has what they need to cover an event.</p>
      </div>
      <div class="why-item">
        <h3>Hands-on, not just talk</h3>
        <p>Meetings are built around actually covering events, not sitting through slides.</p>
      </div>
      <div class="why-item">
        <h3>Find your people</h3>
        <p>Work alongside other students into the same stuff, at whatever level you're at.</p>
      </div>
      <div class="why-item">
        <h3>Get your work seen</h3>
        <p>Every post, recap video, and event poster is your work — seen by the whole school.</p>
      </div>
    </div>
    <p class="home-teaser">
      Want to get better at a specific part of coverage — more photography, more
      motion graphics, running our socials? Let us know; the club's direction
      follows what members want to get sharper at.
    </p>
  </section>

  <!-- ════════════════════════════ LATEST FROM DMAC ═══════════════════════════
       Replaces the old static Quick Links grid — these four cards pull real,
       live content (Announcements / Newsletters / School Events), plus a
       static teaser card for the Update Log, which has no live table behind
       it (see info/UpdateLogView.vue's hardcoded LOG_ENTRIES). -->
  <section class="home-section" v-reveal>
    <SecHead>Latest From DMAC</SecHead>
    <div class="latest-grid">

      <router-link to="/info/announcements" class="latest-card" v-sfx-hover>
        <span class="latest-card-tag latest-card-tag--orange">Announcements</span>
        <template v-if="loadingLatest.announcement">
          <p class="latest-card-empty">Loading…</p>
        </template>
        <template v-else-if="latestAnnouncement">
          <h3 class="latest-card-title">{{ latestAnnouncement.title }}</h3>
          <p class="latest-card-excerpt">{{ latestAnnouncement.body }}</p>
          <time class="latest-card-time">{{ formatDate(latestAnnouncement.created_at) }}</time>
        </template>
        <p v-else class="latest-card-empty">No announcements yet — check back soon.</p>
        <span class="latest-card-arrow">View all announcements →</span>
      </router-link>

      <router-link to="/info/newsletters" class="latest-card" v-sfx-hover>
        <span class="latest-card-tag latest-card-tag--rose">Newsletters</span>
        <template v-if="loadingLatest.newsletter">
          <p class="latest-card-empty">Loading…</p>
        </template>
        <template v-else-if="latestNewsletter">
          <h3 class="latest-card-title">{{ latestNewsletter.title }}</h3>
          <p class="latest-card-excerpt">{{ latestNewsletter.body }}</p>
          <time class="latest-card-time">{{ formatDate(latestNewsletter.created_at) }}</time>
        </template>
        <p v-else class="latest-card-empty">No newsletter entries yet.</p>
        <span class="latest-card-arrow">Read the dev journal →</span>
      </router-link>

      <router-link to="/info/school-events" class="latest-card" v-sfx-hover>
        <span class="latest-card-tag latest-card-tag--violet">Events</span>
        <template v-if="loadingLatest.event">
          <p class="latest-card-empty">Loading…</p>
        </template>
        <template v-else-if="nextEvent">
          <h3 class="latest-card-title">{{ nextEvent.title }}</h3>
          <p class="latest-card-excerpt">{{ nextEvent.location || 'Location TBA' }}</p>
          <time class="latest-card-time">{{ formatEventDate(nextEvent.event_date) }}</time>
        </template>
        <p v-else class="latest-card-empty">Nothing on the calendar yet.</p>
        <span class="latest-card-arrow">See all school events →</span>
      </router-link>

      <router-link to="/info/update-log" class="latest-card" v-sfx-hover>
        <span class="latest-card-tag latest-card-tag--purple">Updates</span>
        <h3 class="latest-card-title">Site &amp; project changelog</h3>
        <p class="latest-card-excerpt">Every commit that's shipped to this site, newest first — see exactly what changed and when.</p>
        <span class="latest-card-arrow">View the update log →</span>
      </router-link>

    </div>
  </section>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue';
import GradWrap from '../components/GradWrap.vue';
import SecHead from '../components/SecHead.vue';
import { sb } from '../lib/supabase-client.js';
import '../assets/css/pages/home.css';

/* ── LATEST-CONTENT PREVIEW CARDS ─────────────────────────────────
   One row read from each of the three live tables — small, cheap
   queries (limit 1), fired in parallel on mount. Update Log has no
   live table (see info/UpdateLogView.vue's hardcoded LOG_ENTRIES), so
   that card is static copy + a link rather than a fetched excerpt. */
const latestAnnouncement = ref(null);
const latestNewsletter = ref(null);
const nextEvent = ref(null);
const loadingLatest = reactive({ announcement: true, newsletter: true, event: true });

onMounted(async () => {
  const [annRes, nlRes, evRes] = await Promise.all([
    sb.from('club_announcements')
      .select('id, title, body, created_at')
      .order('created_at', { ascending: false })
      .limit(1),
    sb.from('announcements')
      .select('id, title, body, kind, created_at')
      .order('created_at', { ascending: false })
      .limit(1),
    sb.from('school_events')
      .select('id, title, location, event_date')
      .gte('event_date', new Date().toISOString().split('T')[0])
      .order('event_date', { ascending: true })
      .limit(1),
  ]);

  if (annRes.error) console.error('HomeView: could not load latest announcement —', annRes.error.message);
  else latestAnnouncement.value = annRes.data?.[0] || null;
  loadingLatest.announcement = false;

  if (nlRes.error) console.error('HomeView: could not load latest newsletter —', nlRes.error.message);
  else latestNewsletter.value = nlRes.data?.[0] || null;
  loadingLatest.newsletter = false;

  if (evRes.error) console.error('HomeView: could not load next event —', evRes.error.message);
  else nextEvent.value = evRes.data?.[0] || null;
  loadingLatest.event = false;
});

function formatDate(dateStr) {
  return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}
function formatEventDate(dateStr) {
  return new Date(`${dateStr}T00:00:00Z`).toLocaleDateString('en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' });
}
</script>

<style scoped>
/* ── HERO V2 — empty photo slot fading into the name banner ───────── */
.hero-v2 {
  position: relative;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: var(--bg, #0d0d0d);
}

.hero-image-slot {
  position: relative;
  min-height: 46vh;
  overflow: hidden;
}

.hero-fade {
  position: absolute;
  inset: 0;
  background: linear-gradient(180deg, transparent 45%, rgba(13, 13, 13, 0.6) 78%, var(--bg, #0d0d0d) 100%);
  pointer-events: none;
}

.hero-banner {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 18px;
  justify-content: center;
  text-align: center;
  padding: 36px 24px 64px;
  background: var(--bg, #0d0d0d);
}
.hero-banner-logo {
  width: 84px;
  height: 84px;
  flex-shrink: 0;
}
.hero-banner-title {
  font-family: var(--font);
  font-weight: 700;
  font-size: clamp(1.7rem, 4.2vw, 3rem);
  line-height: 1.1;
}
.hero-banner-tag {
  margin: 8px 0 0;
  color: var(--muted, rgba(240, 240, 240, 0.6));
  letter-spacing: 0.1em;
  text-transform: uppercase;
  font-size: 0.78rem;
}

@media (min-width: 720px) {
  .hero-banner {
    flex-direction: row;
    text-align: left;
    gap: 26px;
  }
}

/* ── LATEST-FROM-DMAC GRID ────────────────────────────────────────── */
.latest-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 18px;
}

.latest-card {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 20px;
  border-radius: 20px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.03);
  text-decoration: none;
  color: inherit;
  transition: transform 0.2s ease, border-color 0.2s ease;
}
.latest-card:hover {
  transform: translateY(-3px);
  border-color: rgba(249, 115, 22, 0.45);
}

.latest-card-tag {
  align-self: flex-start;
  font-size: 0.66rem;
  font-family: var(--font);
  letter-spacing: 0.1em;
  text-transform: uppercase;
  padding: 4px 10px;
  border-radius: 999px;
}
/* Only --orange and --purple actually exist in global.css — the
   other two tags reuse the mid-gradient stops from #footer's own
   background (rose #d65c6a, violet #6a2aa6) so every accent color on
   this page traces back to a color already established on the site,
   rather than inventing a new one. */
.latest-card-tag--orange { background: rgba(249, 115, 22, 0.16); color: var(--orange); }
.latest-card-tag--rose   { background: rgba(214, 92, 106, 0.18); color: #e08792; }
.latest-card-tag--violet { background: rgba(106, 42, 166, 0.2);  color: #a978d6; }
.latest-card-tag--purple { background: rgba(76, 29, 149, 0.22);  color: #9f7ae0; }

.latest-card-title {
  margin: 0;
  font-family: var(--font);
  font-size: 1.02rem;
  line-height: 1.3;
}
.latest-card-excerpt {
  margin: 0;
  color: rgba(240, 240, 240, 0.68);
  font-size: 0.87rem;
  line-height: 1.55;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.latest-card-time {
  font-size: 0.72rem;
  color: rgba(240, 240, 240, 0.42);
}
.latest-card-empty {
  margin: 0;
  color: rgba(240, 240, 240, 0.5);
  font-size: 0.87rem;
}
.latest-card-arrow {
  margin-top: auto;
  padding-top: 4px;
  font-size: 0.8rem;
  color: var(--orange, #f97316);
}
</style>