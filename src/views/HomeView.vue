<template>
  <!-- ════════════════════════════════ HERO ════════════════════════════════════ -->
  <!-- Photo slot up top, fading down into the DMAC name/logo banner, then into
       the rest of the page. This is the one page that keeps its own hero —
       every other page uses PageHero.vue instead (see that component). -->
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
       Announcements + Newsletters read like news articles now — a big
       side-scrolling row of cover-card teasers, tap one to read the full
       piece in ArticleModal. Events is a real calendar with marked days.
       Updates is a compact preview of the 3 latest changelog entries. -->
  <section class="home-section" v-reveal>
    <SecHead>Latest From DMAC</SecHead>

    <!-- Announcements -->
    <div class="news-row-block">
      <div class="news-row-head">
        <h3>Announcements</h3>
        <router-link to="/info/announcements" class="news-row-link">View all →</router-link>
      </div>
      <div class="news-scroll">
        <button
          v-for="a in announcementsFeed"
          :key="a.id"
          class="news-card"
          v-sfx-hover
          @click="openArticle(a, 'announcement')"
        >
          <div class="news-card-cover">
            <img v-if="a.cover_url" :src="a.cover_url" alt="" />
            <div v-else class="news-card-cover-placeholder tile-dark"></div>
          </div>
          <div class="news-card-body">
            <h4 class="news-card-title">{{ a.title }}</h4>
            <div class="news-card-meta">
              <span class="news-card-author">{{ a.author_name || 'DMAC' }}</span>
              <span class="news-card-dot">·</span>
              <time class="news-card-time">{{ formatDate(a.created_at) }}</time>
            </div>
            <p class="news-card-excerpt">{{ a.body }}</p>
          </div>
        </button>
        <p v-if="!loadingFeeds.announcement && !announcementsFeed.length" class="news-empty">No announcements yet.</p>
      </div>
    </div>

    <!-- Newsletters -->
    <div class="news-row-block">
      <div class="news-row-head">
        <h3>Newsletters</h3>
        <router-link to="/info/newsletters" class="news-row-link">Read the dev journal →</router-link>
      </div>
      <div class="news-scroll">
        <button
          v-for="n in newslettersFeed"
          :key="n.id"
          class="news-card"
          v-sfx-hover
          @click="openArticle(n, 'newsletter')"
        >
          <div class="news-card-cover">
            <img v-if="n.cover_url" :src="n.cover_url" alt="" />
            <div v-else class="news-card-cover-placeholder tile-dark"></div>
          </div>
          <div class="news-card-body">
            <h4 class="news-card-title">{{ n.title }}</h4>
            <div class="news-card-meta">
              <span class="news-card-author">{{ n.author_name || 'DMAC' }}</span>
              <span class="news-card-dot">·</span>
              <time class="news-card-time">{{ formatDate(n.created_at) }}</time>
            </div>
            <p class="news-card-excerpt">{{ n.body }}</p>
          </div>
        </button>
        <p v-if="!loadingFeeds.newsletter && !newslettersFeed.length" class="news-empty">No newsletter entries yet.</p>
      </div>
    </div>

    <!-- Events calendar -->
    <div class="events-block">
      <div class="news-row-head">
        <h3>Events</h3>
        <router-link to="/info/school-events" class="news-row-link">Full calendar →</router-link>
      </div>

      <div class="events-layout">
        <div class="calendar-card">
          <div class="calendar-nav">
            <button class="calendar-nav-btn" aria-label="Previous month" @click="prevMonth">‹</button>
            <strong>{{ monthLabel }}</strong>
            <button class="calendar-nav-btn" aria-label="Next month" @click="nextMonth">›</button>
          </div>
          <div class="calendar-weekdays">
            <span v-for="d in ['S','M','T','W','T','F','S']" :key="d">{{ d }}</span>
          </div>
          <div class="calendar-grid">
            <button
              v-for="cell in calendarCells"
              :key="cell.iso"
              type="button"
              class="calendar-cell"
              :class="{
                'is-out': !cell.inMonth,
                'is-today': cell.isToday,
                'has-event': cell.events.length,
                'is-selected': cell.iso === selectedDay,
              }"
              :disabled="!cell.events.length"
              @click="selectDay(cell)"
            >
              {{ cell.dayNum }}
              <span v-if="cell.events.length" class="calendar-dot"></span>
            </button>
          </div>

          <div v-if="selectedDayEvents.length" class="calendar-detail">
            <div v-for="e in selectedDayEvents" :key="e.id" class="calendar-detail-item">
              <strong>{{ e.title }}</strong>
              <span class="calendar-detail-countdown">{{ daysUntil(e.event_date) }}</span>
              <p v-if="e.location">{{ e.location }}</p>
            </div>
          </div>
        </div>

        <div class="events-upcoming">
          <p class="events-upcoming-label">Coming up</p>
          <button
            v-for="e in upcomingEvents"
            :key="e.id"
            type="button"
            class="events-upcoming-row"
            v-sfx-hover
            @click="selectedDay = e.event_date"
          >
            <span class="events-upcoming-date">{{ formatEventDate(e.event_date) }}</span>
            <span class="events-upcoming-title">{{ e.title }}</span>
          </button>
          <p v-if="!loadingFeeds.event && !upcomingEvents.length" class="news-empty">Nothing on the calendar yet.</p>
        </div>
      </div>
    </div>

    <!-- Updates preview -->
    <div class="updates-block">
      <div class="news-row-head">
        <h3>Updates</h3>
        <router-link to="/info/update-log" class="news-row-link">Full changelog →</router-link>
      </div>
      <ul class="updates-list">
        <li v-for="entry in latestUpdates" :key="entry.hash">
          <span class="updates-date">{{ entry.date }}</span>
          <span class="updates-title">{{ entry.title }}</span>
        </li>
      </ul>
    </div>
  </section>

  <ArticleModal v-if="activeArticle" :article="activeArticle" @close="activeArticle = null" />
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue';
import GradWrap from '../components/GradWrap.vue';
import SecHead from '../components/SecHead.vue';
import ArticleModal from '../components/ArticleModal.vue';
import { sb } from '../lib/supabase-client.js';
import { LOG_ENTRIES } from './info/UpdateLogView.vue';
import '../assets/css/pages/home.css';

