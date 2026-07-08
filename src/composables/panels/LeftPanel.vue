<template>
  <Teleport to="body">
    <div class="side-overlay side-overlay--left" :class="{ open: Panels.leftOpen.value }" @click="onOverlayClick">
      <div class="side-panel side-panel--left" @click.stop>
        <div class="side-panel-head">
          <div class="side-tabs">
            <button
              class="side-tab"
              :class="{ active: Panels.leftTab.value === 'forums' }"
              @click="Panels.leftTab.value = 'forums'"
            >Forums</button>
            <button
              class="side-tab"
              :class="{ active: Panels.leftTab.value === 'dms' }"
              @click="Panels.leftTab.value = 'dms'"
            >DMs</button>
          </div>
          <button class="side-panel-close" aria-label="Close" v-sfx-hover @click="Panels.closeAll">✕</button>
        </div>

        <!-- ══════════════ FORUMS TAB ══════════════
             Front-end shell only — no threads/posts schema exists yet.
             See dmac-social-schema.sql for what DOES have a backend
             (the DMs tab, right below). -->
        <div v-if="Panels.leftTab.value === 'forums'" class="side-panel-body">
          <div class="forums-head">
            <p class="forums-intro">Read by everyone. Starting a thread needs a member login.</p>
            <span class="forums-beta">Beta</span>
          </div>

          <div v-if="isLoggedIn" class="forum-composer-row">
            <button class="forum-btn forum-btn--primary" v-sfx-hover @click="composerOpen = !composerOpen">
              {{ composerOpen ? 'Cancel' : '+ New thread' }}
            </button>
          </div>
          <p v-else class="forums-guest-note">
            <router-link to="/login" @click="Panels.closeAll">Log in</router-link> as a member to start a thread.
          </p>

          <section v-if="composerOpen" class="forum-composer">
            <label class="forum-field">
              <span>Title</span>
              <input class="forum-input" v-model="draftTitle" maxlength="120" placeholder="What's this thread about?" />
            </label>
            <label class="forum-field">
              <span>Message</span>
              <textarea class="forum-input forum-textarea" v-model="draftBody" maxlength="2000" rows="3" placeholder="Say more…"></textarea>
            </label>
            <div class="forum-composer-actions">
              <button class="forum-btn forum-btn--primary" v-sfx-hover @click="submitDraft">Post</button>
            </div>
            <p v-if="composerStatus" class="forums-guest-note">{{ composerStatus }}</p>
          </section>

          <section class="forum-thread-list">
            <article v-for="thread in threads" :key="thread.id" class="forum-thread-card" v-sfx-hover>
              <div class="forum-thread-top">
                <span v-if="thread.pinned" class="forum-pin">Pinned</span>
                <h3 class="forum-thread-title">{{ thread.title }}</h3>
              </div>
              <p class="forum-thread-snippet">{{ thread.snippet }}</p>
              <div class="forum-thread-meta">
                <span>{{ thread.author }}</span><span>·</span>
                <span>{{ thread.replies }} {{ thread.replies === 1 ? 'reply' : 'replies' }}</span><span>·</span>
                <span>{{ thread.lastActive }}</span>
              </div>
            </article>
          </section>
        </div>

        <!-- ══════════════ DMs TAB ══════════════
             This one's real — send_direct_message() / get_conversation()
             from dmac-social-schema.sql, not mock data. The one catch:
             those RPCs only succeed between people with an ACCEPTED
             friendships row, and there's currently no RPC anywhere
             that lets a password-only (Tier A) member create one —
             the friendships table's RLS policies are auth.uid()-gated,
             which only Google-linked sessions have. So this UI is
             wired to the real thing, but will honestly report "You
             can only message friends" until a friend-request RPC
             exists. Flagging that as a known gap, not a bug in this
             panel. -->
        <div v-else class="side-panel-body">
          <div v-if="!isLoggedIn" class="dm-empty-state">
            <p class="forums-guest-note"><router-link to="/login" @click="Panels.closeAll">Log in</router-link> to send and receive DMs.</p>
          </div>
          <template v-else>
            <label class="forum-field dm-picker">
              <span>Message</span>
              <select class="forum-input" v-model="dmTargetSlug" @change="loadConversation">
                <option value="" disabled>Choose a member…</option>
                <option v-for="p in roster" :key="p.slug" :value="p.slug">{{ p.display_name }}</option>
              </select>
            </label>

            <div v-if="dmTargetSlug" class="dm-thread">
              <div class="dm-messages" ref="dmScrollRef">
                <p v-if="dmLoading" class="forums-guest-note">Loading…</p>
                <p v-else-if="dmMessages.length === 0" class="forums-guest-note">No messages yet — say hi.</p>
                <div
                  v-for="m in dmMessages"
                  :key="m.id"
                  class="dm-bubble"
                  :class="{ 'dm-bubble--me': m.from_me }"
                >{{ m.body }}</div>
              </div>

              <div class="dm-compose-row">
                <input
                  class="forum-input"
                  v-model="dmDraft"
                  placeholder="Type a message…"
                  maxlength="1000"
                  @keydown.enter="sendDm"
                />
                <button class="forum-btn forum-btn--primary" v-sfx-hover @click="sendDm">Send</button>
              </div>
              <p v-if="dmStatus" class="forums-guest-note">{{ dmStatus }}</p>
            </div>
          </template>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, nextTick } from 'vue';
