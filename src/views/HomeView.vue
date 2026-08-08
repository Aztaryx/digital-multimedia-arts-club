<template>
  <!-- ════════════════════════════════ HERO ════════════════════════════════════ -->
  <section id="hero" :class="{ 'has-expanded': expanded !== null }">

    <div
      class="hero-panel animate-in"
      :class="{ expanded: expanded === 'digital' }"
      data-delay="1"
      role="button"
      tabindex="0"
      v-sfx-hover
      @click="onPanelClick('digital')"
      @keydown="onPanelKeydown('digital', $event)"
    >
      <img class="hp-img" src="https://aztaryx.github.io/dmac-assets/images/hero/digital.png" alt="Digital" />
      <div class="hp-fade"></div>
      <div class="hp-content">
        <span class="hp-letter">D</span>
        <GradWrap class="hp-word">Digital</GradWrap>
      </div>
      <!-- Expanded overlay -->
      <div class="hp-expanded" :aria-hidden="expanded !== 'digital'">
        <div class="hp-expanded-bg"></div>
        <!-- Cyber decoratives -->
        <div class="cyber-scanlines"></div>
        <div class="cyber-grid"></div>
        <div class="cyber-trace cyber-trace--top"></div>
        <div class="cyber-trace cyber-trace--bottom"></div>
        <div class="cyber-glitch-bar cyber-glitch-bar--1"></div>
        <div class="cyber-glitch-bar cyber-glitch-bar--2"></div>
        <div class="cyber-hex-col cyber-hex-col--1"><span>0x4F</span><span>0xAE</span><span>0x22</span><span>0xD3</span><span>0xEE</span><span>0xFF</span></div>
        <div class="cyber-hex-col cyber-hex-col--2"><span>0xE8</span><span>0x79</span><span>0xF9</span><span>0x0D</span><span>0x0D</span><span>0x42</span></div>
        <button class="hp-expanded-close" aria-label="Close panel" @click.stop="collapsePanel">&times;</button>
        <div class="hp-expanded-body">
          <h2 class="hp-expanded-title"><GradWrap>Digital</GradWrap></h2>
          <p class="hp-expanded-tagline">Upload &bull; Publish &bull; Archive</p>
          <div class="hp-expanded-text">
            <p>
              The Digital pillar covers everything that happens after the camera stops rolling — getting the coverage online, organized, and in front of the rest of the school before everyone's moved on.
            </p>
            <p>
              Whether you're curious about running our social pages, keeping event footage and photos organized, or helping build out this website, this is the place to start. We keep it beginner-friendly and hands-on — no lectures, just learning by doing.
            </p>
            <p>
              Some of the things we get into: posting and scheduling on our Facebook page, organizing shared folders of event footage, writing captions people actually read, and helping maintain this site. You don't need to be a "tech person" — you just need to be curious.
            </p>
          </div>
        </div>
      </div>
    </div>

    <div
      class="hero-panel animate-in"
      :class="{ expanded: expanded === 'multimedia' }"
      data-delay="2"
      role="button"
      tabindex="0"
      v-sfx-hover
      @click="onPanelClick('multimedia')"
      @keydown="onPanelKeydown('multimedia', $event)"
    >
      <img class="hp-img" src="https://aztaryx.github.io/dmac-assets/images/hero/multimedia.png" alt="Multimedia" />
      <div class="hp-fade"></div>
      <div class="hp-content">
        <span class="hp-letter">M</span>
        <GradWrap class="hp-word">Multimedia</GradWrap>
      </div>
      <!-- Expanded overlay -->
      <div class="hp-expanded" :aria-hidden="expanded !== 'multimedia'">
        <div class="hp-expanded-bg"></div>
        <!-- Film decoratives -->
        <div class="film-strip film-strip--left"></div>
        <div class="film-strip film-strip--right"></div>
        <div class="film-grain"></div>
        <div class="film-countdown"><span>3</span></div>
        <div class="film-frame-lines"></div>
        <button class="hp-expanded-close" aria-label="Close panel" @click.stop="collapsePanel">&times;</button>
        <div class="hp-expanded-body">
          <h2 class="hp-expanded-title"><GradWrap>Multimedia</GradWrap></h2>
          <p class="hp-expanded-tagline">Lights &bull; Camera &bull; Render</p>
          <div class="hp-expanded-text">
            <p>
              The Multimedia pillar is where school events actually get captured. If you've ever seen a recap video or event highlight reel and thought "I want to help make those," this is your starting point.
            </p>
            <p>
              We cover the full process — showing up to film and shoot photos at assemblies, competitions, and school activities, then editing that raw footage into something worth posting. You'll get hands-on time with editing software and learn the basics of how recap videos and highlight reels actually come together.
            </p>
            <p>
              No experience needed at all. Whether you want to be behind the camera at school events, cut together highlight reels, try out motion graphics, or just learn how to edit video for fun — we'll help you figure it out step by step. Everyone starts somewhere, and this is a great place to start.
            </p>
          </div>
        </div>
      </div>
    </div>

    <div
      class="hero-panel animate-in"
      :class="{ expanded: expanded === 'arts' }"
      data-delay="3"
      role="button"
      tabindex="0"
      v-sfx-hover
      @click="onPanelClick('arts')"
      @keydown="onPanelKeydown('arts', $event)"
    >
      <img class="hp-img" src="https://aztaryx.github.io/dmac-assets/images/hero/arts.png" alt="Arts" />
      <div class="hp-fade"></div>
      <div class="hp-content">
        <span class="hp-letter">A</span>
        <GradWrap class="hp-word">Arts</GradWrap>
      </div>
      <!-- Expanded overlay -->
      <div class="hp-expanded" :aria-hidden="expanded !== 'arts'">
        <div class="hp-expanded-bg"></div>
        <!-- Paint decoratives -->
        <div class="paint-splotch paint-splotch--1"></div>
        <div class="paint-splotch paint-splotch--2"></div>
        <div class="paint-splotch paint-splotch--3"></div>
        <div class="paint-drip paint-drip--1"></div>
        <div class="paint-drip paint-drip--2"></div>
        <div class="paint-splatter-ring paint-splatter-ring--1"></div>
        <div class="paint-splatter-ring paint-splatter-ring--2"></div>
        <button class="hp-expanded-close" aria-label="Close panel" @click.stop="collapsePanel">&times;</button>
        <div class="hp-expanded-body">
          <h2 class="hp-expanded-title"><GradWrap>Arts</GradWrap></h2>
          <p class="hp-expanded-tagline">Brush &bull; Pixel &bull; Canvas</p>
          <div class="hp-expanded-text">
            <p>
              The Arts pillar is where the coverage gets its look — the posters, thumbnails, and graphics that go alongside everything we film and photograph.
            </p>
            <p>
              We explore graphic design, photo editing, and layout — designing announcement graphics, event posters, and thumbnails for our posts. You'll learn how to use design tools and pick up skills like composition, color theory, and typography along the way — without it feeling like a class.
            </p>
            <p>
              There's no "right way" to make it here. Whether you're already designing every day or you've never opened a design app before, you're welcome. We're here to make our posts and events look as good as the work that goes into them.
            </p>
          </div>
        </div>
      </div>
    </div>

  </section>

  <!-- ════════════════════════════════ BANNER ════════════════════════════════════ -->
  <div class="home-banner-container">
    <div class="home-banner-line"></div>
    <div class="home-banner-wrap">
      <div class="home-banner tile-light">
        <div class="home-banner-inner">
          <img class="home-banner-logo" src="https://aztaryx.github.io/dmac-assets/logo.png" alt="DMAC Logo" />
          <div class="home-banner-title">Digital Multimedia<br />Arts Club</div>
        </div>
      </div>
    </div>
    <div class="home-banner-line"></div>
  </div>

  <!-- ════════════════════════════════ WELCOME ════════════════════════════════ -->
  <section class="home-section" v-reveal>
    <SecHead>Welcome to DMAC</SecHead>
    <p class="home-lead">
      Welcome to DMAC! We're the team behind the camera and the caption — the
      students who show up at school events to record them, edit the footage
      and photos, and post the finished coverage for everyone to see. No
      experience needed, no pressure to be "good" yet. We meet regularly to
      cover events together, learn from each other, and share what we've made.
      If you've ever wondered who's filming at assemblies or editing the recap
      videos afterward, that's us — and we're looking for more people to join in.
    </p>
  </section>

  <!-- ════════════════════════════════ WHAT WE DO ═══════════════════════════════ -->
  <section class="home-section" v-reveal>
    <SecHead>What We Do</SecHead>
    <div class="wwd-grid">
      <div class="wwd-card" v-sfx-hover>
        <h3>Event Coverage</h3>
        <p>Filming and shooting photos at assemblies, competitions, and school activities.</p>
      </div>
      <div class="wwd-card" v-sfx-hover>
        <h3>Video Editing</h3>
        <p>Turning raw footage into recap videos, highlight reels, and clips worth posting.</p>
      </div>
      <div class="wwd-card" v-sfx-hover>
        <h3>Graphic Design</h3>
        <p>Posters, announcement graphics, and thumbnails for everything we post.</p>
      </div>
      <div class="wwd-card" v-sfx-hover>
        <h3>Photography</h3>
        <p>Photo walks during events and picking the shots that tell the story.</p>
      </div>
      <div class="wwd-card" v-sfx-hover>
        <h3>Posting &amp; Socials</h3>
        <p>Getting the finished coverage out on our Facebook page — and eventually this website.</p>
      </div>
    </div>
  </section>

  <!-- ════════════════════════════════ WHY JOIN ═════════════════════════════════ -->
  <section class="home-section" v-reveal>
    <SecHead>Why Join DMAC</SecHead>
    <div class="why-grid">
      <div class="why-item">
        <h3>No experience required</h3>
        <p>We teach the tools as we go — camera work, editing software, or design programs. Show up curious, leave with skills.</p>
      </div>
      <div class="why-item">
        <h3>Build a real portfolio</h3>
        <p>Work on coverage you can point to later, for college applications, job applications, or just to have something to show for your time.</p>
      </div>
      <div class="why-item">
        <h3>Shared tools &amp; resources</h3>
        <p>Members pitch in cameras, drives, cables, and software tips so everyone has what they need to cover an event.</p>
      </div>
      <div class="why-item">
        <h3>Hands-on, not just talk</h3>
        <p>Meetings are built around actually covering events, not sitting through slides.</p>
      </div>
      <div class="why-item">
        <h3>Find your people</h3>
        <p>Work alongside other students into the same stuff, at whatever level you're at.</p>
      </div>
      <div class="why-item">
        <h3>Get your work seen</h3>
        <p>Every post, recap video, and event poster is your work — seen by the whole school.</p>
      </div>
    </div>
    <p class="home-teaser">
      Want to get better at a specific part of coverage — more photography, more
      motion graphics, running our socials? Let us know; the club's direction
      follows what members want to get sharper at.
    </p>
  </section>

  <!-- ════════════════════════════════ QUICK LINKS ═════════════════════════════ -->
  <section class="home-section" v-reveal>
    <SecHead>Quick Links</SecHead>
    <div class="quicklinks-grid">
      <router-link to="/about" class="quicklink-card" v-sfx-hover>
        <h3>Who We Are</h3>
        <p>Meet the team, learn our mission, and see what we've built together.</p>
        <span class="quicklink-arrow">→</span>
      </router-link>
      <router-link to="/info/announcements" class="quicklink-card" v-sfx-hover>
        <h3>Announcements</h3>
        <p>Latest club news, event updates, and important announcements.</p>
        <span class="quicklink-arrow">→</span>
      </router-link>
      <router-link to="/info/school-events" class="quicklink-card" v-sfx-hover>
        <h3>School Events</h3>
        <p>Upcoming assemblies, competitions, and events we'll be covering.</p>
        <span class="quicklink-arrow">→</span>
      </router-link>
      <router-link to="/info/newsletters" class="quicklink-card" v-sfx-hover>
        <h3>Newsletters</h3>
        <p>Member updates, workshops, and what's happening in the club.</p>
        <span class="quicklink-arrow">→</span>
      </router-link>
    </div>
  </section>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue';
