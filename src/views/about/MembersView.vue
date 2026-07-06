<template>
  <main>
    <div class="page-section reveal">
      <SecHead>Members</SecHead>
      <div class="members-content">

        <!-- ── ADVISERS ── -->
        <div class="members-section">
          <p class="members-section-label">Advisers</p>
          <div class="advisers-grid">
            <div
              v-for="adv in ADVISERS"
              :key="adv.id"
              class="adviser-card expandable"
              :data-member-id="adv.id"
              tabindex="0"
              role="button"
              :aria-label="profileLabel(adv.name)"
              v-sfx-hover
              @click="openCard(adv.id)"
              @keydown="onCardKeydown(adv.id, $event)"
            >
              <span class="adviser-role">{{ adv.role }}</span>
              <span class="adviser-name">{{ adv.name }}</span>
              <span class="expand-hint adviser-expand-hint">◆ view profile</span>
            </div>
          </div>
        </div>

        <!-- ── OFFICERS ── -->
        <div class="members-section">
          <p class="members-section-label">Officers</p>
          <div class="officers-grid">
            <div
              v-for="off in OFFICERS"
              :key="off.id"
              class="officer-card expandable"
              :data-member-id="off.id"
              tabindex="0"
              role="button"
              :aria-label="profileLabel(off.name)"
              v-sfx-hover
              @click="openCard(off.id)"
              @keydown="onCardKeydown(off.id, $event)"
            >
              <span class="officer-role">{{ off.role }}</span>
              <span class="officer-name">{{ off.name }}</span>
              <span class="expand-hint">◆ view profile</span>
            </div>
          </div>
        </div>

        <!-- ── MEMBERS ── -->
        <div class="members-section">
          <p class="members-section-label">Members</p>

          <div class="team-block" v-for="team in TEAMS" :key="team.label">
            <span class="team-block-label">{{ team.label }}</span>
            <div class="members-grid">
              <div
                v-for="m in team.members"
                :key="m.id"
                class="member-card expandable"
                :data-member-id="m.id"
                tabindex="0"
                role="button"
                :aria-label="profileLabel(m.name)"
                v-sfx-hover
                @click="openCard(m.id)"
                @keydown="onCardKeydown(m.id, $event)"
              >{{ m.name }}<span class="expand-hint">◆ view</span></div>
            </div>
          </div>
        </div>

      </div>
    </div>
  </main>

  <!-- ════════════════════ MEMBER CARD OVERLAY ════════════════════ -->
  <div
    class="card-overlay"
    :class="{ open: cardOpen }"
    role="dialog"
    aria-modal="true"
    aria-label="Member Profile"
    @click="onOverlayClick"
  >
    <div class="card-panel" :class="{ open: panelOpen, 'is-founder': openedMember?.isFounder }" ref="panelRef">

      <!-- Banner -->
      <div class="card-banner" :class="`card-banner--${openedMember?.bannerKey || 'default'}`">
        <div class="card-banner-content">
          <div
            class="card-avatar"
            :style="openedMember?.avatar ? { backgroundImage: `url(https://aztaryx.github.io/dmac-assets/avatars/${openedMember.avatar})` } : {}"
          ></div>
          <div class="card-header-text">
            <h2 class="card-name">{{ openedMember?.name }}</h2>
            <span class="card-grade">{{ openedMember?.gradeSection || 'DMAC' }}</span>
          </div>
        </div>
      </div>

      <!-- Mini zigzag divider -->
      <div class="card-zigzag" aria-hidden="true">
        <svg class="card-zigzag-svg" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="none" :viewBox="zigzagViewBox">
          <polygon class="card-zigzag-poly" fill="#111" stroke="none" :points="zigzagPoints" />
        </svg>
      </div>

      <!-- Close -->
      <button class="card-close" aria-label="Close profile" v-sfx-hover @click="closeCard">✕ CLOSE</button>

      <!-- Body -->
      <div class="card-body">

        <!-- Header Info (Position & Socials) -->
        <div class="card-header-info">
          <div class="card-identity">
            <span class="card-role">{{ openedMember?.role }}</span>
            <div>
              <div v-if="openedMember?.isFounder" class="founder-title-bar">
                <div class="founder-title-bg"></div>
                <div class="founder-title-main">
                  <span class="founder-title-name">{{ founderFirstName }}</span>
                  <span class="founder-title-slash">/</span>
                  <span class="founder-title-label">{{ openedMember.founderTitle }}</span>
                </div>
                <span class="founder-title-roles">{{ openedMember.founderRoles }}</span>
              </div>
              <span v-else-if="openedMember?.tagline" class="card-tagline">{{ openedMember.tagline }}</span>
            </div>
          </div>

          <div class="card-socials-container">
            <span class="card-socials-label">socials (max 3)</span>
            <div class="card-socials">
              <template v-if="openedMember?.socials?.length">
                <a
                  v-for="soc in openedMember.socials.slice(0, 3)"
                  :key="soc.icon"
                  :href="soc.url"
                  target="_blank"
                  class="card-social-link"
                  v-sfx-hover
                >
                  <img :src="`https://aztaryx.github.io/dmac-assets/icons/${soc.icon}`" :alt="soc.platform" />
                </a>
              </template>
              <span v-else class="card-empty-text">No socials linked.</span>
            </div>
          </div>

          <div class="card-time-working-container">
            <span class="card-time-working-label">time spent working</span>
            <div class="card-time-working">
              <template v-if="openedMember?.timeWorking?.length">
                <div class="card-time-entry" v-for="tw in openedMember.timeWorking" :key="tw.label">
                  <span class="time-label">{{ tw.label }}</span><span class="time-value">{{ tw.value }}</span>
                </div>
              </template>
              <span v-else class="card-empty-text">Unknown time spent.</span>
            </div>
          </div>
        </div>

        <!-- Badges -->
        <div class="card-badges-section">
          <div class="card-badges-header">
            <div class="card-badge-count">
              <span class="card-badge-percent">{{ badgePercent }}%</span>
              <span class="card-badge-text">or<br />{{ openedMember?.badges?.length || 0 }} / {{ TOTAL_POSSIBLE_BADGES }} badges</span>
            </div>
            <div class="card-badges-scrollable">
              <div
                v-for="(badge, i) in openedMember?.badges || []"
                :key="i"
                class="badge-slot"
                :style="{ '--tier-color': tierColor(badge.tierKey) }"
                :title="badgeLabel(badge)"
                @mouseenter="playSfx('menuhover')"
                @click="playSfx('no')"
              >
                <img v-if="badgeBgUrl(badge.tierKey)" :src="badgeBgUrl(badge.tierKey)" alt="" class="badge-bg" />
                <img v-if="badgeIconUrl(badge.file)" :src="badgeIconUrl(badge.file)" :alt="badgeLabel(badge)" class="badge-icon" />
                <span
                  v-else
                  class="badge-diamond"
                  :style="{ color: tierColor(badge.tierKey), textShadow: `0 0 14px ${tierColor(badge.tierKey)}, 0 0 28px ${tierColor(badge.tierKey)}66` }"
                >◆</span>
                <span class="badge-tip">{{ badgeLabel(badge) }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- About -->
        <div class="card-about-section">
          <p class="card-about-text">{{ openedMember?.about || 'No description provided.' }}</p>
        </div>

        <!-- Stats Row -->
        <div class="card-stats-row">
          <div class="card-stat">
            <span class="card-stat-label">year<br />joined</span>
            <span class="card-stat-value">{{ openedMember?.yearJoined || '--' }}</span>
          </div>
          <div class="card-stat">
            <span class="card-stat-label">ar score</span>
            <span class="card-stat-value">{{ openedMember?.arScore || '--' }}</span>
          </div>
          <div class="card-stat">
            <span class="card-stat-label">specializes in..</span>
            <span class="card-stat-value">{{ openedMember?.specialization || '--' }}</span>
          </div>
          <div class="card-stat">
            <span class="card-stat-label">random stat</span>
            <span class="card-stat-value">{{ openedMember?.randomStat || '--' }}</span>
          </div>
        </div>

      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, nextTick, onMounted, onBeforeUnmount } from 'vue';