import Panels from '../../composables/usePanels.js';
import MemberAuth from '../../lib/member-auth.js';
import { sb } from '../../lib/supabase-client.js';

const isLoggedIn = computed(() => !!MemberAuth.sessionMember.value);

function onOverlayClick(e) {
  if (e.target === e.currentTarget) Panels.closeAll();
}

/* ── FORUMS (mock — see note above) ── */
const threads = ref([
  { id: 1, pinned: true, title: 'Welcome new members — introduce yourself!', snippet: 'New to DMAC? Drop your name, year, and what kind of media you want to make.', author: 'Richmond P. Causaren', replies: 21, lastActive: '2h ago' },
  { id: 2, pinned: true, title: 'Show off your latest edit!', snippet: 'Photo, video, motion graphics — whatever you\'ve been working on this week.', author: 'Mark James C. Patnon', replies: 12, lastActive: '5h ago' },
  { id: 3, pinned: false, title: 'Anyone free to help film the fair this weekend?', snippet: 'Looking for 2-3 people with a camera or a phone that shoots decent 4K.', author: 'Jaywin Elson Cambalon', replies: 4, lastActive: '1d ago' },
]);
const composerOpen = ref(false);
const draftTitle = ref('');
const draftBody = ref('');
const composerStatus = ref('');

function submitDraft() {
  if (!draftTitle.value.trim()) { composerStatus.value = 'Give it a title first.'; return; }
  composerStatus.value = 'Forums aren\'t connected to a backend yet, so this wasn\'t actually posted.';
  draftTitle.value = '';
  draftBody.value = '';
}

/* ── DMs (real RPCs) ── */
const roster = ref([]);
const dmTargetSlug = ref('');
const dmMessages = ref([]);
const dmLoading = ref(false);
const dmDraft = ref('');
const dmStatus = ref('');
const dmScrollRef = ref(null);

async function loadRoster() {
  const [members, mods] = await Promise.all([
    MemberAuth.fetchRoster('member'),
    MemberAuth.fetchRoster('moderator'),
  ]);
  const me = MemberAuth.sessionMember.value?.slug;
  roster.value = [...members, ...mods]
    .filter((p) => p.slug !== me)
    .sort((a, b) => a.display_name.localeCompare(b.display_name));
}

async function loadConversation() {
  if (!dmTargetSlug.value) return;
  dmLoading.value = true;
  dmStatus.value = '';
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('get_conversation', {
    p_session_token: token,
    p_with_slug: dmTargetSlug.value,
  });
  dmLoading.value = false;
  if (error || !data?.success) {
    dmMessages.value = [];
    dmStatus.value = data?.message || 'Could not load that conversation.';
    return;
  }
  dmMessages.value = data.messages || [];
  nextTick(() => {
    if (dmScrollRef.value) dmScrollRef.value.scrollTop = dmScrollRef.value.scrollHeight;
  });
}

async function sendDm() {
  if (!dmDraft.value.trim() || !dmTargetSlug.value) return;
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('send_direct_message', {
    p_session_token: token,
    p_to_slug: dmTargetSlug.value,
    p_body: dmDraft.value.trim(),
  });
  if (error || !data?.success) {
    dmStatus.value = data?.message || 'Message failed to send.';
    return;
  }
  dmDraft.value = '';
  dmStatus.value = '';
  await loadConversation();
}

loadRoster();
</script>
