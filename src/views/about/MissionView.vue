<template>
  <main>
    <PageHero title="Mission" />
    <div class="page-section reveal" v-reveal>
      <div class="mission-content">
        <p class="mission-lead">
          DMAC exists to cover what happens at our school — recording events, editing the footage and photos, and getting the finished coverage out to students — while giving members a low-pressure space to build real skills along the way, regardless of experience level.
        </p>

        <div class="mission-grid">
          <div class="mission-card" v-sfx-hover>
            <div class="mission-card-header">
              <span class="mission-icon">◆</span>
              <h3>Learn by doing</h3>
            </div>
            <p>Skills come from covering real events, not just watching tutorials. Your entry sample is just step one; every event after that is a chance to get sharper at filming, editing, or posting.</p>
          </div>

          <div class="mission-card" v-sfx-hover>
            <div class="mission-card-header">
              <span class="mission-icon">◆</span>
              <h3>Open to everyone, with a baseline</h3>
            </div>
            <p>No competitive auditions or elite prerequisites. We just look at a quick sample of what you've made so we know your starting point and where you can help — camera, edit, or post — from day one.</p>
          </div>

          <div class="mission-card" v-sfx-hover>
            <div class="mission-card-header">
              <span class="mission-icon">◆</span>
              <h3>Collaborate, don't gatekeep</h3>
            </div>
            <p>Coverage is a group effort. Members split up who's filming, who's editing, and who's posting, and everyone picks up a bit of everyone else's part along the way.</p>
          </div>

          <div class="mission-card" v-sfx-hover>
            <div class="mission-card-header">
              <span class="mission-icon">◆</span>
              <h3>Grow with our members</h3>
            </div>
            <p>How we cover the school follows what members are actually curious about — more photography, more motion graphics, better captions, whatever raises the bar on our coverage.</p>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>

<script setup>
import PageHero from '../../components/PageHero.vue';
import '../../assets/css/pages/mission.css';
</script>
