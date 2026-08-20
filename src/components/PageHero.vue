<template>
  <header class="page-hero">
    <div class="page-hero-pattern tile-dark" aria-hidden="true"></div>
    <div class="page-hero-tint" aria-hidden="true"></div>

    <div class="page-hero-titlerow">
      <span class="page-hero-line page-hero-line--left"></span>
      <span class="page-hero-diamond page-hero-diamond--left" aria-hidden="true">♦</span>

      <h1 class="page-hero-title">
        <slot name="title">{{ title }}</slot>
      </h1>

      <span class="page-hero-diamond page-hero-diamond--right" aria-hidden="true">♦</span>
      <span class="page-hero-line page-hero-line--right"></span>
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
  /* Horizontal padding dropped entirely — the header line below needs
     to run truly edge-to-edge now, not just to the old 24px inset.
     Title/subtitle apply their own padding instead. */
  padding: calc(var(--nav-h, 80px) + 40px) 0 44px;
  background: var(--surface, #1a1a1a);
  text-align: center;
}

.page-hero-pattern {
  position: absolute;
  inset: 0;
  /* Lowered from 0.5, and now masked to fade out — see .page-hero-tint,
     same mask, same reasoning: both layers need to dissolve away
     before they reach the title's lower half instead of cutting off
     hard underneath it. */
  opacity: 0.28;
  -webkit-mask-image: linear-gradient(180deg, #000 0%, #000 52%, transparent 82%);
          mask-image: linear-gradient(180deg, #000 0%, #000 52%, transparent 82%);
}
.page-hero-tint {
  position: absolute;
  inset: 0;
  /* Brightened — roughly doubled from the old 0.14–0.2 range. */
  background: linear-gradient(
    120deg,
    rgba(249, 115, 22, 0.32) 0%,
    rgba(214, 92, 106, 0.26) 35%,
    rgba(106, 42, 166, 0.3) 65%,
    rgba(76, 29, 149, 0.38) 100%
  );
  mix-blend-mode: soft-light;
  -webkit-mask-image: linear-gradient(180deg, #000 0%, #000 52%, transparent 82%);
          mask-image: linear-gradient(180deg, #000 0%, #000 52%, transparent 82%);
}

.page-hero-titlerow {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  width: 100%;
  /* Pulled up so the title's top half actually rides over the
     grid/tint band above, instead of sitting flush below it. */
  margin-top: -22px;
}

.page-hero-line {
  flex: 1;
  min-width: 20px;
  /* Thicker + brighter — was a 1px hairline at low opacity. */
  height: 3px;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.4));
}
.page-hero-line--right {
  background: linear-gradient(90deg, rgba(255, 255, 255, 0.4), transparent);
}

.page-hero-diamond {
  flex-shrink: 0;
  padding: 0 14px;
  font-size: 1.05rem;
  line-height: 1;
  color: var(--orange);
  text-shadow: 0 0 10px rgba(249, 115, 22, 0.5);
}

.page-hero-title {
  position: relative;
  z-index: 1;
  flex: none;
  margin: 0;
  padding: 0 22px;
  font-family: var(--font);
  /* Bolder on both counts: heavier weight, thicker outline stroke. */
  font-weight: 800;
  font-size: clamp(1.9rem, 5vw, 3.4rem);
  line-height: 1.15;
  background: linear-gradient(135deg, var(--orange), var(--purple));
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  color: transparent;
  -webkit-text-stroke: 2.2px #000;
  paint-order: stroke fill;
}

.page-hero-subtitle {
  position: relative;
  z-index: 1;
  max-width: 640px;
  margin: 16px auto 0;
  padding: 0 24px;
  color: rgba(240, 240, 240, 0.68);
  font-size: 0.92rem;
  line-height: 1.6;
}

@media (max-width: 640px) {
  .page-hero { padding-top: calc(var(--nav-h, 80px) + 28px); }
  .page-hero-line,
  .page-hero-diamond { display: none; }
  .page-hero-titlerow { justify-content: center; margin-top: -14px; }
}
</style>
