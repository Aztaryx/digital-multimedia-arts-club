# DMAC SPA conversion — progress notes

Converting the original multi-page static site into a Vite + Vue 3 +
vue-router SPA. This zip is a checkpoint — everything in it is done and
wired together; nothing partial was included.

**Status: all 11 routes now exist and `npm run build` succeeds
end-to-end** (verified this checkpoint — see below). What's left is
mostly real-world verification (visual QA in a browser, testing login
against a live Supabase project) rather than missing code — see "Not
done yet" at the bottom for the honest list.

## Done

- **Scaffold**: Vite + Vue 3, `vue-router@4`, `@supabase/supabase-js` installed.
- **`src/lib/`** — all shared JS engines ported from `js/` to real ES modules
  (no more `window.sb` / `window.SFX` globals):
  - `supabase-client.js` — now uses the npm `@supabase/supabase-js` package,
    exports `{ sb }`.
  - `sfx-data.js` / `sfx.js` — export `SFX_DATA` / default `SFX`.
  - `animations.js` — exports `initGradText`, `scrambleGradWrap`.
  - `leaderboard.js` — exports default `Leaderboard`, imports `{ sb }`.
  - `member-auth.js` — exports default `MemberAuth`, imports `{ sb }`.
  - `badges.js` — new helper, uses `import.meta.glob` to turn
    `src/assets/badges/*.svg` into URLs (for preloading + badge rendering).
- **`src/assets/css/`** — `global.css`, `animations.css`, `pages/*.css` copied
  over as-is. Not yet wired into individual views (next step).
- **`src/assets/badges/`** — badge SVGs copied over as-is.
- **`src/router/index.js`** — routes for every page in the original site
  (`/`, `/about`, `/about/mission`, `/about/members`, `/projects`,
  `/info/newsletters`, `/info/update-log`, `/info/faq`, `/join`, `/socials`,
  `/login`), lazy-loaded, with `document.title` updates per route.
- **`src/directives/index.js`** — `v-sfx-hover`, `v-sfx-protected`,
  `v-sfx-tap`, `v-reveal` — replace the old `querySelectorAll(...)` wiring
  in `global.js` with directives applied directly where needed.
