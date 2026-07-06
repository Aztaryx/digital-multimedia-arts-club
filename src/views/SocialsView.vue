<template>
  <main>
    <div class="page-section reveal" v-reveal>
      <SecHead>Socials</SecHead>
      <div class="socials-list">
        <a class="social-link" href="https://www.facebook.com/profile.php?id=61590594809333" target="_blank" rel="noopener">
          <span class="social-link-label">Facebook</span>
        </a>
      </div>
    </div>
  </main>
</template>

<script setup>
import SecHead from '../components/SecHead.vue';
import '../assets/css/pages/socials.css';

/* Ported from socials/index.html — static content, no page-specific
   JS in the original. (.social-link isn't in the original
   HOVER_FX_SELECTOR list, so no v-sfx-hover here.) */
</script>