import SecHead from '../../components/SecHead.vue';
import Leaderboard from '../../lib/leaderboard.js';
import { BADGE_URLS } from '../../lib/badges.js';
import { playSfx } from '../../composables/useSfx.js';
import '../../assets/css/pages/members.css';

/* Ported from about/members.html + js/pages/members.js. The roster
   markup (advisers/officers/team members) is now driven by small
   arrays instead of 18 hand-copied card blocks — same DOM shape and
   classes as the original, just generated. The profile-popup data
   (MEMBERS) is kept as a plain object exactly like the original,
   since that's genuinely one-record-per-person content, not a
   layout concern. */

/* ── TIER COLOURS ─────────────────────────────────── */
const TIER_COLORS = {
  ...Leaderboard.TIER_COLORS,
  leaddeveloper: '#ff4444',
  founder: '#f97316',
};

/* ── ROSTER (drives the grid markup) ──────────────── */
const ADVISERS = [
  { id: 'richmond-causaren', role: 'Club Adviser', name: 'Richmond P. Causaren' },
  { id: 'marie-asuncion', role: 'Co-Adviser', name: 'Marie Aldron G. Asuncion' },
  { id: 'rhocell-luteria', role: 'Co-Adviser', name: 'Rhocell C. Luteria' },
  { id: 'johanna-obar', role: 'Co-Adviser', name: 'Johanna Mae E. Obar' },
];

