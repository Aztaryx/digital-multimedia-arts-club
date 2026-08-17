<template>
  <main class="profile-page">
    <div class="page-section profile-shell reveal" v-reveal>
      <SecHead>Admin Panel</SecHead>

      <p class="profile-intro">
        A dashboard for the whole site — newsletters, badges, the member roster, and
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
            <span>Newsletters + moderation, newest first</span>
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

      <!-- ── NEWSLETTERS ────────────────────────────────────────────── -->
      <section v-if="activeTab === 'announcements'" class="admin-tab-panel">
        <p class="profile-intro admin-section-intro">
          Post to the site's own dev journal — roadmap updates, sneak peeks, maintenance notices.
          Everything published here shows up in everyone's notifications panel and on the public
          Newsletters page. This is separate from the Announcements page (club news like meetings
          and results) — that one's edited by hand in Supabase for now, no admin UI yet.
        </p>

        <div class="profile-grid">
          <section class="profile-panel">
            <div class="profile-panel-head">
              <h3>New entry</h3>
              <span>Visible to every visitor</span>
            </div>

            <div class="seg-toggle" role="group" aria-label="Newsletter entry type">
              <button
                type="button"
                class="seg-btn"
                :class="{ active: kind === 'announcement' }"
                v-sfx-hover
                @click="kind = 'announcement'"
              >Update</button>
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

      <!-- ── CONTRIBUTION LOGGING ───────────────────────────────────── -->
      <section v-if="activeTab === 'contributions'" class="admin-tab-panel">
        <p class="profile-intro admin-section-intro">
          Log member contributions to the Bits system. Create drafts, queue them up,
          then submit the entire batch at once.
        </p>

        <div class="profile-grid">
          <section class="profile-panel">
            <div class="profile-panel-head">
              <h3>Log New Contribution</h3>
              <span>Create a draft entry</span>
            </div>

            <label class="profile-field">
              <span>Member</span>
              <select class="profile-input" v-model="contribMemberSlug">
                <option value="" disabled>Choose a member…</option>
                <option v-for="m in roster" :key="m.slug" :value="m.slug">{{ m.display_name }}</option>
              </select>
            </label>

            <label class="profile-field">
              <span>Domain</span>
              <select class="profile-input" v-model="contribDomain">
                <option value="">Choose…</option>
                <option value="Arts">Arts</option>
                <option value="Multimedia">Multimedia</option>
                <option value="Digital">Digital</option>
              </select>
            </label>

            <label class="profile-field">
              <span>Quality</span>
              <select class="profile-input" v-model="contribQuality">
                <option value="medium">Medium</option>
                <option value="low">Low</option>
                <option value="high">High</option>
              </select>
            </label>

            <label class="profile-field">
              <span>Weight (multiplier)</span>
              <input class="profile-input" type="number" step="0.1" v-model="contribWeight" placeholder="1.0" />
            </label>

            <label class="profile-field">
              <span>Description</span>
              <textarea class="profile-textarea" v-model="contribDescription" rows="3" placeholder="What did they do?"></textarea>
            </label>

            <button class="profile-btn" v-sfx-hover @click="createContribDraft">Create Draft</button>
          </section>

          <section class="profile-panel">
            <div class="profile-panel-head">
              <h3>Pending Drafts</h3>
              <span>Ready to submit</span>
            </div>

            <div v-if="contribDrafts.length" class="contribution-list">
              <div v-for="c in contribDrafts" :key="c.id" class="admin-announcement-row">
                <div class="admin-announcement-copy">
                  <strong>{{ c.member_name }} · {{ c.domain }}</strong>
                  <small>{{ c.quality }} · weight {{ c.weight }}</small>
                  <p>{{ c.description }}</p>
                </div>
                <button class="profile-btn profile-btn--danger" v-sfx-hover @click="removeContribDraft(c.id)">Delete</button>
              </div>
            </div>
            <p v-else class="forums-guest-note">No drafts yet.</p>

            <button v-if="contribDrafts.length" class="profile-btn" v-sfx-hover :disabled="submittingBatch" @click="submitContribBatch">
              {{ submittingBatch ? 'Submitting…' : `Submit All ${contribDrafts.length}` }}
            </button>
          </section>
        </div>
      </section>

      <!-- ── ATTENDANCE ─────────────────────────────────────────────── -->
      <section v-if="activeTab === 'attendance'" class="admin-tab-panel">
        <p class="profile-intro admin-section-intro">
          Log who showed up to an event. Backs Ping (bits-threads-spec.md §2.1) once Phase 5 ships —
          for now this just builds up real attendance history so Ping has something to compute from.
        </p>

        <div class="profile-grid">
          <section class="profile-panel">
            <div class="profile-panel-head">
              <h3>Pick an event</h3>
              <span>Or create a new one</span>
            </div>

            <label class="profile-field">
              <span>Event</span>
              <select class="profile-input" v-model="selectedEventId" @change="onEventPicked">
                <option value="">— Select an event —</option>
                <option v-for="e in attendanceEvents" :key="e.id" :value="e.id">
                  {{ e.event_date }} — {{ e.title }}
                </option>
              </select>
            </label>

            <button class="profile-btn profile-btn--ghost" v-sfx-hover @click="showNewEventForm = !showNewEventForm">
              {{ showNewEventForm ? 'Cancel' : '+ New event' }}
            </button>

            <template v-if="showNewEventForm">
              <label class="profile-field">
                <span>Title</span>
                <input class="profile-input" v-model="newEventTitle" maxlength="120" placeholder="e.g. General Assembly" />
              </label>
              <label class="profile-field">
                <span>Date</span>
                <input class="profile-input" type="date" v-model="newEventDate" />
              </label>
              <label class="profile-field">
                <span>Type</span>
                <select class="profile-input" v-model="newEventType">
                  <option value="">— none —</option>
                  <option value="competition">Competition</option>
                  <option value="assembly">Assembly</option>
                  <option value="meeting">Meeting</option>
                  <option value="showcase">Showcase</option>
                  <option value="other">Other</option>
                </select>
              </label>
              <label class="profile-field">
                <span>Location</span>
                <input class="profile-input" v-model="newEventLocation" placeholder="Optional" />
              </label>
              <label class="profile-field">
                <span>Description</span>
                <textarea class="profile-textarea" v-model="newEventDescription" rows="3" placeholder="Optional"></textarea>
              </label>
              <button class="profile-btn" v-sfx-hover :disabled="creatingEvent" @click="createEvent">Create event</button>
            </template>
          </section>

          <section class="profile-panel">
            <div class="profile-panel-head">
              <h3>Attendance</h3>
              <span v-if="selectedEventId">{{ presentCount }} present · {{ lateCount }} late · {{ absentCount }} absent</span>
            </div>

            <template v-if="!selectedEventId">
              <p class="forums-guest-note">Pick or create an event first.</p>
            </template>
            <template v-else>
              <div v-for="m in roster" :key="m.slug" class="admin-roster-row">
                <div class="admin-roster-id">
                  <strong>{{ m.display_name }}</strong>
                </div>
                <div class="seg-toggle" role="group" :aria-label="`Attendance for ${m.display_name}`">
                  <button
                    type="button"
                    class="seg-btn"
                    :class="{ active: attendanceEntries[m.slug] === 'present' }"
                    @click="attendanceEntries[m.slug] = 'present'"
                  >Present</button>
                  <button
                    type="button"
                    class="seg-btn"
                    :class="{ active: attendanceEntries[m.slug] === 'late' }"
                    @click="attendanceEntries[m.slug] = 'late'"
                  >Late</button>
                  <button
                    type="button"
                    class="seg-btn"
                    :class="{ active: attendanceEntries[m.slug] === 'absent' }"
                    @click="attendanceEntries[m.slug] = 'absent'"
                  >Absent</button>
                </div>
              </div>

              <button class="profile-btn" v-sfx-hover :disabled="savingAttendance" @click="saveAttendance">
                {{ savingAttendance ? 'Saving…' : 'Save attendance' }}
              </button>
            </template>
          </section>
        </div>
      </section>

      <!-- ── SEASON RESET ─────────────────────────────────────────── -->
      <section v-if="activeTab === 'season-reset'" class="admin-tab-panel">
        <p class="profile-intro admin-section-intro">
          <strong>⚠️ Destructive Operation</strong> — Start a new season. This will:
          <br />1. Save legacy records (final Threads score + best badges) for each member
          <br />2. Wipe all badge scores
          <br />3. Reset Bits ratings to 1500/350 for each domain, and Threads scores alongside them
          <br />4. Clear Works (keeping legacy ones)
          <br />5. Archive all Contributions
        </p>

        <section class="profile-panel">
          <div class="profile-panel-head">
            <h3>Confirm Season Reset</h3>
            <span>Legacy badges are auto-picked from current standings</span>
          </div>

          <p class="profile-intro">
            The 3 best badges per member (by tier) are picked automatically from their current
            standings below — there's no Works/portfolio data to pull best-works from yet (that
            feature hasn't been built), so <code>best_works</code> is saved empty for now and can
            be filled in by hand later against the <code>legacy_records</code> table if needed.
          </p>

          <label class="profile-field">
            <span>New Season Number</span>
            <input class="profile-input" type="number" v-model="seasonNumber" placeholder="2" />
          </label>

          <div class="season-reset-preview">
            <p>Will affect:</p>
            <ul>
              <li>{{ resetPreview.scoresWiped }} badge scores (wiped)</li>
              <li>{{ resetPreview.worksWiped }} works (cleared, except legacy)</li>
              <li>{{ resetPreview.contributionsArchived }} contributions (archived)</li>
            </ul>
          </div>

          <div class="season-member-list">
            <div v-for="m in legacyPreview" :key="m.slug" class="season-member-row">
              <strong>{{ m.display_name }}</strong>
              <small>
                Threads score {{ m.final_threads_score ?? '—' }} ·
                {{ m.best_badges.length ? m.best_badges.map(b => badgeLabelFor(b.badge_id)).join(', ') : 'no badges to preserve' }}
              </small>
            </div>
            <p v-if="!legacyPreview.length" class="forums-guest-note">Loading current standings…</p>
          </div>

          <button class="profile-btn profile-btn--danger" v-sfx-hover :disabled="resettingSeason" @click="startSeasonReset">
            {{ resettingSeason ? 'Resetting…' : '⚠️ Start New Season' }}
          </button>
        </section>
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

            <label v-if="scoreBadgeChoice === 'inseparable'" class="profile-field">
              <span>Paired with</span>
              <select class="profile-input" v-model="scorePartnerSlug">
                <option value="">— none —</option>
                <option v-for="m in roster" :key="m.slug" :value="m.slug">{{ m.display_name }}</option>
              </select>
            </label>

            <label class="profile-field">
              <span>Value</span>
              <input class="profile-input" type="number" step="any" v-model="scoreValue" placeholder="Numeric score" />
            </label>

            <label class="profile-field">
              <span>Issue # <em>(secret badges only — leave blank otherwise)</em></span>
              <input class="profile-input" type="number" step="1" min="1" v-model="scoreIssueNumber" placeholder="Leave blank for ordinary badges" />
              <small v-if="scoreBadgeChoice === 'new-game' && newGameSuggestedIssue">
                New Game is optionally issue-tracked by join order — this member joined
                #{{ newGameSuggestedIssue }}.
                <button type="button" class="forum-link-btn" @click="scoreIssueNumber = newGameSuggestedIssue">Use #{{ newGameSuggestedIssue }}</button>
              </small>
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
                  <small>{{ s.value }}{{ s.issue_number ? ` · issue #${s.issue_number}` : '' }}{{ s.partner_name ? ` · with ${s.partner_name}` : '' }} · {{ formatTime(s.created_at) }}</small>
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
import { ref, computed, reactive, onMounted } from 'vue';
import SecHead from '../components/SecHead.vue';
import MemberAuth from '../lib/member-auth.js';
import { sb } from '../lib/supabase-client.js';
import { playSfx } from '../composables/useSfx.js';
import Leaderboard from '../lib/leaderboard.js';
import contributionLogging from '../lib/contribution-logging.js';
import seasonReset from '../lib/season-reset.js';

