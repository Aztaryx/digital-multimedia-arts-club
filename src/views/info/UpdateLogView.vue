<template>
  <main>
    <div class="page-section reveal" v-reveal>
      <SecHead>Update Log</SecHead>
      <div class="update-log-intro">
        <p>
          Complete git history for this site, shown newest first. Merge commits are included so the page
          matches the full repository history. Open an entry to see the files changed and a direct link
          to the matching GitHub commit.
        </p>
      </div>

      <ol class="update-timeline">
        <li class="log-entry" v-for="entry in LOG_ENTRIES" :key="entry.hash">
          <details
            class="log-entry-card"
            :class="{ 'is-clicked': flashing[entry.hash] }"
            @animationend="onAnimationEnd(entry.hash, $event)"
          >
            <summary class="log-entry-summary" @click="flash(entry.hash)">
              <span class="log-entry-mark" aria-hidden="true"></span>
              <span class="log-entry-head">
                <span>
                  <span class="log-date">{{ entry.date }}</span>
                  <span class="log-title">{{ entry.title }}</span>
                </span>
                <span class="log-hash">{{ entry.hash }}</span>
              </span>
            </summary>
            <div class="log-entry-body">
              <p class="log-summary">{{ entry.summary }}</p>
              <div class="log-meta-grid">
                <div>
                  <p class="log-meta-label">Files edited</p>
                  <p class="log-meta-value">{{ entry.files }}</p>
                </div>
                <a class="log-commit-link" :href="entry.commitUrl" target="_blank" rel="noreferrer">View commit</a>
              </div>
            </div>
          </details>
        </li>
      </ol>
    </div>
  </main>
</template>

<script setup>
import { reactive } from 'vue';
import SecHead from '../../components/SecHead.vue';
import '../../assets/css/pages/update-log.css';

/* Ported from info/update-log.html + js/pages/update-log.js.
   LOG_ENTRIES was extracted programmatically (one-time script) from
   the 24 <details> blocks in the original page — same content, now
   data instead of hand-copied markup. The click-flash behavior
   (briefly adding .is-clicked to replay the log-card-click CSS
   animation, same as the original's classList dance + void
   offsetWidth reflow trick) is now a small reactive flag per entry,
   keyed by commit hash. */