const OFFICERS = [
  { id: 'jyryn-jayme', role: 'President', name: 'Jyryn Shmily G. Jayme' },
  { id: 'jaywin-cambalon', role: 'Vice President', name: 'Jaywin Elson Cambalon' },
  { id: 'athena-jimenez', role: 'Secretary', name: 'Athena Aruen M. Jimenez' },
  { id: 'nico-melorin', role: 'Asst. Secretary', name: 'Nico Andrei C. Melorin' },
  { id: 'keitharine-secillano', role: 'Treasurer', name: 'Keitharine M. Secillano' },
  { id: 'alianna-abangan', role: 'Auditor', name: 'Alianna Jen M. Abangan' },
  { id: 'mark-patnon', role: 'Public Information Officer', name: 'Mark James C. Patnon' },
  { id: 'jezrylle-andres', role: 'Public Information Officer', name: 'Jezrylle D. Andres' },
];

const TEAMS = [
  {
    label: 'Multimedia & Visual Graphic Specialist Team',
    members: [
      { id: 'leanne-abenoja', name: 'Leanne Rouz E. Abenoja' },
      { id: 'micah-bartolome', name: 'Micah Sophia H. Bartolome' },
      { id: 'liane-labitan', name: 'Liane Jhaydel D. Labitan' },
      { id: 'clarisse-luego', name: 'Clarisse Madel M. Luego' },
      { id: 'rhycel-nato', name: 'Rhycel Dennese M. Nato' },
      { id: 'ysabel-pernala', name: 'Ysabel A. Pernala' },
      { id: 'rojan-sajol', name: 'Rojan Jacob D. Sajol' },
      { id: 'ethan-salamat', name: 'Ethan Carlo M. Salamat' },
    ],
  },
  {
    label: 'Creative Imagery Specialist Team',
    members: [
      { id: 'sophia-angeles', name: 'Sophia Lorraine F. Angeles' },
      { id: 'jemwell-boton', name: 'Jemwell Boton' },
      { id: 'clarence-eblasin', name: 'Clarence Lei P. Eblasin' },
      { id: 'mary-magalona', name: 'Mary Jeanelle Magalona' },
      { id: 'lorien-naval', name: 'Lorien Rose A. Naval' },
      { id: 'sofia-obejas', name: 'Sofia Lois A. Obejas' },
    ],
  },
];

function profileLabel(name) {
  return `View ${name}'s profile`;
}

/* ── MEMBER PROFILE DATA (card overlay content) ───── */
const EMPTY = { tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null };

