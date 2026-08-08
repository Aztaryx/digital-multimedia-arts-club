<template>
  <div class="view leaderboard-view">
    <SecHead title="Leaderboard" subtitle="Member rankings & performance" />

    <!-- Countdown/Teaser before September 1, 2026 -->
    <div v-if="isCountdown" class="leaderboard-teaser">
      <p>Leaderboard launches {{ revealDate }}</p>
      <div class="countdown">
        <div class="countdown-item">
          <span class="number">{{ countdown.days }}</span>
          <span class="label">days</span>
        </div>
        <div class="countdown-item">
          <span class="number">{{ countdown.hours }}</span>
          <span class="label">hours</span>
        </div>
        <div class="countdown-item">
          <span class="number">{{ countdown.minutes }}</span>
          <span class="label">minutes</span>
        </div>
      </div>
    </div>

    <!-- Main leaderboard view (after reveal date) -->
    <div v-else class="leaderboard-content">
      <div class="tabs">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          :class="['tab-btn', { active: activeTab === tab.id }]"
          @click="activeTab = tab.id"
        >
          {{ tab.label }}
        </button>
      </div>

      <!-- Threads Leaderboard (primary) -->
      <div v-show="activeTab === 'threads'" class="tab-content">
        <h3>Threads Ranking (90-day Composite)</h3>
        <table class="leaderboard-table">
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
              <td class="score">{{ entry.score }}</td>
              <td>{{ entry.ping }}</td>
              <td>{{ entry.bandwidth }}</td>
              <td>{{ entry.flops }}</td>
              <td>{{ entry.commits }}</td>
              <td>{{ entry.hertz }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Badge Leaderboards -->
      <div v-show="activeTab === 'badges'" class="tab-content">
        <h3>Badge Rankings</h3>
        <div class="badge-selector">
          <select v-model="selectedBadge">
            <option v-for="badge in availableBadges" :key="badge" :value="badge">
              {{ badge }}
            </option>
          </select>
        </div>
        <table class="leaderboard-table">
          <thead>
            <tr>
              <th>Rank</th>
              <th>Member</th>
              <th>Value</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(entry, idx) in badgeData" :key="entry.id">
              <td>{{ idx + 1 }}</td>
              <td>{{ entry.name }}</td>
              <td>{{ entry.value }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Per-Factor Views -->
      <div v-show="activeTab === 'factors'" class="tab-content">
        <h3>Individual Factors</h3>
        <div class="factor-grid">
          <div v-for="factor in factors" :key="factor" class="factor-card">
            <h4>{{ factor }}</h4>
            <table class="factor-table">
              <tbody>
                <tr v-for="(entry, idx) in factorData[factor]" :key="entry.id">
                  <td>{{ idx + 1 }}.</td>
                  <td>{{ entry.name }}</td>
                  <td>{{ entry.value }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import SecHead from '../components/SecHead.vue';
import { supabase } from '../lib/supabase-client.js';

const revealDate = new Date(2026, 8, 1); // Sept 1, 2026
const activeTab = ref('threads');
const selectedBadge = ref(null);

const tabs = [
  { id: 'threads', label: 'Threads' },
  { id: 'badges', label: 'Badges' },
  { id: 'factors', label: 'Factors' },
];

const factors = ['Ping', 'Bandwidth', 'FLOPS', 'Commits', 'Hertz'];

const countdown = ref({ days: 0, hours: 0, minutes: 0 });
const threadsData = ref([]);
const badgeData = ref([]);
const availableBadges = ref([]);
const factorData = ref({});

const isCountdown = computed(() => {
  return new Date() < revealDate;
});

onMounted(() => {
  updateCountdown();
  setInterval(updateCountdown, 60000); // Update every minute
  
  if (!isCountdown.value) {
    loadLeaderboardData();
  }
});

function updateCountdown() {
  const now = new Date();
  const diff = revealDate - now;
  
  if (diff <= 0) {
    countdown.value = { days: 0, hours: 0, minutes: 0 };
    return;
  }
  
  const days = Math.floor(diff / (1000 * 60 * 60 * 24));
  const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
  
  countdown.value = { days, hours, minutes };
}

async function loadLeaderboardData() {
  try {
    // Load Threads leaderboard (primary ranking with 90-day composite score)
    const { data: threads, error: threadsError } = await supabase
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
      threadsData.value = threads.map((t, idx) => ({
        id: t.id,
        member_id: t.member_id,
        score: Math.round(t.score),
        ping: (t.ping_factor * 100).toFixed(1),
        bandwidth: (t.bandwidth_factor * 100).toFixed(1),
        flops: (t.flops_factor * 100).toFixed(1),
        commits: (t.commits_factor * 100).toFixed(1),
        hertz: (t.hertz_factor * 100).toFixed(1),
        name: t.members?.display_name || 'Anonymous',
        slug: t.members?.slug || 'unknown',
      }));
    }

    // Load badge rankings (query scores table grouped by badge)
    const { data: badgeScores, error: badgesError } = await supabase
      .from('scores')
      .select('badge, member_id, value, members!inner(display_name, slug)')
      .not('badge', 'is', null)
      .order('badge', { ascending: true })
      .order('value', { ascending: false });

    if (!badgesError && badgeScores) {
      // Extract unique badges for selector
      const badgeSet = new Set(badgeScores.map(s => s.badge));
      availableBadges.value = Array.from(badgeSet).sort();
      if (availableBadges.value.length > 0 && !selectedBadge.value) {
        selectedBadge.value = availableBadges.value[0];
      }

      // Group by badge for easier lookup
      const byBadge = {};
      badgeScores.forEach(entry => {
        if (!byBadge[entry.badge]) byBadge[entry.badge] = [];
        byBadge[entry.badge].push({
          member_id: entry.member_id,
          name: entry.members?.display_name || 'Anonymous',
          slug: entry.members?.slug || 'unknown',
          value: Math.round(entry.value),
        });
      });
      badgeData.value = byBadge;
    }

    // Load factor data (individual dimension scores from member_domain_ratings)
    const { data: ratings, error: ratingsError } = await supabase
      .from('member_domain_ratings')
      .select(`
        domain,
        rating,
        member_id,
        members!inner(display_name, slug)
      `)
      .order('domain', { ascending: true })
      .order('rating', { ascending: false });

    if (!ratingsError && ratings) {
      const factorMap = {
        'Arts': 'Ping',
        'Tech': 'Bandwidth',
        'Digital': 'FLOPS',
        'Community': 'Commits',
        'Leadership': 'Hertz'
      };

      // Group by domain/factor
      factors.forEach(factor => {
        const domain = Object.keys(factorMap).find(k => factorMap[k] === factor);
        if (domain) {
          factorData.value[factor] = ratings
            .filter(r => r.domain === domain)
            .map(r => ({
              member_id: r.member_id,
              name: r.members?.display_name || 'Anonymous',
              slug: r.members?.slug || 'unknown',
              value: r.rating ? r.rating.toFixed(1) : '0.0',
            }))
            .slice(0, 50); // Top 50 per factor
        }
      });
    }
  } catch (err) {
    console.error('Failed to load leaderboard data:', err);
  }
}
</script>

<style scoped>
.leaderboard-view {
  padding: 2rem;
}

.leaderboard-teaser {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 400px;
  text-align: center;
}

.countdown {
  display: flex;
  gap: 2rem;
  margin-top: 2rem;
}

.countdown-item {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.countdown-item .number {
  font-size: 2.5rem;
  font-weight: bold;
  color: var(--primary);
}

.countdown-item .label {
  font-size: 0.9rem;
  color: var(--text-secondary);
  margin-top: 0.5rem;
}

.tabs {
  display: flex;
  gap: 1rem;
  margin: 2rem 0;
  border-bottom: 1px solid var(--border);
}

.tab-btn {
  padding: 0.75rem 1.5rem;
  background: none;
  border: none;
  cursor: pointer;
  font-size: 1rem;
  color: var(--text-secondary);
  transition: all 0.2s;
}

.tab-btn.active {
  color: var(--primary);
  border-bottom: 2px solid var(--primary);
}

.tab-content {
  margin: 2rem 0;
}

.leaderboard-table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 1rem;
}

.leaderboard-table thead {
  background: var(--bg-secondary);
}

.leaderboard-table th, .leaderboard-table td {
  padding: 0.75rem;
  text-align: left;
  border-bottom: 1px solid var(--border);
}

.leaderboard-table tr:hover {
  background: var(--bg-secondary);
}

.score {
  font-weight: bold;
  color: var(--primary);
}

.badge-selector {
  margin: 1rem 0;
}

.badge-selector select {
  padding: 0.5rem;
  font-size: 1rem;
}

.factor-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 2rem;
  margin-top: 2rem;
}

.factor-card {
  padding: 1rem;
  border: 1px solid var(--border);
  border-radius: 8px;
}

.factor-card h4 {
  margin: 0 0 1rem 0;
}

.factor-table {
  width: 100%;
  font-size: 0.9rem;
}

.factor-table td {
  padding: 0.5rem;
}
</style>
