<!-- MemberCard.vue — the new shared member card.
     One presentational component, two call sites:
       - about/MembersView.vue's popup overlay (per-member, on click)
       - ProfileView.vue's public preview aside (always your own)
     This component owns no data-fetching of its own — both call
     sites hand it fully-resolved props (name/bio/socials/badges/
     Threads numbers/rank). That keeps the two different data paths
     (MembersView's static roster + live overrides vs. ProfileView's
     own profile fetch) from needing to agree on a shape beyond what
     this card actually renders.

     The banner's mountain silhouette reuses the SAME triangle-strip
     generation MembersView used to draw its thin zigzag divider
     (ZZ_PITCH/ZZ_DEPTH, recomputed to the container's real width) —
     just taller, and used as the banner's own background shape
     instead of a divider line underneath it. -->
<template>
  <section class="member-card-panel" :class="{ 'is-founder': founder }" :style="{ '--rank-color': rankColor }">
    <div class="member-card-banner" ref="bannerRef" :style="bannerStyle">
      <svg
        v-if="zigzagPoints"
        class="member-card-zigzag"
        :viewBox="zigzagViewBox"
        preserveAspectRatio="none"
        aria-hidden="true"
      >
        <polygon class="member-card-zigzag-poly" :points="zigzagPoints" />
      </svg>

      <div v-if="founder" class="member-card-founder-ribbon">
        <span class="member-card-founder-name">{{ founderTitle || 'Founder' }}</span>
        <span v-if="founderRoles" class="member-card-founder-roles">{{ founderRoles }}</span>
      </div>

      <div class="member-card-socials">
        <a
          v-for="(link, i) in (socials || []).slice(0, 3)"
          :key="i"
          class="member-card-social"
          :href="link.url"
          target="_blank"
          rel="noopener"
        >{{ link.label }}</a>
        <span v-if="!socials || !socials.length" class="member-card-social member-card-social--ghost">No socials yet</span>
      </div>

      <div class="member-card-avatar-wrap">
        <img v-if="avatarUrl" :src="avatarUrl" class="member-card-avatar" alt="" />
        <span v-else class="member-card-avatar-fallback">{{ initials }}</span>
      </div>
    </div>

    <div class="member-card-identity">
      <div class="member-card-name-block">
        <h3>{{ name }}</h3>
        <span class="member-card-section">{{ section || 'DMAC member' }}</span>
        <p v-if="bio" class="member-card-bio">{{ bio }}</p>
      </div>

      <div class="member-card-meta">
        <div class="member-card-meta-item">
          <span>Position</span>
          <strong>{{ position || 'Member' }}</strong>
        </div>
        <div class="member-card-meta-item">
          <span>Leaderboard</span>
          <strong class="member-card-rank-value">{{ rank ? `#${rank}` : '—' }}</strong>
        </div>
      </div>
    </div>

    <div class="member-card-body">
      <!-- Radial diagram: Threads composite in the middle, its 5
           rolling factors around it as circuit-board "chip" nodes,
           connected by right-angled PCB-style traces rather than
           plain lines. Factor nodes idly drift (disabled under
           prefers-reduced-motion, see styles). -->
      <div class="member-card-radar">
        <svg class="member-card-radar-traces" viewBox="0 0 280 280" aria-hidden="true">
          <path
            v-for="n in factorNodes"
            :key="`trace-${n.key}`"
            class="member-card-trace"
            :d="`M140,140 L${n.x},140 L${n.x},${n.y}`"
          />
          <circle
            v-for="n in factorNodes"
            :key="`via-${n.key}`"
            class="member-card-via"
            :cx="n.x" cy="140" r="2.2"
          />
        </svg>

        <div class="member-node member-node--threads">
          <svg class="member-node-frame" viewBox="0 0 64 64" aria-hidden="true">
            <rect x="10" y="10" width="44" height="44" rx="8" />
            <line x1="32" y1="0" x2="32" y2="10" /><line x1="32" y1="54" x2="32" y2="64" />
            <line x1="0" y1="32" x2="10" y2="32" /><line x1="54" y1="32" x2="64" y2="32" />
            <line x1="11" y1="11" x2="17" y2="17" /><line x1="53" y1="11" x2="47" y2="17" />
            <line x1="11" y1="53" x2="17" y2="47" /><line x1="53" y1="53" x2="47" y2="47" />
          </svg>
          <span class="member-node-value">{{ threadsScore != null ? Math.round(threadsScore) : '—' }}</span>
          <small class="member-node-label">Threads</small>
        </div>

        <div
          v-for="(n, i) in factorNodes"
          :key="n.key"
          class="member-node member-node--factor"
          :style="{ left: `${n.x}px`, top: `${n.y}px`, animationDelay: `${i * 0.55}s` }"
        >
          <svg class="member-node-frame" viewBox="0 0 56 56" aria-hidden="true">
            <rect x="9" y="9" width="38" height="38" rx="6" />
            <line x1="28" y1="1" x2="28" y2="9" /><line x1="28" y1="47" x2="28" y2="55" />
            <line x1="1" y1="28" x2="9" y2="28" /><line x1="47" y1="28" x2="55" y2="28" />
          </svg>
          <span class="member-node-value">{{ n.display }}</span>
          <small class="member-node-label">{{ n.label }}</small>
        </div>
      </div>

      <!-- Badge collection -->
      <div class="member-card-badges">
        <div class="member-card-badges-head">
          <strong>{{ (badges || []).length }}/{{ totalBadgeTypes }} badges</strong>
          <span>{{ badgePercent }}%<template v-if="badgeRank"> · top {{ badgeRank }}/{{ rosterCount || '?' }}</template></span>
        </div>
        <div class="member-card-badges-grid">
          <div
            v-for="b in badges"
            :key="b.badge_id"
            class="member-badge-chip"
            :style="{ '--tier-color': tierColor(b.tierKey) }"
            :title="badgeTitle(b)"
            @mouseenter="playSfx('menuhover')"
          >
            <div v-if="badgeBg(b.tierKey)" class="member-badge-bg" v-html="badgeBg(b.tierKey)"></div>
            <span v-else class="member-badge-diamond">◆</span>
          </div>
          <p v-if="!badges || !badges.length" class="member-card-badges-empty">No badges yet.</p>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch, nextTick } from 'vue';
