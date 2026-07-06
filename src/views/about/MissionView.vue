<template>
  <main>
    <div class="page-section reveal" v-reveal>
      <SecHead>Mission</SecHead>
      <div class="mission-content">
        <p class="mission-lead">
          DMAC exists to give students a low-pressure space to learn digital skills, build real projects, and create alongside people with similar interests — regardless of experience level.
        </p>

        <div class="mission-grid">
          <div class="mission-card" v-sfx-hover>
            <div class="mission-card-header">
              <span class="mission-icon">◆</span>
              <h3>Learn by doing</h3>
            </div>
            <p>Skills come from making things, not just watching tutorials. Your entry sample is just step one; everything after that is about leveling up.</p>
          </div>

          <div class="mission-card" v-sfx-hover>
            <div class="mission-card-header">
              <span class="mission-icon">◆</span>
              <h3>Open to everyone, with a baseline</h3>
            </div>
            <p>No competitive auditions or elite prerequisites. We just look at a quick sample of what you've made so we know your starting point, what you want to learn, and how we can build real projects together from day one.</p>
          </div>

          <div class="mission-card" v-sfx-hover>
            <div class="mission-card-header">
              <span class="mission-icon">◆</span>
              <h3>Collaborate, don't gatekeep</h3>
            </div>
            <p>Members teach each other and share resources. Having a baseline standard ensures we can dive straight into collaborative work without wasting time.</p>
          </div>

          <div class="mission-card" v-sfx-hover>
            <div class="mission-card-header">
              <span class="mission-icon">◆</span>
              <h3>Grow with our members</h3>
            </div>
            <p>The club's direction follows what students are actually curious about. (Game design and audio production are already on our radar if people want them).</p>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>

<script setup>
import SecHead from '../../components/SecHead.vue';
import '../../assets/css/pages/mission.css';

/* Ported from about/mission.html — no page-specific JS in the
   original (gradient heading + reveal are global.js concerns,
   now handled by GradWrap/SecHead + the v-reveal directive). */
</script>
