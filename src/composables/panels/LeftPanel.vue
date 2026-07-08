<template>
  <Teleport to="body">
    <div class="side-overlay side-overlay--left" :class="{ open: Panels.leftOpen.value }" @click="onOverlayClick">
      <div class="side-panel side-panel--left" @click.stop>
        <div class="side-panel-head">
          <div class="side-tabs">
            <button
              class="side-tab"
              :class="{ active: Panels.leftTab.value === 'forums' }"
              @click="switchTab('forums')"
            >Forums</button>
            <button
              class="side-tab"
              :class="{ active: Panels.leftTab.value === 'dms' }"
              @click="switchTab('dms')"
            >DMs</button>
          </div>
          <button class="side-panel-close" aria-label="Close" v-sfx-hover @click="Panels.closeAll">✕</button>
        </div>

        <!-- ══════════════ FORUMS TAB ══════════════ -->
        <div v-if="Panels.leftTab.value === 'forums'" class="side-panel-body">

          <!-- ── THREAD DETAIL ── -->
          <template v-if="selectedThread">
            <button class="forum-back-btn" v-sfx-hover @click="closeThread">‹ Back to threads</button>

            <div class="forum-thread-detail-head">
              <span v-if="selectedThread.pinned" class="forum-pin">Pinned</span>
              <h3 class="forum-thread-title">{{ selectedThread.title }}</h3>
              <div class="forum-thread-meta">
                <span>{{ selectedThread.author_name }}</span><span>·</span>
                <span>{{ formatTime(selectedThread.created_at) }}</span>
              </div>
              <div v-if="canModerate || isThreadOwner" class="forum-thread-actions">
                <button
                  v-if="canModerate"
                  class="forum-link-btn"
                  @click="togglePin"
                >{{ selectedThread.pinned ? 'Unpin' : 'Pin' }}</button>
                <button class="forum-link-btn forum-link-btn--danger" @click="removeThread">Delete thread</button>
              </div>
            </div>

            <p v-if="postsLoading" class="forums-guest-note">Loading…</p>
            <section v-else class="forum-post-list">
              <article v-for="post in posts" :key="post.id" class="forum-post-card">
                <div class="forum-post-meta">
                  <strong>{{ post.author_name }}</strong>
                  <span>{{ formatTime(post.created_at) }}</span>
                  <button
                    v-if="canModerate || post.author_slug === myMoveSlug"
                    class="forum-link-btn forum-link-btn--danger"
                    @click="removePost(post.id)"
                  >delete</button>
                </div>
                <p class="forum-post-body">{{ post.body }}</p>
              </article>
            </section>

            <div v-if="isLoggedIn" class="forum-composer-row forum-reply-row">
              <textarea class="forum-input forum-textarea" v-model="replyDraft" rows="2" maxlength="4000" placeholder="Write a reply…"></textarea>
              <button class="forum-btn forum-btn--primary" v-sfx-hover @click="submitReply">Reply</button>
            </div>
            <p v-if="replyStatus" class="forums-guest-note">{{ replyStatus }}</p>
          </template>

          <!-- ── THREAD LIST ── -->
          <template v-else>
            <div class="forums-head">
              <p class="forums-intro">Read by everyone. Starting a thread needs a member login.</p>
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
                <textarea class="forum-input forum-textarea" v-model="draftBody" maxlength="4000" rows="3" placeholder="Say more…"></textarea>
              </label>
              <div class="forum-composer-actions">
                <button class="forum-btn forum-btn--primary" v-sfx-hover @click="submitDraft">Post</button>
              </div>
              <p v-if="composerStatus" class="forums-guest-note">{{ composerStatus }}</p>
            </section>

            <p v-if="threadsLoading" class="forums-guest-note">Loading…</p>
            <p v-else-if="threads.length === 0" class="forums-guest-note">No threads yet — be the first.</p>
            <section v-else class="forum-thread-list">
              <article
                v-for="thread in threads"
                :key="thread.id"
                class="forum-thread-card"
                v-sfx-hover
                @click="openThread(thread)"
              >
                <div class="forum-thread-top">
                  <span v-if="thread.pinned" class="forum-pin">Pinned</span>
                  <h3 class="forum-thread-title">{{ thread.title }}</h3>
                </div>
                <div class="forum-thread-meta">
                  <span>{{ thread.author_name }}</span><span>·</span>
                  <span>{{ thread.reply_count }} {{ thread.reply_count === 1 ? 'reply' : 'replies' }}</span><span>·</span>
                  <span>{{ formatTime(thread.last_activity || thread.created_at) }}</span>
                </div>
              </article>
            </section>
          </template>
        </div>

        <!-- ══════════════ DMs TAB ══════════════ -->
        <div v-else class="side-panel-body">
          <div v-if="!isLoggedIn" class="dm-empty-state">
            <p class="forums-guest-note"><router-link to="/login" @click="Panels.closeAll">Log in</router-link> to add friends and send DMs.</p>
          </div>
          <template v-else>
            <!-- ── ADD FRIEND ── -->
            <section class="dm-section">
              <p class="notif-section-label">Add friend</p>
              <div class="dm-add-row">
                <select class="forum-input" v-model="addTargetSlug">
                  <option value="" disabled>Choose a member…</option>
                  <option v-for="p in addableRoster" :key="p.slug" :value="p.slug">{{ p.display_name }}</option>
                </select>
                <button class="forum-btn forum-btn--primary" v-sfx-hover @click="sendFriendRequest">Add</button>
              </div>
              <p v-if="addStatus" class="forums-guest-note">{{ addStatus }}</p>
            </section>

            <!-- ── INCOMING REQUESTS ── -->
            <section v-if="incomingRequests.length" class="dm-section">
              <p class="notif-section-label">Friend requests</p>
              <div v-for="req in incomingRequests" :key="req.slug" class="dm-request-row">
                <span>{{ req.display_name }}</span>
                <div class="dm-request-actions">
                  <button class="forum-link-btn" @click="respondRequest(req.slug, true)">Accept</button>
                  <button class="forum-link-btn forum-link-btn--danger" @click="respondRequest(req.slug, false)">Decline</button>
                </div>
              </div>
            </section>

            <!-- ── FRIENDS / CONVERSATION ── -->
            <section class="dm-section">
              <p class="notif-section-label">Messages</p>
              <p v-if="friends.length === 0" class="forums-guest-note">No friends yet — add someone above to start messaging.</p>
              <label v-else class="forum-field dm-picker">
                <select class="forum-input" v-model="dmTargetSlug" @change="loadConversation">
                  <option value="" disabled>Choose a friend…</option>
                  <option v-for="p in friends" :key="p.slug" :value="p.slug">{{ p.display_name }}</option>
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
            </section>
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
const myMoveSlug = computed(() => MemberAuth.sessionMember.value?.slug || null);
const canModerate = computed(() => MemberAuth.hasRole('moderator'));

