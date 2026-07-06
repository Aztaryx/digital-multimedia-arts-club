<template>
  <main>
    <div class="page-section reveal">
      <SecHead>How to Join</SecHead>
      <div class="join-content">

        <!-- ── PHASE 1: SCHOOL ENROLLMENT ── -->
        <div class="join-phase">
          <div class="join-phase-header">
            <span class="join-phase-number">Step 1</span>
            <h2 class="join-phase-title">Enroll at Our School</h2>
          </div>
          <p style="font-family:var(--font);font-size:.92rem;line-height:1.75;color:var(--muted);">
            Before you can join DMAC, you need to be an officially enrolled student at
            Governor Ferrer Memorial Integrated National High School. If you're new to the school,
            here's the standard DepEd enrollment process.
          </p>

          <!-- Requirements -->
          <div class="req-grid">
            <div class="req-card" v-sfx-hover>
              <span class="req-card-label">Grade 7 — Elementary Graduates</span>
              <ul class="req-list">
                <li>SF9 / Form 138 (Elementary Report Card showing promotion eligibility)</li>
                <li>PSA Birth Certificate — Original &amp; Photocopy</li>
              </ul>
            </div>
            <div class="req-card" v-sfx-hover>
              <span class="req-card-label">Transferees — From Another High School</span>
              <ul class="req-list">
                <li>SF9 / Form 138 (Latest report card from your previous school)</li>
                <li>PSA Birth Certificate — Original &amp; Photocopy</li>
                <li>Certificate of Good Moral Character (from your old school)</li>
              </ul>
              <p class="req-note">
                Your SF10 / Form 137 (Permanent Record) will be requested directly by our school
                registrar from your previous school once you begin classes.
              </p>
            </div>
          </div>

          <!-- Enrollment Process -->
          <div class="process-steps">
            <div class="process-step">
              <p class="process-step-title">Online Pre-Registration</p>
              <p class="process-step-body">
                Keep an eye on the official school Facebook page at the start of enrollment season.
                You'll fill out the digital Enhanced Basic Education Enrollment Form (EBEEF) via
                the Google Form link posted there.
              </p>
            </div>
            <div class="process-step">
              <p class="process-step-title">On-Site Document Submission</p>
              <p class="process-step-body">
                Bring your physical requirements to campus during the scheduled enrollment days for
                your grade level. Place everything in a long brown envelope and submit to the
                assigned Teacher-in-Charge.
              </p>
            </div>
            <div class="process-step">
              <p class="process-step-title">Get Your Section</p>
              <p class="process-step-body">
                Once approved by school authorities, your details are logged into the Learner
                Information System (LIS). Final sectioning lists will be posted after processing.
              </p>
            </div>
          </div>
        </div>

        <div class="join-divider"></div>

        <!-- ── PHASE 2: CLUB SIGN-UP ── -->
        <div class="join-phase">
          <div class="join-phase-header">
            <span class="join-phase-number">Step 2</span>
            <h2 class="join-phase-title">Join the Club</h2>
          </div>
          <div class="club-join-box">
            <p>
              Once you're a student at the school, joining DMAC is straightforward.
              Reach out to us by email to get the application form and for any other inquiries.
            </p>
            <a class="join-email-link" href="mailto:aztaryxspersonalspacce@gmail.com" v-sfx-hover>
              aztaryxspersonalspacce@gmail.com
            </a>
            <div>
              <p style="font-family:var(--font);font-size:.8rem;font-weight:700;letter-spacing:.1em;text-transform:uppercase;color:var(--teal);margin-bottom:12px;">
                What to Prepare
              </p>
              <ul class="club-req-list">
                <li>
                  At least one image or media file showcasing one of your works or projects —
                  anything you've made or edited counts. It doesn't need to be polished;
                  it just gives us a starting point.
                </li>
              </ul>
            </div>
          </div>
        </div>

      </div>
    </div>
  </main>
</template>

<script setup>
import SecHead from '../components/SecHead.vue';
import '../assets/css/pages/join.css';

/* Ported from join/index.html — static content, no page-specific
   JS in the original. */
</script>