import GradWrap from '../components/GradWrap.vue';
import SecHead from '../components/SecHead.vue';
import { playSfx } from '../composables/useSfx.js';
import '../assets/css/pages/home.css';

/* ── HERO PANEL EXPAND/COLLAPSE ───────────────────
   Ported from js/pages/home.js. `expanded` tracks at most one open
   panel by id ('digital' | 'multimedia' | 'arts' | null); template
   class/aria bindings replace the old classList + querySelector
   wiring, and this view owns its own Escape-key listener so it's
   cleaned up on unmount instead of leaking across route changes. */
const expanded = ref(null);

function expandPanel(name) {
  if (expanded.value === name) return;
  expanded.value = name;
  document.body.style.overflow = 'hidden';
}

function collapsePanel() {
  if (expanded.value === null) return;
  playSfx('menuback');
  expanded.value = null;
  document.body.style.overflow = '';
}

function onPanelClick(name) {
  if (expanded.value === name) return;
  expandPanel(name);
}

function onPanelKeydown(name, e) {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault();
    if (expanded.value !== name) expandPanel(name);
  }
}

function onKeydown(e) {
  if (e.key === 'Escape' && expanded.value !== null) collapsePanel();
}

onMounted(() => {
  document.addEventListener('keydown', onKeydown);
});

onBeforeUnmount(() => {
  document.removeEventListener('keydown', onKeydown);
  // Safety net in case the view unmounts (route change) while a
  // panel is still expanded — don't leave scrolling locked.
  document.body.style.overflow = '';
});
</script>
