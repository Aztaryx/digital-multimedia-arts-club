<template>
  <main>
    <div class="page-section reveal" v-reveal>
      <SecHead>Leaderboard</SecHead>

      <!-- Countdown/Teaser before September 1, 2026 -->
      <div v-if="isCountdown" class="leaderboard-teaser">

        <!-- Mystery podium silhouette — glowing, blurred, pulsing -->
        <div class="teaser-podium" aria-hidden="true">
          <div class="podium-block podium-block--2"></div>
          <div class="podium-block podium-block--1">
            <span class="podium-mystery">?</span>
          </div>
          <div class="podium-block podium-block--3"></div>
        </div>

        <!-- Floating sparkle field -->
        <div class="teaser-sparkle-field" aria-hidden="true">
          <span
            v-for="(s, i) in sparkles"
            :key="i"
            class="teaser-sparkle"
            :style="s.style"
          >◆</span>
        </div>

        <!-- Sweeping light beam -->
        <div class="teaser-scanbeam" aria-hidden="true"></div>

        <div class="teaser-content">
          <span class="teaser-pill"><span class="teaser-pill-dot"></span>sneak peek incoming</span>

          <p class="leaderboard-teaser-lead">
            <GradWrap ref="leadWrapRef">Leaderboard launches {{ revealDateLabel }}</GradWrap>
          </p>

          <div class="countdown">
            <div class="countdown-item">
              <span class="number">{{ pad(countdown.days) }}</span>
              <span class="label">days</span>
            </div>
            <div class="countdown-item">
              <span class="number">{{ pad(countdown.hours) }}</span>
              <span class="label">hours</span>
            </div>
            <div class="countdown-item">
              <span class="number">{{ pad(countdown.minutes) }}</span>
              <span class="label">minutes</span>
            </div>
            <div class="countdown-item countdown-item--seconds">
              <span class="number number--seconds" :class="{ 'is-ticking': secondsTicking }">{{ pad(countdown.seconds) }}</span>
              <span class="label">seconds</span>
            </div>
          </div>

          <p class="teaser-subtext">something's about to drop…</p>
        </div>
      </div>

      <!-- Main leaderboard view (after reveal date) -->
      <div v-else class="leaderboard-content">
        <div class="lb-tabs" role="tablist">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            type="button"
            class="lb-tab-btn"
            :class="{ active: activeTab === tab.id }"
            role="tab"
            :aria-selected="activeTab === tab.id"
            v-sfx-hover
            @click="activeTab = tab.id"
          >{{ tab.label }}</button>
        </div>

        <!-- Threads Leaderboard (primary) -->
        <div v-if="activeTab === 'threads'" class="lb-tab-panel">
          <h3 class="lb-panel-title">Threads Ranking (90-day Composite)</h3>
          <div class="lb-table-wrap">
            <table class="lb-table">
              <thead>
                <tr>
                  <th>Rank</th>
                  <th>Member</th>
                  <th>Score</th>
                  <th>Ping</th>
                  <th>Bandwidth</th>
                  <th>FLOPS</th>
                  <th>Commits</th>
                  <th>Hertz</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(entry, idx) in threadsData" :key="entry.id">
                  <td>{{ idx + 1 }}</td>
                  <td><router-link :to="`/profile?member=${entry.slug}`">{{ entry.name }}</router-link></td>
                  <td class="lb-score">{{ entry.score }}</td>
                  <td>{{ entry.ping }}</td>
                  <td>{{ entry.bandwidth }}</td>
                  <td>{{ entry.flops }}</td>
                  <td>{{ entry.commits }}</td>
                  <td>{{ entry.hertz }}</td>
                </tr>
                <tr v-if="!threadsData.length">
                  <td colspan="8" class="lb-empty">No Threads data yet.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Badge Leaderboards -->
        <div v-if="activeTab === 'badges'" class="lb-tab-panel">
          <h3 class="lb-panel-title">Badge Rankings</h3>
          <div class="lb-badge-selector">
            <select class="lb-select" v-model="selectedBadge">
              <option v-for="badge in availableBadges" :key="badge" :value="badge">{{ badge }}</option>
            </select>
          </div>
          <div class="lb-table-wrap">
            <table class="lb-table">
              <thead>
                <tr>
                  <th>Rank</th>
                  <th>Member</th>
                  <th>Value</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(entry, idx) in badgeData" :key="entry.id ?? entry.member_id">
                  <td>{{ idx + 1 }}</td>
                  <td>{{ entry.name }}</td>
                  <td>{{ entry.value }}</td>
                </tr>
                <tr v-if="!badgeData.length">
                  <td colspan="3" class="lb-empty">No data for this badge yet.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Per-Factor Views -->
        <div v-if="activeTab === 'factors'" class="lb-tab-panel">
          <h3 class="lb-panel-title">Individual Factors</h3>
          <div class="lb-factor-grid">
            <div v-for="factor in factors" :key="factor" class="lb-factor-card">
              <h4>{{ factor }}</h4>
              <table class="lb-factor-table">
                <tbody>
                  <tr v-for="(entry, idx) in (factorData[factor] || [])" :key="entry.id ?? entry.member_id">
                    <td>{{ idx + 1 }}.</td>
                    <td>{{ entry.name }}</td>
                    <td>{{ entry.value }}</td>
                  </tr>
                  <tr v-if="!(factorData[factor] || []).length">
                    <td colspan="3" class="lb-empty">No data yet.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>

