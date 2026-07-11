<template>
  <main class="profile-page">
    <div class="page-section profile-shell reveal" v-reveal>
      <SecHead>Admin Panel</SecHead>

      <p class="profile-intro">
        A dashboard for the whole site — announcements, badges, the member roster, and
        moderation, all in one place.
      </p>

      <p v-if="statusMsg" class="profile-status" :class="statusType">{{ statusMsg }}</p>

      <!-- ── AT-A-GLANCE STATS ─────────────────────────────────────── -->
      <div class="admin-stats-grid">
        <div v-for="c in statCards" :key="c.label" class="admin-stat-card">
          <span class="admin-stat-value">{{ c.value }}</span>
          <span class="admin-stat-label">{{ c.label }}</span>
          <span class="admin-stat-sub">{{ c.sub }}</span>
        </div>
      </div>

      <!-- ── TABS ───────────────────────────────────────────────────── -->
      <div class="admin-tabs" role="tablist">
        <button
          v-for="t in tabs"
          :key="t.id"
          type="button"
          class="admin-tab-btn"
          :class="{ active: activeTab === t.id }"
          role="tab"
          :aria-selected="activeTab === t.id"
          v-sfx-hover
          @click="setTab(t.id)"
        >{{ t.label }}</button>
      </div>

      <!-- ── OVERVIEW ───────────────────────────────────────────────── -->
      <section v-if="activeTab === 'overview'" class="admin-tab-panel">
        <section class="profile-panel">
          <div class="profile-panel-head">
            <h3>Recent activity</h3>
            <span>Announcements + moderation, newest first</span>
          </div>

          <template v-if="recentActivity.length">
            <div v-for="item in recentActivity" :key="item.id" class="admin-announcement-row">
              <div class="admin-announcement-copy">
                <template v-if="item.type === 'announcement'">
                  <strong>{{ item.title }}</strong>
                  <small>{{ item.kind }} · {{ formatTime(item.created_at) }}</small>
                </template>
                <template v-else>
                  <strong>
                    <span class="mod-action-pill" :class="'mod-action-pill--' + item.action">{{ item.action }}</span>
                    {{ item.actor_name }} → {{ item.target_name }}
                  </strong>
                  <small>{{ formatTime(item.created_at) }}</small>
                  <p v-if="item.reason">{{ item.reason }}</p>
                </template>
              </div>
            </div>
          </template>
          <p v-else class="forums-guest-note">Nothing's happened yet.</p>
        </section>
      </section>

      <!-- ── ANNOUNCEMENTS ──────────────────────────────────────────── -->
      <section v-if="activeTab === 'announcements'" class="admin-tab-panel">
        <p class="profile-intro admin-section-intro">
          Post global announcements and maintenance notices — everything published here shows
          up in everyone's notifications panel.
        </p>

        <div class="profile-grid">
          <section class="profile-panel">
            <div class="profile-panel-head">
              <h3>New announcement</h3>
              <span>Visible to every visitor</span>
            </div>

            <div class="seg-toggle" role="group" aria-label="Announcement type">
              <button
                type="button"
                class="seg-btn"
                :class="{ active: kind === 'announcement' }"
                v-sfx-hover
                @click="kind = 'announcement'"
              >Announcement</button>
              <button
                type="button"
                class="seg-btn"
                :class="{ active: kind === 'maintenance' }"
                v-sfx-hover
                @click="kind = 'maintenance'"
              >Maintenance</button>
            </div>

            <label class="profile-field">
              <span>Title</span>
              <input class="profile-input" v-model="title" maxlength="120" placeholder="Short headline" />
            </label>

            <label class="profile-field">
              <span>Body</span>
              <textarea class="profile-textarea" v-model="body" maxlength="2000" rows="5" placeholder="What do people need to know?"></textarea>
            </label>

            <button class="profile-btn" v-sfx-hover :disabled="posting" @click="postAnnouncement">Publish</button>
          </section>

          <section class="profile-panel">
            <div class="profile-panel-head">
              <h3>Published</h3>
              <span>Latest first</span>
            </div>

            <template v-if="announcements.length">
              <div v-for="a in announcements" :key="a.id" class="admin-announcement-row">
                <div class="admin-announcement-copy">
                  <strong>{{ a.title }}</strong>
                  <small>{{ a.kind }} · {{ formatTime(a.created_at) }}</small>
                  <p>{{ a.body }}</p>
                </div>
                <button class="profile-btn profile-btn--danger" v-sfx-hover @click="removeAnnouncement(a.id)">Delete</button>
              </div>
            </template>
            <p v-else class="forums-guest-note">Nothing published yet.</p>
          </section>
        </div>
      </section>

      <!-- ── SCORES & BADGES ────────────────────────────────────────── -->
      <section v-if="activeTab === 'scores'" class="admin-tab-panel">
        <p class="profile-intro admin-section-intro">
          Award or correct a badge score — this writes directly to the <code>scores</code> table
          the leaderboard and member badges read from. Saving a score a member doesn't already
          have (or changing one they do) shows up in their notifications the next time they check.
        </p>

        <div class="profile-grid">
          <section class="profile-panel">
            <div class="profile-panel-head">
              <h3>Award / update score</h3>
              <span>Writes directly to scores</span>
            </div>

            <label class="profile-field">
              <span>Member</span>
              <select class="profile-input" v-model="scoreMemberSlug">
                <option value="" disabled>Choose a member…</option>
                <option v-for="m in roster" :key="m.slug" :value="m.slug">{{ m.display_name }}</option>
              </select>
            </label>

            <label class="profile-field">
              <span>Badge</span>
              <select class="profile-input" v-model="scoreBadgeChoice">
                <option value="" disabled>Choose a badge…</option>
                <option v-for="(label, id) in badgeOptions" :key="id" :value="id">{{ label }}</option>
                <option value="__custom">Custom badge id…</option>
              </select>
            </label>

            <label v-if="scoreBadgeChoice === '__custom'" class="profile-field">
              <span>Custom badge id</span>
              <input class="profile-input" v-model="scoreBadgeCustom" placeholder="e.g. pixelwizard" />
            </label>

            <label class="profile-field">
              <span>Value</span>
              <input class="profile-input" type="number" step="any" v-model="scoreValue" placeholder="Numeric score" />
            </label>

            <label class="profile-field">
              <span>Issue # <em>(secret badges only — leave blank otherwise)</em></span>
              <input class="profile-input" type="number" step="1" min="1" v-model="scoreIssueNumber" placeholder="Leave blank for ordinary badges" />
            </label>

            <label class="profile-field">
              <span>Awarded on</span>
              <input class="profile-input" type="date" v-model="scoreAwardedOn" />
            </label>

            <button class="profile-btn" v-sfx-hover :disabled="savingScore" @click="submitScore">Save score</button>
          </section>

          <section class="profile-panel">
            <div class="profile-panel-head">
              <h3>Recent scores</h3>
              <span>Latest first</span>
            </div>

            <template v-if="scores.length">
              <div v-for="s in scores" :key="s.id" class="admin-announcement-row">
                <div class="admin-announcement-copy">
                  <strong>{{ s.display_name || s.slug || 'Unlinked member' }} — {{ badgeLabelFor(s.badge_id) }}</strong>
                  <small>{{ s.value }}{{ s.issue_number ? ` · issue #${s.issue_number}` : '' }} · {{ formatTime(s.created_at) }}</small>
                </div>
                <button class="profile-btn profile-btn--danger" v-sfx-hover @click="removeScore(s.id)">Delete</button>
              </div>
            </template>
            <p v-else class="forums-guest-note">No scores yet.</p>
          </section>
        </div>
      </section>

      <!-- ── MEMBERS ────────────────────────────────────────────────── -->
      <section v-if="activeTab === 'members'" class="admin-tab-panel">
        <section class="profile-panel">
          <div class="profile-panel-head">
            <h3>Roster</h3>
            <span>{{ filteredRoster.length }} of {{ roster.length }}</span>
          </div>

          <input
            class="profile-input"
            v-model="memberSearch"
            placeholder="Search by name or slug…"
          />

          <template v-if="filteredRoster.length">
            <div v-for="m in filteredRoster" :key="m.slug" class="admin-roster-row">
              <div class="admin-roster-id">
                <strong>{{ m.display_name }}</strong>
                <small>{{ m.club_role || 'Member' }} · joined {{ m.year_joined }}</small>
                <span v-if="isSilenced(m)" class="admin-silence-badge">Silenced until {{ formatTime(m.silenced_until) }}</span>
              </div>

              <select
                class="profile-input admin-role-select"
                :class="'role-select--' + m.site_role"
                :value="m.site_role"
                :disabled="savingRoleFor === m.slug"
                @change="changeRole(m, $event.target.value)"
              >
                <option value="member">member</option>
                <option value="moderator">moderator</option>
                <option value="admin">admin</option>
              </select>

              <div class="admin-roster-actions">
                <button
                  v-if="isSilenced(m)"
                  class="profile-btn profile-btn--danger"
                  v-sfx-hover
                  :disabled="moderating"
                  @click="quickModerate(m.slug, 'unsilence')"
                >Unsilence</button>
                <button
                  class="profile-btn profile-btn--ghost"
                  v-sfx-hover
                  @click="toggleModerateForm(m.slug)"
                >{{ moderatingSlug === m.slug ? 'Cancel' : 'Moderate' }}</button>
              </div>

              <div v-if="moderatingSlug === m.slug" class="admin-moderate-form">
                <div class="seg-toggle" role="group" aria-label="Moderation action">
                  <button type="button" class="seg-btn" :class="{ active: modAction === 'warn' }" @click="modAction = 'warn'">Warn</button>
                  <button type="button" class="seg-btn" :class="{ active: modAction === 'silence' }" @click="modAction = 'silence'">Silence</button>
                </div>
                <input class="profile-input" v-model="modReason" placeholder="Reason (optional)" />
                <input
                  v-if="modAction === 'silence'"
                  class="profile-input"
                  type="number"
                  min="1"
                  v-model="modHours"
                  placeholder="Hours (default 24)"
                />
                <button class="profile-btn" v-sfx-hover :disabled="moderating" @click="submitModerate(m.slug)">Confirm</button>
              </div>
            </div>
          </template>
          <p v-else class="forums-guest-note">No members match "{{ memberSearch }}".</p>
        </section>
      </section>

      <!-- ── MODERATION ─────────────────────────────────────────────── -->
      <section v-if="activeTab === 'moderation'" class="admin-tab-panel">
        <section class="profile-panel">
          <div class="profile-panel-head">
            <h3>Active silences</h3>
            <span>{{ silencedMembers.length }} right now</span>
          </div>

          <template v-if="silencedMembers.length">
            <div v-for="m in silencedMembers" :key="m.slug" class="admin-announcement-row">
              <div class="admin-announcement-copy">
                <strong>{{ m.display_name }}</strong>
                <small>Silenced until {{ formatTime(m.silenced_until) }}</small>
              </div>
              <button class="profile-btn profile-btn--danger" v-sfx-hover :disabled="moderating" @click="quickModerate(m.slug, 'unsilence')">Unsilence</button>
            </div>
          </template>
          <p v-else class="forums-guest-note">Nobody's silenced right now.</p>
        </section>

        <section class="profile-panel">
          <div class="profile-panel-head">
            <h3>Full moderation log</h3>
            <span>Latest first · every member</span>
          </div>

          <template v-if="modLog.length">
            <div v-for="e in modLog" :key="e.id" class="admin-announcement-row">
              <div class="admin-announcement-copy">
                <strong>
                  <span class="mod-action-pill" :class="'mod-action-pill--' + e.action">{{ e.action }}</span>
                  {{ e.actor_name }} → {{ e.target_name }}
                </strong>
                <small>{{ formatTime(e.created_at) }}</small>
                <p v-if="e.reason">{{ e.reason }}</p>
              </div>
            </div>
          </template>
          <p v-else class="forums-guest-note">No moderation actions yet.</p>
        </section>
      </section>
    </div>
  </main>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import SecHead from '../components/SecHead.vue';
