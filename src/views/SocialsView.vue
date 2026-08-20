<template>
  <main>
    <PageHero title="Socials" />
    <div class="page-section reveal" v-reveal>
      <div class="socials-list">
        <a class="social-link" href="https://www.facebook.com/profile.php?id=61590594809333" target="_blank" rel="noopener">
          <span class="social-link-label">Facebook</span>
        </a>
      </div>
    </div>
  </main>
</template>

<script setup>
import PageHero from '../components/PageHero.vue';
import '../assets/css/pages/socials.css';
</script>