<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import SecHead from '../components/SecHead.vue';
import GradWrap from '../components/GradWrap.vue';
import { sb } from '../lib/supabase-client.js';
import { scrambleGradWrap } from '../lib/animations.js';
import { playSfx } from '../composables/useSfx.js';
import '../assets/css/pages/leaderboard.css';

/* Reveal gate per dmac-consolidated-plan.md §8 — Sept 1, 2026. Before
   that, a countdown/teaser shows in place of real standings.

   Flashier pass: seconds now tick (was minutes-only), the seconds
   digit punches on every tick, a glowing "mystery podium" silhouette
   + floating sparkles + a sweeping light beam sit behind the content,
   and the headline periodically glitch-scrambles via the
   scrambleGradWrap() effect that already existed in lib/animations.js
   but had no caller anywhere in the app until now. */
const revealDate = new Date(2026, 8, 1); // month is 0-indexed — 8 = September
const revealDateLabel = revealDate.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });

const activeTab = ref('threads');
const selectedBadge = ref(null);

const tabs = [
  { id: 'threads', label: 'Threads' },
  { id: 'badges', label: 'Badges' },
  { id: 'factors', label: 'Factors' },
];

const factors = ['Ping', 'Bandwidth', 'FLOPS', 'Commits', 'Hertz'];

const countdown = ref({ days: 0, hours: 0, minutes: 0, seconds: 0 });
const threadsData = ref([]);
const badgeScoresByBadge = ref({}); // { badge_id: [entry, ...] }
const availableBadges = ref([]);
const factorData = ref({});

const badgeData = computed(() => badgeScoresByBadge.value[selectedBadge.value] || []);

const isCountdown = computed(() => new Date() < revealDate);

function pad(n) {
  return String(n).padStart(2, '0');
}

let countdownTimer = null;
let scrambleTimer = null;

// Restarts on every tick (see updateCountdown) — same "clear the class,
// wait a frame, re-add it" reflow trick UpdateLogView.vue's flash()
// uses to let a CSS animation replay on rapid repeats, applied here
// to the seconds digit so it visibly punches once per second.
const secondsTicking = ref(false);

const leadWrapRef = ref(null);

const sparkles = ref([]);
function generateSparkles(count = 16) {
  const arr = [];
  for (let i = 0; i < count; i++) {
    arr.push({
      style: {
        left: `${(Math.random() * 100).toFixed(1)}%`,
        top: `${(Math.random() * 100).toFixed(1)}%`,
        animationDelay: `${(Math.random() * 6).toFixed(2)}s`,
        animationDuration: `${(3 + Math.random() * 3).toFixed(2)}s`,
        fontSize: `${(8 + Math.random() * 10).toFixed(0)}px`,
      },
    });
  }
  sparkles.value = arr;
}

onMounted(() => {
  updateCountdown();
  countdownTimer = setInterval(updateCountdown, 1000);

  if (isCountdown.value) {
    generateSparkles();
    playSfx('mmstart'); // one-time entrance chime — "get ready" cue
    scrambleTimer = setInterval(() => {
      if (leadWrapRef.value?.$el) scrambleGradWrap(leadWrapRef.value.$el);
    }, 7000);
  } else {
    loadLeaderboardData();
  }
});

