<template>
  <main>
    <div class="page-section reveal" v-reveal>
      <SecHead>FAQ</SecHead>
      <div class="faq-list">

        <div class="faq-item">
          <p class="faq-q">Does your team work anywhere else? Do you do commissions?</p>
          <p class="faq-a">
            No — DMAC is a school-based club, not a freelance team. We operate exclusively at
            Governor Ferrer Memorial Integrated National High School, located in Pinagtipunan,
            General Trias, Cavite. We don't take on outside projects or paid commissions.
          </p>
        </div>

        <div class="faq-item">
          <p class="faq-q">What are the minimum requirements for joining?</p>
          <p class="faq-a">
            Head over to our <router-link to="/join">How to Join</router-link> page for the full rundown on
            the sign-up process and what you'll need to prepare.
          </p>
        </div>

        <div class="faq-item">
          <p class="faq-q">Where else can I follow DMAC for updates?</p>
          <p class="faq-a">
            We're on Facebook! Check out our <router-link to="/socials">Socials</router-link> page for the link
            and stay in the loop on what we're up to.
          </p>
        </div>

      </div>
    </div>
  </main>
</template>

<script setup>
import SecHead from '../../components/SecHead.vue';
import '../../assets/css/pages/faq.css';

/* Ported from info/faq.html — static content, no page-specific JS
   in the original. Internal links converted to <router-link>. */
</script>
