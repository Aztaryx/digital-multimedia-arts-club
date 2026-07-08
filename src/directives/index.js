import SFX from '../lib/sfx.js';

/* ── v-sfx-hover ─────────────────────────────────
   Elements with a real visual hover effect (lift, glow, scale,
   border) rather than a plain text-color swap. Replaces the old
   HOVER_FX_SELECTOR querySelectorAll wiring in global.js — apply
   this directive directly on .hero-panel, .wwd-card, .member-card,
   etc. wherever they're used. */
export const vSfxHover = {
  mounted(el) {
    el.__sfxHoverHandler = () => SFX.play('menuhover');
    el.addEventListener('mouseenter', el.__sfxHoverHandler);
  },
  unmounted(el) {
    if (el.__sfxHoverHandler) el.removeEventListener('mouseenter', el.__sfxHoverHandler);
  },
};

/* ── v-sfx-protected ─────────────────────────────
   Empty/stub content (e.g. .news-empty) — plays one of three
   "protected" stings at random on click. */
const PROTECTED_SOUNDS = ['protectedsmall', 'protectedmedium', 'protectedlarge'];

export const vSfxProtected = {
  mounted(el) {
    el.__sfxProtectedHandler = () => {
      const pick = PROTECTED_SOUNDS[Math.floor(Math.random() * PROTECTED_SOUNDS.length)];
      SFX.play(pick);
    };
    el.addEventListener('click', el.__sfxProtectedHandler);
  },
  unmounted(el) {
    if (el.__sfxProtectedHandler) el.removeEventListener('click', el.__sfxProtectedHandler);
  },
};

/* ── v-sfx-tap ────────────────────────────────────
   Small-hit-target confirmation tick (nav dropdown triggers). */
export const vSfxTap = {
  mounted(el) {
    el.__sfxTapHandler = () => SFX.play('menutap');
    el.addEventListener('click', el.__sfxTapHandler);
  },
  unmounted(el) {
    if (el.__sfxTapHandler) el.removeEventListener('click', el.__sfxTapHandler);
  },
};

/* ── v-reveal ─────────────────────────────────────
   Scroll-triggered fade/slide-in, same IntersectionObserver logic
   as global.js's REVEAL section, but scoped as a directive so it
   naturally re-applies to each view's elements as routes change. */
let revealObs = null;
function revealElement(el) {
  if (el.classList.contains('visible')) return;
  el.classList.add('visible');
}

function getRevealObserver() {
  if (revealObs) return revealObs;
  if (typeof IntersectionObserver === 'undefined') return null;
  revealObs = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        revealElement(entry.target);
        revealObs.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });
  return revealObs;
}

export const vReveal = {
  mounted(el) {
    el.classList.add('reveal');
    const observer = getRevealObserver();
    if (!observer) {
      requestAnimationFrame(() => revealElement(el));
      return;
    }

    observer.observe(el);

    requestAnimationFrame(() => {
      const rect = el.getBoundingClientRect();
      const inView = rect.top < window.innerHeight * 0.88 && rect.bottom > 0;
      if (inView) {
        observer.unobserve(el);
        revealElement(el);
      }
    });
  },
  unmounted(el) {
    const observer = getRevealObserver();
    if (observer) observer.unobserve(el);
  },
};

export function installDirectives(app) {
  app.directive('sfx-hover', vSfxHover);
  app.directive('sfx-protected', vSfxProtected);
  app.directive('sfx-tap', vSfxTap);
  app.directive('reveal', vReveal);
}
