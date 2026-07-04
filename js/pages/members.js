/* ═══════════════════════════════════════════════════
   members.js — Member card expansion + badge system
   ═══════════════════════════════════════════════════ */

/* ── TIER COLOURS ─────────────────────────────────── */
/* The 8 leaderboard tiers now live in js/leaderboard.js as the single
   source of truth (this file used to keep its own copy, which drifted
   out of sync — don't reintroduce that). Only truly unique, non-tiered
   badges belong here. */
const TIER_COLORS = {
  ...Leaderboard.TIER_COLORS,
  leaddeveloper: '#ff4444',
  founder:       '#f97316',
};

/* ── MEMBER DATA ──────────────────────────────────── */
const MEMBERS = {
  /* ── ADVISERS ── */
  'richmond-causaren': {
    name:       'Richmond P. Causaren',
    role:       'Club Adviser',
    tagline:    'Founder · DMAC',
    about:      'The visionary who started it all. Sir Richmond founded the Digital Multimedia Arts Club, bringing together creative minds with a shared passion for digital media.',
    bannerKey:  'founder',
    isFounder:  true,
    founderTitle: 'DMAC FOUNDER',
    founderRoles: 'Club Adviser · Founder',
    badges: [
      { level: null, name: 'Founder', file: 'founder.png', tierKey: 'founder' },
    ],
    gradeSection: '',
    socials: [],
    timeWorking: [],
    yearJoined: '',
    arScore: '',
    specialization: '',
    randomStat: '',
    avatar: null
  },
  'marie-asuncion': {
    name: 'Marie Aldron G. Asuncion', role: 'Co-Adviser', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'rhocell-luteria': {
    name: 'Rhocell C. Luteria', role: 'Co-Adviser', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'johanna-obar': {
    name: 'Johanna Mae E. Obar', role: 'Co-Adviser', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },

  /* ── OFFICERS ── */
  'jyryn-jayme': {
    name: 'Jyryn Shmily G. Jayme', role: 'President', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'jaywin-cambalon': {
    name: 'Jaywin Elson Cambalon', role: 'Vice President', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'athena-jimenez': {
    name: 'Athena Aruen M. Jimenez', role: 'Secretary', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'nico-melorin': {
    name: 'Nico Andrei C. Melorin', role: 'Asst. Secretary', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'keitharine-secillano': {
    name: 'Keitharine M. Secillano', role: 'Treasurer', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'alianna-abangan': {
    name: 'Alianna Jen M. Abangan', role: 'Auditor', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'mark-patnon': {
    name:       'Mark James C. Patnon',
    role:       'Public Information Officer',
    tagline:    'Lead Developer · Web & Systems',
    about:      "The guy who actually builds stuff around here. If it's on the site, I probably made it.",
    bannerKey:  'mark',
    /* Lead Developer isn't in this grid — it lives in the card's
       "Special stuff" section instead, rendered separately from the
       regular badge slots (that section is on you to build/wire up). */
    badges: [
      { level: 'Prism',   name: 'Contributor',    file: 'quartzcontributor.png', tierKey: 'prism'         },
      { level: 'Prism',   name: 'Builder',        file: 'quartzbuilder.png',     tierKey: 'prism'         },
      { level: 'Prism',   name: 'Secret',         file: 'quartzsecret.png',      tierKey: 'prism'         },
      { level: 'Copper',  name: 'larper',         file: 'copperlarper.png',      tierKey: 'copper'        },
    ],
    gradeSection: '',
    socials: [],
    timeWorking: [],
    yearJoined: '',
    arScore: '',
    specialization: '',
    randomStat: '',
    avatar: null
  },
  'jezrylle-andres': {
    name: 'Jezrylle D. Andres', role: 'Public Information Officer', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },

  /* ── MEMBERS - Multimedia & Visual Graphic Specialist Team ── */
  'leanne-abenoja': {
    name: 'Leanne Rouz E. Abenoja', role: 'Multimedia & Visual Graphic Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'micah-bartolome': {
    name: 'Micah Sophia H. Bartolome', role: 'Multimedia & Visual Graphic Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'liane-labitan': {
    name: 'Liane Jhaydel D. Labitan', role: 'Multimedia & Visual Graphic Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'clarisse-luego': {
    name: 'Clarisse Madel M. Luego', role: 'Multimedia & Visual Graphic Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'rhycel-nato': {
    name: 'Rhycel Dennese M. Nato', role: 'Multimedia & Visual Graphic Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'ysabel-pernala': {
    name: 'Ysabel A. Pernala', role: 'Multimedia & Visual Graphic Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'rojan-sajol': {
    name: 'Rojan Jacob D. Sajol', role: 'Multimedia & Visual Graphic Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'ethan-salamat': {
    name: 'Ethan Carlo M. Salamat', role: 'Multimedia & Visual Graphic Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },

  /* ── MEMBERS - Creative Imagery Specialist Team ── */
  'sophia-angeles': {
    name: 'Sophia Lorraine F. Angeles', role: 'Creative Imagery Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'jemwell-boton': {
    name: 'Jemwell Boton', role: 'Creative Imagery Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'clarence-eblasin': {
    name: 'Clarence Lei P. Eblasin', role: 'Creative Imagery Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'mary-magalona': {
    name: 'Mary Jeanelle Magalona', role: 'Creative Imagery Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'lorien-naval': {
    name: 'Lorien Rose A. Naval', role: 'Creative Imagery Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
  'sofia-obejas': {
    name: 'Sofia Lois A. Obejas', role: 'Creative Imagery Specialist', tagline: '', about: '', bannerKey: '', badges: [], gradeSection: '', socials: [], timeWorking: [], yearJoined: '', arScore: '', specialization: '', randomStat: '', avatar: null
  },
};

/* ── DOM REFS ─────────────────────────────────────── */
const overlay       = document.getElementById('card-overlay');
const panel         = document.getElementById('card-panel');
const closeBtn      = document.getElementById('card-close');
const elName        = document.getElementById('card-name');
const elRole        = document.getElementById('card-role');
const elGrade       = document.getElementById('card-grade');
const elTitleBar    = document.getElementById('card-title-bar-container');
const elSocials     = document.getElementById('card-socials');
const elTimeWorking = document.getElementById('card-time-working');
const elAbout       = document.getElementById('card-about');
const elBadges      = document.getElementById('card-badges');
const elBadgeCount  = document.getElementById('card-badge-count');
const elBanner      = document.getElementById('card-banner');
const elAvatar      = document.getElementById('card-avatar');
const elStatYear    = document.getElementById('stat-year');
const elStatScore   = document.getElementById('stat-score');
const elStatSpec    = document.getElementById('stat-spec');
const elStatRandom  = document.getElementById('stat-random');
const zzSvg         = document.querySelector('.card-zigzag-svg');
const zzPoly        = document.querySelector('.card-zigzag-poly');

/* ── MINI ZIGZAG ──────────────────────────────────── */
const ZZ_PITCH = 52;   /* triangle base width (px) — scaled down from global 150 */
const ZZ_DEPTH = 28;   /* triangle height (px) — matches .card-zigzag height      */

function drawCardZigzag() {
  if (!zzSvg || !zzPoly) return;
  const W      = panel.offsetWidth || 760;
  const startX = -ZZ_PITCH;
  const count  = Math.ceil((W + ZZ_PITCH * 2) / ZZ_PITCH);
  const pts    = [`${startX},0`];                         /* baseline at top (y=0) */

  for (let i = 0; i < count; i++) {
    const tipX  = startX + i * ZZ_PITCH + ZZ_PITCH / 2;
    const baseX = startX + (i + 1) * ZZ_PITCH;
    pts.push(`${tipX},${ZZ_DEPTH}`, `${baseX},0`);       /* tips point down into card body */
  }

  /* Close the polygon: sweep bottom-right → bottom-left to fill below the teeth */
  const farRight = startX + (count + 1) * ZZ_PITCH;
  pts.push(`${farRight},${ZZ_DEPTH}`, `${startX},${ZZ_DEPTH}`);

  zzSvg.setAttribute('viewBox', `0 0 ${W} ${ZZ_DEPTH}`);
  zzPoly.setAttribute('points', pts.join(' '));
}

/* ── BADGE RENDERING ──────────────────────────────── *
   Each badge is two stacked images, not one:
     - .badge-bg   the tier gem, e.g. "gold-badge.svg" — one per
                   leaderboard tier, filename = `${tierKey}-badge.svg`
     - .badge-icon the actual badge logo on top, e.g. "speedtypist.svg"
                   — this is `badge.file` from MEMBERS, unchanged
   Non-tiered badges (e.g. founder) have no matching gem asset —
   that's expected, not an error. .badge-bg just silently
   removes itself on 404 and the existing --tier-color border/glow
   on .badge-slot carries the "background" for those instead.

   The icon layer has a two-step fallback: missing icon → placeholder.svg
   (add that file to assets/badges/ once — it's the generic "badge not
   drawn yet" art) → if even that 404s, the old ◆ glyph as a last resort
   so a card never shows a broken-image icon. */
function renderBadge(badge) {
  const color   = TIER_COLORS[badge.tierKey] || '#888';
  const label   = badge.level ? `${badge.level} ${badge.name}` : badge.name;

  const slot = document.createElement('div');
  slot.className = 'badge-slot';
  slot.setAttribute('title', label);
  slot.style.setProperty('--tier-color', color);

  // Tooltip label below slot
  const tip = document.createElement('span');
  tip.className = 'badge-tip';
  tip.textContent = label;

  // Tier gem background — behind the icon, tier-driven, optional.
  const bg = document.createElement('img');
  bg.src = `../assets/badges/${badge.tierKey}-badge.svg`;
  bg.alt = '';
  bg.className = 'badge-bg';
  bg.onerror = () => bg.remove(); // no gem for this tierKey — fine, .badge-slot's glow covers it

  // Badge icon — the actual logo, always present, always on top.
  const icon = document.createElement('img');
  icon.src = `../assets/badges/${badge.file}`;
  icon.alt = label;
  icon.className = 'badge-icon';

  icon.onerror = () => {
    if (icon.dataset.fallback !== 'placeholder') {
      icon.dataset.fallback = 'placeholder';
      icon.src = '../assets/badges/placeholder.svg';
      return;
    }
    // Even placeholder.svg is missing — glyph as the true last resort.
    icon.remove();
    const diamond = document.createElement('span');
    diamond.className  = 'badge-diamond';
    diamond.textContent = '◆';
    diamond.style.color      = color;
    diamond.style.textShadow = `0 0 14px ${color}, 0 0 28px ${color}66`;
    slot.insertBefore(diamond, tip);
  };

  slot.appendChild(bg);
  slot.appendChild(icon);
  slot.appendChild(tip);

  // Badges are decorative — they visually invite a click (glow +
  // tooltip) but there's nothing behind them, so confirm that with
  // a "no" tick rather than silence. Hover still gets a tick too,
  // same as every other effect-hover element on the site.
  slot.addEventListener('mouseenter', () => window.playSfx?.('menuhover'));
  slot.addEventListener('click', () => window.playSfx?.('no'));

  return slot;
}

/* ── OPEN CARD ────────────────────────────────────── */
function openCard(memberId) {
  const data = MEMBERS[memberId];
  if (!data) return;

  window.playSfx?.('menuconfirm');

  // Populate text & stats
  elName.textContent       = data.name;
  elGrade.textContent      = data.gradeSection || 'DMAC';
  elRole.textContent       = data.role;
  elAbout.textContent      = data.about || 'No description provided.';
  elStatYear.textContent   = data.yearJoined || '--';
  elStatScore.textContent  = data.arScore || '--';
  elStatSpec.textContent   = data.specialization || '--';
  elStatRandom.textContent = data.randomStat || '--';

  // Banner & Avatar styling
  elBanner.className = `card-banner card-banner--${data.bannerKey || 'default'}`;
  
  // Clean up banner children
  Array.from(elBanner.children).forEach(child => {
    if (child.classList.contains('card-banner-wm')) {
      child.remove();
    }
  });

  if (!data.isFounder && data.name) {
    const wm = document.createElement('div');
    wm.className = 'card-banner-wm';
    wm.setAttribute('aria-hidden', 'true');
    const shortName = data.name.split(' ').map(w => w[0]).join('').toUpperCase();
    wm.textContent = (shortName + ' ').repeat(40);
    elBanner.insertBefore(wm, elBanner.firstChild);
  }

  if (data.avatar) {
    elAvatar.style.backgroundImage = `url(https://aztaryx.github.io/dmac-assets/avatars/${data.avatar})`;
  } else {
    elAvatar.style.backgroundImage = 'none'; // Fallback to CSS default
  }

  // Founder title bar
  elTitleBar.innerHTML = '';
  if (data.isFounder) {
    panel.classList.add('is-founder');
    elTitleBar.innerHTML = `
      <div class="founder-title-bar">
        <div class="founder-title-bg"></div>
        <div class="founder-title-main">
          <span class="founder-title-name">${data.name.split(' ')[0].toLowerCase()}</span>
          <span class="founder-title-slash">/</span>
          <span class="founder-title-label">${data.founderTitle}</span>
        </div>
        <span class="founder-title-roles">${data.founderRoles}</span>
      </div>
    `;
  } else {
    panel.classList.remove('is-founder');
    if (data.tagline) {
      elTitleBar.innerHTML = `<span class="card-tagline">${data.tagline}</span>`;
    }
  }

  // Socials
  elSocials.innerHTML = '';
  if (data.socials && data.socials.length > 0) {
    data.socials.slice(0, 3).forEach(soc => {
      const a = document.createElement('a');
      a.href = soc.url;
      a.target = '_blank';
      a.className = 'card-social-link';
      a.innerHTML = `<img src="https://aztaryx.github.io/dmac-assets/icons/${soc.icon}" alt="${soc.platform}" />`;
      a.addEventListener('mouseenter', () => window.playSfx?.('menuhover'));
      elSocials.appendChild(a);
    });
  } else {
    elSocials.innerHTML = '<span class="card-empty-text">No socials linked.</span>';
  }

  // Time Spent Working
  elTimeWorking.innerHTML = '';
  if (data.timeWorking && data.timeWorking.length > 0) {
    data.timeWorking.forEach(tw => {
      const div = document.createElement('div');
      div.className = 'card-time-entry';
      div.innerHTML = `<span class="time-label">${tw.label}</span><span class="time-value">${tw.value}</span>`;
      elTimeWorking.appendChild(div);
    });
  } else {
    elTimeWorking.innerHTML = '<span class="card-empty-text">Unknown time spent.</span>';
  }

  // Badges & Badge Count
  elBadges.innerHTML = '';
  const badges = data.badges || [];
  badges.forEach(b => elBadges.appendChild(renderBadge(b)));
  
  const TOTAL_POSSIBLE_BADGES = 42;
  const percent = badges.length > 0 ? Math.floor((badges.length / TOTAL_POSSIBLE_BADGES) * 100) : 0;
  elBadgeCount.innerHTML = `
    <span class="card-badge-percent">${percent}%</span>
    <span class="card-badge-text">or<br>${badges.length} / ${TOTAL_POSSIBLE_BADGES} badges</span>
  `;

  // Show overlay
  overlay.classList.add('open');
  document.body.style.overflow = 'hidden';
  requestAnimationFrame(() => {
    panel.classList.add('open');
    drawCardZigzag();
  });
}

/* ── CLOSE CARD ───────────────────────────────────── */
function closeCard() {
  window.playSfx?.('menuback');
  panel.classList.remove('open');
  panel.addEventListener('transitionend', () => {
    overlay.classList.remove('open');
    document.body.style.overflow = '';
  }, { once: true });
}

/* ── EVENT LISTENERS ──────────────────────────────── */
document.querySelectorAll('[data-member-id]').forEach(card => {
  card.addEventListener('click', () => openCard(card.dataset.memberId));
  card.addEventListener('keydown', e => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      openCard(card.dataset.memberId);
    }
  });
});

closeBtn.addEventListener('click', closeCard);

overlay.addEventListener('click', e => {
  if (e.target === overlay) closeCard();
});

document.addEventListener('keydown', e => {
  if (e.key === 'Escape' && overlay.classList.contains('open')) closeCard();
});

/* Redraw zigzag if card is open and window is resized */
window.addEventListener('resize', () => {
  if (overlay.classList.contains('open')) drawCardZigzag();
});