/* ── TABS ──────────────────────────────────────────────────────────
   Everything below is fetched up front on mount rather than lazily
   per tab — roster/scores/announcements/mod log are all small,
   club-scale datasets, and the Overview tab's stat cards need all of
   them anyway, so there's no real win to deferring any one of them.
   Tab id 'announcements' is kept as-is (not renamed to 'newsletters')
   to avoid a churny rename across every ref/handler below — only the
   user-facing label and copy changed, per dmac-consolidated-plan.md
   §4/§11. */
const tabs = [
  { id: 'overview', label: 'Overview' },
  { id: 'announcements', label: 'Newsletters' },
  { id: 'contributions', label: 'Contribution Logging' },
  { id: 'attendance', label: 'Attendance' },
  { id: 'season-reset', label: 'Start New Season' },
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
const scorePartnerSlug = ref('');
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

// Contribution logging
const contribMemberSlug = ref('');
const contribDomain = ref('');
const contribQuality = ref('medium');
const contribWeight = ref('1.0');
const contribDescription = ref('');
const contribDrafts = ref([]);
const submittingBatch = ref(false);

// ── ATTENDANCE (Phase 1) ─────────────────────────────────────────
const attendanceEvents = ref([]);
const selectedEventId = ref('');
const attendanceEntries = reactive({}); // slug -> 'present' | 'late' | 'absent'
const savingAttendance = ref(false);
const showNewEventForm = ref(false);
const newEventTitle = ref('');
const newEventDate = ref('');
const newEventType = ref('');
const newEventLocation = ref('');
const newEventDescription = ref('');
const creatingEvent = ref(false);

const presentCount = computed(() => Object.values(attendanceEntries).filter((s) => s === 'present').length);
const lateCount = computed(() => Object.values(attendanceEntries).filter((s) => s === 'late').length);
const absentCount = computed(() => Object.values(attendanceEntries).filter((s) => s === 'absent').length);

// Season reset
const seasonNumber = ref('2');
const resetPreview = ref({ scoresWiped: 0, worksWiped: 0, contributionsArchived: 0 });
const legacyScores = ref([]);   // raw Leaderboard.fetchScores() output, for legacy-badge computation
const threadsScores = ref({});  // member_id -> current Threads score
const resettingSeason = ref(false);

// Site-wide counts for the Overview stat cards.
const siteStats = ref({ totalScores: 0, distinctBadges: 0, totalAnnouncements: 0, totalClubAnnouncements: 0, totalContributions: 0 });

const badgeOptions = computed(() => {
  const opts = {};
  for (const id of Object.keys(Leaderboard.BADGE_LABELS)) {
    opts[id] = Leaderboard.BADGE_LABELS[id] || id;
  }
  return opts;
});

const newGameSuggestedIssue = computed(() => {
  if (!scoreMemberSlug.value || !roster.value.length) return null;
  const withDates = roster.value.filter(m => m.created_at);
  if (!withDates.length) return null;
  const ordered = [...withDates].sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
  const idx = ordered.findIndex(m => m.slug === scoreMemberSlug.value);
  return idx === -1 ? null : idx + 1;
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
  loadResetPreview();
  loadLegacyCandidates();
  loadAttendanceEvents();
});

async function loadAnnouncements() {
  const { data, error } = await sb
    .from('announcements')
    .select('id, title, body, kind, created_at')
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) {
    status('Could not load newsletters — has the schema been fully migrated?', 'error');
    return;
  }
  announcements.value = data || [];
}