import MemberAuth from '../lib/member-auth.js';
import { sb } from '../lib/supabase-client.js';
import { playSfx } from '../composables/useSfx.js';
import Leaderboard from '../lib/leaderboard.js';

/* ── TABS ──────────────────────────────────────────────────────────
   Everything below is fetched up front on mount rather than lazily
   per tab — roster/scores/announcements/mod log are all small,
   club-scale datasets, and the Overview tab's stat cards need all of
   them anyway, so there's no real win to deferring any one of them. */
const tabs = [
  { id: 'overview', label: 'Overview' },
  { id: 'announcements', label: 'Announcements' },
  { id: 'scores', label: 'Badges & Scores' },
  { id: 'members', label: 'Members' },
  { id: 'moderation', label: 'Moderation' },
];
const activeTab = ref('overview');
function setTab(id) {
  if (id === activeTab.value) return;
  playSfx('menutap');
  activeTab.value = id;
}

const kind = ref('announcement');
const title = ref('');
const body = ref('');
const posting = ref(false);
const announcements = ref([]);

const roster = ref([]);
const scores = ref([]);
const scoreMemberSlug = ref('');
const scoreBadgeChoice = ref('');
const scoreBadgeCustom = ref('');
const scoreValue = ref('');
const scoreIssueNumber = ref('');
const scoreAwardedOn = ref('');
const savingScore = ref(false);

