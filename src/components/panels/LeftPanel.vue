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
            <button
              class="side-tab"
              :class="{ active: Panels.leftTab.value === 'rules' }"
              @click="switchTab('rules')"
            >Rulebook</button>
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
              <div v-if="threadEditId === selectedThread.id" class="forum-inline-editor">
                <label class="forum-field">
                  <span>Edit thread title</span>
                  <input class="forum-input" v-model="threadEditDraft" maxlength="120" />
                </label>
                <div class="forum-composer-actions forum-composer-actions--compact">
                  <button class="forum-btn forum-btn--primary" v-sfx-hover @click="saveThreadEdit">Save title</button>
                  <button class="forum-btn" v-sfx-hover @click="cancelThreadEdit">Cancel</button>
                </div>
                <p v-if="threadEditStatus" class="forums-guest-note">{{ threadEditStatus }}</p>
              </div>
              <div v-else-if="canModerate || isThreadOwner" class="forum-thread-actions">
                <button
                  v-if="canEditThread"
                  class="forum-link-btn"
                  @click="beginThreadEdit"
                >Edit title</button>
                <button
                  v-if="canModerate"
                  class="forum-link-btn"
                  @click="togglePin"
                >{{ selectedThread.pinned ? 'Unpin' : 'Pin' }}</button>
                <button
                  v-if="canModerate"
                  class="forum-link-btn"
                  @click="beginModeration(selectedThread.author_slug, selectedThread.author_name, 'warn')"
                >Warn author</button>
                <button
                  v-if="canModerate"
                  class="forum-link-btn"
                  @click="beginModeration(selectedThread.author_slug, selectedThread.author_name, 'silence')"
                >Silence author</button>
                <button
                  v-if="canModerate"
                  class="forum-link-btn"
                  @click="beginModeration(selectedThread.author_slug, selectedThread.author_name, 'unsilence')"
                >Unsilence author</button>
                <button class="forum-link-btn forum-link-btn--danger" @click="removeThread">Delete thread</button>
              </div>

              <div v-if="modTarget" class="forum-warning-composer">
                <div class="forum-warning-head">
                  <strong>{{ modActionLabel }} {{ modTarget.displayName }}</strong>
                  <button class="forum-link-btn" v-sfx-hover @click="clearModeration">Cancel</button>
                </div>
                <label v-if="modAction === 'silence'" class="forum-field">
                  <span>Duration</span>
                  <select class="forum-input" v-model.number="modDuration">
                    <option :value="1">1 hour</option>
                    <option :value="24">24 hours</option>
                    <option :value="72">3 days</option>
                    <option :value="168">7 days</option>
                    <option :value="720">30 days</option>
                  </select>
                </label>
                <label class="forum-field">
                  <span>Reason</span>
                  <textarea
                    class="forum-input forum-textarea"
                    v-model="modReason"
                    rows="3"
                    maxlength="500"
                    placeholder="Optional note for the moderation log"
                  ></textarea>
                </label>
                <div class="forum-composer-actions forum-composer-actions--compact">
                  <button class="forum-btn forum-btn--primary" v-sfx-hover @click="sendModeration">{{ modSubmitLabel }}</button>
                  <button class="forum-btn" v-sfx-hover @click="clearModeration">Cancel</button>
                </div>
                <p v-if="modStatus" class="forums-guest-note">{{ modStatus }}</p>
              </div>
            </div>

            <p v-if="postsLoading" class="forums-guest-note">Loading…</p>
            <section v-else class="forum-post-list">
              <article v-for="post in posts" :key="post.id" class="forum-post-card">
                <div class="forum-post-meta">
                  <strong>{{ post.author_name }}</strong>
                  <span>{{ formatTime(post.created_at) }}</span>
                  <div v-if="canModerate || canEditPost(post)" class="forum-post-meta-actions">
                    <button
                      v-if="canEditPost(post)"
                      class="forum-link-btn"
                      @click="beginPostEdit(post)"
                    >Edit</button>
                    <button
                      v-if="canModerate"
                      class="forum-link-btn"
                      @click="beginModeration(post.author_slug, post.author_name, 'warn')"
                    >Warn</button>
                    <button
                      v-if="canModerate"
                      class="forum-link-btn"
                      @click="beginModeration(post.author_slug, post.author_name, 'silence')"
                    >Silence</button>
                    <button
                      v-if="canModerate"
                      class="forum-link-btn"
                      @click="beginModeration(post.author_slug, post.author_name, 'unsilence')"
                    >Unsilence</button>
                    <button
                      class="forum-link-btn forum-link-btn--danger"
                      @click="removePost(post.id)"
                    >Delete</button>
                  </div>
                </div>
                <div v-if="editingPostId === post.id" class="forum-inline-editor">
                  <label class="forum-field">
                    <span>Edit post</span>
                    <textarea class="forum-input forum-textarea" v-model="postEditDraft" rows="4" maxlength="4000"></textarea>
                  </label>
                  <div class="forum-composer-actions forum-composer-actions--compact">
                    <button class="forum-btn forum-btn--primary" v-sfx-hover @click="savePostEdit(post.id)">Save post</button>
                    <button class="forum-btn" v-sfx-hover @click="cancelPostEdit">Cancel</button>
                  </div>
                  <p v-if="postEditStatus" class="forums-guest-note">{{ postEditStatus }}</p>
                </div>
                <p v-else class="forum-post-body">{{ post.body }}</p>
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
        <div v-else-if="Panels.leftTab.value === 'dms'" class="side-panel-body">
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

        <!-- ══════════════ RULEBOOK TAB ══════════════ -->
        <div v-else class="side-panel-body">
          <div class="forums-head">
            <p class="forums-intro">Applies to every thread, reply, and DM sent through DMAC's forums.</p>
          </div>

          <ol class="rulebook-list">
            <li class="rulebook-item">
              <span class="rulebook-item-num">1</span>
              <div class="rulebook-item-body">
                <h4>Be respectful</h4>
                <p>Treat officers, advisers, and fellow members the way you'd want to be treated. No bullying, harassment, or personal attacks.</p>
              </div>
            </li>
            <li class="rulebook-item">
              <span class="rulebook-item-num">2</span>
              <div class="rulebook-item-body">
                <h4>Stay on topic</h4>
                <p>Keep threads relevant to DMAC — event coverage, club projects, and school-related discussion.</p>
              </div>
            </li>
            <li class="rulebook-item">
              <span class="rulebook-item-num">3</span>
              <div class="rulebook-item-body">
                <h4>No spam or unrelated self-promotion</h4>
                <p>Keep the noise down so real discussion doesn't get buried.</p>
              </div>
            </li>
            <li class="rulebook-item">
              <span class="rulebook-item-num">4</span>
              <div class="rulebook-item-body">
                <h4>Keep it appropriate</h4>
                <p>No explicit, hateful, or illegal content — this is a school space.</p>
              </div>
            </li>
            <li class="rulebook-item">
              <span class="rulebook-item-num">5</span>
              <div class="rulebook-item-body">
                <h4>Respect privacy</h4>
                <p>Don't share anyone's personal information without their permission.</p>
              </div>
            </li>
            <li class="rulebook-item">
              <span class="rulebook-item-num">6</span>
              <div class="rulebook-item-body">
                <h4>Post as yourself</h4>
                <p>Threads and replies are tied to your member account — no impersonating other members, officers, or advisers.</p>
              </div>
            </li>
            <li class="rulebook-item">
              <span class="rulebook-item-num">7</span>
              <div class="rulebook-item-body">
                <h4>Follow moderator instructions</h4>
                <p>Officers and advisers can pin, edit, or remove content that breaks these rules. Breaking a rule can mean a warning; repeated or serious violations can mean a temporary silence.</p>
              </div>
            </li>
          </ol>

          <p class="forums-guest-note">Questions about a moderation action? Reach out to an officer directly.</p>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, nextTick } from 'vue';