async function loadRoster() {
  const { data, error } = await sb
    .from('members')
    .select('id, slug, display_name, club_role, site_role, silenced_until, year_joined, created_at')
    .order('display_name');
  if (error) {
    console.error('AdminView: could not load roster —', error.message);
    return;
  }
  roster.value = data || [];
}

async function loadScores() {
  const { data, error } = await sb
    .from('scores')
    .select('id, badge_id, value, issue_number, awarded_on, created_at, members!member_id(slug, display_name), partner:members!partner_member_id(display_name)')
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
    partner_name: r.partner?.display_name || null,
  }));
}

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

async function loadAttendanceEvents() {
  const { data, error } = await sb
    .from('events')
    .select('id, title, event_date, event_type')
    .order('event_date', { ascending: false });

  if (error) {
    console.error('AdminView: could not load events —', error.message);
    return;
  }

  attendanceEvents.value = data || [];
}

// Default everyone to Present (matches how attendance is actually
// taken — mark the exceptions, not the whole roster), then overlay
// anything already logged for this event so reopening one to fix a
// mistake doesn't blow away what's already there.
async function onEventPicked() {
  for (const m of roster.value) attendanceEntries[m.slug] = 'present';
  if (!selectedEventId.value) return;

  const { data, error } = await sb.rpc('admin_get_attendance', {
    p_session_token: MemberAuth.getSessionToken(),
    p_event_id: selectedEventId.value,
  });
  if (error || !data?.success) return;

  const idToSlug = Object.fromEntries(roster.value.map((m) => [m.id, m.slug]));
  for (const entry of data.entries || []) {
    const slug = idToSlug[entry.member_id];
    if (slug) attendanceEntries[slug] = entry.status;
  }
}