function onOverlayClick(e) {
  if (e.target === e.currentTarget) Panels.closeAll();
}

function formatTime(iso) {
  if (!iso) return '';
  const diffMs = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  if (days < 7) return `${days}d ago`;
  return new Date(iso).toLocaleDateString();
}

function switchTab(tab) {
  Panels.leftTab.value = tab;
  if (tab === 'dms' && isLoggedIn.value) {
    loadFriends();
    loadFriendRequests();
    loadAddableRoster();
  }
}

/* ══════════════ FORUMS (real — forum_threads/forum_posts) ══════════════ */
const threads = ref([]);
const threadsLoading = ref(false);
const selectedThread = ref(null);
const posts = ref([]);
const postsLoading = ref(false);
const composerOpen = ref(false);
const draftTitle = ref('');
const draftBody = ref('');
const composerStatus = ref('');
const replyDraft = ref('');
const replyStatus = ref('');

const isThreadOwner = computed(() => selectedThread.value?.author_slug === myMoveSlug.value);

async function loadThreads() {
  threadsLoading.value = true;
  const { data, error } = await sb
    .from('forum_threads_feed')
    .select('*')
    .order('pinned', { ascending: false })
    .order('last_activity', { ascending: false, nullsFirst: false });
  threadsLoading.value = false;
  if (error) {
    console.error('LeftPanel: could not load forum threads —', error.message);
    return;
  }
  threads.value = data || [];
}