import Panels from '../../composables/usePanels.js';
import MemberAuth from '../../lib/member-auth.js';
import { playSfx } from '../../composables/useSfx.js';
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
const canEditThread = computed(() => !!selectedThread.value && (canModerate.value || isThreadOwner.value));

const threadEditId = ref(null);
const threadEditDraft = ref('');
const threadEditStatus = ref('');

const editingPostId = ref(null);
const postEditDraft = ref('');
const postEditStatus = ref('');

const modTarget = ref(null);
const modAction = ref('warn');
const modDuration = ref(24);
const modReason = ref('');
const modStatus = ref('');

const MOD_ACTION_LABELS = { warn: 'Warn', silence: 'Silence', unsilence: 'Unsilence' };
const modActionLabel = computed(() => MOD_ACTION_LABELS[modAction.value] || 'Warn');
const modSubmitLabel = computed(() => {
  if (modAction.value === 'silence') return 'Silence member';
  if (modAction.value === 'unsilence') return 'Lift silence';
  return 'Send warning';
});

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
  threadEditId.value = null;
  threadEditDraft.value = '';
  threadEditStatus.value = '';
  editingPostId.value = null;
  postEditDraft.value = '';
  postEditStatus.value = '';
  clearModeration();
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
  threadEditId.value = null;
  threadEditDraft.value = '';
  threadEditStatus.value = '';
  editingPostId.value = null;
  postEditDraft.value = '';
  postEditStatus.value = '';
  clearModeration();
}