async function createEvent() {
  if (!newEventTitle.value.trim() || !newEventDate.value) {
    status('An event needs a title and a date.', 'error');
    return;
  }
  creatingEvent.value = true;
  const { data, error } = await sb.rpc('admin_create_event', {
    p_session_token: MemberAuth.getSessionToken(),
    p_title: newEventTitle.value.trim(),
    p_event_date: newEventDate.value,
    p_description: newEventDescription.value.trim() || null,
    p_location: newEventLocation.value.trim() || null,
    p_event_type: newEventType.value || null,
  });
  creatingEvent.value = false;

  if (error || !data?.success) {
    status(data?.message || error?.message || 'Could not create event.', 'error');
    return;
  }

  newEventTitle.value = '';
  newEventDate.value = '';
  newEventType.value = '';
  newEventLocation.value = '';
  newEventDescription.value = '';
  showNewEventForm.value = false;
  status('Event created.', 'success');

  await loadAttendanceEvents();
  selectedEventId.value = data.event_id;
  await onEventPicked();
}

async function saveAttendance() {
  if (!selectedEventId.value) return;
  const slugToId = Object.fromEntries(roster.value.map((m) => [m.slug, m.id]));
  const entries = roster.value
    .map((m) => ({ member_id: slugToId[m.slug], status: attendanceEntries[m.slug] || 'present' }))
    .filter((e) => e.member_id);

  savingAttendance.value = true;
  const { data, error } = await sb.rpc('admin_log_attendance', {
    p_session_token: MemberAuth.getSessionToken(),
    p_event_id: selectedEventId.value,
    p_entries: entries,
  });
  savingAttendance.value = false;

  if (error || !data?.success) {
    status(data?.message || error?.message || 'Could not save attendance.', 'error');
    return;
  }
  status(`Attendance saved for ${data.entries_logged} member(s).`, 'success');
}

