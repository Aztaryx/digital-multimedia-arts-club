/* ═══════════════════════════════════════════════════
   DMAC — ANIMATION UTILITIES
   initGradText(wrapEl, layerEl) — kept for compatibility.
   The gradient text is now static; this hook intentionally does
   nothing so older call sites do not need to change immediately.
═══════════════════════════════════════════════════ */

/**
 * Compatibility stub for the old animated gradient text effect.
 *
 * @param {HTMLElement} wrapEl  The .grad-wrap container
 * @param {HTMLElement} layerEl The .grad-layer span inside it
 */
export function initGradText(wrapEl, layerEl) {
  if (!wrapEl || !layerEl) return;

  wrapEl.dataset.gradStatic = 'true';
  layerEl.style.clipPath = 'none';
  layerEl.style.backgroundPosition = 'center';
}

/**
 * Applies a text scramble glitch effect on a .grad-wrap element,
 * keeping both the base and layer text perfectly in sync so they don't clash.
 *
 * @param {HTMLElement} wrapEl The .grad-wrap container
 */
export function scrambleGradWrap(wrapEl) {
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

