<template>
  <main>
    <div class="page-section reveal" v-reveal>
      <SecHead>Announcements</SecHead>
      <hr class="news-divider" />

      <!--
        Card template — copy/paste into .news-scroll below (in place of
        .news-empty) for each new announcement:

        <a href="#" class="news-panel">
          <div class="news-panel-img">
            <img src="https://aztaryx.github.io/dmac-assets/images/misc/FILENAME.jpg" alt="" loading="lazy" />
          </div>
          <h3 class="news-panel-title">Headline goes here</h3>
        </a>
      -->
      <div class="news-scroll">
        <div class="news-empty" v-sfx-protected>
          <span class="stub-label">no announcements yet</span>
        </div>
      </div>
    </div>

    <div class="page-section reveal" v-reveal>
      <SecHead>Events</SecHead>
      <hr class="news-divider" />

      <!-- Same card template as above — see Announcements section -->
      <div class="news-scroll">
        <div class="news-empty" v-sfx-protected>
          <span class="stub-label">no events yet</span>
        </div>
      </div>
    </div>
  </main>
</template>

<script setup>
import SecHead from '../../components/SecHead.vue';
import '../../assets/css/pages/newsletters.css';

/* Ported from info/newsletters.html. No page-specific JS existed
   for this page — the one bit of behavior (.news-empty stub clicks
   playing a random "protected" sting) lived in global.js's generic
   querySelectorAll pass and is now the v-sfx-protected directive,
   applied directly per the directive's own doc comment. */
</script>