/* ── ANNOUNCEMENTS + NEWSLETTERS — news-style scroll rows ─────────
   cover_url doesn't exist on either table yet (see the note in
   ArticleModal.vue) — each fetch tries WITH it first and falls back
   to without, same "optional column, retry on error" pattern
   lib/member-profile.js already uses elsewhere. The moment a real
   `cover_url text` column is added to `announcements` /
   `club_announcements`, this starts showing real photos with no code
   change needed. */
const announcementsFeed = ref([]);
const newslettersFeed = ref([]);
const loadingFeeds = reactive({ announcement: true, newsletter: true, event: true });
const activeArticle = ref(null);

async function fetchFeed(table, baseCols) {
  let { data, error } = await sb
    .from(table)
    .select(`${baseCols}, author_id, members!author_id(display_name), cover_url`)
    .order('created_at', { ascending: false })
    .limit(6);
  if (error) {
    ({ data, error } = await sb
      .from(table)
      .select(`${baseCols}, author_id, members!author_id(display_name)`)
      .order('created_at', { ascending: false })
      .limit(6));
  }
  if (error) console.error(`HomeView: could not load ${table} —`, error.message);
  return (data || []).map((row) => ({ ...row, author_name: row.members?.display_name || null }));
}

function openArticle(item, type) {
  activeArticle.value = { ...item, type };
}

