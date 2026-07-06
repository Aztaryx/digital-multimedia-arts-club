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
          <p class="hp-expanded-tagline">Code &bull; Circuits &bull; Cyberspace</p>
          <div class="hp-expanded-text">
            <p>
              The Digital pillar is all about understanding the tech we use every day — and learning how to make it do cool stuff. We explore web development, basic coding, and how computers actually work, all at a pace that makes sense for everyone.
            </p>
            <p>
              Whether you're curious about how websites are built, want to learn what's inside your computer, or just like figuring out how things work, this is the place to start. We keep it beginner-friendly and hands-on — no lectures, just learning by doing.
            </p>
            <p>
              Some of the things we get into: building simple websites with HTML and CSS, learning your way around different software, troubleshooting tech problems like a pro, and exploring tools that make everyday tasks easier. You don't need to be a "tech person" — you just need to be curious.
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
              The Multimedia pillar is where we bring ideas to life through video, sound, and motion. If you've ever watched a cool edit or short film and thought "I wanna make something like that," this is your starting point.
            </p>
            <p>
              We cover the full process — coming up with ideas, planning shots, filming, editing, adding effects, and putting it all together into something you're proud of. You'll get hands-on time with editing software and learn the basics of how movies, music videos, and online content are actually made.
            </p>
            <p>
              No experience needed at all. Whether you want to make short films with friends, put together highlight reels, try out motion graphics, or just learn how to edit videos for fun — we'll help you figure it out step by step. Everyone starts somewhere, and this is a great place to start.
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
              The Arts pillar is where your creativity gets to run free. This is all about making things that look awesome — whether that's digital drawings, poster designs, photo edits, or anything visual you can dream up.
            </p>
            <p>
              We explore digital illustration, graphic design, photography, and more. You'll learn how to use design tools, develop your own style, and pick up skills like composition, color theory, and typography along the way — without it feeling like a class.
            </p>
            <p>
              There's no "right way" to make art here. Whether you're already sketching every day or you've never opened a drawing app before, you're welcome. We're here to experiment, share ideas, and help each other get better. Your portfolio starts here.
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
      Welcome to DMAC! We're a community for anyone who loves making things —
      whether that's editing video, drawing digital art, taking photos, building
      websites, or just messing around with new software and hardware to see what
      it can do. No experience needed, no pressure to be "good" yet. We meet
      regularly to work on projects together, learn from each other, and share
      what we've made. If you've ever thought "I wish I knew how to make that,"
      this is where you find out.
    </p>
  </section>

  <!-- ════════════════════════════════ WHAT WE DO ═══════════════════════════════ -->
  <section class="home-section" v-reveal>
    <SecHead>What We Do</SecHead>
    <div class="wwd-grid">
      <div class="wwd-card" v-sfx-hover>
        <h3>Video &amp; Animation</h3>
        <p>Short films, edits, motion graphics, and everything in between.</p>
      </div>
      <div class="wwd-card" v-sfx-hover>
        <h3>Graphic Design &amp; Digital Art</h3>
        <p>Illustration, branding, digital painting, and design challenges.</p>
      </div>
      <div class="wwd-card" v-sfx-hover>
        <h3>Photography</h3>
        <p>Photo walks, editing, and visual storytelling.</p>
      </div>
      <div class="wwd-card" v-sfx-hover>
        <h3>Web Development</h3>
        <p>Building websites and web apps — including this one.</p>
      </div>
      <div class="wwd-card" v-sfx-hover>
        <h3>Tech &amp; Computer Skills</h3>
        <p>ADB, benchmarking, computer setup, and getting under the hood of how things work.</p>
      </div>
    </div>
  </section>

  <!-- ════════════════════════════════ WHY JOIN ═════════════════════════════════ -->
  <section class="home-section" v-reveal>
    <SecHead>Why Join DMAC</SecHead>
    <div class="why-grid">
      <div class="why-item">
        <h3>No experience required</h3>
        <p>We teach the tools as we go, whether that's editing software, design programs, or the basics of coding and computer setup. Show up curious, leave with skills.</p>
      </div>
      <div class="why-item">
        <h3>Build a real portfolio</h3>
        <p>Work on projects you can point to later, for college applications, job applications, or just to have something to show for your time.</p>
      </div>
      <div class="why-item">
        <h3>Shared tools &amp; resources</h3>
        <p>Members pitch in extra gear, drives, cables, and software tips so everyone has what they need to get started.</p>
      </div>
      <div class="why-item">
        <h3>Hands-on, not just talk</h3>
        <p>Meetings are built around making things, not sitting through slides.</p>
      </div>
      <div class="why-item">
        <h3>Find your people</h3>
        <p>Work alongside other students into the same stuff, at whatever level you're at.</p>
      </div>
      <div class="why-item">
        <h3>Get your work seen</h3>
        <p>Featured in our projects gallery and at school events.</p>
      </div>
    </div>
    <p class="home-teaser">
      Game design and audio production are on our radar as the club grows —
      let us know if that's something you'd want to see.
    </p>
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