const modLog = ref([]);
const memberSearch = ref('');
const savingRoleFor = ref('');
const moderatingSlug = ref('');
const modAction = ref('warn');
const modReason = ref('');
const modHours = ref('');
const moderating = ref(false);

// Site-wide counts for the Overview stat cards. Everything here reads
// from tables that have been publicly SELECT-able since their own
// schema files (members, scores, announcements, forum_threads,
// forum_posts) — no new RPC needed just to count rows.
const siteStats = ref({ totalScores: 0, distinctBadges: 0, totalAnnouncements: 0, totalThreads: 0, totalPosts: 0 });

// Known badge_ids + labels come from lib/leaderboard.js — the same
// single source of truth the leaderboard itself, about/MembersView.vue,
// and RightPanel's badges list all already read from. "Custom badge
// id…" in the template covers anything not registered there yet.
const badgeOptions = computed(() => {
  const opts = {};
  for (const id of Object.keys(Leaderboard.BADGES)) {
    opts[id] = Leaderboard.BADGE_LABELS[id] || id;
  }
  return opts;
});

const statusMsg = ref('');
const statusType = ref('info');

function status(msg, type = 'info') {
  statusMsg.value = msg;
  statusType.value = type;
}

onMounted(() => {
  loadAnnouncements();
  loadRoster();
  loadScores();
  loadModerationLog();
  loadSiteStats();
});

