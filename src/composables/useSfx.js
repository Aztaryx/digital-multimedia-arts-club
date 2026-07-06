import SFX from '../lib/sfx.js';

/**
 * Thin wrapper so components don't import the SFX engine directly.
 * Mirrors the old global window.playSfx(name, opts) helper.
 */
export function playSfx(name, opts) {
  SFX.play(name, opts);
}

export function useSfx() {
  return { playSfx };
}
