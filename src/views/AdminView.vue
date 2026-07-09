<template>
  <main>
    <div class="page-section reveal admin-shell" v-reveal>
      <SecHead>Admin Panel</SecHead>

      <p class="admin-intro">
        This space is for club-wide maintenance, announcements, and moderation controls. The data wiring can land later; the route and layout are in place now.
      </p>

      <div class="admin-grid">
        <section class="admin-card">
          <p class="admin-card-label">Global announcements</p>
          <h3>Publish club-wide notices</h3>
          <p>Announcements and maintenance updates will surface in notifications once the backend feed is connected.</p>
        </section>

        <section class="admin-card">
          <p class="admin-card-label">Maintenance</p>
          <h3>Track live updates</h3>
          <p>Use this area for downtime notes, repair windows, and rollout summaries.</p>
        </section>

        <section class="admin-card admin-card--accent">
          <p class="admin-card-label">Moderation</p>
          <h3>Oversee forums and member roles</h3>
          <p>Admin users can reach this panel directly from the navbar and the profile menu.</p>
        </section>
      </div>
    </div>
  </main>
</template>

<script setup>
import SecHead from '../components/SecHead.vue';
</script>

<style scoped>
.admin-shell {
  gap: 20px;
}

.admin-intro {
  max-width: 760px;
  color: rgba(240, 240, 240, 0.72);
  line-height: 1.7;
}

.admin-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
}

.admin-card {
  padding: 22px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.07);
}

.admin-card--accent {
  background: linear-gradient(135deg, rgba(249, 115, 22, 0.12), rgba(76, 29, 149, 0.14));
}

.admin-card-label {
  font-size: 0.7rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--orange);
  margin-bottom: 10px;
}

.admin-card h3 {
  margin: 0 0 10px;
  font-size: 1.1rem;
}

.admin-card p {
  margin: 0;
  color: rgba(240, 240, 240, 0.74);
  line-height: 1.65;
}

@media (max-width: 900px) {
  .admin-grid {
    grid-template-columns: 1fr;
  }
}
</style>