function formatDate(dateStr) {
  return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

/* ── EVENTS — real calendar, marked days, click-through countdown ── */
const today = new Date();
const calYear = ref(today.getFullYear());
const calMonth = ref(today.getMonth());
const allEvents = ref([]);
const eventsByDate = ref({});
const selectedDay = ref(null);

function pad2(n) { return String(n).padStart(2, '0'); }
function isoDate(d) { return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`; }
const todayIso = isoDate(new Date());

async function loadEvents() {
  const { data, error } = await sb
    .from('school_events')
    .select('id, title, description, location, event_date')
    .order('event_date', { ascending: true });

  loadingFeeds.event = false;
  if (error) {
    console.error('HomeView: could not load school events —', error.message);
    return;
  }
  allEvents.value = data || [];
  const map = {};
  for (const e of allEvents.value) {
    (map[e.event_date] ||= []).push(e);
  }
  eventsByDate.value = map;
}

const monthLabel = computed(() =>
  new Date(calYear.value, calMonth.value, 1).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })
);

const calendarCells = computed(() => {
  const firstWeekday = new Date(calYear.value, calMonth.value, 1).getDay();
  const daysInMonth = new Date(calYear.value, calMonth.value + 1, 0).getDate();
  const totalCells = Math.ceil((firstWeekday + daysInMonth) / 7) * 7;
  const cells = [];
  for (let i = 0; i < totalCells; i++) {
    const date = new Date(calYear.value, calMonth.value, i - firstWeekday + 1);
    const iso = isoDate(date);
    cells.push({
      iso,
      dayNum: date.getDate(),
      inMonth: date.getMonth() === calMonth.value,
      isToday: iso === todayIso,
      events: eventsByDate.value[iso] || [],
    });
  }
  return cells;
});

const selectedDayEvents = computed(() => (selectedDay.value ? eventsByDate.value[selectedDay.value] || [] : []));
const upcomingEvents = computed(() => allEvents.value.filter((e) => e.event_date >= todayIso).slice(0, 6));

function selectDay(cell) {
  if (!cell.events.length) return;
  selectedDay.value = cell.iso;
}

function daysUntil(iso) {
  const target = new Date(`${iso}T00:00:00`);
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  const diff = Math.round((target - now) / 86400000);
  if (diff === 0) return 'Today!';
  if (diff < 0) return `${Math.abs(diff)} day${Math.abs(diff) === 1 ? '' : 's'} ago`;
  return `In ${diff} day${diff === 1 ? '' : 's'}`;
}

function prevMonth() {
  if (calMonth.value === 0) { calMonth.value = 11; calYear.value -= 1; } else { calMonth.value -= 1; }
  selectedDay.value = null;
}
function nextMonth() {
  if (calMonth.value === 11) { calMonth.value = 0; calYear.value += 1; } else { calMonth.value += 1; }
  selectedDay.value = null;
}
function formatEventDate(dateStr) {
  return new Date(`${dateStr}T00:00:00Z`).toLocaleDateString('en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' });
}

/* ── UPDATES — 3 most recent entries, reusing UpdateLogView's own
   LOG_ENTRIES export rather than a second copy of the same data. ── */
const latestUpdates = LOG_ENTRIES.slice(0, 3);

onMounted(async () => {
  const [announcements, newsletters] = await Promise.all([
    fetchFeed('club_announcements', 'id, title, body, created_at'),
    fetchFeed('announcements', 'id, title, body, kind, created_at'),
  ]);
  announcementsFeed.value = announcements;
  newslettersFeed.value = newsletters;
  loadingFeeds.announcement = false;
  loadingFeeds.newsletter = false;

  loadEvents();
});
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
.hero-banner-logo { width: 84px; height: 84px; flex-shrink: 0; }
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
  .hero-banner { flex-direction: row; text-align: left; gap: 26px; }
}

/* ── LATEST-FROM-DMAC ROW HEADS ────────────────────────────────── */
.news-row-block,
.events-block,
.updates-block {
  margin-top: 28px;
}
.news-row-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
}
.news-row-head h3 {
  font-family: var(--font);
  font-size: 1.05rem;
  color: rgba(240, 240, 240, 0.92);
}
.news-row-link {
  font-size: 0.8rem;
  color: var(--orange);
  white-space: nowrap;
}

/* ── NEWS SCROLL ROW — big, side-scrolling article teasers ───────── */
.news-scroll {
  display: flex;
  gap: 16px;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  padding-bottom: 6px;
  scrollbar-width: thin;
}
.news-card {
  flex: 0 0 auto;
  scroll-snap-align: start;
  width: 320px;
  display: flex;
  flex-direction: column;
  text-align: left;
  border-radius: 20px;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.03);
  cursor: pointer;
  font: inherit;
  color: inherit;
  padding: 0;
  transition: transform 0.2s ease, border-color 0.2s ease;
}
.news-card:hover {
  transform: translateY(-3px);
  border-color: rgba(249, 115, 22, 0.45);
}
.news-card-cover { width: 100%; height: 160px; overflow: hidden; }
.news-card-cover img { width: 100%; height: 100%; object-fit: cover; display: block; }
.news-card-cover-placeholder { width: 100%; height: 100%; opacity: 0.6; }
.news-card-body { padding: 16px 18px 18px; display: flex; flex-direction: column; gap: 8px; }
.news-card-title { margin: 0; font-family: var(--font); font-size: 1rem; line-height: 1.3; }
.news-card-meta {
  display: flex;
  align-items: baseline;
  gap: 6px;
  font-size: 0.74rem;
  color: rgba(240, 240, 240, 0.5);
}
.news-card-author { color: var(--orange); }
.news-card-dot { color: rgba(240, 240, 240, 0.3); }
.news-card-excerpt {
  margin: 0;
  color: rgba(240, 240, 240, 0.68);
  font-size: 0.85rem;
  line-height: 1.5;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.news-card-time { font-size: 0.72rem; color: rgba(240, 240, 240, 0.42); }
.news-empty { color: rgba(240, 240, 240, 0.5); font-size: 0.87rem; }

/* ── CALENDAR ───────────────────────────────────────────────────── */
.events-layout {
  display: grid;
  grid-template-columns: minmax(0, 380px) minmax(0, 1fr);
  gap: 20px;
  align-items: start;
}
.calendar-card {
  border-radius: 20px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.03);
  padding: 16px;
}
.calendar-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
  font-family: var(--font);
}
.calendar-nav-btn {
  width: 28px; height: 28px;
  border-radius: 50%;
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(255, 255, 255, 0.04);
  color: #fff;
  cursor: pointer;
  font-size: 1rem;
}
.calendar-weekdays,
.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
}
.calendar-weekdays span {
  text-align: center;
  font-size: 0.66rem;
  color: rgba(240, 240, 240, 0.45);
  padding-bottom: 6px;
}
.calendar-cell {
  position: relative;
  aspect-ratio: 1;
  border: none;
  background: transparent;
  color: rgba(240, 240, 240, 0.75);
  font-size: 0.8rem;
  cursor: default;
  border-radius: 8px;
}
.calendar-cell.is-out { color: rgba(240, 240, 240, 0.22); }
.calendar-cell.is-today { border: 1px solid rgba(249, 115, 22, 0.6); }
.calendar-cell.has-event { cursor: pointer; color: #fff; background: rgba(249, 115, 22, 0.1); }
.calendar-cell.has-event:hover { background: rgba(249, 115, 22, 0.2); }
.calendar-cell.is-selected { background: rgba(249, 115, 22, 0.32); }
.calendar-dot {
  position: absolute;
  bottom: 4px; left: 50%;
  transform: translateX(-50%);
  width: 4px; height: 4px;
  border-radius: 50%;
  background: var(--orange);
}
.calendar-detail {
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.calendar-detail-item strong { display: block; font-size: 0.9rem; }
.calendar-detail-countdown { font-size: 0.76rem; color: var(--orange); }
.calendar-detail-item p { margin: 2px 0 0; font-size: 0.78rem; color: rgba(240, 240, 240, 0.6); }

.events-upcoming {
  border-radius: 20px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.03);
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.events-upcoming-label {
  font-size: 0.7rem;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: rgba(240, 240, 240, 0.5);
  margin-bottom: 6px;
}
.events-upcoming-row {
  display: flex;
  align-items: baseline;
  gap: 10px;
  padding: 8px 6px;
  border-radius: 10px;
  background: none;
  border: none;
  text-align: left;
  cursor: pointer;
  color: inherit;
  font: inherit;
}
.events-upcoming-row:hover { background: rgba(255, 255, 255, 0.05); }
.events-upcoming-date { font-size: 0.72rem; color: var(--orange); white-space: nowrap; }
.events-upcoming-title { font-size: 0.86rem; }

@media (max-width: 780px) {
  .events-layout { grid-template-columns: 1fr; }
}

/* ── UPDATES PREVIEW ────────────────────────────────────────────── */
.updates-list { list-style: none; display: flex; flex-direction: column; gap: 2px; }
.updates-list li {
  display: flex;
  gap: 12px;
  align-items: baseline;
  padding: 10px 4px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  font-size: 0.86rem;
}
.updates-date { color: rgba(240, 240, 240, 0.45); font-size: 0.74rem; white-space: nowrap; }
.updates-title { color: rgba(240, 240, 240, 0.85); }
</style>