async function loadAnnouncements() {
  const { data, error } = await sb
    .from('announcements')
    .select('id, title, body, kind, created_at')
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) {
    status('Could not load announcements — has dmac-site-polish-schema.sql been run?', 'error');
    return;
  }
  announcements.value = data || [];
}

// club_role/site_role/silenced_until/year_joined are all separately
// column-granted (dmac-member-auth-schema.sql,
// dmac-moderation-silence-enforcement.sql, dmac-profile-sync-fix.sql)
// — this one query backs the score-award member picker, the Members
// tab roster, and the Overview role-breakdown/silenced-count cards.
async function loadRoster() {
  const { data, error } = await sb
    .from('members')
    .select('slug, display_name, club_role, site_role, silenced_until, year_joined')
    .order('display_name');
  if (error) {
    console.error('AdminView: could not load roster —', error.message);
    return;
  }
  roster.value = data || [];
}

// scores is publicly readable (dmac-social-schema-core.sql), and the
// members(slug, display_name) embed needs the real member_id FK from
// dmac-scores-members-link.sql — same query shape lib/leaderboard.js's
// fetchScores() uses, just with the columns this list actually shows.
async function loadScores() {
  const { data, error } = await sb
    .from('scores')
    .select('id, badge_id, value, issue_number, awarded_on, created_at, members!member_id(slug, display_name)')
    .order('created_at', { ascending: false })
    .limit(100);
  if (error) {
    status('Could not load scores — has dmac-scores-members-link.sql been run?', 'error');
    return;
  }
  scores.value = (data || []).map((r) => ({
    id: r.id,
    badge_id: r.badge_id,
    value: r.value,
    issue_number: r.issue_number,
    awarded_on: r.awarded_on,
    created_at: r.created_at,
    slug: r.members?.slug || null,
    display_name: r.members?.display_name || null,
  }));
}

// admin_list_moderation_log is the admin-scoped sibling of
// list_my_moderation_log — same shape, but every member's history
// instead of just the caller's own (dmac-admin-dashboard-schema.sql).
// Silently no-ops with an empty list if that file hasn't been run yet
// or the caller isn't an admin, same as the rest of this view.
async function loadModerationLog() {
  const { data, error } = await sb.rpc('admin_list_moderation_log', {
    p_session_token: MemberAuth.getSessionToken(),
    p_limit: 100,
  });
  if (error || !data?.success) {
    console.error('AdminView: could not load moderation log —', data?.message || error?.message);
    return;
  }
  modLog.value = data.entries || [];
}