import Leaderboard from '../lib/leaderboard.js';
import { BADGE_SVG } from '../lib/badges.js';
import { hexToRgb } from '../lib/color-utils.js';
import { playSfx } from '../composables/useSfx.js';

const props = defineProps({
  name: { type: String, default: 'DMAC member' },
  section: String,
  position: String,
  bio: String,
  initials: { type: String, default: 'DMAC' },
  avatarUrl: String,
  bannerUrl: String,
  bannerColor: String,
  socials: { type: Array, default: () => [] },

  rank: Number,
  rankColor: { type: String, default: '#b0b0b0' },
  threadsScore: Number,
  threadsFactors: { type: Object, default: () => ({}) },

  badges: { type: Array, default: () => [] },
  badgeRank: Number,
  rosterCount: Number,
  totalBadgeTypes: { type: Number, default: () => Object.keys(Leaderboard.BADGE_LABELS).length },

  founder: Boolean,
  founderTitle: String,
  founderRoles: String,

  // Whether this card is currently visible — MembersView's popup
  // stays mounted while closed (just visually hidden), so its width
  // isn't measurable until it actually opens. ProfileView's usage is
  // always visible and never needs to flip this.
  active: { type: Boolean, default: true },
});

/* ── BANNER TINT (behind the zigzag) ───────────────────────────── */
const bannerStyle = computed(() => {
  if (props.bannerUrl) {
    return { backgroundImage: `url(${props.bannerUrl})`, backgroundSize: 'cover', backgroundPosition: 'center' };
  }
  if (props.bannerColor) {
    const { r, g, b } = hexToRgb(props.bannerColor);
    return { background: `linear-gradient(160deg, rgba(${r},${g},${b},0.5), #101014 78%)` };
  }
  return {};
});

/* ── DYNAMIC MOUNTAIN ZIGZAG — same triangle-strip math the old
   card-zigzag divider used, just taller (banner-scale) and used as a
   filled silhouette instead of a thin stroked line. ───────────── */
const ZZ_PITCH = 60;
const ZZ_DEPTH = 46;
const bannerRef = ref(null);
const zigzagViewBox = ref('0 0 400 90');
const zigzagPoints = ref('');
let resizeObs = null;

function drawZigzag() {
  const W = bannerRef.value?.offsetWidth || 400;
  const startX = -ZZ_PITCH;
  const count = Math.ceil((W + ZZ_PITCH * 2) / ZZ_PITCH);
  const pts = [`${startX},${ZZ_DEPTH + 40}`, `${startX},${ZZ_DEPTH}`];

  for (let i = 0; i < count; i++) {
    const tipX = startX + i * ZZ_PITCH + ZZ_PITCH / 2;
    const baseX = startX + (i + 1) * ZZ_PITCH;
    pts.push(`${tipX},0`, `${baseX},${ZZ_DEPTH}`);
  }

  const farRight = startX + (count + 1) * ZZ_PITCH;
  pts.push(`${farRight},${ZZ_DEPTH + 40}`);

  zigzagViewBox.value = `0 0 ${W} ${ZZ_DEPTH + 40}`;
  zigzagPoints.value = pts.join(' ');
}

