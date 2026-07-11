/* Local badge art — the one exception to "media lives in the
   dmac-assets repo" (see README), since badges get edited alongside
   the site itself. Vite's import.meta.glob turns every file in
   src/assets/badges/ into either a URL or its raw text content —
   both read from the same source files, just two different ways in. */

const urlModules = import.meta.glob('../assets/badges/*.svg', {
  eager: true,
  query: '?url',
  import: 'default',
});

const rawModules = import.meta.glob('../assets/badges/*.svg', {
  eager: true,
  query: '?raw',
  import: 'default',
});

function nameFromPath(path) {
  return path.split('/').pop().replace(/\.svg$/, '');
}

// Strips the XML prolog + Inkscape's export comment that every file
// here starts with, keeping only the actual <svg>...</svg> — that's
// the part that's safe (and clean) to drop straight into innerHTML
// via v-html.
function cleanSvg(raw) {
  const match = raw.match(/<svg[\s\S]*<\/svg>/i);
  return match ? match[0] : raw;
}

// { 'copper-badge': '/assets/copper-badge-hash.svg', ... } — still
// used by App.vue's preloader (an <img> still needs a real URL to
// preload). Badge *rendering* itself no longer uses this — see
// BADGE_SVG below — so this now exists purely for that preload step.
export const BADGE_URLS = Object.fromEntries(
  Object.entries(urlModules).map(([path, url]) => [nameFromPath(path), url])
);

export const BADGE_URL_LIST = Object.values(BADGE_URLS);

// { 'copper-badge': '<svg ...>...</svg>', ... } — the actual markup,
// meant to be inlined directly into the DOM (v-html) wherever a badge
// renders (about/MembersView.vue), rather than sitting behind an
// opaque <img src="...">. Once it's real <svg>/<path> DOM nodes, CSS
// can reach its internals directly (recolor a fill, target a specific
// path, animate a piece of it, whatever) — none of which is possible
// through an <img>, which is a black box no matter what's inside it.
export const BADGE_SVG = Object.fromEntries(
  Object.entries(rawModules).map(([path, svg]) => [nameFromPath(path), cleanSvg(svg)])
);