async function loadSiteStats() {
  try {
    const [announceRes, threadRes, postRes, scoreRes] = await Promise.all([
      sb.from('announcements').select('*', { count: 'exact', head: true }),
      sb.from('forum_threads').select('*', { count: 'exact', head: true }),
      sb.from('forum_posts').select('*', { count: 'exact', head: true }),
      sb.from('scores').select('badge_id', { count: 'exact' }),
    ]);
    siteStats.value = {
      totalAnnouncements: announceRes.count || 0,
      totalThreads: threadRes.count || 0,
      totalPosts: postRes.count || 0,
      totalScores: scoreRes.count || 0,
      distinctBadges: new Set((scoreRes.data || []).map((r) => r.badge_id)).size,
    };
  } catch (e) {
    console.error('AdminView: could not load site stats —', e);
  }
}

function badgeLabelFor(badgeId) {
  return Leaderboard.BADGE_LABELS[badgeId] || badgeId;
}

const roleCounts = computed(() => {
  const c = { admin: 0, moderator: 0, member: 0 };
  for (const m of roster.value) c[m.site_role] = (c[m.site_role] || 0) + 1;
  return c;
});

function isSilenced(m) {
  return !!m.silenced_until && new Date(m.silenced_until) > new Date();
}

const silencedMembers = computed(() => roster.value.filter(isSilenced));

const filteredRoster = computed(() => {
  const q = memberSearch.value.trim().toLowerCase();
  if (!q) return roster.value;
  return roster.value.filter(
    (m) => m.display_name.toLowerCase().includes(q) || m.slug.toLowerCase().includes(q)
  );
});

const statCards = computed(() => [
  {
    label: 'Members',
    value: roster.value.length,
    sub: `${roleCounts.value.admin || 0} admin · ${roleCounts.value.moderator || 0} mod · ${roleCounts.value.member || 0} member`,
  },
  {
    label: 'Badges awarded',
    value: siteStats.value.totalScores,
    sub: `${siteStats.value.distinctBadges} distinct badge${siteStats.value.distinctBadges === 1 ? '' : 's'}`,
  },
  {
    label: 'Forum threads',
    value: siteStats.value.totalThreads,
    sub: `${siteStats.value.totalPosts} replies total`,
  },
  {
    label: 'Announcements',
    value: siteStats.value.totalAnnouncements,
    sub: announcements.value[0] ? `last: ${formatTime(announcements.value[0].created_at)}` : 'none yet',
  },
  {
    label: 'Currently silenced',
    value: silencedMembers.value.length,
    sub: silencedMembers.value.length ? 'see Moderation tab' : 'all clear',
  },
]);

// Merges the two event streams this dashboard actually has timestamps
// for (announcements + moderation actions) into one newest-first feed.
// Forum posts/scores have created_at too, but folding every score
// correction and forum reply in here would drown out the signal —
// those already have their own "latest first" lists on their own tabs.
const recentActivity = computed(() => {
  const items = [];
  for (const a of announcements.value.slice(0, 8)) {
    items.push({ id: `ann-${a.id}`, type: 'announcement', kind: a.kind, title: a.title, created_at: a.created_at });
  }
  for (const m of modLog.value.slice(0, 8)) {
    items.push({
      id: `mod-${m.id}`,
      type: 'moderation',
      action: m.action,
      actor_name: m.actor_name,
      target_name: m.target_name,
      reason: m.reason,
      created_at: m.created_at,
    });
  }
  return items.sort((a, b) => new Date(b.created_at) - new Date(a.created_at)).slice(0, 6);
});