function refreshZigzag() {
  nextTick(() => requestAnimationFrame(drawZigzag));
}

watch(() => props.active, (isActive) => {
  if (isActive) refreshZigzag();
}, { immediate: true });

onMounted(() => {
  if (typeof ResizeObserver !== 'undefined' && bannerRef.value) {
    resizeObs = new ResizeObserver(() => drawZigzag());
    resizeObs.observe(bannerRef.value);
  } else {
    window.addEventListener('resize', drawZigzag);
  }
});
onBeforeUnmount(() => {
  if (resizeObs) resizeObs.disconnect();
  else window.removeEventListener('resize', drawZigzag);
});

/* ── RADAR — pentagon layout, Threads centered ─────────────────── */
const FACTOR_DEFS = [
  { key: 'ping', label: 'Ping' },
  { key: 'bandwidth', label: 'Bandwidth' },
  { key: 'flops', label: 'FLOPS' },
  { key: 'commits', label: 'Commits' },
  { key: 'hertz', label: 'Hertz' },
];

const factorNodes = computed(() => {
  const cx = 140, cy = 140, r = 100;
  return FACTOR_DEFS.map((f, i) => {
    const angle = (-90 + (360 / FACTOR_DEFS.length) * i) * (Math.PI / 180);
    const raw = props.threadsFactors?.[f.key];
    return {
      ...f,
      x: Math.round(cx + r * Math.cos(angle)),
      y: Math.round(cy + r * Math.sin(angle)),
      display: raw != null ? `${Math.round(raw * 100)}%` : '—',
    };
  });
});

const badgePercent = computed(() => {
  const total = props.totalBadgeTypes || 1;
  return Math.round(((props.badges?.length || 0) / total) * 100);
});

function tierColor(tierKey) {
  return Leaderboard.TIER_COLORS[tierKey] || '#888';
}
function badgeBg(tierKey) {
  return BADGE_SVG[`${tierKey}-badge`] || null;
}
function badgeTitle(b) {
  return b?.level ? `${b.level} ${b.name}` : b?.name || 'Badge';
}
</script>

<style scoped>
.member-card-panel {
  border-radius: 28px;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.09);
  background: rgba(13, 13, 13, 0.82);
  box-shadow: 0 20px 48px rgba(0, 0, 0, 0.34);
}

/* ── BANNER ─────────────────────────────────────────────────────── */
.member-card-banner {
  position: relative;
  height: 118px;
  background: linear-gradient(160deg, #1c1c22, #0d0d0d);
  overflow: hidden;
}
.member-card-zigzag {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}
.member-card-zigzag-poly {
  fill: var(--rank-color, #f97316);
  opacity: 0.28;
}

.member-card-founder-ribbon {
  position: absolute;
  left: 0;
  top: 0;
  z-index: 1;
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 8px 14px;
  background: linear-gradient(90deg, rgba(0, 0, 0, 0.6), transparent);
}
.member-card-founder-name {
  font-family: var(--font);
  font-weight: 700;
  font-size: 0.78rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--orange);
}
.member-card-founder-roles {
  font-size: 0.65rem;
  color: rgba(240, 240, 240, 0.6);
}

.member-card-socials {
  position: absolute;
  top: 12px;
  right: 14px;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 8px;
  max-width: 65%;
}
.member-card-social {
  font-size: 0.7rem;
  color: rgba(240, 240, 240, 0.78);
  background: rgba(0, 0, 0, 0.4);
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: 999px;
  padding: 4px 10px;
  text-decoration: none;
  white-space: nowrap;
}
.member-card-social--ghost { color: rgba(240, 240, 240, 0.42); }

.member-card-avatar-wrap {
  position: absolute;
  left: 20px;
  bottom: -34px;
  z-index: 2;
  width: 88px;
  height: 88px;
  border-radius: 24px;
  padding: 5px;
  background: linear-gradient(135deg, rgba(249, 115, 22, 0.9), rgba(76, 29, 149, 0.9));
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.4);
}
.member-card-avatar {
  width: 100%; height: 100%;
  border-radius: 19px;
  object-fit: cover;
  display: block;
}
.member-card-avatar-fallback {
  width: 100%; height: 100%;
  border-radius: 19px;
  display: grid; place-items: center;
  background: #111; color: #fff;
  font-size: 1.15rem; letter-spacing: 0.08em;
}