- **`src/composables/useSfx.js`** — `playSfx()` helper.
- **`src/components/`**:
  - `GradWrap.vue` — the `.grad-wrap/.grad-base/.grad-layer` gradient-text
    pattern as a self-wiring component (calls `initGradText` on mount —
    no more global `querySelectorAll('.grad-wrap')` pass needed).
  - `SecHead.vue` — the diamond + heading pattern reused across pages.
  - `NavBar.vue` — full desktop + mobile nav, active-link state computed
    from `useRoute()` (same "section stays highlighted, sub-link needs
    exact match" logic as the old `resolvePath()`/`startsWith()` code).
  - `FooterSection.vue` — footer + the animated zigzag divider (ported
    1:1, ref-based instead of `getElementById`).
- **`src/App.vue`** — persistent `NavBar` + `FooterSection` around
  `<router-view>`, plus the preloader. The preloader now genuinely only
  runs once per visit (mounts once), instead of once per page load —
  the old code's own comments flagged this as something only an SPA
  rewrite could fix.
- **`src/main.js`**, root **`index.html`** (fonts/title/favicon moved here
  since they're now app-shell-level, not per-page) — wired up.

## Done since last checkpoint

- **`src/views/HomeView.vue`** — first full view, ported from `index.html` +
  `js/pages/home.js`:
  - Hero (3 panels: Digital / Multimedia / Arts) with expand/collapse —
    the old `currentExpanded` module variable + classList wiring is now a
    single `expanded` ref (`'digital' | 'multimedia' | 'arts' | null`),
    driving the `.expanded` / `.has-expanded` classes and the overlay's
    `aria-hidden` via template bindings instead of manual DOM queries.
  - Click-to-expand, Enter/Space-to-expand, close-button, and
    Escape-to-collapse all ported 1:1. The Escape listener is added in
    `onMounted` and explicitly removed in `onBeforeUnmount` (with a
    `body.style.overflow` safety reset) so it can't leak across route
    changes the way a page-scoped `document.addEventListener` never had
    to worry about before.
  - Gradient headings (`hp-word`, `hp-expanded-title`, and the three
    `SecHead` section titles) use the existing `GradWrap`/`SecHead`
    components instead of hand-rolled `.grad-wrap`/`.grad-layer` markup.
  - Welcome / What We Do / Why Join sections use `v-reveal` (in place of
    the old `class="reveal"` + global IntersectionObserver pass) and
    `v-sfx-hover` on the `.wwd-card` grid (matching the directive's own
    doc comment, which named `.wwd-card` as an intended use site).
  - `css/pages/home.css` is now imported directly in the view (first
    page CSS actually wired in — confirmed via a scratch `vite build`
    with stub views for the remaining routes, which bundled it as its
    own `HomeView-*.css` chunk).

## Done since last checkpoint (this pass)

- **`src/views/about/AboutView.vue`** — ported from `about/index.html`.
  Static content; `v-sfx-hover` added to `.about-img-frame` per the
  original `HOVER_FX_SELECTOR` list (this was the point where that
  full list — see `js/global.js`'s `HOVER_FX_SELECTOR` — got cross-
  checked; it also caught missing `v-sfx-hover` on `.mission-card`
  and `.req-card`/`.join-email-link`, fixed below).
- **`src/views/about/MissionView.vue`** — ported from
  `about/mission.html`. Static, no page JS in the original.
- **`src/views/about/MembersView.vue`** — the big one. Ported from
  `about/members.html` + `js/pages/members.js` (401 lines):
  - Roster grids (advisers/officers/team members) are now driven by
    small arrays (`ADVISERS`/`OFFICERS`/`TEAMS`) instead of 18
    hand-copied card blocks — same DOM/classes as the original.
  - The `MEMBERS` profile-popup data object is kept 1:1 as a plain
    object (genuinely per-person content, not a layout concern).
  - Card open/close state is `selectedId`/`cardOpen`/`panelOpen` refs
    instead of overlay/panel classList toggles; the mini zigzag divider
    is computed into `zigzagViewBox`/`zigzagPoints` refs instead of
    direct `setAttribute` calls, same triangle-strip math.
  - Badge rendering: `lib/badges.js`'s `BADGE_URLS` (import.meta.glob
    over `src/assets/badges/*.svg`) only knows about the tier gems +
    `speedtypist.svg` — none of the per-person badge icons referenced
    in `MEMBERS` (`founder.png`, `quartzcontributor.png`, etc.) exist
    as files yet. Rather than port the old two-step `<img onerror>`
    fallback chain, the view checks up front and renders the ◆ glyph
    fallback directly when a file isn't known — same end visual result
    today, and it'll start resolving real art automatically once
    matching `.svg` files are added (no code change needed then).
  - Skipped porting the `card-banner-wm` cleanup block from the
    original `openCard()` — confirmed via grep that no element ever
    gets that class anywhere in the codebase; it was dead code, and
    Vue's declarative re-render can't accumulate stale children the
    way the old imperative DOM-append code theoretically could anyway.
- **`src/views/ProjectsView.vue`**, **`SocialsView.vue`**,
  **`src/views/JoinView.vue`** — static content ports. `v-sfx-hover`
  added to `.req-card` and `.join-email-link` on the Join view per
  `HOVER_FX_SELECTOR`.
- **`src/views/info/FaqView.vue`** — static; internal `<a href="../join/">`
  links converted to `<router-link>`.
- **`src/views/info/NewslettersView.vue`** — static; `.news-empty` stubs
  get `v-sfx-protected` (the directive's own doc comment names this as
  its intended use site, and `js/global.js` confirms the original wiring).
- **`src/views/LoginView.vue`** — ported from `login/index.html` +
  `js/pages/login.js` (338 lines): two-step role→credentials flow,
  wired to the already-ported `lib/member-auth.js` and `lib/supabase-client.js`.
  `window.location.href = '../index.html'` redirects became
  `router.push('/')`. This is a **standalone route** — the original
  login page has its own header/footer, not the site nav — so:
  - `router/index.js`'s `/login` route got `meta.hideChrome: true`.
  - `App.vue` now reads `route.meta.hideChrome` and conditionally
    skips rendering `NavBar`/`FooterSection` (small, deliberate edit
    to an already-"done" file — this gap only became visible once
    there was an actual `LoginView` to route to).
  - Copied `assets/aztaryx logo.svg` into `src/assets/` (referenced by
    the login page's bottom bar) — this was missed in the original
    asset-copying pass, since only `css/` and `badges/` were carried
    over then.
- **`src/views/info/UpdateLogView.vue`** — ported from
  `info/update-log.html` (752 lines) + `js/pages/update-log.js`. The
  24 changelog entries were extracted programmatically (one-time
  BeautifulSoup script, not hand-retyped) into a `LOG_ENTRIES` array
  driving a `v-for`, rather than porting 700+ lines of near-identical
  `<details>` markup by hand — same content, verified count (24 in,
  24 out). The click-flash interaction (`.is-clicked` + the
  `log-card-click` CSS animation) is a small `flashing` reactive map
  keyed by commit hash, using `requestAnimationFrame` in place of the
  original's `void card.offsetWidth` forced-reflow trick to let the
  animation restart on a rapid repeat click.

## Verified this checkpoint

- `npm install && npm run build` succeeds with no errors or warnings —
  all 11 routes (`/`, `/about`, `/about/mission`, `/about/members`,
  `/projects`, `/info/newsletters`, `/info/update-log`, `/info/faq`,
  `/join`, `/socials`, `/login`) resolve and bundle, each with its own
  CSS chunk (confirms every view's `assets/css/pages/*.css` import is
  actually wired in, not just copied).
- This was a build-level check only — no dev server click-through, no
  visual QA in an actual browser, no test against a live Supabase
  project. See below.

## Not done yet / needs real verification

- **Visual QA.** Nothing in this pass was checked in an actual
  rendered browser — only `vite build` output (module resolution +
  CSS bundling). Run `npm run dev` and click through all 11 routes,
  including the mobile nav (`#hamburger`), the members card overlay,
  and the login flow's two steps.
- **Login against a real Supabase project.** `LoginView.vue` is wired
  to `MemberAuth`/`sb.auth`, but password login, the Google OAuth
  redirect round-trip, and session restore on reload were not
  exercised against live data here — needs the actual Supabase
  project's env vars/URL and a real member row to test against.
- **Badge art.** As noted above, per-person badge icons
  (`founder.png`, `quartzcontributor.png`, `quartzbuilder.png`,
  `quartzsecret.png`, `copperlarper.png`) don't exist as files, so
  every badge on the Members page currently renders its ◆ fallback.
  Add matching `.svg` files to `src/assets/badges/` (same naming
  convention as the tier gems) to make real icons appear — no other
  code change needed, `lib/badges.js`'s glob will pick them up.
  `placeholder.svg` (the old file-missing fallback) still doesn't
  exist either; not needed anymore since the view checks statically,
  but add it if you want the exact old two-step fallback back.
- **Newsletters content.** `.news-empty` stubs are still stubs — swap
  in real `.news-panel` cards (template for one is commented directly
  above `.news-scroll` in `NewslettersView.vue`) once there's an
  actual announcement/event to show. Note `.news-panel` is in
  `HOVER_FX_SELECTOR`, so give it `v-sfx-hover` when you add it.
- **Projects content.** `ProjectsView.vue` is still the "coming soon,
  check Facebook" notice from the original — no change needed unless
  the club is ready to link real project pages.
- **`dev/*.html`** test harnesses (`sfx-test.html`, `leaderboard-test.html`,
  `auth-test.html`) and the Supabase SQL files weren't touched — they
  were out of scope for the SPA conversion in the original static
  site too, and still are.