async function submitScore() {
  playSfx('menuclick');

  const badgeId = scoreBadgeChoice.value === '__custom'
    ? scoreBadgeCustom.value.trim()
    : scoreBadgeChoice.value;

  if (!scoreMemberSlug.value) {
    status('Choose a member first.', 'error');
    return;
  }
  if (!badgeId) {
    status('A badge id is required.', 'error');
    return;
  }
  if (scoreValue.value === '' || scoreValue.value === null || isNaN(Number(scoreValue.value))) {
    status('Enter a numeric value.', 'error');
    return;
  }

  savingScore.value = true;
  const { data, error } = await sb.rpc('admin_upsert_score', {
    p_session_token: MemberAuth.getSessionToken(),
    p_member_slug: scoreMemberSlug.value,
    p_badge_id: badgeId,
    p_value: Number(scoreValue.value),
    p_issue_number: scoreIssueNumber.value === '' ? null : Number(scoreIssueNumber.value),
    p_awarded_on: scoreAwardedOn.value || null,
  });
  savingScore.value = false;

  if (error || !data?.success) {
    status(data?.message || error?.message || 'Could not save score — has dmac-admin-score-writing.sql been run?', 'error');
    return;
  }

  scoreValue.value = '';
  scoreIssueNumber.value = '';
  scoreAwardedOn.value = '';
  status('Score saved.', 'success');
  loadScores();
  loadSiteStats();
}

async function removeScore(id) {
  playSfx('menuclick');
  const { data, error } = await sb.rpc('admin_delete_score', {
    p_session_token: MemberAuth.getSessionToken(),
    p_score_id: id,
  });

  if (error || !data?.success) {
    status(data?.message || error?.message || 'Could not delete.', 'error');
    return;
  }
  status('Deleted.', 'success');
  loadScores();
  loadSiteStats();
}

async function postAnnouncement() {
  playSfx('menuclick');
  if (!title.value.trim() || !body.value.trim()) {
    status('Both a title and a body are required.', 'error');
    return;
  }

  posting.value = true;
  const { data, error } = await sb.rpc('create_announcement', {
    p_session_token: MemberAuth.getSessionToken(),
    p_title: title.value.trim(),
    p_body: body.value.trim(),
    p_kind: kind.value,
  });
  posting.value = false;

  if (error || !data?.success) {
    status(data?.message || error?.message || 'Could not publish.', 'error');
    return;
  }

  title.value = '';
  body.value = '';
  status('Published.', 'success');
  loadAnnouncements();
  loadSiteStats();
}

async function removeAnnouncement(id) {
  playSfx('menuclick');
  const { data, error } = await sb.rpc('delete_announcement', {
    p_session_token: MemberAuth.getSessionToken(),
    p_announcement_id: id,
  });

  if (error || !data?.success) {
    status(data?.message || error?.message || 'Could not delete.', 'error');
    return;
  }
  status('Deleted.', 'success');
  loadAnnouncements();
  loadSiteStats();
}

// admin_set_role is new (dmac-admin-dashboard-schema.sql) — refuses
// to demote the last remaining admin server-side, so the worst a bad
// click does here is an error message, not a locked-out site.
async function changeRole(m, newRole) {
  if (newRole === m.site_role) return;
  playSfx('menuclick');
  savingRoleFor.value = m.slug;
  const { data, error } = await sb.rpc('admin_set_role', {
    p_session_token: MemberAuth.getSessionToken(),
    p_target_slug: m.slug,
    p_new_role: newRole,
  });
  savingRoleFor.value = '';

  if (error || !data?.success) {
    status(data?.message || error?.message || 'Could not update role — has dmac-admin-dashboard-schema.sql been run?', 'error');
    return;
  }
  m.site_role = newRole;
  status(`${m.display_name} is now ${newRole}.`, 'success');
}

function toggleModerateForm(slug) {
  if (moderatingSlug.value === slug) {
    moderatingSlug.value = '';
    return;
  }
  moderatingSlug.value = slug;
  modAction.value = 'warn';
  modReason.value = '';
  modHours.value = '';
}

async function submitModerate(slug) {
  const hours = modAction.value === 'silence' ? (Number(modHours.value) || 24) : undefined;
  await runModerate(slug, modAction.value, modReason.value.trim() || null, hours);
  moderatingSlug.value = '';
}

async function quickModerate(slug, action) {
  await runModerate(slug, action, null);
}