async function loadSiteStats() {
  try {
    // forum_threads/forum_posts are gone — see
    // dmac-forum-removal-and-role-merge.sql §1 — so the Overview
    // cards now surface club news + contributions instead, both of
    // which are real going forward. A query error on either (e.g.
    // the migration hasn't been run yet) just leaves that count at
    // its default rather than throwing.
    const [announceRes, clubRes, contribRes, scoreRes] = await Promise.all([
      sb.from('announcements').select('*', { count: 'exact', head: true }),
      sb.from('club_announcements').select('*', { count: 'exact', head: true }),
      sb.from('contributions').select('*', { count: 'exact', head: true }),
      sb.from('scores').select('badge_id', { count: 'exact' }),
    ]);
    siteStats.value = {
      totalAnnouncements: announceRes.count || 0,
      totalClubAnnouncements: clubRes.count || 0,
      totalContributions: contribRes.count || 0,
      totalScores: scoreRes.count || 0,
      distinctBadges: new Set((scoreRes.data || []).map((r) => r.badge_id)).size,
    };
  } catch (e) {
    console.error('AdminView: could not load site stats —', e);
  }
}

// admin_get_reset_preview — real counts instead of the hardcoded
// zeros this panel used to show. Silently leaves the preview at zero
// if the RPC hasn't been deployed yet (see
// dmac-forum-removal-and-role-merge.sql), same "missing migration"
// handling every other tab here already has.
async function loadResetPreview() {
  const { data, error } = await sb.rpc('admin_get_reset_preview', {
    p_session_token: MemberAuth.getSessionToken(),
  });
  if (error || !data?.success) return;
  resetPreview.value = {
    scoresWiped: data.scores_wiped || 0,
    worksWiped: data.works_wiped || 0,
    contributionsArchived: data.contributions_archived || 0,
  };
}

// Pulls current badge standings + Threads scores so the Season Reset
// tab can show (and submit) an auto-computed legacy pick — top 3
// badges per member by tier, plus their current Threads score. There
// is deliberately no "best works" data here: no Works/portfolio UI
// exists yet anywhere in the app, so that field goes to the RPC empty
// (see the note in the Season Reset tab itself).
async function loadLegacyCandidates() {
  try {
    legacyScores.value = await Leaderboard.fetchScores();
  } catch (err) {
    console.error('AdminView: could not load scores for legacy preview —', err.message);
  }
  const { data, error } = await sb.from('threads').select('member_id, score');
  if (!error) {
    const map = {};
    for (const row of data || []) map[row.member_id] = row.score;
    threadsScores.value = map;
  }
}

