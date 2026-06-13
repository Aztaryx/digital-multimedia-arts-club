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
├── assets/                  Drop logo, images, libs here
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

## Nav + Footer

The nav and footer HTML are duplicated across all pages.
`_partials/nav.html` and `_partials/footer.html` are the
source-of-truth templates. When editing nav or footer, update
the partial first, then copy the changes to each affected page.

## Assets

Drop files into `assets/`:
- `logo.png`           — main logo
- `logo-alt.png`       — simplified variant
- `tile-pattern-light.png`  — replace data URI in global.css
- `tile-pattern-dark.png`   — replace data URI in global.css
- `images/hero/`       — D / M / A panel photos
- `images/members/`    — member photos (photo-[name].webp)
- `images/projects/`   — project thumbnails ([slug]-thumb.webp)
- `lib/`               — self-hosted JS libraries (e.g. pixi.min.js)
