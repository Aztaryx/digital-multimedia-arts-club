/* ═══════════════════════════════════════════════════
   home.js — page-specific scripts for index.html
   Handles: hero panel expand/collapse interaction
═══════════════════════════════════════════════════ */

(function () {
  'use strict';

  const hero   = document.getElementById('hero');
  const panels = document.querySelectorAll('.hero-panel');

  if (!hero || !panels.length) return;

  let currentExpanded = null;

  /* ── EXPAND ──────────────────────────────────── */
  function expandPanel(panel) {
    if (currentExpanded === panel) return;

    // Close any currently expanded panel first
    if (currentExpanded) collapsePanel(currentExpanded);

    currentExpanded = panel;
    panel.classList.add('expanded');
    hero.classList.add('has-expanded');
    document.body.style.overflow = 'hidden';

    // ARIA
    const overlay = panel.querySelector('.hp-expanded');
    if (overlay) overlay.setAttribute('aria-hidden', 'false');

    // Wire up gradient text in expanded overlay (if not already wired)
    if (typeof initGradText === 'function') {
      const overlayWraps = overlay?.querySelectorAll('.grad-wrap');
      overlayWraps?.forEach(wrap => {
        const layer = wrap.querySelector('.grad-layer');
        if (layer && !wrap._gradInited) {
          initGradText(wrap, layer);
          wrap._gradInited = true;
        }
      });
    }
  }

  /* ── COLLAPSE ────────────────────────────────── */
  function collapsePanel(panel) {
    panel.classList.remove('expanded');
    hero.classList.remove('has-expanded');
    document.body.style.overflow = '';

    // ARIA
    const overlay = panel.querySelector('.hp-expanded');
    if (overlay) overlay.setAttribute('aria-hidden', 'true');

    currentExpanded = null;
  }

  /* ── PANEL CLICK ─────────────────────────────── */
  panels.forEach(panel => {
    panel.addEventListener('click', (e) => {
      // Don't expand if clicking the close button or links inside expanded content
      if (e.target.closest('.hp-expanded-close')) return;
      if (e.target.closest('a')) return;

      if (panel.classList.contains('expanded')) return;

      expandPanel(panel);
    });

    // Keyboard: Enter/Space to expand
    panel.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        if (!panel.classList.contains('expanded')) {
          expandPanel(panel);
        }
      }
    });
  });

  /* ── CLOSE BUTTONS ───────────────────────────── */
  document.querySelectorAll('.hp-expanded-close').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const panel = btn.closest('.hero-panel');
      if (panel) collapsePanel(panel);
    });
  });

  /* ── ESCAPE KEY ──────────────────────────────── */
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && currentExpanded) {
      collapsePanel(currentExpanded);
    }
  });

})();
