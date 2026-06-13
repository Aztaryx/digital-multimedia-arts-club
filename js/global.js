/* ═══════════════════════════════════════════════════
   DMAC — GLOBAL SCRIPTS
   Runs on every page. Handles: preloader, nav,
   hamburger, mobile nav, scroll reveals, active link
   detection, gradient-text headings, and the
   zigzag + footer divider.
═══════════════════════════════════════════════════ */

(function () {
  'use strict';

  const el = id => document.getElementById(id);

  /* ── PRELOADER ──────────────────────────────── */
  Promise.all([
    document.fonts.ready,
    new Promise(res => {
      if (document.readyState === 'complete') res();
      else window.addEventListener('load', res);
    })
  ]).then(() => {
    document.body.classList.add('loaded');
    setTimeout(() => el('preloader')?.classList.add('hidden'), 380);

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

})();