const legacyPreview = computed(() => {
  if (!roster.value.length) return [];
  return roster.value.map((m) => {
    const badges = Leaderboard.getBadgesForSlug(legacyScores.value, m.slug) || [];
    const top3 = [...badges]
      .sort((a, b) => (b.percent ?? -1) - (a.percent ?? -1))
      .slice(0, 3)
      .map((b) => ({ badge_id: b.badge_id, value: b.value }));
    const memberRow = legacyScores.value.find((s) => s.slug === m.slug);
    const memberId = memberRow?.member_id || null;
    return {
      slug: m.slug,
      display_name: m.display_name,
      member_id: memberId,
      final_threads_score: memberId ? (threadsScores.value[memberId] ?? null) : null,
      best_badges: top3,
      best_works: [], // no Works UI/data exists yet — see loadLegacyCandidates()
    };
  });
});

function badgeLabelFor(badgeId) {
  return Leaderboard.BADGE_LABELS[badgeId] || badgeId;
}

const roleCounts = computed(() => {
  const c = { admin: 0, member: 0 };
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
    sub: `${roleCounts.value.admin || 0} admin · ${roleCounts.value.member || 0} member`,
  },
  {
    label: 'Badges awarded',
    value: siteStats.value.totalScores,
    sub: `${siteStats.value.distinctBadges} distinct badge${siteStats.value.distinctBadges === 1 ? '' : 's'}`,
  },
  {
    label: 'Newsletter entries',
    value: siteStats.value.totalAnnouncements,
    sub: announcements.value[0] ? `last: ${formatTime(announcements.value[0].created_at)}` : 'none yet',
  },
  {
    label: 'Club announcements + contributions',
    value: siteStats.value.totalClubAnnouncements + siteStats.value.totalContributions,
    sub: `${siteStats.value.totalClubAnnouncements} news · ${siteStats.value.totalContributions} contributions`,
  },
  {
    label: 'Currently silenced',
    value: silencedMembers.value.length,
    sub: silencedMembers.value.length ? 'see Moderation tab' : 'all clear',
  },
]);

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
    p_partner_slug: scorePartnerSlug.value || null,
  });
  savingScore.value = false;

  if (error || !data?.success) {
    status(data?.message || error?.message || 'Could not save score — has dmac-admin-score-writing.sql been run?', 'error');
    return;
  }

  scoreValue.value = '';
  scoreIssueNumber.value = '';
  scoreAwardedOn.value = '';
  scorePartnerSlug.value = '';
  status('Score saved.', 'success');
  loadScores();
  loadSiteStats();
  loadLegacyCandidates();
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
  loadLegacyCandidates();
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
    status(data?.message || error?.message || 'Could not update role.', 'error');
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

// ── CONTRIBUTION LOGGING ────────────────────────────────────────
function createContribDraft() {
  if (!contribMemberSlug.value || !contribDomain.value) {
    status('Please fill in required fields.', 'error');
    return;
  }

  const member = roster.value.find(m => m.slug === contribMemberSlug.value);

  contribDrafts.value.push({
    id: crypto.randomUUID(),
    member_name: member?.display_name || contribMemberSlug.value,
    member_slug: contribMemberSlug.value,
    domain: contribDomain.value,
    quality: contribQuality.value,
    weight: contribWeight.value,
    description: contribDescription.value,
  });

  contribMemberSlug.value = '';
  contribDomain.value = '';
  contribQuality.value = 'medium';
  contribWeight.value = '1.0';
  contribDescription.value = '';

  status('Draft created. Add more or submit the batch.', 'success');
}

function removeContribDraft(id) {
  contribDrafts.value = contribDrafts.value.filter(c => c.id !== id);
  status('Draft removed.', 'info');
}