function beginThreadEdit() {
  if (!selectedThread.value) return;
  threadEditId.value = selectedThread.value.id;
  threadEditDraft.value = selectedThread.value.title;
  threadEditStatus.value = '';
}

function cancelThreadEdit() {
  threadEditId.value = null;
  threadEditDraft.value = '';
  threadEditStatus.value = '';
}

function beginPostEdit(post) {
  editingPostId.value = post.id;
  postEditDraft.value = post.body;
  postEditStatus.value = '';
}

function cancelPostEdit() {
  editingPostId.value = null;
  postEditDraft.value = '';
  postEditStatus.value = '';
}

function beginModeration(slug, displayName, action) {
  modTarget.value = { slug, displayName };
  modAction.value = action;
  modDuration.value = 24;
  modReason.value = '';
  modStatus.value = '';
}

function clearModeration() {
  modTarget.value = null;
  modAction.value = 'warn';
  modDuration.value = 24;
  modReason.value = '';
  modStatus.value = '';
}

function canEditPost(post) {
  return canModerate.value || post.author_slug === myMoveSlug.value;
}

async function saveThreadEdit() {
  if (!selectedThread.value) return;
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('edit_forum_thread', {
    p_session_token: token,
    p_thread_id: selectedThread.value.id,
    p_title: threadEditDraft.value.trim(),
  });
  if (error || !data?.success) {
    threadEditStatus.value = data?.message || 'Could not update that thread.';
    return;
  }
  selectedThread.value = { ...selectedThread.value, title: threadEditDraft.value.trim() };
  threadEditId.value = null;
  threadEditDraft.value = '';
  threadEditStatus.value = '';
  playSfx('staffsilence');
  await loadThreads();
}

async function savePostEdit(postId) {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('edit_forum_post', {
    p_session_token: token,
    p_post_id: postId,
    p_body: postEditDraft.value.trim(),
  });
  if (error || !data?.success) {
    postEditStatus.value = data?.message || 'Could not update that post.';
    return;
  }
  editingPostId.value = null;
  postEditDraft.value = '';
  postEditStatus.value = '';
  playSfx('staffsilence');
  await openThread(selectedThread.value);
  await loadThreads();
}

async function sendModeration() {
  if (!modTarget.value) return;
  const action = modAction.value;
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('member_moderate', {
    p_session_token: token,
    p_target_slug: modTarget.value.slug,
    p_action: action,
    p_reason: modReason.value.trim() || null,
    p_duration_hours: modDuration.value,
  });
  if (error || !data?.success) {
    const fallback = action === 'silence' ? 'Could not silence that member.'
      : action === 'unsilence' ? 'Could not lift that silence.'
      : 'Could not send that warning.';
    modStatus.value = data?.message || fallback;
    return;
  }
  playSfx(action === 'warn' ? 'staffwarning' : 'staffsilence');
  clearModeration();
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
  playSfx('staffsilence');
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
  playSfx('staffspam');
  closeThread();
  await loadThreads();
}

async function removePost(postId) {
  const token = MemberAuth.getSessionToken();
  const { data, error } = await sb.rpc('delete_forum_post', { p_session_token: token, p_post_id: postId });
  if (error || !data?.success) return;
  playSfx('staffspam');
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
