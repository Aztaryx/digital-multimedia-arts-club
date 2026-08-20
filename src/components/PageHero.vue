<!-- PageHero.vue — the new per-page title band, used at the top of
     every page EXCEPT Home (Home keeps its own hero). Sits directly
     under the fixed navbar, full-bleed (outside .page-section's
     max-width), with the actual page content following as a normal
     sibling afterward.

     The checkerboard is the same tile-dark pattern global.css already
     ships; the tint layered over it reuses #footer's own gradient
     recipe (orange → rose → violet → purple) rather than inventing a
     new palette. Both layers are confined to this component's own
     box, so the pattern visually "ends at the lines" the way the
     wireframe called for — nothing below .page-hero carries it. -->
<template>
  <header class="page-hero">
    <div class="page-hero-pattern tile-dark" aria-hidden="true"></div>
    <div class="page-hero-tint" aria-hidden="true"></div>

    <div class="page-hero-titlerow">
      <span class="page-hero-line page-hero-line--left">
        <svg class="page-hero-circuit" viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="12" cy="12" r="2.2" />
          <path d="M12 9.8V4M12 14.2V20M9.8 12H2M14.2 12H22" />
          <circle cx="12" cy="4" r="1.1" /><circle cx="12" cy="20" r="1.1" />
          <circle cx="2" cy="12" r="1.1" /><circle cx="22" cy="12" r="1.1" />
        </svg>
      </span>

      <h1 class="page-hero-title">
        <slot name="title">{{ title }}</slot>
      </h1>

      <span class="page-hero-line page-hero-line--right">
        <svg class="page-hero-circuit" viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="12" cy="12" r="2.2" />
          <path d="M12 9.8V4M12 14.2V20M9.8 12H2M14.2 12H22" />
          <circle cx="12" cy="4" r="1.1" /><circle cx="12" cy="20" r="1.1" />
          <circle cx="2" cy="12" r="1.1" /><circle cx="22" cy="12" r="1.1" />
        </svg>
      </span>
    </div>

    <p v-if="subtitle" class="page-hero-subtitle">{{ subtitle }}</p>
  </header>
</template>

<script setup>
defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
});
</script>

<style scoped>
.page-hero {
  position: relative;
  overflow: hidden;
  padding: calc(var(--nav-h, 80px) + 40px) 24px 44px;
  background: var(--surface, #1a1a1a);
  text-align: center;
}

.page-hero-pattern {
  position: absolute;
  inset: 0;
  opacity: 0.5;
}
.page-hero-tint {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    120deg,
    rgba(249, 115, 22, 0.18) 0%,
    rgba(214, 92, 106, 0.14) 35%,
    rgba(106, 42, 166, 0.16) 65%,
    rgba(76, 29, 149, 0.2) 100%
  );
  mix-blend-mode: soft-light;
}

.page-hero-titlerow {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 16px;
  max-width: 1200px;
  margin: 0 auto;
}

.page-hero-line {
  flex: 1;
  min-width: 20px;
  height: 1px;
  background: rgba(255, 255, 255, 0.3);
  position: relative;
  display: flex;
  align-items: center;
}
.page-hero-line--left { justify-content: flex-end; }
.page-hero-line--right { justify-content: flex-start; }

.page-hero-circuit {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
  fill: none;
  stroke: var(--orange);
  stroke-width: 1.4;
  stroke-linecap: round;
}
.page-hero-circuit circle:first-child {
  fill: var(--orange);
  stroke: none;
}
.page-hero-line--left .page-hero-circuit { transform: translateX(10px); }
.page-hero-line--right .page-hero-circuit { transform: translateX(-10px); }

.page-hero-title {
  flex: none;
  margin: 0;
  font-family: var(--font);
  font-weight: 700;
  font-size: clamp(1.9rem, 5vw, 3.4rem);
  line-height: 1.15;
  background: linear-gradient(135deg, var(--orange), var(--purple));
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  color: transparent;
  -webkit-text-stroke: 1.5px #000;
  paint-order: stroke fill;
}

.page-hero-subtitle {
  position: relative;
  z-index: 1;
  max-width: 640px;
  margin: 16px auto 0;
  color: rgba(240, 240, 240, 0.68);
  font-size: 0.92rem;
  line-height: 1.6;
}

@media (max-width: 640px) {
  .page-hero { padding-top: calc(var(--nav-h, 80px) + 28px); }
  .page-hero-line { display: none; }
  .page-hero-titlerow { justify-content: center; }
}
</style>