onBeforeUnmount(() => {
  if (countdownTimer) clearInterval(countdownTimer);
  if (scrambleTimer) clearInterval(scrambleTimer);
});

function updateCountdown() {
  const now = new Date();
  const diff = revealDate - now;

  if (diff <= 0) {
    countdown.value = { days: 0, hours: 0, minutes: 0, seconds: 0 };
    return;
  }

  const days = Math.floor(diff / (1000 * 60 * 60 * 24));
  const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
  const seconds = Math.floor((diff % (1000 * 60)) / 1000);

  countdown.value = { days, hours, minutes, seconds };

  secondsTicking.value = false;
  requestAnimationFrame(() => { secondsTicking.value = true; });
}

async function loadLeaderboardData() {
  try {
    const { data: threads, error: threadsError } = await sb
      .from('threads')
      .select(`
        id,
        member_id,
        score,
        ping_factor,
        bandwidth_factor,
        flops_factor,
        commits_factor,
        hertz_factor,
        members!inner(id, display_name, slug)
      `)
      .order('score', { ascending: false })
      .limit(100);

    if (!threadsError && threads) {
      threadsData.value = threads.map((t) => ({
        id: t.id,
        member_id: t.member_id,
        score: Number(t.score).toFixed(2),
        ping: Number(t.ping_factor).toFixed(2),
        bandwidth: Number(t.bandwidth_factor).toFixed(2),
        flops: Number(t.flops_factor).toFixed(2),
        commits: Number(t.commits_factor).toFixed(2),
        hertz: Number(t.hertz_factor).toFixed(2),
        name: t.members?.display_name || 'Anonymous',
        slug: t.members?.slug || 'unknown',
      }));
    } else if (threadsError) {
      console.error('LeaderboardView: could not load threads —', threadsError.message);
    }

    const { data: badgeScores, error: badgesError } = await sb
      .from('scores')
      .select('badge_id, member_id, value, members!member_id(display_name, slug)')
      .order('badge_id', { ascending: true })
      .order('value', { ascending: false });

    if (!badgesError && badgeScores) {
      const badgeSet = new Set(badgeScores.map((s) => s.badge_id));
      availableBadges.value = Array.from(badgeSet).sort();
      if (availableBadges.value.length > 0 && !selectedBadge.value) {
        selectedBadge.value = availableBadges.value[0];
      }

      const byBadge = {};
      badgeScores.forEach((entry) => {
        if (!byBadge[entry.badge_id]) byBadge[entry.badge_id] = [];
        byBadge[entry.badge_id].push({
          member_id: entry.member_id,
          name: entry.members?.display_name || 'Anonymous',
          slug: entry.members?.slug || 'unknown',
          value: Math.round(entry.value),
        });
      });
      badgeScoresByBadge.value = byBadge;
    } else if (badgesError) {
      console.error('LeaderboardView: could not load badge scores —', badgesError.message);
    }

    const { data: ratings, error: ratingsError } = await sb
      .from('member_domain_ratings')
      .select(`
        domain_arts, domain_multimedia, domain_digital,
        member_id,
        members!inner(display_name, slug)
      `);

    if (!ratingsError && ratings) {
      const domainToFactor = { domain_arts: 'Ping', domain_multimedia: 'Bandwidth', domain_digital: 'FLOPS' };
      const grouped = { Ping: [], Bandwidth: [], FLOPS: [], Commits: [], Hertz: [] };

      for (const r of ratings) {
        for (const [col, factor] of Object.entries(domainToFactor)) {
          grouped[factor].push({
            member_id: r.member_id,
            name: r.members?.display_name || 'Anonymous',
            slug: r.members?.slug || 'unknown',
            value: r[col] != null ? Number(r[col]).toFixed(1) : '0.0',
          });
        }
      }
      for (const factor of Object.keys(grouped)) {
        grouped[factor].sort((a, b) => Number(b.value) - Number(a.value));
        grouped[factor] = grouped[factor].slice(0, 50);
      }
      factorData.value = grouped;
    } else if (ratingsError) {
      console.error('LeaderboardView: could not load Bits ratings —', ratingsError.message);
    }
  } catch (err) {
    console.error('LeaderboardView: failed to load leaderboard data —', err.message || err);
  }
}
</script>