// Wraps the existing member_moderate RPC (dmac-moderation-silence-
// enforcement.sql) — no new SQL needed for warn/silence/unsilence
// themselves, just a UI that actually calls it.
async function runModerate(slug, action, reason, hours) {
  playSfx(action === 'warn' ? 'staffwarning' : 'staffsilence');
  moderating.value = true;
  const payload = {
    p_session_token: MemberAuth.getSessionToken(),
    p_target_slug: slug,
    p_action: action,
    p_reason: reason,
  };
  if (hours !== undefined) payload.p_duration_hours = hours;

  const { data, error } = await sb.rpc('member_moderate', payload);
  moderating.value = false;

  if (error || !data?.success) {
    status(data?.message || error?.message || 'Could not apply that action.', 'error');
    return;
  }
  status('Moderation action applied.', 'success');
  await Promise.all([loadRoster(), loadModerationLog()]);
}

function formatTime(ts) {
  try {
    return new Date(ts).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' });
  } catch (_) {
    return '';
  }
}
</script>

<style scoped>
.profile-shell {
  gap: 22px;
}

.profile-intro {
  max-width: 820px;
  color: rgba(240, 240, 240, 0.72);
  line-height: 1.7;
  font-size: 1rem;
}

.admin-section-intro {
  margin-top: 6px;
}

.profile-field span em {
  font-style: normal;
  font-weight: 400;
  text-transform: none;
  letter-spacing: 0;
  color: rgba(240, 240, 240, 0.4);
  font-size: 0.72rem;
}

.profile-intro code {
  font-family: var(--font2, monospace);
  background: rgba(255, 255, 255, 0.08);
  padding: 1px 6px;
  border-radius: 6px;
  font-size: 0.9em;
}

/* ── STAT CARDS ──────────────────────────────────────────────────── */
.admin-stats-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 14px;
}

.admin-stat-card {
  border-radius: 20px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.04);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.03);
  padding: 16px 18px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.admin-stat-value {
  font-family: var(--font);
  font-weight: 700;
  font-size: 1.8rem;
  line-height: 1.1;
  background: linear-gradient(135deg, var(--orange), var(--purple));
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
}

.admin-stat-label {
  font-size: 0.76rem;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: rgba(240, 240, 240, 0.62);
}

.admin-stat-sub {
  font-size: 0.78rem;
  color: rgba(240, 240, 240, 0.48);
}

/* ── TABS ────────────────────────────────────────────────────────── */
.admin-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  padding-bottom: 14px;
}

.admin-tab-btn {
  font: inherit;
  font-size: 0.85rem;
  color: rgba(240, 240, 240, 0.66);
  background: rgba(8, 8, 12, 0.5);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 999px;
  padding: 9px 16px;
  cursor: pointer;
  transition: border-color 0.2s ease, color 0.2s ease, background 0.2s ease;
}

.admin-tab-btn:hover {
  border-color: rgba(249, 115, 22, 0.5);
  color: #fff;
}

.admin-tab-btn.active {
  background: linear-gradient(135deg, var(--orange), var(--purple));
  border-color: transparent;
  color: #fff;
}

.admin-tab-panel {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.profile-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 18px;
}

.profile-panel {
  border-radius: 24px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.04);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.03);
  padding: 18px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.profile-panel-head {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 12px;
}

.profile-panel-head h3 {
  margin: 0;
  line-height: 1.1;
  font-size: 1rem;
}

.profile-panel-head span {
  color: rgba(240, 240, 240, 0.58);
}

.profile-field {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.profile-field span {
  font-size: 0.76rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: rgba(240, 240, 240, 0.55);
}

/* Segmented button toggle — swapped in for the old "Type" label +
   <select>, since a two-option dropdown is just two buttons wearing a
   trenchcoat: one click either way instead of open-menu-then-click. */
.seg-toggle {
  display: flex;
  gap: 8px;
}

.seg-btn {
  flex: 1;
  font: inherit;
  font-size: 0.85rem;
  color: rgba(240, 240, 240, 0.7);
  background: rgba(8, 8, 12, 0.58);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 16px;
  padding: 10px 14px;
  cursor: pointer;
  transition: border-color 0.2s ease, color 0.2s ease, background 0.2s ease;
}

.seg-btn:hover {
  border-color: rgba(249, 115, 22, 0.5);
  color: #fff;
}

.seg-btn.active {
  background: linear-gradient(135deg, var(--orange), var(--purple));
  border-color: transparent;
  color: #fff;
}

.profile-input,
.profile-textarea {
  width: 100%;
  font: inherit;
  color: #f7f4ee;
  border-radius: 16px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  background: rgba(8, 8, 12, 0.58);
  padding: 12px 14px;
  outline: none;
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}

.profile-textarea {
  resize: vertical;
  min-height: 120px;
}

.profile-input:focus,
.profile-textarea:focus {
  border-color: rgba(249, 115, 22, 0.7);
  box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.18);
}