async function openThread(thread) {
  selectedThread.value = thread;
  postsLoading.value = true;
  const { data, error } = await sb
    .from('forum_posts_feed')
    .select('*')
    .eq('thread_id', thread.id)
    .order('created_at', { ascending: true });
  postsLoading.value = false;
  if (error) {
    console.error('LeftPanel: could not load thread posts —', error.message);
    posts.value = [];
    return;
  }
  posts.value = data || [];
}

function closeThread() {
  selectedThread.value = null;
  posts.value = [];
  replyDraft.value = '';
  replyStatus.value = '';
}

async function submitDraft() {
  if (!draftTitle.value.trim() || !draftBody.value.trim()) {
    composerStatus.value = 'Fill in both a title and a message.';
    return;
  }
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('create_forum_thread', {
    p_session_token: token,
    p_title: draftTitle.value.trim(),
    p_body: draftBody.value.trim(),
  });
  if (error || !data?.success) {
    composerStatus.value = data?.message || 'Could not post that thread.';
    return;
  }
  draftTitle.value = '';
  draftBody.value = '';
  composerStatus.value = '';
  composerOpen.value = false;
  await loadThreads();
}

async function submitReply() {
  if (!replyDraft.value.trim() || !selectedThread.value) return;
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('create_forum_post', {
    p_session_token: token,
    p_thread_id: selectedThread.value.id,
    p_body: replyDraft.value.trim(),
  });
  if (error || !data?.success) {
    replyStatus.value = data?.message || 'Could not post that reply.';
    return;
  }
  replyDraft.value = '';
  replyStatus.value = '';
  await openThread(selectedThread.value);
  await loadThreads(); // keep reply_count/last_activity current in the background list
}

async function togglePin() {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('set_forum_thread_pinned', {
    p_session_token: token,
    p_thread_id: selectedThread.value.id,
    p_pinned: !selectedThread.value.pinned,
  });
  if (error || !data?.success) return;
  selectedThread.value = { ...selectedThread.value, pinned: !selectedThread.value.pinned };
  await loadThreads();
}

async function removeThread() {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('delete_forum_thread', {
    p_session_token: token,
    p_thread_id: selectedThread.value.id,
  });
  if (error || !data?.success) return;
  closeThread();
  await loadThreads();
}

async function removePost(postId) {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('delete_forum_post', { p_session_token: token, p_post_id: postId });
  if (error || !data?.success) return;
  await openThread(selectedThread.value);
}

/* ══════════════ DMs (real — friendships + direct_messages) ══════════════ */
const addableRoster = ref([]);
const addTargetSlug = ref('');
const addStatus = ref('');
const incomingRequests = ref([]);
const friends = ref([]);
const dmTargetSlug = ref('');
const dmMessages = ref([]);
const dmLoading = ref(false);
const dmDraft = ref('');
const dmStatus = ref('');
const dmScrollRef = ref(null);

async function loadAddableRoster() {
  const [members, mods] = await Promise.all([
    MemberAuth.fetchRoster('member'),
    MemberAuth.fetchRoster('moderator'),
  ]);
  const me = myMoveSlug.value;
  addableRoster.value = [...members, ...mods]
    .filter((p) => p.slug !== me)
    .sort((a, b) => a.display_name.localeCompare(b.display_name));
}

async function loadFriends() {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('list_friends', { p_session_token: token });
  if (error || !data?.success) return;
  friends.value = data.friends || [];
}

async function loadFriendRequests() {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('list_friend_requests', { p_session_token: token });
  if (error || !data?.success) return;
  incomingRequests.value = data.incoming || [];
}

async function sendFriendRequest() {
  if (!addTargetSlug.value) return;
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('send_friend_request', {
    p_session_token: token,
    p_to_slug: addTargetSlug.value,
  });
  addStatus.value = (error || !data?.success) ? (data?.message || 'Could not send that request.') : 'Request sent.';
  if (data?.success) addTargetSlug.value = '';
}

async function respondRequest(slug, accept) {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('respond_friend_request', {
    p_session_token: token,
    p_from_slug: slug,
    p_accept: accept,
  });
  if (error || !data?.success) return;
  await loadFriendRequests();
  if (accept) await loadFriends();
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

// Threads are public — load them right away regardless of tab/login
// state. DM-related data only matters once logged in, and only gets
// fetched when the DMs tab is actually opened (see switchTab()).
loadThreads();
</script>
