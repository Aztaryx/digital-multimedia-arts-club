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