const MEMBERS = {
  'richmond-causaren': {
    name: 'Richmond P. Causaren', role: 'Club Adviser', ...EMPTY,
    tagline: 'Founder · DMAC',
    about: 'The visionary who started it all. Sir Richmond founded the Digital Multimedia Arts Club, bringing together creative minds with a shared passion for digital media.',
    bannerKey: 'founder',
    isFounder: true,
    founderTitle: 'DMAC FOUNDER',
    founderRoles: 'Club Adviser · Founder',
    badges: [{ level: null, name: 'Founder', file: 'founder.png', tierKey: 'founder' }],
  },
  'marie-asuncion': { name: 'Marie Aldron G. Asuncion', role: 'Co-Adviser', ...EMPTY },
  'rhocell-luteria': { name: 'Rhocell C. Luteria', role: 'Co-Adviser', ...EMPTY },
  'johanna-obar': { name: 'Johanna Mae E. Obar', role: 'Co-Adviser', ...EMPTY },

  'jyryn-jayme': { name: 'Jyryn Shmily G. Jayme', role: 'President', ...EMPTY },
  'jaywin-cambalon': { name: 'Jaywin Elson Cambalon', role: 'Vice President', ...EMPTY },
  'athena-jimenez': { name: 'Athena Aruen M. Jimenez', role: 'Secretary', ...EMPTY },
  'nico-melorin': { name: 'Nico Andrei C. Melorin', role: 'Asst. Secretary', ...EMPTY },
  'keitharine-secillano': { name: 'Keitharine M. Secillano', role: 'Treasurer', ...EMPTY },
  'alianna-abangan': { name: 'Alianna Jen M. Abangan', role: 'Auditor', ...EMPTY },
  'mark-patnon': {
    name: 'Mark James C. Patnon', role: 'Public Information Officer', ...EMPTY,
    tagline: 'Lead Developer · Web & Systems',
    about: "The guy who actually builds stuff around here. If it's on the site, I probably made it.",
    bannerKey: 'mark',
    /* Lead Developer isn't in this grid — it lives in the card's
       "Special stuff" section instead, rendered separately from the
       regular badge slots (that section is on you to build/wire up). */
    badges: [
      { level: 'Prism', name: 'Contributor', file: 'quartzcontributor.png', tierKey: 'prism' },
      { level: 'Prism', name: 'Builder', file: 'quartzbuilder.png', tierKey: 'prism' },
      { level: 'Prism', name: 'Secret', file: 'quartzsecret.png', tierKey: 'prism' },
      { level: 'Copper', name: 'larper', file: 'copperlarper.png', tierKey: 'copper' },
    ],
  },
  'jezrylle-andres': { name: 'Jezrylle D. Andres', role: 'Public Information Officer', ...EMPTY },

  'leanne-abenoja': { name: 'Leanne Rouz E. Abenoja', role: 'Multimedia & Visual Graphic Specialist', ...EMPTY },
  'micah-bartolome': { name: 'Micah Sophia H. Bartolome', role: 'Multimedia & Visual Graphic Specialist', ...EMPTY },
  'liane-labitan': { name: 'Liane Jhaydel D. Labitan', role: 'Multimedia & Visual Graphic Specialist', ...EMPTY },
  'clarisse-luego': { name: 'Clarisse Madel M. Luego', role: 'Multimedia & Visual Graphic Specialist', ...EMPTY },
  'rhycel-nato': { name: 'Rhycel Dennese M. Nato', role: 'Multimedia & Visual Graphic Specialist', ...EMPTY },
  'ysabel-pernala': { name: 'Ysabel A. Pernala', role: 'Multimedia & Visual Graphic Specialist', ...EMPTY },
  'rojan-sajol': { name: 'Rojan Jacob D. Sajol', role: 'Multimedia & Visual Graphic Specialist', ...EMPTY },
  'ethan-salamat': { name: 'Ethan Carlo M. Salamat', role: 'Multimedia & Visual Graphic Specialist', ...EMPTY },

  'sophia-angeles': { name: 'Sophia Lorraine F. Angeles', role: 'Creative Imagery Specialist', ...EMPTY },
  'jemwell-boton': { name: 'Jemwell Boton', role: 'Creative Imagery Specialist', ...EMPTY },
  'clarence-eblasin': { name: 'Clarence Lei P. Eblasin', role: 'Creative Imagery Specialist', ...EMPTY },
  'mary-magalona': { name: 'Mary Jeanelle Magalona', role: 'Creative Imagery Specialist', ...EMPTY },
  'lorien-naval': { name: 'Lorien Rose A. Naval', role: 'Creative Imagery Specialist', ...EMPTY },
  'sofia-obejas': { name: 'Sofia Lois A. Obejas', role: 'Creative Imagery Specialist', ...EMPTY },
};

/* ── BADGE HELPERS ─────────────────────────────────
   BADGE_URLS only knows about the .svg files actually sitting in
   src/assets/badges/ (see lib/badges.js's import.meta.glob). Right
   now that's just the tier gems + speedtypist.svg — none of the
   per-person badge icons referenced above (founder.png,
   quartzcontributor.png, etc.) exist yet. Rather than port the old
   two-step <img onerror> fallback chain, we just check up front:
   known file → render the real image; unknown → render the ◆
   glyph fallback directly. Once real badge art is dropped into
   src/assets/badges/ as .svg (matching the tier-gem convention),
   these start resolving automatically — no code change needed. */
