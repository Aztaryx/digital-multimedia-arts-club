/* ═══════════════════════════════════════════════════
   DMAC — GLOBAL SCRIPTS
   Runs on every page. Handles: preloader, nav,
   hamburger, mobile nav, scroll reveals, active link
   detection, gradient-text headings, the zigzag +
   footer divider, and site-wide sound effect wiring
   (hover/tap/edge/empty-state feedback — see SFX
   sections near the bottom of this file).
═══════════════════════════════════════════════════ */

(function () {
  'use strict';

  const el = id => document.getElementById(id);

  /* ── SFX HELPER ──────────────────────────────
     Every page now loads js/sfx-data.js + js/sfx.js before this
     file, but this guards against that failing to load (bad
     network, etc.) so a missing SFX global can't crash the rest
     of the page's scripts — same defensive pattern as the
     initGradText / scrambleGradWrap checks below. */
  window.playSfx = (name, opts) => {
    if (typeof SFX !== 'undefined') SFX.play(name, opts);
  };

  /* ── PRELOADER ──────────────────────────────── */
  const preStatus = el('pre-status');
  const setStatus = text => { if (preStatus) preStatus.textContent = text; };

  /* Site root, derived from this script's own <script src="…js/global.js">
     tag rather than hardcoded. Every page loads this file via a relative
     path matching its own folder depth ("js/global.js" at root,
     "../js/global.js" one level down — see any page's <script> block), so
     this resolves the same way and keeps working regardless of nesting or
     a GitHub Pages project-page subpath. Must be read synchronously, right
     here at parse time — document.currentScript is only valid while this
     file is the one actively executing, not inside a later callback. */
  const ROOT = (() => {
    const src = document.currentScript && document.currentScript.src;
    return src ? src.replace(/js\/global\.js(?:[?#].*)?$/, '') : '';
  })();

  /* Local badge art — the one exception to "all media lives in the
     dmac-assets repo" (see README "Assets"), since badges get edited
     alongside the site itself. They're stamped into the DOM by
     members.js only when a member card is opened, so they never sit in
     an <img> at initial page load and the native `window.load` wait
     below never covers them — preloaded by hand here so the first card
     opened on ANY page already has them cached and decoded.
     No directory listing on a static site, so this list has to be kept
     in sync with assets/badges/ by hand when a file is added/renamed. */
  const BADGE_FILES = [
    'copper-badge.svg', 'silver-badge.svg', 'gold-badge.svg',
    'diamond-badge.svg', 'orichalcum-badge.svg', 'ruby-badge.svg',
    'amethyst-badge.svg', 'prism-badge.svg', 'speedtypist.svg'
  ];

  function preloadImage(url) {
    return new Promise(resolve => {
      const img = new Image();
      img.onload  = resolve;
      img.onerror = resolve; // one missing/renamed badge shouldn't stall the preloader
      img.src = url;
    });
  }

  const badgesReady = Promise.all(
    BADGE_FILES.map(f => preloadImage(`${ROOT}assets/badges/${f}`))
  );

  /* Every SFX sprite, fetched + decoded ahead of time instead of on
     first play(). A page nav is a real page load — nothing survives
     from the previous page, the AudioContext and decoded buffers are
     gone, and there's no way around that short of rebuilding this as a
     JS-routed single-page app (a much bigger change than this site's
     plain multi-page structure calls for). Without this preload, the
     FIRST sound triggered on each new page has to wait on a fetch +
     decode before it's audible, which is what reads as "the audio has
     to reload." Preloading here pays that cost during the loading
     screen instead — on every page — so playback is already warm the
     moment anything on the page could trigger a sound. */
  const sfxReady = (typeof SFX === 'undefined' || typeof SFX_DATA === 'undefined')
    ? Promise.resolve()
    : Promise.all(
        Object.keys(SFX_DATA).map(sprite =>
          SFX.preload(sprite).catch(err => {
            console.error(`SFX: preload failed for sprite "${sprite}" —`, err.message || err);
          })
        )
      );

  /* Stage 1: code — this script is mid-parse (this tag runs before
     animations.js / page scripts have loaded), so "code" is still
     genuinely in flight until DOMContentLoaded fires. */
  setStatus('Loading code…');

  const showImagesStage = () => setStatus('Loading images…');
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', showImagesStage, { once: true });
  } else {
    /* Scripts already parsed by the time we got here — skip straight
       to the images stage. */
    showImagesStage();
  }

  const fontsAndImagesReady = Promise.all([
    document.fonts.ready,
    new Promise(res => {
      if (document.readyState === 'complete') res();
      else window.addEventListener('load', res);
    }),
    badgesReady
  ]);

  fontsAndImagesReady.then(() => {
    setStatus('Loading audio…');
    return sfxReady;
  }).then(() => {
    setStatus('Ready');
    document.body.classList.add('loaded');
    setTimeout(() => {
      el('preloader')?.classList.add('hidden');
      playSfx('menuback');
    }, 380);

    /* Clean up will-change on hero panels (homepage only) */
    document.querySelectorAll('.hero-panel').forEach(p => {
      p.addEventListener('transitionend', () => { p.style.willChange = 'auto'; }, { once: true });
    });

    /* ── GRADIENT TEXT HEADINGS ──────────────────
       Auto-wires every .grad-wrap / .grad-layer pair on the page
       (section headings) once initGradText (animations.js) is
       available. The first .grad-wrap inside .sec-head is the
       solid-color diamond — its .grad-layer is display:none via
       CSS, so it's skipped automatically. */
    if (typeof initGradText === 'function') {
      document.querySelectorAll('.grad-wrap').forEach(wrap => {
        const layer = wrap.querySelector('.grad-layer');
        if (!layer || getComputedStyle(layer).display === 'none') return;
        initGradText(wrap, layer);
      });
    }
  });

  /* ── HAMBURGER ──────────────────────────────── */
  const burger   = el('hamburger');
  const mobileNav = el('mobile-nav');

  burger?.addEventListener('click', () => {
    burger.classList.toggle('open');
    mobileNav?.classList.toggle('open');
    playSfx('menutap');
  });

  /* Close mobile nav on any link click */
  mobileNav?.querySelectorAll('a').forEach(a => {
    a.addEventListener('click', () => {
      burger?.classList.remove('open');
      mobileNav.classList.remove('open');
    });
  });

  /* ── ACTIVE NAV LINK ────────────────────────── */
  /* Multi-page: compare resolved href to current pathname.
     - Top-level links (section entry points) light up on an
       exact match OR when the current page lives inside that
       section, so the parent stays highlighted while browsing
       its sub-pages.
     - Dropdown / mobile-group sub-links only light up on an
       exact match, so e.g. visiting Mission doesn't also mark
       the sibling "about us" link as active. */
  function resolvePath(href) {
    try {
      return new URL(href, window.location.href).pathname
        .replace(/\/index\.html$/, '/');
    } catch (_) {
      return null;
    }
  }

  function initActiveLinks() {
    const current = window.location.pathname.replace(/\/index\.html$/, '/');

    document.querySelectorAll('.nav-links > li > a, #mobile-nav > a').forEach(a => {
      const href = a.getAttribute('href');
      if (!href || href === '#') return;
      const resolved = resolvePath(href);
      if (!resolved) return;
      const isActive = current === resolved ||
        (resolved.length > 1 && current.startsWith(resolved));
      if (isActive) a.classList.add('active');
    });

    document.querySelectorAll('.nav-links .dropdown a, .mobile-group a').forEach(a => {
      const href = a.getAttribute('href');
      if (!href || href === '#') return;
      const resolved = resolvePath(href);
      if (!resolved) return;
      if (current === resolved) a.classList.add('active');
    });
  }
  initActiveLinks();

  /* ── SCROLL REVEALS (IntersectionObserver) ── */
  const revealObs = new IntersectionObserver((entries) => {
    entries.forEach(e => {
      if (e.isIntersecting) {
        e.target.classList.add('visible');
        revealObs.unobserve(e.target);

        // Trigger scramble effect on any .grad-wrap inside the revealed element
        if (typeof scrambleGradWrap === 'function') {
          setTimeout(() => {
            e.target.querySelectorAll('.grad-wrap').forEach(wrap => {
              const layer = wrap.querySelector('.grad-layer');
              if (layer && getComputedStyle(layer).display !== 'none') {
                scrambleGradWrap(wrap);
              }
            });
          }, 150);
        }
      }
    });
  }, { threshold: 0.12 });

  document.querySelectorAll('.reveal').forEach(e => revealObs.observe(e));

  /* ── ZIGZAG + FOOTER ─────────────────────────────
     Draws the jagged divider above the footer and clips the
     footer's top edge to match. Runs on every page that
     includes the zigzag SVG + footer markup (_partials/footer.html). */
  (function () {
    const PITCH = 150;   /* triangle base width (px, fixed) */
    const DEPTH = 70;    /* triangle height     (px, fixed) */
    const SPEED = 0.4;   /* px per frame at 60fps           */

    const svg    = document.getElementById('zigzag-svg');
    const poly   = document.getElementById('zigzag-poly');
    const footer = document.getElementById('footer');
    if (!svg || !poly || !footer) return;

    let offset = 0;

    function build(off) {
      const W      = document.documentElement.clientWidth;
      const startX = -(off % PITCH) - PITCH;
      const count  = Math.ceil((W + PITCH * 3) / PITCH);

      const svgPts  = [`${startX},${DEPTH}`];
      const clipPts = [`${startX}px ${DEPTH}px`];

      for (let i = 0; i < count; i++) {
        const tipX  = startX + i * PITCH + PITCH / 2;
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
      requestAnimationFrame(tick);
    }

    build(0);
    requestAnimationFrame(tick);
  })();

  /* ── SFX: NAV DROPDOWN TAP ───────────────────────
     The "about" / "information" / "socials" nav links are small
     hit targets that also open a dropdown on hover — a tap-style
     tick on click (in addition to whatever CSS hover already gives
     text-only feedback for) makes that small target feel
     confirmed. These are still real links, so the click also
     navigates — the sound just plays alongside, not instead of. */
  document.querySelectorAll('.nav-links li.has-dropdown > a[data-icon="down"]').forEach(a => {
    a.addEventListener('click', () => playSfx('menutap'));
  });

  /* ── SFX: HOVER (effect, not text) ───────────────
     Elements with a real visual hover effect (lift, glow, scale,
     border) rather than a plain text-color swap. Nav links, footer
     links, and inline FAQ links are deliberately excluded — those
     are just text turning a different color. Badge slots and member
     social icons are wired separately in members.js since they're
     created dynamically after a card opens, not present at load. */
  const HOVER_FX_SELECTOR = [
    '.hero-panel',
    '.hp-expanded-close',
    '.wwd-card',
    '.req-card',
    '.join-email-link',
    '.about-img-frame',
    '.officer-card',
    '.adviser-card',
    '.member-card',
    '.card-close',
    '.mission-card',
    '.news-panel'
  ].join(', ');

  document.querySelectorAll(HOVER_FX_SELECTOR).forEach(fx => {
    fx.addEventListener('mouseenter', () => playSfx('menuhover'));
  });

  /* ── SFX: PROTECTED CLICKS (empty/stub content) ──
     .news-empty (newsletters — announcements & events before any
     are added) is a placeholder with nothing behind it yet. Picks
     one of three "protected" stings at random each click so it
     doesn't feel like a broken button repeating the exact same
     sound. Projects/Socials used to share this via .stub-body —
     both now have real content, so that class no longer exists. */
  const PROTECTED_SOUNDS = ['protectedsmall', 'protectedmedium', 'protectedlarge'];
  document.querySelectorAll('.news-empty').forEach(stub => {
    stub.addEventListener('click', () => {
      const pick = PROTECTED_SOUNDS[Math.floor(Math.random() * PROTECTED_SOUNDS.length)];
      playSfx(pick);
    });
  });

  /* ── SFX: FLOOR (bottom of page) ─────────────────
     Fires once when the page is scrolled to (or within a hair of)
     the bottom, and re-arms only after scrolling back up a decent
     margin — otherwise a person resting at the bottom would hear
     it fire repeatedly on every micro-scroll. Never fires on pages
     short enough that they don't scroll at all (no scroll event to
     trigger it), which is the correct behavior — nothing was "hit". */
  (function () {
    const REARM_MARGIN = 60; // px — must scroll up this far above the bottom to re-arm
    let atFloor = false;

    function checkFloor() {
      const distanceFromBottom = document.documentElement.scrollHeight - (window.scrollY + window.innerHeight);
      if (distanceFromBottom <= 1 && !atFloor) {
        atFloor = true;
        playSfx('floor');
      } else if (distanceFromBottom > REARM_MARGIN && atFloor) {
        atFloor = false;
      }
    }

    window.addEventListener('scroll', checkFloor, { passive: true });
  })();

  /* ── SFX: SIDEHIT (page/scroll-area edges) ───────
     Two distinct edge triggers, both re-arming the same way as
     FLOOR above (hit → arm false → must move away by a margin to
     re-arm) so hovering right at an edge doesn't spam the sound:
       1. Cursor reaching the left/right edge of the viewport.
       2. A horizontally-scrolling area (.news-scroll on the
          newsletters page, .card-badges-scrollable inside a member
          card) reaching the start/end of its scroll range. */
  (function () {
    const EDGE_PX = 3;
    const REARM_PX = 40;
    const armed = { left: true, right: true };

    document.addEventListener('mousemove', e => {
      const x = e.clientX;
      const w = window.innerWidth;

      if (x <= EDGE_PX) {
        if (armed.left) { armed.left = false; playSfx('sidehit'); }
      } else if (x > REARM_PX) {
        armed.left = true;
      }

      if (x >= w - EDGE_PX) {
        if (armed.right) { armed.right = false; playSfx('sidehit'); }
      } else if (x < w - REARM_PX) {
        armed.right = true;
      }
    }, { passive: true });
  })();

  document.querySelectorAll('.news-scroll, .card-badges-scrollable').forEach(scroller => {
    const armed = { start: true, end: true };
    const REARM_PX = 40;

    scroller.addEventListener('scroll', () => {
      const maxScroll = scroller.scrollWidth - scroller.clientWidth;
      if (maxScroll <= 0) return; // nothing to scroll — no edges to hit

      const pos = scroller.scrollLeft;

      if (pos <= 0) {
        if (armed.start) { armed.start = false; playSfx('sidehit'); }
      } else if (pos > REARM_PX) {
        armed.start = true;
      }

      if (pos >= maxScroll) {
        if (armed.end) { armed.end = false; playSfx('sidehit'); }
      } else if (pos < maxScroll - REARM_PX) {
        armed.end = true;
      }
    }, { passive: true });
  });

})();