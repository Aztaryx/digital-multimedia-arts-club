<template>
  <div class="view branding-view">
    <SecHead title="Branding" subtitle="DMAC visual identity & assets" />

    <div class="branding-content">
      <!-- Brand Guide Section -->
      <section class="brand-section">
        <h2>Brand Guidelines</h2>
        <div class="guidelines-grid">
          <div class="guideline-card">
            <h3>Logo</h3>
            <img src="https://aztaryx.github.io/dmac-assets/logo.png" alt="DMAC Logo" class="logo-preview" />
            <p>Our primary logo, used across all platforms and materials.</p>
          </div>

          <div class="guideline-card">
            <h3>Color Palette</h3>
            <div class="color-swatches">
              <div class="color-swatch" style="background: #f97316;">
                <span>#f97316</span>
              </div>
              <div class="color-swatch" style="background: #1f2937;">
                <span>#1f2937</span>
              </div>
              <div class="color-swatch" style="background: #ffffff; border: 1px solid #ccc;">
                <span>#ffffff</span>
              </div>
            </div>
          </div>

          <div class="guideline-card">
            <h3>Typography</h3>
            <div class="typography-sample">
              <p style="font-size: 1.5rem; font-weight: bold;">Heading (Bold)</p>
              <p>Body text (Regular weight, readable)</p>
            </div>
          </div>

          <div class="guideline-card">
            <h3>Icon Set</h3>
            <p>Hand-drawn minimalist icons (sourced).</p>
            <p class="small-text">Icons for: Home, About, Projects, Information, Join, Leaderboard, Branding, Socials, Admin, Notifications</p>
          </div>
        </div>
      </section>

      <!-- Asset Library Section -->
      <section class="brand-section">
        <h2>Asset Library</h2>
        <div class="assets-grid">
          <div class="asset-card">
            <h3>Logo Files</h3>
            <ul>
              <li><a href="#">dmac-logo.png</a></li>
              <li><a href="#">dmac-logo.svg</a></li>
              <li><a href="#">dmac-logo-white.png</a></li>
            </ul>
          </div>

          <div class="asset-card">
            <h3>Icons</h3>
            <p>19 hand-drawn icons in SVG and PNG formats</p>
            <ul>
              <li><a href="#">icon-set.zip</a></li>
              <li><a href="#">icon-usage-guide.pdf</a></li>
            </ul>
          </div>

          <div class="asset-card">
            <h3>Brand Guide PDF</h3>
            <p>Complete guidelines for using DMAC branding in projects</p>
            <a href="#" class="download-btn">Download PDF</a>
          </div>

          <div class="asset-card">
            <h3>Social Media Templates</h3>
            <p>Ready-to-use templates for announcements and posts</p>
            <ul>
              <li><a href="#">Facebook Post Template</a></li>
              <li><a href="#">Instagram Story Template</a></li>
            </ul>
          </div>
        </div>
      </section>

      <!-- Usage Guidelines -->
      <section class="brand-section">
        <h2>Usage Guidelines</h2>
        <div class="guidelines-text">
          <h3>Do's</h3>
          <ul>
            <li>Use the official logo files provided</li>
            <li>Maintain clear space around logos</li>
            <li>Use brand colors consistently</li>
            <li>Follow typography guidelines</li>
          </ul>

          <h3>Don'ts</h3>
          <ul>
            <li>Don't stretch or distort the logo</li>
            <li>Don't change the brand colors</li>
            <li>Don't use low-resolution versions</li>
            <li>Don't add effects or filters</li>
          </ul>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import SecHead from '../components/SecHead.vue';
</script>

<style scoped>
.branding-view {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.branding-content {
  margin-top: 2rem;
}

.brand-section {
  margin-bottom: 4rem;
}

.brand-section h2 {
  margin-bottom: 2rem;
  border-bottom: 2px solid var(--primary);
  padding-bottom: 1rem;
}

.guidelines-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 2rem;
}

.guideline-card {
  padding: 1.5rem;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--bg-secondary);
}

.guideline-card h3 {
  margin-top: 0;
}

.logo-preview {
  width: 100%;
  max-width: 200px;
  margin: 1rem 0;
}

.color-swatches {
  display: flex;
  gap: 1rem;
  margin: 1rem 0;
}

.color-swatch {
  width: 80px;
  height: 80px;
  border-radius: 4px;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  padding: 0.5rem;
  font-size: 0.75rem;
  color: #fff;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
}

.typography-sample {
  margin: 1rem 0;
}

.small-text {
  font-size: 0.9rem;
  color: var(--text-secondary);
}

.assets-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 2rem;
}

.asset-card {
  padding: 1.5rem;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--bg-secondary);
}

.asset-card h3 {
  margin-top: 0;
}

.asset-card ul {
  list-style: none;
  padding: 0;
  margin: 1rem 0;
}

.asset-card li {
  padding: 0.5rem 0;
}

.asset-card a {
  color: var(--primary);
  text-decoration: none;
}

.asset-card a:hover {
  text-decoration: underline;
}

.download-btn {
  display: inline-block;
  padding: 0.75rem 1.5rem;
  background: var(--primary);
  color: white;
  border-radius: 4px;
  text-decoration: none;
  margin-top: 1rem;
}

.download-btn:hover {
  opacity: 0.9;
}

.guidelines-text {
  background: var(--bg-secondary);
  padding: 2rem;
  border-radius: 8px;
}

.guidelines-text h3 {
  margin-top: 0;
}

.guidelines-text ul {
  margin-left: 1.5rem;
}

.guidelines-text li {
  margin: 0.5rem 0;
}
</style>
