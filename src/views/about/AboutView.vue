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
          DMAC — the Digital Multimedia Arts Club — is a student-run community watched over by Sir Richmond Causaren and the Head of TLE for anyone into digital creation: editing video, designing graphics, building websites, taking photos, or tinkering with tech and computers.
        </p>
        <p class="about-paragraph">
          We're brand new, just a couple of weeks old, so there's no long list of traditions yet — just a small group of students who decided to start making things together and are looking for more people to join in.
        </p>
        <p class="about-paragraph">
          That means if you sign up now, you're getting in early. Meetings are hands-on, projects are collaborative, and a lot of what DMAC becomes depends on what members want to do. We're open to any student, run by students, and growing based on interest — so if there's something you want to explore that we don't cover yet, tell us. That's basically how we got here in the first place.
        </p>
        <p class="about-paragraph">
          To keep everyone on the same page, we do ask for a quick example of your work when you sign up. It doesn't have to be a masterpiece, and it doesn't matter if it's "good" yet. It just shows us what you're currently into—whether that's a video edit, a design piece, a photo, a line of code, or a PC spec sheet you put together. It sets our starting standard so we know exactly what tools and projects to dive into first.
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
