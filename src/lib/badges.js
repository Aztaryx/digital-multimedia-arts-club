/* Local badge art — the one exception to "media lives in the
   dmac-assets repo" (see README), since badges get edited alongside
   the site itself. Vite's import.meta.glob turns every file in
   src/assets/badges/ into a URL the bundler knows how to resolve
   (works the same in dev and after a production build). */

const modules = import.meta.glob('../assets/badges/*.svg', {
  eager: true,
  query: '?url',
  import: 'default',
});

// { 'copper-badge': '/assets/copper-badge-hash.svg', ... }
export const BADGE_URLS = Object.fromEntries(
  Object.entries(modules).map(([path, url]) => {
    const name = path.split('/').pop().replace(/\.svg$/, '');
    return [name, url];
  })
);

export const BADGE_URL_LIST = Object.values(BADGE_URLS);
