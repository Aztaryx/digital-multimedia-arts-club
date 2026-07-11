## Beta v1.5 — admin panel → admin dashboard

The Admin Panel did exactly two things: post announcements/maintenance
notices, and award scores. Everything else an admin might need —
who's on the roster, who's silenced, what moderation has actually
happened, promoting/demoting roles — had no UI at all, either
hand-edited in the Supabase Table Editor or (for moderation history)
genuinely unreadable from the app in any form. This pass turns it into
an actual dashboard without touching either of the two things it
already did well.

- **New `supabase/dmac-admin-dashboard-schema.sql`** — two RPCs,
  same `_resolve_member_id()` + `site_role = 'admin'` gate every other
  admin RPC here uses (see `admin_upsert_score` in
  `dmac-admin-score-writing.sql`):
  - `admin_list_moderation_log()` — the admin-scoped sibling of
    `list_my_moderation_log` (`dmac-my-moderation-log-fix.sql`), minus
    the `target_id = caller` scoping, plus the target's name. Closes
    the same "no policies on `moderation_log`, so nothing could ever
    read it" gap that file documented, just for admins-viewing-everyone
    instead of members-viewing-themselves.
  - `admin_set_role()` — the write path `site_role` has never had.
    Refuses to demote the last remaining admin, so a wrong click in
    the new Members tab can't lock everyone out of `/admin` at once
    (`requiresAdmin` in `router/index.js`).
- **`AdminView.vue` rebuilt around five tabs** (Overview /
  Announcements / Badges & Scores / Members / Moderation) instead of
  one long scroll, with a persistent row of stat cards up top (member
  count + role breakdown, badges awarded + distinct badge count, forum
  thread/reply counts, announcement count, live silence count) that
  stays visible across every tab. The stat counts and Overview's
  "recent activity" feed (announcements + moderation actions, merged
  and sorted) come from tables that have been publicly readable since
  their own schema files (`members`, `scores`, `announcements`,
  `forum_threads`, `forum_posts`) — no new SQL needed for those, just
  count/select queries the client wasn't running before.
  - **Members tab** — searchable roster with each member's role shown
    as an editable `<select>` (calls `admin_set_role`), live silence
    status, and a per-row "Moderate" toggle (warn / silence, with
    reason + duration) that wraps the existing `member_moderate()` RPC
    (`dmac-moderation-silence-enforcement.sql`) — that RPC has existed
    since that file shipped but had no caller anywhere in the app
    until now.
  - **Moderation tab** — active silences (with one-click unsilence)
    plus the full sitewide log from `admin_list_moderation_log`.
  - Announcements and Scores & Badges tabs are the same panels from
    v1.4, unchanged in behavior, just moved under tabs instead of
    stacked on one page.

### To run

**`supabase/dmac-admin-dashboard-schema.sql`** — new file, run against
your live Supabase project (Dashboard → SQL Editor), after
`dmac-moderation-silence-enforcement.sql` and
`dmac-admin-score-writing.sql`. Without it, the Members tab's role
dropdown and the Moderation tab's log both fail gracefully (inline
error / empty list) rather than breaking the rest of the page — same
"missing migration" handling every other tab here already has.

`npm run build` verified clean after every change above.

---

## Beta v1.4 — badge notifications + admin score writing

Both flagged directly in v1.3's own notes (RightPanel.vue's "flag it
if you want that wired up too" for badges, and
dmac-scores-members-link.sql's "flag it if you want score-writing
moved into the app itself" for the admin side) — both now done.

