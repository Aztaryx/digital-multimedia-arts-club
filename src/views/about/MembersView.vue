<template>
  <main>
    <PageHero title="Members" />
    <div class="page-section reveal" v-reveal>
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

  <!-- ════════════════════ MEMBER CARD POPUP ════════════════════ -->
  <div
    class="member-popup-overlay"
    :class="{ open: cardOpen }"
    role="dialog"
    aria-modal="true"
    aria-label="Member Profile"
    @click="onOverlayClick"
  >
    <div class="member-popup-panel" :class="{ open: panelOpen }" @click.stop>
      <button class="member-popup-close" aria-label="Close profile" v-sfx-hover @click="closeCard">✕</button>
      <MemberCard
        v-if="openedMember"
        :name="openedMember.name"
        :section="openedMember.role"
        :position="openedMember.role"
        :bio="openedMember.about"
        :initials="openedMember.initials"
        :avatar-url="openedMember.avatarUrl"
        :banner-url="openedMember.liveBannerUrl"
        :banner-color="openedMember.liveBannerColor"
        :socials="openedMember.socials"
        :rank="openedMember.rank"
        :rank-color="openedMember.rankColor"
        :threads-score="openedMember.threadsScore"
        :threads-factors="openedMember.threadsFactors"
        :badges="openedMember.badges"
        :badge-rank="openedMember.badgeRank"
        :roster-count="openedMember.rosterCount"
        :founder="openedMember.isFounder"
        :founder-title="openedMember.founderTitle"
        :founder-roles="openedMember.founderRoles"
        :active="panelOpen"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import PageHero from '../../components/PageHero.vue';
import MemberCard from '../../components/MemberCard.vue';
import Leaderboard from '../../lib/leaderboard.js';
import { fetchThreadsBoard, rankByBadgeCount } from '../../lib/threads-board.js';
import { colorForPercentile } from '../../lib/rank-color.js';
import { sb } from '../../lib/supabase-client.js';
import { playSfx } from '../../composables/useSfx.js';
import '../../assets/css/pages/members.css';

/* Roster markup + MEMBERS profile data are untouched from before —
   still small arrays / one plain object, same as ever. What changed
   is everything past "click a card": the popup used to render its
   own big banner/badges/stats markup directly; now it just resolves
   this member's data and hands it to the shared MemberCard.vue
   (about/MembersView.vue's popup + ProfileView.vue's own preview both
   use it now — see that component's header comment). */

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

const EMPTY = { tagline: '', about: '', isFounder: false, gradeSection: '', socials: [], avatar: null };

