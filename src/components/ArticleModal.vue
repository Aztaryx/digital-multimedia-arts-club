<!-- ArticleModal.vue — the "one-header-look, then read everything
     inside" detail view for a news-style card. Cover image is
     optional and rendered only if the item actually has one — see
     the note in HomeView.vue about adding a cover_url column. -->
<template>
  <Teleport to="body">
    <div class="article-overlay" @click="onOverlayClick">
      <div class="article-modal" @click.stop>
        <button class="article-close" aria-label="Close" @click="$emit('close')">✕</button>

        <img v-if="article.cover_url" class="article-cover" :src="article.cover_url" alt="" />
        <div v-else class="article-cover article-cover--placeholder tile-dark"></div>

        <div class="article-body">
          <span class="article-tag" :class="`article-tag--${article.type}`">{{ tagLabel }}</span>
          <h2 class="article-title">{{ article.title }}</h2>
          <div class="article-meta">
            <span class="article-author">{{ article.author_name || 'DMAC' }}</span>
            <span class="article-dot">·</span>
            <time class="article-time">{{ formattedDate }}</time>
          </div>
          <p class="article-text">{{ article.body }}</p>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  article: { type: Object, required: true },
});
const emit = defineEmits(['close']);

const tagLabel = computed(() => (props.article.type === 'newsletter' ? 'Newsletter' : 'Announcement'));
const formattedDate = computed(() =>
  props.article.created_at
    ? new Date(props.article.created_at).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
    : ''
);

function onOverlayClick(e) {
  if (e.target === e.currentTarget) emit('close');
}
</script>

<style scoped>
.article-overlay {
  position: fixed;
  inset: 0;
  z-index: 1000;
  display: grid;
  place-items: center;
  padding: 20px;
  background: rgba(8, 8, 12, 0.78);
  backdrop-filter: blur(4px);
}
.article-modal {
  position: relative;
  width: min(680px, 100%);
  max-height: 86vh;
  overflow-y: auto;
  border-radius: 26px;
  background: #14141a;
  border: 1px solid rgba(255, 255, 255, 0.1);
  box-shadow: 0 30px 70px rgba(0, 0, 0, 0.5);
}
.article-close {
  position: absolute;
  top: 14px; right: 14px;
  z-index: 2;
  width: 34px; height: 34px;
  border-radius: 50%;
  border: none;
  background: rgba(0, 0, 0, 0.55);
  color: #fff;
  cursor: pointer;
  font-size: 0.9rem;
}
.article-cover {
  width: 100%;
  height: 240px;
  object-fit: cover;
  display: block;
}
.article-cover--placeholder {
  background-color: rgba(255, 255, 255, 0.03);
}
.article-body { padding: 26px 28px 32px; }
.article-tag {
  display: inline-block;
  font-size: 0.68rem;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  padding: 4px 10px;
  border-radius: 999px;
  margin-bottom: 12px;
}
.article-tag--announcement { background: rgba(249, 115, 22, 0.16); color: var(--orange); }
.article-tag--newsletter   { background: rgba(214, 92, 106, 0.18); color: #e08792; }
.article-title { margin: 0 0 8px; font-family: var(--font); font-size: 1.5rem; line-height: 1.25; }
.article-meta {
  display: flex;
  align-items: baseline;
  gap: 8px;
  font-size: 0.8rem;
  margin-bottom: 18px;
}
.article-author { color: var(--orange); }
.article-dot { color: rgba(240, 240, 240, 0.3); }
.article-time { color: rgba(240, 240, 240, 0.5); }
.article-text {
  margin: 0;
  white-space: pre-wrap;
  line-height: 1.75;
  color: rgba(240, 240, 240, 0.85);
}

@media (max-width: 560px) {
  .article-cover { height: 170px; }
  .article-body { padding: 20px; }
}
</style>