- **Badge notifications, wired end to end.** `lib/leaderboard.js`'s
  `fetchScores()` now also selects `id`/`created_at` per score row,
  and a new shared `Leaderboard.getBadgesForSlug(scores, slug)`
  helper (pulled out of what was `about/MembersView.vue`'s local
  `badgesForSlug()` — that view now just calls the shared one, so
  there's one badge-computation path instead of a second copy) backs
  all three places a member's own badges now show up:
  - **New `checkBadges()` in `lib/notifications.js`**, run from
    `pollOnce()` (so it fires immediately on login/session-restore via
    `startPolling()`'s own immediate first tick, then every 6s after)
    — compares a member's current badges against a per-member
    `dmac_badge_since_<slug>` localStorage checkpoint (own key, since
    badges read from `scores` via `Leaderboard`, not the
    `list_unseen_notifications` RPC everything else here polls) and
    toasts anything new via the already-existing `notifyBadgeEarned()`
    (built in an earlier pass but never actually triggered until now).
    First-ever check per member baselines silently — no toast storm
    for badges someone already held before this shipped.
  - **RightPanel.vue's Badges section** is no longer the "not wired up
    yet" placeholder — it's a real, persistent list of the logged-in
    member's current badges (icon, tier, rank/percent), loaded the
    same way the Warnings/Silences/Forum sections already were (on
    panel open). New compact `.notif-badge-*` CSS in `global.css`.
  - Requires `dmac-scores-members-link.sql` to already be run (same
    requirement v1.3 documented) — nothing new to run for this half.
- **Admin score writing — new `supabase/dmac-admin-score-writing.sql`.**
  The "Officers can insert/update/delete scores" RLS policies
  (`dmac-social-schema-core.sql`) still key off the old Tier-B-only
  `profiles.role = 'officer'` / `auth.uid()` scheme, which a Tier A
  (password-only) admin can't satisfy — same shape of gap every other
  "list/write my ___" fix in this project has closed the same way.
  New `admin_upsert_score()` / `admin_delete_score()` RPCs, gated by
  `members.site_role = 'admin'` via `_resolve_member_id()`, same
  pattern as `create_announcement()`. Two new partial unique indexes
  on the real `member_id` column (one for ordinary badges, one for
  issue-tracked/secret ones) so upserts correct a value in place
  instead of piling up duplicate rows; `legacy_member_id` loses its
  `NOT NULL` since a score written for a member who only ever existed
  in the new scheme has no legacy `profiles` row to point at. AdminView
  gets a new "Award / update score" panel (member picker, badge picker
  — known `Leaderboard.BADGES` entries + a "Custom badge id…" escape
  hatch, value, optional issue #, optional date) plus a "Recent
  scores" list with per-row delete. Correcting an existing score bumps
  its `created_at`, which double-serves as a badge-notification
  trigger — fixing a value re-surfaces it to the member as a toast,
  which is the point.

### To run

**`supabase/dmac-admin-score-writing.sql`** — new file, run against
your live Supabase project (Dashboard → SQL Editor), after
`dmac-scores-members-link.sql` and `dmac-site-polish-schema.sql`. The
badge-notification half needs no new SQL beyond what v1.3 already
asked for.

`npm run build` verified clean after every change above.

---

## Beta v1.3 — follow-up round (backend badges fix + 2 clarifications)

Three corrections/clarifications on top of v1.2:

- **"The bug in badges" — actually a backend issue, confirmed.** This
  was v1.2's flagged best-effort guess; the real bug is exactly the
  gap that guess described, so it's now actually fixed rather than
  just documented. New **`supabase/dmac-scores-members-link.sql`**
  gives `scores` a real `member_id uuid references members(id)`
  column (the old text column is kept, renamed to
  `legacy_member_id`), with a zero-risk best-effort auto-backfill —
  see that file's header for exactly how, and what you still need to
  spot-check afterward (some rows may need linking by hand if the old
  `profiles.member_id` was never set to match a real `members.slug`).
  `lib/leaderboard.js` now returns a real `slug` on every leaderboard
  entry (via the new FK), and `about/MembersView.vue` computes each
  opened member's `badges` array from an actual
  `Leaderboard.getLeaderboard()` call matched by slug — no longer the
  static, hardcoded `[]` every member had before. **You need to run
  this new SQL file** against your live project; nothing works until
  you do. The v1.2 crash-guard fix (`badgeIconUrl`'s missing-`file`
  guard) stays in, per your note.
  - RightPanel.vue's Badges notification section is intentionally
    UNCHANGED — the link now exists, but "did *I* earn anything new"
    is a different, per-member check nobody's asked for yet. Flag it
    if you want that wired up too, now that it's possible.
- **"Change card color" — the whole popup card, not the profile
  banner.** Re-read as: on the Members tab, when you click a card
  open, the *entire* popup (not just the top banner strip) should
  reflect their color. Added `cardTintStyle` to
  `about/MembersView.vue` — washes `.card-panel`'s background in the
  member's color from the top, fading back to the normal dark
  background by mid-card, so the about/badges/stats text underneath
  stays exactly as readable as before.
- **"Add a color wheel."** The hex text field from v1.2 stays (still
  useful for pasting/typing an exact code), but the picker itself is
  now a real interactive color wheel — new
  `src/components/ColorWheelPicker.vue` (hue around the ring,
  saturation from center to edge, brightness slider underneath; plain
  canvas + Pointer Events, no new dependency, same approach as
  `AvatarCropModal.vue`). Replaces the native `<input type="color">`
  in `ProfileView.vue`'s banner-color section — swatches, wheel, and
  hex field all stay in sync through the same `bannerColor` ref.
- **"Inline all badges so the SVG is directly manipulable."**
  `lib/badges.js` now also exports `BADGE_SVG` — the same badge
  `.svg` files, but as raw markup (Vite's `?raw` import) instead of
  only a URL. `about/MembersView.vue` renders both the tier-gem
  background and the specific badge icon via `v-html` now, so they're
  real `<svg>`/`<path>` DOM nodes — reachable by CSS/JS for recoloring,
  targeting a specific path, animating a piece of it, etc. — instead
  of sitting opaque behind an `<img src="...">`. `BADGE_URLS` (the
  original URL export) stays for `App.vue`'s preloader, which still
  needs real URLs to preload — the two exports serve genuinely
  different purposes now, not a leftover duplicate. Added real CSS
  for `.badge-icon` too, which never actually had any before now
  (dead code path until this pass, since badges were always `[]`).

`npm run build` verified clean after every change above.

---



Everything filed through the in-app admin feedback board this round.
Two items below (marked) are best-effort interpretations rather than
1:1 restatements of the one-line report — see each for reasoning.

### Feature requests

- **Req #1 — Crop in avatar edit.** `ProfileView.vue`'s avatar picker
  used to upload whatever file you chose, raw, no matter its aspect
  ratio. New `src/components/AvatarCropModal.vue` — a plain
  canvas + Pointer Events square cropper (drag to reposition, scroll
  or slider to zoom), no new dependency — opens on file-select;
  `onAvatarChosen` now just stages the file, and the actual
  `MemberProfile.uploadAvatar()` call happens on confirm, with the
  cropped `File` (512×512, PNG if the source could have transparency,
  JPEG otherwise).
- **Req #2/#3 — Card color switcher → "actually make it a hex
  picker".** The banner-color swatches + native `<input type="color">`
  already existed; #3 came in 6 minutes after #2 specifically asking
  for a typeable hex code, since a native color-picker dialog isn't
  really that. Added a real text input (`hexDraft`) synced against the
  canonical `bannerColor`, with `#rgb`/`#rrggbb` validation and a
  preview swatch — swatches, native picker, and the new text field all
  write to the same `bannerColor` ref, so any of the three stays in
  sync with the other two.
- **Req #4 — Less labels, more buttons.** Interpreted as: two spots
  where a `<label>` + `<select>` was standing in for a small, fixed
  set of options a segmented button row handles in one click instead
  of open-menu-then-click. Converted **both** the Admin panel's
  announcement "Type" dropdown (`AdminView.vue`) and the moderation
  composer's "Duration" dropdown (`LeftPanel.vue`) — same underlying
  `kind`/`modDuration` refs, just a `.seg-toggle`/`.duration-group`
  button row instead of a `<select>`. If there's a specific other
  screen this was actually about, flag it and I'll convert that one
  too — this is a pattern, not a one-off, so it's easy to extend.

### Bugs

- **#1 — Announcement Notif no sfx and popup.**
  `list_unseen_notifications()` only ever returned `kind='maintenance'`
  rows (as `maintenance`) — regular (`kind='announcement'`) posts
  weren't in the poll payload *at all*, so they could never become a
  toast, even though they always showed up fine in the Notifications
  panel itself (that panel queries `announcements` directly,
  kind-agnostic — never the broken part). New
  `supabase/dmac-notifications-panel-fixes.sql` adds a second
  `announcements` key to that same RPC; `lib/notifications.js` gained
  an `announcement` `NOTIF_TYPES` entry + a poll loop for it.
- **#2 — Friend Request Notif no saved + accept.** A friend request
  only ever surfaced as a toast — dismiss it or miss it, and it was
  gone until you happened to check the DMs tab. `RightPanel.vue` now
  has a real "Friend requests" section (reusing the existing
  `list_friend_requests` / `respond_friend_request` RPCs LeftPanel's
  DMs tab already calls) with Accept/Decline right on the card.
- **#3 — Silences aren't in Notifs.** Same root cause as the Warnings
  section before the v1.1 pass, just for `action='silence'`/
  `'unsilence'` instead of `'warn'` — `list_my_moderation_log` already
  returns both, RightPanel just wasn't reading the silence ones out of
  it. Added a "Silences" section alongside Warnings, same RPC, split
  client-side by `action`.
- **#4 — The bug in badges.** *Best-effort interpretation* — the
  Badges section's "not wired up yet" honesty note (see v1.1) is a
  known, flagged gap, not new breakage, and reconciling `scores` with
  `members` needs a real data decision on the live project (matching
  old hand-entered `profiles.member_id` values to real
  `members.slug` — see `dmac-social-schema-core.sql`'s own comment)
  that isn't safe to guess at blind. What I *did* find and fix:
  `MembersView.vue`'s `badgeIconUrl()` called `.replace()` directly on
  `badge.file` with no guard — a badge object missing (or with a
  non-string) `file` would throw and take the whole card down with it.
  Hardened that plus `badgeLabel()`'s `badge.name` the same way. If
  there's a specific visible badge glitch this was meant to be
  instead, describe what you're seeing and I'll chase that down
  directly.
- **#5 — Forum Update Notifs not saving.** *Best-effort
  interpretation* — read as "forum-reply notifications have nothing
  persistent behind them," the one gap Warnings/Silences/Friend
  requests/Announcements didn't share: miss the toast and it's gone,
  no way to check "what did I miss" on a followed thread. New
  `list_my_followed_thread_activity()` RPC (same file as bug #1) backs
  a new persistent "Forum" section in `RightPanel.vue`. If "not
  saving" meant something more specific (e.g. the Follow toggle itself
  not persisting) — I re-checked that path and it looks correct
  end-to-end (`follow_forum_thread`/`unfollow_forum_thread` round-trip
  through `loadFollowedThreads()` correctly) — let me know what you
  saw and I'll dig further.
- **#6 — Notif Latency.** Polling was every 15s; dropped to 6s, and
  added a `visibilitychange` listener that fires an immediate poll the
  moment a backgrounded tab becomes visible again, rather than always
  waiting out whatever's left of the interval. Real-time (Supabase
  Realtime) isn't an option here without new schema-level policy work
  — see the "why polling, not Realtime" note at the top of
  `dmac-notifications-schema.sql` — so this is the practical ceiling
  without that larger change; flag it if 6s is still too slow and I'll
  look at what Realtime would actually take.

### To run

**`supabase/dmac-notifications-panel-fixes.sql`** — new file, run
against your live Supabase project (Dashboard → SQL Editor), after
`dmac-notifications-schema.sql`. Everything else this pass is
client-only.

`npm run build` verified clean after every change above.

---



Beta v1 shipped (all 11+ routes, forums/DMs/moderation/profiles/admin
all wired to real Supabase RPCs — none of which made it into the
"Done" sections below; this doc had fallen behind the actual code).
This pass targeted concrete, verifiable gaps rather than new features:

- **Dead code**: deleted `src/composables/panels/` — an orphaned,
  materially older duplicate of `src/components/panels/LeftPanel.vue`/
  `RightPanel.vue` that a previous pass's own notes claimed was already
  deleted, but wasn't. Confirmed nothing imported from it before
  removing.
- **Fake stats, Members page**: `about/MembersView.vue`'s member-card
  overlay had two separate "badge count" displays hardcoded to `?`/
  "Unknown" — even though the real count (`openedMember.badges.length`)
  was already sitting right there in the same component, one field
  away. Both now show the real number.
- **Fake stats, Profile page**: `ProfileView.vue`'s stat grid had two
  copy-pasted "Badges: Unknown" tiles. One is now "Site role" (from
  the already-loaded member object); the other is "Profile complete",
  backed by a `profileScore` computed that existed in the file already
  but was never actually referenced in the template.
- **Unwired notifications — Warnings**: `RightPanel.vue`'s Warnings
  section always showed a hardcoded "Nothing here — good," regardless
  of whether a member had actually been warned, because nothing could
  read `moderation_log` back — RLS is on with zero SELECT policies,
  and even a policy keyed off `auth.uid()` wouldn't reach Tier A
  (password-only) members anyway. Added
  `supabase/dmac-my-moderation-log-fix.sql` (`list_my_moderation_log`
  RPC, same session-token pattern as every other "list my ___" RPC
  here) and wired the section up to it. **You still need to run this
  SQL file against your live Supabase project**, same as every other
  `.sql` file in this folder.
- **Unwired notifications — Badges**: NOT faked. The Badges section's
  "No new badges" was a lie by omission — nothing was actually being
  checked. Root cause: `scores.member_id` (what `lib/leaderboard.js`
  reads) still points at the old Google-OAuth `profiles.member_id`
  scheme, which was never migrated to `members.slug` the way forums/
  DMs/moderation all were — so there's genuinely no live link from a
  logged-in member to a score row today. Left the section's copy
  honest ("Badge tracking isn't wired up yet.") instead of inventing a
  query against a table that can't actually answer it. Reconciling
  `scores` with `members` is real, separate schema work — flag if you
  want that done next.
- Build verified clean after every change (`npm run build`, no new
  warnings, one new SQL file — no other schema changes).

---

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

## Deployment (GitHub Pages)

Added this pass, since the SPA is now what's live on `main`:

- **`.github/workflows/deploy.yml`** — builds on every push to `main`
  (and on manual trigger) and deploys via `actions/deploy-pages`. This
  assumes the SPA's `package.json`/`src`/etc. sit at the **repo root**
  (matching the old flattened-structure convention from the static
  site). If it's actually nested in a subfolder in the real repo, add
  `working-directory: <folder>` to the install/build steps and change
  the `upload-pages-artifact` `path` to `<folder>/dist`.
- **One manual step you still need to do**: in the repo, go to
  Settings → Pages → Build and deployment → Source → select
  **"GitHub Actions"**. This has to be clicked once before the
  workflow's first run will actually deploy (the `github-pages`
  environment doesn't exist until you do).
- **`vite.config.js`** now sets `base: '/digital-multimedia-arts-club/'`
  — needed because this is a project page
  (`username.github.io/digital-multimedia-arts-club`), not a custom
  domain or a `username.github.io` root repo. Verified the built
  `index.html` correctly emits `/digital-multimedia-arts-club/assets/...`
  paths. **Side effect**: `npm run dev` now also serves from
  `http://localhost:5173/digital-multimedia-arts-club/` instead of the
  root — that's expected, not a bug. If a custom domain gets set up
  later (there's CNAME history for one), change `base` back to `'/'`
  and drop a `CNAME` file in `public/` so Vite copies it into `dist/`.
- **SPA routing fix**: the workflow copies `dist/index.html` to
  `dist/404.html` after build. Router stays on `createWebHistory()`
  (clean URLs) — no code change there. GitHub Pages serves that
  404.html (still with a 404 status, but the right content) for any
  path it doesn't recognize as a real file, so a direct visit or
  refresh on something like `/about/members` still boots the SPA,
  which then reads the real path from the URL and renders correctly.
  Confirmed locally that the copied file is byte-identical to
  `index.html`.

## Done since last checkpoint (moderation pass)

- **`src/components/panels/LeftPanel.vue`** — this file was quietly out
  of date: a materially more complete version had been built at
  `src/composables/panels/LeftPanel.vue` (wrong directory — composables
  shouldn't hold `.vue` components) and never wired into `App.vue`,
  which only ever imported the plainer copy from `components/panels/`.
  That orphaned copy already called real, existing RPCs
  (`edit_forum_thread`, `edit_forum_post`, `member_moderate`) that
  nothing else in the app used. Merged it in as the one active version:
  - Inline thread-title editing and inline post editing (mods or the
    original author).
  - "Warn author" — logs to `moderation_log` via `member_moderate`.
  - Deleted the now-redundant `src/composables/panels/` directory.
- **New: real silence enforcement.** `member_moderate`'s own comment
  said it plainly — action='silence' only ever wrote a log row; a
  silenced member could still post normally. Added
  `supabase/dmac-moderation-silence-enforcement.sql`:
  - `members.silenced_until` (timestamptz, null = not silenced).
  - `member_moderate` gained `p_duration_hours` (default 24) and an
    `'unsilence'` action; both now actually set/clear the column, not
    just log.
  - `create_forum_thread` / `create_forum_post` re-check that column
    server-side and refuse new posts while it's in the future — same
    "never trust the client" pattern as every other RPC here. Edits/
    deletes of a silenced member's *existing* posts are untouched —
    scope is "can't post new things," same as a normal forum timeout.
  - Verified end-to-end against a scratch local Postgres (not your live
    project — no network access here): non-mods correctly rejected,
    warn stays log-only, silence blocks both new threads and replies,
    unsilence immediately restores posting, a 0/negative duration
    floors to 1 hour instead of silently no-op'ing, and the whole file
    re-runs cleanly (idempotent, per its own header).
  - Frontend: added a "Silence"/"Unsilence" pair next to "Warn" (thread
    view and per-post), with a duration picker (1h/24h/3d/7d/30d) that
    only shows up for Silence.
  - **You still need to run `dmac-moderation-silence-enforcement.sql`
    against your live Supabase project** (Dashboard → SQL Editor) —
    same as every other `.sql` file in this folder; nothing here
    applies itself.



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