// Wired to the real admin_log_contribution RPC via lib/contribution-logging.js
// (that lib was already fully written — it just needed a caller and a
// working `sb` import, see supabase-client.js). admin_log_contribution
// takes a member_id (uuid), not a slug, so each draft's member row is
// looked up fresh here rather than trusting whatever was cached when
// the draft was created — a role/roster change between drafting and
// submitting shouldn't be able to submit against a stale id.
async function submitContribBatch() {
  if (contribDrafts.value.length === 0) {
    status('No drafts to submit.', 'error');
    return;
  }

  const token = MemberAuth.getSessionToken();
  submittingBatch.value = true;

  const { data: freshRoster, error: rosterError } = await sb.from('members').select('id, slug');
  if (rosterError) {
    submittingBatch.value = false;
    status('Could not resolve member ids — try again.', 'error');
    return;
  }
  const idBySlug = Object.fromEntries((freshRoster || []).map((r) => [r.slug, r.id]));

  let succeeded = 0;
  const failures = [];

  for (const draft of contribDrafts.value) {
    const memberId = idBySlug[draft.member_slug];
    if (!memberId) {
      failures.push(`${draft.member_name}: member no longer exists`);
      continue;
    }
    const result = await contributionLogging.createContribution(
      token,
      memberId,
      draft.domain,
      Number(draft.weight) || 1.0,
      draft.quality,
      draft.description || null,
    );
    if (result.success) succeeded++;
    else failures.push(`${draft.member_name}: ${result.error || 'unknown error'}`);
  }

  submittingBatch.value = false;

  if (failures.length) {
    status(`Submitted ${succeeded}/${contribDrafts.value.length}. Failed: ${failures.join('; ')}`, failures.length === contribDrafts.value.length ? 'error' : 'info');
  } else {
    status(`Submitted ${succeeded} contribution${succeeded === 1 ? '' : 's'}.`, 'success');
  }

  // Only clear the drafts that actually succeeded — a partial batch
  // failure shouldn't silently drop the ones that didn't go through.
  const failedNames = new Set(failures.map((f) => f.split(':')[0]));
  contribDrafts.value = contribDrafts.value.filter((d) => failedNames.has(d.member_name));

  await loadSiteStats();
}

// ── SEASON RESET ────────────────────────────────────────────────
async function startSeasonReset() {
  const seasonNum = parseInt(seasonNumber.value, 10);
  if (!seasonNum || seasonNum < 1) {
    status('Please enter a valid season number.', 'error');
    return;
  }

  const confirmed = confirm(
    `⚠️ This will reset the entire season.\n\n` +
    `${resetPreview.value.scoresWiped} badge scores will be wiped\n` +
    `${resetPreview.value.worksWiped} works will be cleared\n` +
    `${resetPreview.value.contributionsArchived} contributions will be archived\n\n` +
    `Legacy records will be saved for ${legacyPreview.value.filter(m => m.member_id).length} member(s) first.\n\n` +
    `Are you sure?`
  );
  if (!confirmed) return;

  resettingSeason.value = true;
  const token = MemberAuth.getSessionToken();

  // Only members we actually have a resolved member_id for can be
  // written into legacy_records — a member row missing from
  // legacyScores.value (e.g. never had a score row at all) just gets
  // skipped rather than sent up with a null id.
  const legacyData = legacyPreview.value
    .filter((m) => m.member_id)
    .map((m) => ({
      member_id: m.member_id,
      final_threads_score: m.final_threads_score,
      best_badges: m.best_badges,
      best_works: m.best_works,
    }));

  const result = await seasonReset.startNewSeason(token, seasonNum, legacyData);
  resettingSeason.value = false;

  if (!result.success) {
    status(result.error || 'Season reset failed.', 'error');
    return;
  }

  status('Season reset complete.', 'success');
  seasonNumber.value = String(seasonNum + 1);
  await Promise.all([loadSiteStats(), loadResetPreview(), loadLegacyCandidates(), loadScores()]);
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
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
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

/* ── CONTRIBUTION LOGGING ──────────────────────────────────── */
.contribution-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

/* ── SEASON RESET ───────────────────────────────────────── */
.season-reset-preview {
  padding: 12px;
  background: rgba(220, 38, 38, 0.1);
  border-left: 3px solid #dc2626;
  border-radius: 6px;
  margin: 1rem 0;
}

.season-reset-preview ul {
  margin: 0;
  padding-left: 1.5rem;
}

.season-member-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin: 1rem 0;
  max-height: 300px;
  overflow-y: auto;
}

.season-member-row {
  padding: 8px;
  background: rgba(255, 255, 255, 0.02);
  border-radius: 6px;
  border: 1px solid rgba(255, 255, 255, 0.08);
}

.season-member-row strong {
  display: block;
  margin-bottom: 4px;
}

.season-member-row small {
  color: rgba(240, 240, 240, 0.6);
  font-size: 0.85rem;
}
</style>
