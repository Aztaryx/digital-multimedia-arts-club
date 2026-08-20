<template>
  <main>
    <PageHero title="404" />
    <div class="page-section reveal" v-reveal>
      <p class="faq-a" style="text-align:center; max-width:520px; margin:0 auto 24px;">
        There's nothing here. Whatever you were looking for, this isn't it.
      </p>
      <p class="faq-a" style="text-align:center;">
        <router-link to="/home">Back to home</router-link>
      </p>
    </div>
  </main>
</template>

<script setup>
import { onMounted } from 'vue';
import PageHero from '../components/PageHero.vue';
import { claimWhoops } from '../lib/secret-badges.js';

// Whoops. (see dmac-badge-implementation-plan.md, Part 4) — this is
// the trigger point. claim_secret_badge() itself is the guard
// against duplicate rows, so it's safe to just call this every time
// someone lands here, logged in or not (claim() no-ops for guests).
onMounted(() => {
  claimWhoops();
});
</script>