select.profile-input option {
  background: #16161c;
}

.profile-btn {
  align-self: flex-start;
  font: inherit;
  border: none;
  cursor: pointer;
  color: #fff;
  border-radius: 999px;
  padding: 11px 18px;
  background: linear-gradient(135deg, var(--orange), var(--purple));
  box-shadow: 0 10px 24px rgba(76, 29, 149, 0.22);
}

.profile-btn:disabled {
  opacity: 0.6;
  cursor: default;
}

.profile-btn--danger {
  background: rgba(184, 61, 61, 0.16);
  color: #ffb0b0;
  border: 1px solid rgba(255, 130, 130, 0.2);
  box-shadow: none;
}

.profile-btn--ghost {
  background: rgba(255, 255, 255, 0.05);
  color: rgba(240, 240, 240, 0.8);
  border: 1px solid rgba(255, 255, 255, 0.12);
  box-shadow: none;
}

.profile-status {
  padding: 11px 14px;
  border-radius: 18px;
  font-size: 0.9rem;
  border: 1px solid transparent;
}

.profile-status.success {
  background: rgba(20, 61, 31, 0.76);
  color: #9ff0b4;
  border-color: rgba(159, 240, 180, 0.16);
}

.profile-status.error {
  background: rgba(61, 20, 20, 0.78);
  color: #ffb0b0;
  border-color: rgba(255, 176, 176, 0.16);
}

.profile-status.info {
  background: rgba(26, 42, 61, 0.78);
  color: #aed7ff;
  border-color: rgba(174, 215, 255, 0.16);
}

.admin-announcement-row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  padding: 14px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
}

.admin-announcement-copy {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.admin-announcement-copy small {
  color: rgba(240, 240, 240, 0.55);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-size: 0.68rem;
}

.admin-announcement-copy p {
  margin: 0;
  color: rgba(240, 240, 240, 0.78);
  line-height: 1.5;
  font-size: 0.9rem;
  white-space: pre-wrap;
}

/* ── MEMBERS / ROSTER ────────────────────────────────────────────── */
.admin-roster-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
  padding: 14px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
}

.admin-roster-id {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 180px;
  flex: 1;
}

.admin-roster-id small {
  color: rgba(240, 240, 240, 0.55);
  font-size: 0.75rem;
}

.admin-role-select {
  width: auto;
  padding: 8px 12px;
  font-size: 0.82rem;
  text-transform: capitalize;
}

.role-select--admin { border-color: rgba(239, 68, 68, 0.4); color: #f87171; }
.role-select--moderator { border-color: rgba(168, 85, 247, 0.4); color: #c084fc; }

.admin-roster-actions {
  display: flex;
  gap: 8px;
}

.admin-silence-badge {
  align-self: flex-start;
  font-size: 0.7rem;
  letter-spacing: 0.04em;
  color: #ffb0b0;
  background: rgba(184, 61, 61, 0.16);
  border: 1px solid rgba(255, 130, 130, 0.2);
  border-radius: 999px;
  padding: 3px 10px;
}

.admin-moderate-form {
  flex-basis: 100%;
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: center;
  padding-top: 10px;
  border-top: 1px dashed rgba(255, 255, 255, 0.08);
}

.admin-moderate-form .profile-input {
  width: auto;
  flex: 1;
  min-width: 160px;
}

/* ── MODERATION ACTION PILLS ─────────────────────────────────────── */
.mod-action-pill {
  display: inline-block;
  font-size: 0.68rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  padding: 2px 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.mod-action-pill--warn {
  background: rgba(234, 179, 8, 0.16);
  color: #eab308;
}

.mod-action-pill--silence {
  background: rgba(239, 68, 68, 0.16);
  color: #f87171;
}

.mod-action-pill--unsilence {
  background: rgba(74, 222, 128, 0.16);
  color: #4ade80;
}

@media (max-width: 1040px) {
  .profile-grid {
    grid-template-columns: 1fr;
  }
  .admin-stats-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .admin-announcement-row {
    flex-direction: column;
  }
  .admin-stats-grid {
    grid-template-columns: 1fr;
  }
  .admin-roster-row {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
