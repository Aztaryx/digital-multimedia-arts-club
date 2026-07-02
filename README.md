# DMAC Website

**Digital Multimedia Arts Club**

## Structure

```
dmac/
├── index.html               Homepage (hero)
├── about/
│   ├── index.html           About Us
│   ├── mission.html         Mission
│   └── members.html         Members
├── projects/
│   └── index.html           Projects gallery
├── info/
│   ├── announcements.html   Announcements
│   ├── events.html          Events
│   ├── update-log.html      Website update log
│   └── faq.html             FAQ
├── join/
│   └── index.html           How to Join
├── socials/
│   └── index.html           Socials hub
├── assets/                  Drop logo, images, libs, audio here
├── css/
│   ├── global.css           Shared styles (all pages)
│   ├── animations.css       .animate-in + .reveal
│   └── pages/               Page-specific CSS
├── js/
│   ├── global.js            Preloader, nav, reveals (all pages)
│   ├── animations.js        initGradText()
│   └── pages/               Page-specific JS
└── _partials/               Nav + footer reference templates
    ├── nav.html
    └── footer.html
```

## Serving

Must be served over HTTP/HTTPS — not opened as file:// directly.
Local: `npx serve .` or `python -m http.server` in this folder.

**Note:** images/logo/etc. now load from `https://aztaryx.github.io/dmac-assets/`
(see Assets below), so GitHub Pages must be enabled on the `dmac-assets` repo
for images to show up, even when developing this repo locally.

## Nav + Footer

The nav and footer HTML are duplicated across all pages.
`_partials/nav.html` and `_partials/footer.html` are the
source-of-truth templates. When editing nav or footer, update
the partial first, then copy the changes to each affected page.

## Assets

**Media assets live in a separate repo: [`dmac-assets`](https://github.com/aztaryx/dmac-assets),
served via GitHub Pages at `https://aztaryx.github.io/dmac-assets/`.**
This keeps this repo light and fast to clone. Every image, logo, and future
audio/lib file is referenced by its full `https://aztaryx.github.io/dmac-assets/...`
URL in the HTML/CSS/JS — nothing but code lives in this repo's `assets/` folder.

To add or change a logo, hero image, group photo, member avatar, or social icon:
push it to the `dmac-assets` repo, then reference it as
`https://aztaryx.github.io/dmac-assets/<path>` wherever you need it here.

**Exception — badges (`assets/badges/`):** badge icons are SVGs that get edited
directly as part of this repo (not just dropped in as-is), so they stay local.
Reference them as `../assets/badges/<file>` like `js/pages/members.js` already does.

If you ever rename the `dmac-assets` repo or move it off GitHub Pages, every
reference uses the exact same base string `https://aztaryx.github.io/dmac-assets`
— a project-wide find & replace across `.html`, `.js`, and `.css` is all it takes.

### dmac-assets structure (for reference — lives in the other repo)
```
dmac-assets/
├── logo.png
├── images/
│   ├── hero/        D / M / A panel photos
│   ├── misc/        group photos, school/org logos
│   ├── members/      member photos
│   └── projects/     project thumbnails
├── avatars/          member avatar images (js/pages/members.js)
├── icons/             social platform icons (js/pages/members.js)
├── lib/               self-hosted JS libraries (e.g. pixi.min.js)
└── audio/             sound effects and audio tracks
```

## Leaderboard system

Badges are metric-based (e.g. speedtypist tracks lines of code written).
Tiers aren't fixed thresholds — a badge's #1 holder sets "the floor," and
everyone else's tier is their percentage of that floor. The floor moves
automatically as scores change; nothing needs manual recalculating.

**Where things live:**
- `js/leaderboard.js` — the engine (fetch, rank, tier assignment). Fully
  documented at the top of the file, including exact Sheet setup steps.
- `dev/leaderboard-test.html` — standalone test harness, not linked from
  the nav. Paste a published Sheet CSV URL in here to sanity-check
  rankings before wiring a badge into a real page.

**Data lives in Google Sheets**, not in this repo — a "Scores" tab
(`badge_id | member_id | value | issue_number | date`), published to web
as CSV. Club officers add a row to update a score; no code or deploy
needed. Get the published CSV URL via
`File → Share → Publish to web → Scores tab → CSV`.

**Two assumptions baked into the current defaults** — both are just
config constants at the top of `js/leaderboard.js`, safe to tune without
touching the ranking logic:
- Tier order (low → high): copper, silver, gold, diamond, orichalcum,
  ruby, amethyst, prism, allomorphite. Note diamond sits well below
  orichalcum/ruby/amethyst here — this isn't alphabetical or "rarity
  intuition," it's Aztaryx's balance pass. Allomorphite is exclusive to
  an exact 100% — i.e. the actual floor holder (or a tie for #1). Prism
  is the "close second" band just below that.
- Tier % breakpoints: copper 1–6.99, silver 7–16.99, gold 17–23.99,
  diamond 24–48.99, orichalcum 49–57.99, ruby 58–73.99, amethyst
  74–93.99, prism 94–99.99, allomorphite 100 only. Copper starts at 1
  rather than 0 — a literal zero still falls back to copper (the
  bottom rung), there's just nowhere lower to land.

Tier **colors** live in `Leaderboard.TIER_COLORS` — the single source of
truth other files should reference rather than keeping their own copy
(that already caused a real bug once: `members.js` had stale tier names
before this system existed).

Secret/issue-tracked badges don't use percent-of-floor — worth decays
by issue order (first to earn it = issue #1 = allomorphite, same "you're
literally first" logic), reassigned to match the same tier order above.
Also tunable in `js/leaderboard.js` (`ISSUE_TIER_BREAKPOINTS`), currently
placeholder values pending real secret badges to test against.

Not yet wired into `members.js`/member cards — this is the engine +
test harness only, so you can verify the ranking math against a real
Sheet before deciding how it should render on badge cards.
