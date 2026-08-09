<template>
  <main>
    <div class="page-section reveal" v-reveal>
      <SecHead>Branding</SecHead>
      <p class="brand-subtitle">DMAC's visual identity, in one place — how to identify us, and where the actual files live.</p>

      <!-- ── GUIDELINES ── -->
      <section class="brand-section">
        <h2 class="brand-section-title">Brand Guidelines</h2>
        <div class="brand-guidelines-grid">
          <div class="brand-card" v-sfx-hover>
            <h3>Logo</h3>
            <img src="https://aztaryx.github.io/dmac-assets/logo.png" alt="DMAC Logo" class="brand-logo-preview" />
            <p>Our primary logo, used across all platforms and materials.</p>
          </div>

          <div class="brand-card" v-sfx-hover>
            <h3>Color Palette</h3>
            <div class="brand-swatches">
              <div class="brand-swatch" style="background: var(--orange);"><span>#f97316</span></div>
              <div class="brand-swatch" style="background: var(--purple);"><span>#4c1d95</span></div>
              <div class="brand-swatch brand-swatch--light" style="background: #f0f0f0;"><span>#f0f0f0</span></div>
            </div>
          </div>

          <div class="brand-card" v-sfx-hover>
            <h3>Typography</h3>
            <div class="brand-type-sample">
              <p class="brand-type-heading">Chakra Petch — headings</p>
              <p class="brand-type-body">Rajdhani — body text, readable at small sizes.</p>
            </div>
          </div>

          <div class="brand-card" v-sfx-hover>
            <h3>Icon Set</h3>
            <p>Hand-drawn minimalist icons, sourced rather than generated — in progress.</p>
            <p class="brand-small-text">Home, About, Projects, Information, Join, Leaderboard, Branding, Socials, Admin, Notifications, and 9 more for dropdown items.</p>
          </div>
        </div>
      </section>

      <!-- ── ASSET LIBRARY ── -->
      <section class="brand-section">
        <h2 class="brand-section-title">Asset Library</h2>
        <div class="brand-assets-grid">
          <div class="brand-card" v-sfx-hover>
            <h3>Logo Files</h3>
            <p class="brand-small-text">Hosted in the <a href="https://github.com/Aztaryx/dmac-assets" target="_blank" rel="noopener">dmac-assets</a> repo alongside every other piece of shared media.</p>
          </div>

          <div class="brand-card" v-sfx-hover>
            <h3>Icons</h3>
            <p class="brand-small-text">The hand-drawn set referenced above — not published yet.</p>
          </div>

          <div class="brand-card" v-sfx-hover>
            <h3>Social Templates</h3>
            <p class="brand-small-text">Facebook post and story templates for announcements — not published yet.</p>
          </div>
        </div>
      </section>

      <!-- ── USAGE ── -->
      <section class="brand-section">
        <h2 class="brand-section-title">Usage Guidelines</h2>
        <div class="brand-usage-grid">
          <div class="brand-usage-col">
            <h3 class="brand-usage-do">Do</h3>
            <ul>
              <li>Use the official logo files as provided.</li>
              <li>Keep clear space around the logo.</li>
              <li>Use the two brand colors consistently.</li>
              <li>Follow the typography pairing above.</li>
            </ul>
          </div>
          <div class="brand-usage-col">
            <h3 class="brand-usage-dont">Don't</h3>
            <ul>
              <li>Stretch or distort the logo.</li>
              <li>Substitute the brand colors.</li>
              <li>Use low-resolution exports.</li>
              <li>Apply filters or effects on top of it.</li>
            </ul>
          </div>
        </div>
      </section>
    </div>
  </main>
</template>

<script setup>
import SecHead from '../components/SecHead.vue';
import '../assets/css/pages/branding.css';

/* Single combined page — identity guide + asset library in one place,
   not a dropdown, per dmac-consolidated-plan.md §9. Content here is
   still a placeholder pass; the icon set and downloadable asset
   files themselves aren't ready yet (see §3/§13). */
</script>
