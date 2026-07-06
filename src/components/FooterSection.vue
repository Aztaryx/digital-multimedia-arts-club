<template>
  <div class="zigzag-row" aria-hidden="true">
    <svg id="zigzag-svg" ref="svgRef" xmlns="http://www.w3.org/2000/svg">
      <polyline
        id="zigzag-poly"
        ref="polyRef"
        fill="none"
        stroke="rgba(255,255,255,.85)"
        stroke-width="1.5"
        stroke-linejoin="miter"
      />
    </svg>
  </div>

  <footer id="footer" ref="footerRef" class="tile-dark">
    <div class="footer-inner">
      <div class="footer-logo-row">
        <img src="https://aztaryx.github.io/dmac-assets/logo.png" alt="DMAC" height="48" />
        <span class="footer-club-name">Digital Multimedia Arts Club</span>
      </div>
      <nav class="footer-nav" aria-label="Footer navigation">
        <router-link to="/">Home</router-link>
        <router-link to="/about">About</router-link>
        <router-link to="/projects">Projects</router-link>
        <router-link to="/info/newsletters">Newsletters</router-link>
        <router-link to="/join">Join</router-link>
        <a href="https://github.com/Aztaryx/digital-multimedia-arts-club" target="_blank" rel="noopener">GitHub</a>
      </nav>
      <p class="footer-copy">© 2025 Digital Multimedia Arts Club. All rights reserved.</p>
    </div>
  </footer>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue';

const svgRef = ref(null);
const polyRef = ref(null);
const footerRef = ref(null);

let rafId = null;

onMounted(() => {
  const PITCH = 150; // triangle base width (px, fixed)
  const DEPTH = 70;  // triangle height     (px, fixed)
  const SPEED = 0.4; // px per frame at 60fps

  const svg = svgRef.value;
  const poly = polyRef.value;
  const footer = footerRef.value;
  if (!svg || !poly || !footer) return;

  let offset = 0;

  function build(off) {
    const W = document.documentElement.clientWidth;
    const startX = -(off % PITCH) - PITCH;
    const count = Math.ceil((W + PITCH * 3) / PITCH);

    const svgPts = [`${startX},${DEPTH}`];
    const clipPts = [`${startX}px ${DEPTH}px`];

    for (let i = 0; i < count; i++) {
      const tipX = startX + i * PITCH + PITCH / 2;
      const baseX = startX + (i + 1) * PITCH;
      svgPts.push(`${tipX},0`, `${baseX},${DEPTH}`);
      clipPts.push(`${tipX}px 0px`, `${baseX}px ${DEPTH}px`);
    }

    const farRight = startX + count * PITCH;
    clipPts.push(`${farRight}px 100%`, `${startX}px 100%`);

    svg.setAttribute('viewBox', `0 0 ${W} ${DEPTH}`);
    poly.setAttribute('points', svgPts.join(' '));
    footer.style.clipPath = `polygon(${clipPts.join(', ')})`;
  }

  function tick() {
    offset = (offset + SPEED) % PITCH;
    build(offset);
    rafId = requestAnimationFrame(tick);
  }

  build(0);
  rafId = requestAnimationFrame(tick);
});

onBeforeUnmount(() => {
  if (rafId) cancelAnimationFrame(rafId);
});
</script>