/* ── IDENTITY ───────────────────────────────────────────────────── */
.member-card-identity {
  padding: 44px 20px 18px;
  display: flex; flex-direction: column; gap: 14px;
}
.member-card-name-block h3 { margin: 0 0 2px; font-size: 1.14rem; line-height: 1.2; }
.member-card-section {
  font-size: 0.76rem; letter-spacing: 0.08em; text-transform: uppercase;
  color: rgba(240, 240, 240, 0.55);
}
.member-card-bio {
  margin: 8px 0 0; font-size: 0.85rem; line-height: 1.6;
  color: rgba(240, 240, 240, 0.78);
}

.member-card-meta { display: flex; gap: 12px; }
.member-card-meta-item {
  flex: 1; padding: 10px 12px; border-radius: 14px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.06);
  display: flex; flex-direction: column; gap: 2px;
}
.member-card-meta-item span {
  font-size: 0.66rem; text-transform: uppercase; letter-spacing: 0.08em;
  color: rgba(240, 240, 240, 0.5);
}
.member-card-meta-item strong { font-size: 1rem; }
.member-card-rank-value { color: var(--rank-color, #f0f0f0); }

/* ── BODY ───────────────────────────────────────────────────────── */
.member-card-body {
  display: flex; flex-wrap: wrap; gap: 18px;
  padding: 0 20px 22px;
}

/* ── RADAR ──────────────────────────────────────────────────────── */
.member-card-radar {
  position: relative;
  width: 280px; height: 280px;
  margin: 0 auto;
  flex-shrink: 0;
}
.member-card-radar-traces {
  position: absolute; inset: 0; width: 100%; height: 100%;
  opacity: 0.45; /* dimmed — was full-strength */
}
.member-card-trace {
  fill: none;
  stroke: color-mix(in srgb, var(--rank-color, #888) 25%, rgba(255, 255, 255, 0.08));
  stroke-width: 1.1;
}
.member-card-via {
  fill: color-mix(in srgb, var(--rank-color, #888) 35%, rgba(255, 255, 255, 0.14));
}

.member-node {
  position: absolute;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  text-align: center; line-height: 1.15;
  color: color-mix(in srgb, var(--rank-color, #888) 55%, rgba(255, 255, 255, 0.3));
}
.member-node-frame {
  position: absolute; inset: 0; width: 100%; height: 100%;
  fill: rgba(255, 255, 255, 0.04);
  stroke: currentColor;
  stroke-width: 1.4;
}
.member-node--factor .member-node-frame {
  opacity: 0.7;
}

.member-node--threads {
  left: 140px; top: 140px;
  transform: translate(-50%, -50%);
  width: 88px; height: 88px;
  z-index: 2;
}
.member-node--threads .member-node-frame {
  filter: drop-shadow(0 0 10px color-mix(in srgb, var(--rank-color, #f97316) 45%, transparent));
}
.member-node-value {
  position: relative; z-index: 1;
  font-family: var(--font); font-weight: 700; color: #fff;
}
.member-node--threads .member-node-value { font-size: 1.05rem; }
.member-node-label {
  position: relative; z-index: 1;
  font-size: 0.56rem; letter-spacing: 0.08em; text-transform: uppercase;
  color: rgba(240, 240, 240, 0.62);
}

.member-node--factor {
  transform: translate(-50%, -50%);
  width: 58px; height: 58px;
  animation: member-node-float 4.6s ease-in-out infinite;
}
.member-node--factor .member-node-value { font-size: 0.74rem; font-weight: 600; }

@keyframes member-node-float {
  0%, 100% { transform: translate(-50%, -50%) translateY(0); }
  50%      { transform: translate(-50%, -50%) translateY(-6px); }
}
@media (prefers-reduced-motion: reduce) {
  .member-node--factor { animation: none; }
}

/* ── BADGES ─────────────────────────────────────────────────────── */
.member-card-badges { flex: 1; min-width: 200px; }
.member-card-badges-head {
  display: flex; justify-content: space-between; align-items: baseline;
  margin-bottom: 10px; font-size: 0.8rem; color: rgba(240, 240, 240, 0.6);
}
.member-card-badges-head strong { color: #fff; font-size: 0.94rem; }
.member-card-badges-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(40px, 1fr));
  gap: 8px;
}
.member-badge-chip {
  position: relative; aspect-ratio: 1; border-radius: 10px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--tier-color, rgba(255, 255, 255, 0.14));
  display: grid; place-items: center; overflow: hidden;
}
.member-badge-bg :deep(svg) { width: 100%; height: 100%; }
.member-badge-diamond { color: var(--tier-color, #888); font-size: 1.1rem; }
.member-card-badges-empty {
  grid-column: 1 / -1; margin: 0;
  color: rgba(240, 240, 240, 0.5); font-size: 0.84rem;
}

@media (max-width: 640px) {
  .member-card-avatar-wrap { width: 76px; height: 76px; }
  .member-card-radar { width: 250px; height: 250px; }
}
</style>
