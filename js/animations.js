/* ═══════════════════════════════════════════════════
   DMAC — ANIMATION UTILITIES
   initGradText(wrapEl, layerEl) — wave-gradient text.
   Call once per heading after DOM is ready.
═══════════════════════════════════════════════════ */

/**
 * Attaches a continuous wave-clip + gradient-scroll effect to a
 * .grad-wrap / .grad-layer pair. Idles slowly; accelerates on hover.
 *
 * @param {HTMLElement} wrapEl  The .grad-wrap container
 * @param {HTMLElement} layerEl The .grad-layer span inside it
 */
function initGradText(wrapEl, layerEl) {
  if (!wrapEl || !layerEl) return;

  let hovered  = false;
  let waveOff  = 0, waveSpd = 0.012;
  let gradOff  = 0, gradSpd = 0;

  const W_HOV  = 0.09;   /* wave speed on hover     */
  const G_HOV  = 0.004;  /* gradient scroll on hover */
  const SPLIT  = 0.5;    /* vertical cut point       */

  function path(off, W, H) {
    const mid  = H * SPLIT;
    const amp  = H * 0.08;
    const freq = W / 200;
    const steps = Math.ceil(W / 3);
    let d = `M 0 ${H}`;
    for (let i = 0; i <= steps; i++) {
      const x = (i / steps) * W;
      const y = mid + Math.sin((i / steps) * freq * Math.PI * 2 + off) * amp;
      d += ` L ${x.toFixed(1)} ${y.toFixed(1)}`;
    }
    return d + ` L ${W} ${H} Z`;
  }

  function tick() {
    waveSpd += ((hovered ? W_HOV : 0.012) - waveSpd) * 0.04;
    gradSpd += ((hovered ? G_HOV : 0)     - gradSpd) * 0.04;
    waveOff += waveSpd;
    gradOff += gradSpd;

    const W = wrapEl.offsetWidth;
    const H = wrapEl.offsetHeight;
    layerEl.style.clipPath           = `path('${path(waveOff, W, H)}')`;
    layerEl.style.backgroundPosition = `${(gradOff % 1) * 200}% center`;

    requestAnimationFrame(tick);
  }

  wrapEl.addEventListener('mouseenter', () => hovered = true);
  wrapEl.addEventListener('mouseleave', () => hovered = false);
  document.fonts.ready.then(() => requestAnimationFrame(tick));
}

/**
 * Applies a text scramble glitch effect on a .grad-wrap element,
 * keeping both the base and layer text perfectly in sync so they don't clash.
 *
 * @param {HTMLElement} wrapEl The .grad-wrap container
 */
function scrambleGradWrap(wrapEl) {
  const base = wrapEl.querySelector('.grad-base');
  const layer = wrapEl.querySelector('.grad-layer');
  if (!base) return;

  // Use base.textContent as the source of truth for the original string
  const original = base.dataset.orig || (base.dataset.orig = base.textContent.trim());
  const CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%&';
  
  let frame = 0;
  const total = 26;

  // If already scrambling, clear it
  if (wrapEl._st) clearInterval(wrapEl._st);

  wrapEl._st = setInterval(() => {
    const scrambled = original.split('').map((ch, i) => {
      if (ch === ' ' || ch === "'") return ch;
      return (frame / total > i / original.length)
        ? ch
        : CHARS[Math.floor(Math.random() * CHARS.length)];
    }).join('');

    base.textContent = scrambled;
    if (layer) layer.textContent = scrambled;

    if (++frame > total) {
      base.textContent = original;
      if (layer) layer.textContent = original;
      clearInterval(wrapEl._st);
    }
  }, 28);
}