function tierColor(tierKey) {
  return TIER_COLORS[tierKey] || '#888';
}
function badgeLabel(badge) {
  return badge.level ? `${badge.level} ${badge.name}` : badge.name;
}
function badgeBgUrl(tierKey) {
  return BADGE_URLS[`${tierKey}-badge`] || null;
}
function badgeIconUrl(file) {
  const base = file.replace(/\.[^.]+$/, '');
  return BADGE_URLS[base] || null;
}

const TOTAL_POSSIBLE_BADGES = 42;

/* ── CARD OPEN/CLOSE STATE ─────────────────────────
   selectedId is the source of truth; cardOpen/panelOpen mirror the
   old overlay/panel classList toggles (panelOpen lags one frame
   behind cardOpen so the CSS transition actually plays, same as
   the original's requestAnimationFrame trick). */
const selectedId = ref(null);
const cardOpen = ref(false);
const panelOpen = ref(false);
const panelRef = ref(null);
const zigzagViewBox = ref('0 0 760 28');
const zigzagPoints = ref('');

const openedMember = computed(() => (selectedId.value ? MEMBERS[selectedId.value] : null));
const founderFirstName = computed(() => openedMember.value?.name?.split(' ')[0]?.toLowerCase() || '');
const badgePercent = computed(() => {
  const n = openedMember.value?.badges?.length || 0;
  return n > 0 ? Math.floor((n / TOTAL_POSSIBLE_BADGES) * 100) : 0;
});

/* ── MINI ZIGZAG ────────────────────────────────────
   Same triangle-strip math as the original drawCardZigzag(), just
   writing into refs instead of setAttribute-ing an SVG directly. */
const ZZ_PITCH = 52;
const ZZ_DEPTH = 28;

function drawCardZigzag() {
  const W = panelRef.value?.offsetWidth || 760;
  const startX = -ZZ_PITCH;
  const count = Math.ceil((W + ZZ_PITCH * 2) / ZZ_PITCH);
  const pts = [`${startX},0`];

  for (let i = 0; i < count; i++) {
    const tipX = startX + i * ZZ_PITCH + ZZ_PITCH / 2;
    const baseX = startX + (i + 1) * ZZ_PITCH;
    pts.push(`${tipX},${ZZ_DEPTH}`, `${baseX},0`);
  }

  const farRight = startX + (count + 1) * ZZ_PITCH;
  pts.push(`${farRight},${ZZ_DEPTH}`, `${startX},${ZZ_DEPTH}`);

  zigzagViewBox.value = `0 0 ${W} ${ZZ_DEPTH}`;
  zigzagPoints.value = pts.join(' ');
}

/* ── OPEN / CLOSE ───────────────────────────────────── */
function openCard(memberId) {
  if (!MEMBERS[memberId]) return;
  playSfx('menuconfirm');
  selectedId.value = memberId;
  cardOpen.value = true;
  document.body.style.overflow = 'hidden';
  nextTick(() => {
    requestAnimationFrame(() => {
      panelOpen.value = true;
      drawCardZigzag();
    });
  });
}

function closeCard() {
  if (!cardOpen.value) return;
  playSfx('menuback');
  panelOpen.value = false;
  const panel = panelRef.value;
  const finish = () => {
    cardOpen.value = false;
    document.body.style.overflow = '';
  };
  if (panel) {
    panel.addEventListener('transitionend', finish, { once: true });
  } else {
    finish();
  }
}

function onCardKeydown(memberId, e) {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault();
    openCard(memberId);
  }
}

function onOverlayClick(e) {
  if (e.target === e.currentTarget) closeCard();
}

function onGlobalKeydown(e) {
  if (e.key === 'Escape' && cardOpen.value) closeCard();
}

function onResize() {
  if (cardOpen.value) drawCardZigzag();
}

onMounted(() => {
  document.addEventListener('keydown', onGlobalKeydown);
  window.addEventListener('resize', onResize);
});

onBeforeUnmount(() => {
  document.removeEventListener('keydown', onGlobalKeydown);
  window.removeEventListener('resize', onResize);
  // Safety net if the view unmounts (route change) while a card is
  // still open — don't leave scrolling locked.
  document.body.style.overflow = '';
});
</script>