const LOG_ENTRIES = [
  {
    date: '2026-07-05',
    title: 'supabase prep 3.5',
    hash: '2da34de',
    summary: 'Finished the latest Supabase prep pass by tightening the auth test page.',
    files: 'dev/auth-test.html',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/2da34de',
  },
  {
    date: '2026-07-05',
    title: 'supabase prep 3',
    hash: 'c9cf0c6',
    summary: 'Continued the Supabase prep work on the auth test page.',
    files: 'dev/auth-test.html',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/c9cf0c6',
  },
  {
    date: '2026-07-05',
    title: 'supabase prep 2',
    hash: '8ab0cfb',
    summary: 'Expanded the Supabase prep work across the auth test page and leaderboard script.',
    files: 'dev/auth-test.html, js/leaderboard.js',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/8ab0cfb',
  },
  {
    date: '2026-07-05',
    title: 'supabase prep',
    hash: '8cad431',
    summary: 'Started the Supabase integration prep with the leaderboard test and support scripts.',
    files: 'dev/leaderboard-test.html, js/leaderboard.js, js/supabase-client.js',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/8cad431',
  },
  {
    date: '2026-07-05',
    title: 'update log added + new badge asset',
    hash: 'd1d301d',
    summary: 'Added the update log page itself, refreshed the shared scripts and styling, and added a new badge asset.',
    files: 'assets/badges/allomorphite-badge.svg, css/pages/update-log.css, info/update-log.html, js/global.js, js/pages/update-log.js',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/d1d301d',
  },
  {
    date: '2026-07-04',
    title: 'merge issue',
    hash: 'f73d934',
    summary: 'Merged the latest branch state. This was a merge commit with no direct file changes.',
    files: 'No file changes',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/f73d934',
  },
  {
    date: '2026-07-01',
    title: 'leaderboard test',
    hash: '7586e49',
    summary: 'Added a leaderboard test page and the supporting leaderboard script, with a few small member-page and README updates.',
    files: 'README.md, about/members.html, dev/leaderboard-test.html, js/leaderboard.js, js/pages/members.js',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/7586e49',
  },
  {
    date: '2026-07-04',
    title: 'sfx added',
    hash: '2bb4a51',
    summary: 'Expanded the shared sound-effect system and touched the main pages so SFX could be wired through the site.',
    files: 'about/index.html, about/members.html, about/mission.html, css/global.css, css/pages/members.css, css/pages/newsletters.css, index.html, info/faq.html, info/newsletters.html, info/update-log.html, join/index.html, js/global.js, js/pages/home.js, js/pages/members.js, projects/index.html, socials/index.html',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/2bb4a51',
  },
  {
    date: '2026-07-04',
    title: 'iforgot',
    hash: '8a859a1',
    summary: 'Added missing global script behavior and tightened the members page styling and spacing.',
    files: 'about/index.html, about/members.html, about/mission.html, css/global.css, css/pages/members.css, index.html, info/faq.html, info/newsletters.html, info/update-log.html, join/index.html, js/global.js, js/pages/members.js, projects/index.html, socials/index.html',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/8a859a1',
  },
  {
    date: '2026-07-04',
    title: 'devtools',
    hash: '1a94766',
    summary: 'Added a sound-effects test page plus the data and playback scripts behind it.',
    files: 'dev/sfx-test.html, js/sfx-data.js, js/sfx.js',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/1a94766',
  },
  {
    date: '2026-07-04',
    title: 'Merge branch \'main\' of https://github.com/aztaryx/digital-multimedia-arts-club',
    hash: '87413a0',
    summary: 'Merge commit with no file changes in this repository snapshot.',
    files: 'No file changes',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/87413a0',
  },
  {
    date: '2026-07-04',
    title: 'asset push 1',
    hash: 'b56543e',
    summary: 'Added the badge SVG assets used for club ranks and achievements.',
    files: 'assets/badges/amethyst-badge.svg, assets/badges/copper-badge.svg, assets/badges/diamond-badge.svg, assets/badges/gold-badge.svg, assets/badges/orichalcum-badge.svg, assets/badges/prism-badge.svg, assets/badges/ruby-badge.svg, assets/badges/silver-badge.svg, assets/badges/speedtypist.svg',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/b56543e',
  },
  {
    date: '2026-07-01',
    title: 'Move assets to external repo, merge announcements+events into newsletters',
    hash: '0cb42e5',
    summary: 'Moved media references out of the repository, replaced the old announcements/events split with the newsletters page, and updated links across the site.',
    files: 'README.md, _partials/footer.html, _partials/nav.html, about/index.html, about/members.html, about/mission.html, assets/audio/.gitkeep, assets/badges/.gitkeep, assets/images/hero/.gitkeep, assets/images/members/.gitkeep, assets/images/misc/.gitkeep, assets/images/projects/.gitkeep, assets/lib/.gitkeep, css/global.css, css/pages/announcements.css, css/pages/events.css, css/pages/home.css, css/pages/newsletters.css, index.html, info/events.html, info/newsletters.html, info/update-log.html, join/index.html, js/pages/events.js, js/pages/members.js, projects/index.html, socials/index.html',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/0cb42e5',
  },
  {
    date: '2026-06-29',
    title: 'updated git relecant files',
    hash: 'd0e298c',
    summary: 'Added repository metadata files for Git behavior and tracking.',
    files: '.gitattributes, .gitignore',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/d0e298c',
  },
  {
    date: '2026-06-29',
    title: 'overhaul + added missing placeholders mostly',
    hash: 'ac070e5',
    summary: 'Major homepage and members refresh, plus placeholder imagery, VS Code launch config, and supporting script updates.',
    files: '.vscode/launch.json, about/members.html, assets/images/hero/arts.png, assets/images/hero/digital.png, assets/images/hero/multimedia.png, assets/images/misc/schoollogo.png, assets/images/misc/tlelogo.png, css/pages/home.css, css/pages/members.css, index.html, js/pages/home.js, js/pages/members.js',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/ac070e5',
  },
  {
    date: '2026-06-17',
    title: 'removed ai slop',
    hash: '60141c9',
    summary: 'Replaced the about hero asset with group photos and expanded the FAQ and join pages with more complete content and styling.',
    files: 'about/index.html, assets/images/misc/about-hero.png, assets/images/misc/groupphoto1.jpg, assets/images/misc/groupphoto2.jpg, css/pages/about.css, css/pages/faq.css, css/pages/join.css, info/faq.html, join/index.html',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/60141c9',
  },
  {
    date: '2026-06-16',
    title: 'update',
    hash: '7166d84',
    summary: 'Large visual and content pass across the home, about, and mission pages, including new logo and hero assets plus animation and global script changes.',
    files: 'about/index.html, about/mission.html, assets/images/misc/about-hero.png, assets/logo.png, bonus/index_v4.html, css/global.css, css/pages/about.css, css/pages/home.css, css/pages/mission.css, index.html, js/animations.js, js/global.js',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/7166d84',
  },
  {
    date: '2026-06-13',
    title: 'fix 2',
    hash: 'a01e0c1',
    summary: 'Adjusted the about and home layouts, moved work into the home stylesheet, and cleaned up the shared global styling.',
    files: 'about/index.html, css/global.css, css/pages/about.css, css/pages/home.css, index.html',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/a01e0c1',
  },
  {
    date: '2026-06-13',
    title: 'fix',
    hash: '6ec7a5c',
    summary: 'Refined the homepage and shared CSS to fix layout issues and improve the first published version.',
    files: 'css/global.css, index.html',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/6ec7a5c',
  },
  {
    date: '2026-06-13',
    title: 'Delete CNAME',
    hash: '824f5b9',
    summary: 'Removed the GitHub Pages CNAME file.',
    files: 'CNAME',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/824f5b9',
  },
  {
    date: '2026-06-13',
    title: 'Create CNAME',
    hash: 'fbfece4',
    summary: 'Added a CNAME file for the site deployment configuration.',
    files: 'CNAME',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/fbfece4',
  },
  {
    date: '2026-06-13',
    title: 'fixed path issue for future website pushing',
    hash: 'a215ffb',
    summary: 'Flattened the repository structure so the site files live at the root and are ready for future deployments.',
    files: 'README.md, _partials/footer.html, _partials/nav.html, about/index.html, about/members.html, about/mission.html, assets/.gitkeep, assets/audio/.gitkeep, assets/images/hero/.gitkeep, assets/images/members/.gitkeep, assets/images/misc/.gitkeep, assets/images/projects/.gitkeep, assets/lib/.gitkeep, css/animations.css, css/global.css, css/pages/about.css, css/pages/announcements.css, css/pages/events.css, css/pages/faq.css, css/pages/home.css, css/pages/join.css, css/pages/members.css, css/pages/mission.css, css/pages/projects.css, css/pages/socials.css, css/pages/update-log.css, index.html, info/announcements.html, info/events.html, info/faq.html, info/update-log.html, join/index.html, js/animations.js, js/global.js, js/pages/about.js, js/pages/events.js, js/pages/home.js, js/pages/projects.js, js/pages/update-log.js, projects/index.html, socials/index.html',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/a215ffb',
  },
  {
    date: '2026-06-13',
    title: 'small fix',
    hash: '3e75f24',
    summary: 'Minor README cleanup and an added audio placeholder folder.',
    files: 'README.md, assets/audio/.gitkeep',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/3e75f24',
  },
  {
    date: '2026-06-13',
    title: 'first push..',
    hash: '7c43497',
    summary: 'Initial site scaffold with the main pages, partials, styling, scripts, and placeholder asset folders.',
    files: 'README.md, _partials/footer.html, _partials/nav.html, about/index.html, about/members.html, about/mission.html, assets/.gitkeep, assets/images/hero/.gitkeep, assets/images/members/.gitkeep, assets/images/misc/.gitkeep, assets/images/projects/.gitkeep, assets/lib/.gitkeep, css/animations.css, css/global.css, css/pages/about.css, css/pages/announcements.css, css/pages/events.css, css/pages/faq.css, css/pages/home.css, css/pages/join.css, css/pages/members.css, css/pages/mission.css, css/pages/projects.css, css/pages/socials.css, css/pages/update-log.css, index.html, info/announcements.html, info/events.html, info/faq.html, info/update-log.html, join/index.html, js/animations.js, js/global.js, js/pages/about.js, js/pages/events.js, js/pages/home.js, js/pages/projects.js, js/pages/update-log.js, projects/index.html, socials/index.html',
    commitUrl: 'https://github.com/Aztaryx/digital-multimedia-arts-club/commit/7c43497',
  },
];
const flashing = reactive({});

function flash(hash) {
  // Reset then re-add on the next frame so the animation restarts
  // even on a rapid repeat click (mirrors the original's
  // `void card.offsetWidth` forced-reflow trick).
  flashing[hash] = false;
  requestAnimationFrame(() => {
    flashing[hash] = true;
  });
}

function onAnimationEnd(hash, event) {
  if (event.animationName === 'log-card-click') {
    flashing[hash] = false;
  }
}
</script>