const MEMBERS = {
  'richmond-causaren': {
    name: 'Richmond P. Causaren', role: 'Club Adviser', ...EMPTY,
    about: 'The visionary who started it all. Sir Richmond founded the Digital Multimedia Arts Club, bringing together creative minds with a shared passion for digital media.',
    isFounder: true,
    founderTitle: 'DMAC Founder',
    founderRoles: 'Club Adviser · Founder',
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
    about: "The guy who actually builds stuff around here. If it's on the site, I probably made it.",
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

function initialsFor(name) {
  return (name || 'DMAC').trim().split(/\s+/).filter(Boolean).slice(0, 2)
    .map((p) => p[0]?.toUpperCase() || '').join('') || 'DMAC';
}

/* ── LIVE PROFILE DATA + BADGES + THREADS BOARD ────────────────── */
const liveProfiles = ref({});
const liveScores = ref([]);
const threadsBoard = ref([]);

async function loadLiveProfiles() {
  let { data, error } = await sb
    .from('members')
    .select('slug, nickname, bio, avatar_url, social_links, banner_url, banner_color')
    .in('slug', Object.keys(MEMBERS));

  if (error) {
    ({ data, error } = await sb
      .from('members')
      .select('slug, nickname, bio, avatar_url, social_links')
      .in('slug', Object.keys(MEMBERS)));
  }
  if (error) {
    console.error('MembersView: could not load live profile data —', error.message);
    return;
  }
  const map = {};
  for (const row of data || []) map[row.slug] = row;
  liveProfiles.value = map;
}

async function loadLiveScores() {
  try {
    liveScores.value = await Leaderboard.fetchScores();
  } catch (err) {
    console.error('MembersView: could not load live scores —', err.message);
  }
}

async function loadThreadsBoard() {
  try {
    threadsBoard.value = await fetchThreadsBoard();
  } catch (err) {
    console.error('MembersView: could not load Threads board —', err.message);
  }
}

function badgesForSlug(slug) {
  const stored = Leaderboard.getBadgesForSlug(liveScores.value, slug);
  const computed = Leaderboard.getCompletionStatus(liveScores.value, slug);
  return [...stored, ...computed];
}

/* ── CARD OPEN/CLOSE STATE ─────────────────────────────────────── */
const selectedId = ref(null);
const cardOpen = ref(false);
const panelOpen = ref(false);

const openedMember = computed(() => {
  if (!selectedId.value) return null;
  const base = MEMBERS[selectedId.value];
  if (!base) return null;

  const live = liveProfiles.value[selectedId.value];
  const name = live?.nickname?.trim() || base.name;
  const threadsRow = threadsBoard.value.find((r) => r.slug === selectedId.value);
  const percentile = threadsRow && threadsBoard.value.length > 1
    ? 1 - (threadsRow.rank - 1) / (threadsBoard.value.length - 1)
    : (threadsRow ? 1 : 0);
  const { rank: badgeRank, rosterCount } = rankByBadgeCount(liveScores.value, selectedId.value);

  const liveSocials = Array.isArray(live?.social_links) && live.social_links.length
    ? live.social_links.map((l) => ({ label: l?.label || '', url: l?.url || '' }))
    : [];

  return {
    name,
    initials: initialsFor(name),
    role: base.role,
    about: live?.bio?.trim() || base.about,
    avatarUrl: live?.avatar_url || (base.avatar ? `https://aztaryx.github.io/dmac-assets/avatars/${base.avatar}` : null),
    liveBannerUrl: live?.banner_url || null,
    liveBannerColor: live?.banner_color || null,
    socials: liveSocials,
    badges: badgesForSlug(selectedId.value),
    isFounder: !!base.isFounder,
    founderTitle: base.founderTitle,
    founderRoles: base.founderRoles,
    rank: threadsRow?.rank ?? null,
    rankColor: colorForPercentile(percentile),
    threadsScore: threadsRow?.score ?? null,
    threadsFactors: threadsRow?.factors ?? {},
    badgeRank,
    rosterCount,
  };
});

function openCard(memberId) {
  if (!MEMBERS[memberId]) return;
  playSfx('menuconfirm');
  selectedId.value = memberId;
  cardOpen.value = true;
  document.body.style.overflow = 'hidden';
  requestAnimationFrame(() => { panelOpen.value = true; });
}

function closeCard() {
  if (!cardOpen.value) return;
  playSfx('menuback');
  panelOpen.value = false;
  setTimeout(() => {
    cardOpen.value = false;
    document.body.style.overflow = '';
  }, 260);
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

onMounted(() => {
  document.addEventListener('keydown', onGlobalKeydown);
  loadLiveProfiles();
  loadLiveScores();
  loadThreadsBoard();
});

onBeforeUnmount(() => {
  document.removeEventListener('keydown', onGlobalKeydown);
  document.body.style.overflow = '';
});
</script>

<style scoped>
.member-popup-overlay {
  position: fixed;
  inset: 0;
  z-index: 900;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: rgba(8, 8, 12, 0);
  opacity: 0;
  visibility: hidden;
  pointer-events: none;
  transition: opacity 0.25s ease, background 0.25s ease, visibility 0.25s;
}
.member-popup-overlay.open {
  opacity: 1;
  visibility: visible;
  pointer-events: auto;
  background: rgba(8, 8, 12, 0.78);
  backdrop-filter: blur(4px);
}

.member-popup-panel {
  position: relative;
  width: min(560px, 100%);
  max-height: 86vh;
  overflow-y: auto;
  transform: scale(0.94) translateY(10px);
  opacity: 0;
  transition: transform 0.25s var(--ease-out, ease), opacity 0.25s ease;
}
.member-popup-panel.open {
  transform: scale(1) translateY(0);
  opacity: 1;
}

.member-popup-close {
  position: absolute;
  top: -14px;
  right: -14px;
  z-index: 3;
  width: 34px;
  height: 34px;
  border-radius: 50%;
  border: none;
  cursor: pointer;
  background: rgba(0, 0, 0, 0.6);
  color: #fff;
  font-size: 0.7rem;
}
</style>
