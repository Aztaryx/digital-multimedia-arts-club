<template>
  <main>
    <!-- Two-column body -->
    <div class="about-body">

      <div class="about-img-frame reveal" v-sfx-hover v-reveal>
        <img class="about-img" src="https://aztaryx.github.io/dmac-assets/images/misc/groupphoto1.jpg" alt="Group Photo 1" />
      </div>
      <div class="about-img-frame reveal" v-sfx-hover v-reveal>
        <img class="about-img" src="https://aztaryx.github.io/dmac-assets/images/misc/groupphoto2.jpg" alt="Group Photo 2" />
      </div>

      <div class="about-text reveal" v-reveal>
        <SecHead>About Us</SecHead>
        <p class="about-paragraph">
          DMAC — the Digital Multimedia Arts Club — is a student-run club watched over by Sir Richmond Causaren and the Head of TLE. In practice, that makes us the school's go-to team for event coverage: we show up to record what happens, edit the footage and photos afterward, and post the finished coverage for the rest of the school to see.
        </p>
        <p class="about-paragraph">
          We're brand new, just a couple of weeks old, so there's no long list of traditions yet — just a small group of students who decided to start covering school events together and are looking for more people to join in.
        </p>
        <p class="about-paragraph">
          That means if you sign up now, you're getting in early. Coverage is a team effort — someone's filming, someone's taking photos, someone's editing, someone's designing the graphic, someone's writing the post — and a lot of how that work gets divided depends on what members are into. We're open to any student, run by students, and growing based on interest — so if there's a part of the process you want to get better at, tell us.
        </p>
        <p class="about-paragraph">
          To keep everyone on the same page, we do ask for a quick example of your work when you sign up. It doesn't have to be a masterpiece, and it doesn't matter if it's "good" yet. It just shows us what you're currently into — whether that's a video edit, a photo, a design piece, or anything else you've made. It sets our starting standard so we know exactly where to plug you into event coverage first.
        </p>
      </div>

    </div>
  </main>
</template>

<script setup>
import SecHead from '../../components/SecHead.vue';
import '../../assets/css/pages/about.css';

/* Ported from about/index.html. Original page had no page-specific
   JS (js/pages/about.js was an empty stub) — reveal-on-scroll and
   the gradient heading are handled by the v-reveal directive and
   SecHead/GradWrap components respectively. */
</script>
