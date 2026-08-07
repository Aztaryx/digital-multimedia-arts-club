/* ═══════════════════════════════════════════════════
   leaderboard.js — badge leaderboard / tier engine
   ═══════════════════════════════════════════════════
   Reads raw scores from the `scores` table in Supabase, ranks
   members per badge, and assigns each member a tier based on
   their percentage of the current #1 holder's value (the
   "floor"). The floor moves automatically as scores change —
   there's nothing to manually recalculate.

   USAGE
   ------------------------------------------------------
   Any page using this must load, in order, BEFORE this file:
     1. the supabase-js CDN script
     2. js/supabase-client.js  (creates window.sb)

   Then:
   Leaderboard.fetchScores().then(scores => {
     const board = Leaderboard.getLeaderboard(scores, 'speedtypist');
     // board is an array of ranked entries, see getLeaderboard() below
   });

   DATA SOURCE
   ------------------------------------------------------
   Scores live in the `scores` table (see the schema + RLS policies
   set up via the SQL Editor — public.scores, publicly readable,
   writable only by members with role='officer' in public.profiles).
   Officers add/edit rows directly in the Supabase Table Editor, or
   through a future admin UI — either way, no code changes or
   redeploys are needed for a score update to show up on the site.

   Previously this read a published Google Sheet as CSV. That path
   is gone — parseCSV() below is kept only as a one-time-import
   utility if you ever need to bulk-load old Sheet data into
   Supabase again; it's no longer part of the live fetch path.
   ═══════════════════════════════════════════════════ */

import { sb } from './supabase-client.js';

const Leaderboard = (() => {

  /* ── TIER CONFIG ───────────────────────────────────
     Percent-of-floor breakpoints, low → high. A member's percent
     is always value/floor*100 (or floor/value*100 for "lower is
     better" badges — see BADGES below).

     Order matters here — must stay ascending by `min`, since
     tierFor() walks the array backwards looking for the first
     match. Note Diamond sits much lower than it used to (below
     Orichalcum and Ruby now) — this isn't the same order as the
     original 8-tier draft, it's a real reshuffle.

     Allomorphite is exclusive to an exact 100% — the actual floor
     holder (or a tie for #1). Copper's floor is 1, not 0 — nobody
     registers a flat zero, everyone with a positive value is at
     least copper. */
  const TIER_CONFIG = [
    { name: 'copper',       min: 1   },
    { name: 'silver',       min: 7   },
    { name: 'gold',         min: 17  },
    { name: 'diamond',      min: 24  },
    { name: 'orichalcum',   min: 49  },
    { name: 'ruby',         min: 58  },
    { name: 'amethyst',     min: 74  },
    { name: 'prism',        min: 94  },
    { name: 'allomorphite', min: 100 },
  ];

  /* ── TIER COLORS ───────────────────────────────────
     Single source of truth for tier → color, so nothing else in the
     codebase drifts out of sync with this list (that already happened
     once — members.js had stale tier names before this file existed).
     Other files should reference Leaderboard.TIER_COLORS rather than
     keeping their own copy. */
  const TIER_COLORS = {
    copper:       '#b87333',
    silver:       '#c0c0c0',
    gold:         '#ffd700',
    diamond:      '#b9f2ff',
    orichalcum:   '#c9a13b',
    ruby:         '#e0115f',
    amethyst:     '#9b59b6',
    prism:        '#f0d9ff',
    allomorphite: '#ffffff',  /* placeholder — the #1-only tier probably deserves real art, not a flat hex */
  };

  /* ── BADGE DIRECTIONS ──────────────────────────────
     Most badges are "higher is better" (desc). A few, like
     2fast4u (fastest time wins), are "lower is better" (asc).
     Add new badge_ids here as you define them — anything not
     listed defaults to 'desc'. */
  const BADGES = {
    speedtypist: { direction: 'desc' },
    '2fast4u':   { direction: 'asc'  },
  };

  /* ── DISPLAY NAMES ──────────────────────────────────
     badge_id → human label, for anywhere a badge needs to show a
     name rather than its raw id (see about/MembersView.vue). Falls
     back to the raw badge_id itself for anything not listed here, so
     a newly-added badge_id never renders blank while you get around
     to naming it. */
  const BADGE_LABELS = {
    speedtypist:        'Speedtypist',
    '2fast4u':           '2 Fast 4 U',
    // Tiered
    shakespeare:         'Shakespeare',
    'frame-by-frame':    'Frame By Frame',
    'reel-deal':          'Reel Deal',
    'thumbnail-titan':   'Thumbnail Titan',
    archivist:            'Archivist',
    'showed-up':         'Showed Up',
    inseparable:          'Inseparable',
    'hive-mind':         'Hive Mind',
    initiate:             '[INITIATE]',
    // One-off
    whoops:               'Whoops.',
    'h4h4-n00b':         'h4h4 n00b!',
    'beta-tester':       'Beta Tester',
    superstar:            'Superstar!',
    'day-one':           'Day One',
    'brick-placer':      'Brick Placer',
    dethroned:            'Dethroned',
    'growth-spurt':      'Growth Spurt',
    'new-game':          'New Game',
  };

  /* ── COMPUTED / META BADGES ─────────────────────────
     Completionist and The True Completionist! are never awarded
     through admin_upsert_score() — there's no scores row, nothing to
     pick from a dropdown. Deliberately kept OUT of BADGE_LABELS so
     they never show up in AdminView's "Choose a badge" list (which
     reads BADGE_LABELS — see badgeOptions in AdminView.vue). Their
     display name/flavor still need a home for rendering, hence this
     separate map. See getCompletionStatus() below for how these get
     computed. */
  const COMPUTED_BADGES = {
    completionist: {
      name: 'Completionist',
      flavor: '',
      threshold: 0.75,
    },
    'true-completionist': {
      name: 'The True Completionist!',
      flavor: '',
      threshold: 1,
    },
  };

  /* ── FLAVOR TEXT ────────────────────────────────────
     badge_id → flavor line, shown wherever a badge renders
     (about/MembersView.vue, RightPanel.vue). Same fallback
     philosophy as BADGE_LABELS: nothing here just means no flavor
     line shows, not a broken render.

     Inseparable's entry is a *template*, not a static string — it
     contains {value}/{s}/{partner} tokens because the real text
     differs per member (the shared project count, and which of the
     two people is named). See applyFlavorTemplate() below for the
     substitution and getBadgesForSlug() for where it gets called. */
  const BADGE_FLAVOR = {
    shakespeare:         'A master at work.',
    'frame-by-frame':    'I built this thing, brick by brick.',
    'reel-deal':          "Cut. Print. Next one's already due.",
    'thumbnail-titan':   'Good hook. Now beat it.',
    archivist:            "You can tell this guy a secret and he'd remember it for 20 years.",
    'showed-up':         "Present again. Don't break the streak.",
    inseparable:          '{value} project{s} worked on with {partner}.',
    'hive-mind':         'moi moi moi moi moi moi',
    initiate:             'PUBLISH? Y/N',
    whoops:               '"how" — lead dev',
    'h4h4-n00b':         'Up up down down left right left right... you know the rest.',
    'beta-tester':       'dev pls fix',
    superstar:            'Look who made the front page!',
    'day-one':           'Before any of this existed, you were already here.',
    'brick-placer':      'One brick. Infinite regret.',
    dethroned:            'GG. No re.',
    'growth-spurt':      'Sorry for blocking the group photo.',
    'new-game':          'Press Start.',
  };

  /* ── FLAVOR TEMPLATING ──────────────────────────────
     Only Inseparable needs this today, but written generically off
     any {token} found in the string rather than a hardcoded
     'inseparable' special-case, so a future badge that wants the
     same named-pair pattern gets it for free. `ctx` supplies
     whatever tokens the specific badge's template needs; tokens with
     no matching ctx entry are left as-is rather than silently
     vanishing, so a missing context value is obvious instead of
     produci a blank hole in the sentence. */
  function applyFlavorTemplate(template, ctx = {}) {
    if (!template) return template;
    let out = template.replace(/\{s\}/g, ctx.value === 1 ? '' : 's');
    out = out.replace(/\{(\w+)\}/g, (match, token) => {
      if (token === 's') return match; // already handled above
      return Object.prototype.hasOwnProperty.call(ctx, token) ? ctx[token] : match;
    });
    return out;
  }

  /* ── FETCH ─────────────────────────────────────────
     Pulls every row from the `scores` table and returns them in
     the same shape the rest of this file has always expected:
     an array of { badge_id, member_id, slug, value, issue_number,
     awarded_on }. `slug` is new — requires
     dmac-scores-members-link.sql to have been run (adds the real
     `member_id uuid references members(id)` column this embed
     needs); rows that haven't been linked yet just come back with
     `slug: null` and get filtered out below, same as they always
     silently were before that link existed at all. `id`/`created_at`
     are new too — badge-notification "is this new?" checks (see
     notifications.js's checkBadges()) need a real per-row timestamp,
     not just the badge itself. */
  async function fetchScores() {
    const { data, error } = await sb
      .from('scores')
     .select('id, badge_id, member_id, value, issue_number, awarded_on, created_at, partner_member_id, members!member_id(slug), partner:members!partner_member_id(slug, display_name)');

    if (error) throw new Error(`Leaderboard fetch failed: ${error.message}`);

    return (data || [])
      .map(r => ({
        id: r.id,
        badge_id: r.badge_id,
        member_id: r.member_id,
        slug: r.members?.slug || null,
        value: parseFloat(r.value),
        issue_number: r.issue_number ?? null,
        awarded_on: r.awarded_on || null,
        created_at: r.created_at || null,
        // partner_member_id/partner_name are only ever populated for
        // badges awarded with a paired member (Inseparable today) —
        // null for every ordinary row. `?.` throughout means this is
        // a no-op until dmac's partner_member_id migration has run;
        // older/unmigrated schemas just come back with partner: null.
        partner_member_id: r.partner_member_id || null,
        partner_name: r.partner?.display_name || null,
      }))
      .filter(r => r.badge_id && r.member_id && !isNaN(r.value));
  }

  /* ── LEGACY: CSV PARSING ───────────────────────────
     No longer used by fetchScores() — kept only in case you need
     to bulk-import old published-Sheet data into Supabase once.
     Not part of the live site's fetch path. */
  function parseCSV(text) {
    const rows = [];
    let row = [], field = '', inQuotes = false;

    for (let i = 0; i < text.length; i++) {
      const c = text[i], next = text[i + 1];
      if (inQuotes) {
        if (c === '"' && next === '"') { field += '"'; i++; }
        else if (c === '"') { inQuotes = false; }
        else { field += c; }
      } else {
        if (c === '"') inQuotes = true;
        else if (c === ',') { row.push(field); field = ''; }
        else if (c === '\n' || c === '\r') {
          if (field !== '' || row.length) { row.push(field); rows.push(row); }
          row = []; field = '';
          if (c === '\r' && next === '\n') i++;
        } else { field += c; }
      }
    }
    if (field !== '' || row.length) { row.push(field); rows.push(row); }

    if (!rows.length) return [];
    const headers = rows[0].map(h => h.trim());
    return rows.slice(1)
      .filter(r => r.some(cell => cell.trim() !== ''))
      .map(r => {
        const obj = {};
        headers.forEach((h, i) => { obj[h] = (r[i] || '').trim(); });
        return obj;
      });
  }

  /* ── TIER ASSIGNMENT ───────────────────────────────
     Given a percent-of-floor (0-100), returns the tier config
     object it falls into. */
  function tierFor(percent) {
    for (let i = TIER_CONFIG.length - 1; i >= 0; i--) {
      if (percent >= TIER_CONFIG[i].min) return TIER_CONFIG[i];
    }
    return TIER_CONFIG[0];
  }

  /* ── LEADERBOARD COMPUTATION ───────────────────────
     scores:   the array returned by fetchScores()
     badgeId:  which badge to rank, e.g. 'speedtypist'

     Returns an array, ranked best → worst, of:
       { member_id, value, rank, percent, tier }
     `tier` is the full tier object ({ name, min }).
     `percent` is always rounded and always caps at 100
     (the floor holder is always exactly 100%). */
  function getLeaderboard(scores, badgeId) {
    const direction = (BADGES[badgeId] && BADGES[badgeId].direction) || 'desc';
    const entries = scores.filter(s => s.badge_id === badgeId);
    if (!entries.length) return [];

    const sorted = [...entries].sort((a, b) =>
      direction === 'desc' ? b.value - a.value : a.value - b.value
    );

    const floor = sorted[0].value;

    return sorted.map((entry, i) => {
      const rawPercent = direction === 'desc'
        ? (entry.value / floor) * 100
        : (floor / entry.value) * 100;
      const percent = Math.min(100, Math.round(rawPercent));
      return {
        member_id: entry.member_id,
        slug: entry.slug,
        value: entry.value,
        rank: i + 1,
        percent,
        tier: tierFor(percent),
      };
    });
  }

  /* ── BADGES FOR A MEMBER ────────────────────────────
     Given fetchScores()'s output and a member's slug, returns every
     badge that member currently holds — one entry per badge_id
     present anywhere in `scores`, ranked against everyone else who
     has that badge. Same shape/logic about/MembersView.vue's own
     (now-removed) badgesForSlug() used, pulled up here so
     RightPanel.vue's Badges panel and notifications.js's "did I earn
     anything new" check compute this identically instead of drifting
     out of sync with three separate copies. `created_at`/`awarded_on`
     pass through from the member's own raw score row (not a
     leaderboard-computed field) — that's what makes "new since last
     check" possible client-side.

     Tiering mode is decided per-row, not per-badge_id, off whether
     `issue_number` is set — the same signal the admin form already
     uses ("Issue # — secret badges only, leave blank otherwise").
     A tiered badge (Shakespeare, Hive Mind, etc.) never gets an
     issue_number, so it always goes through getLeaderboard()'s
     percent-of-floor tiering. A one-off/secret badge always gets one,
     so it always goes through tierForIssueNumber() instead — value
     is conventionally just `1` for those and would otherwise put
     every holder at a flat 100%/allomorphite, which isn't what "the
     Nth person in" is supposed to mean. `mode` on the returned object
     tells the UI which kind of badge this is, so it can show "Rank
     #N · X%" for tiered badges and "#N to earn this" for one-off
     ones instead of a meaningless 0%/blank percent. */
  function getBadgesForSlug(scores, slug) {
    if (!slug || !scores?.length) return [];
    const own = scores.filter(s => s.slug === slug);
    const badgeIds = [...new Set(own.map(s => s.badge_id))];
    const badges = [];
    for (const badgeId of badgeIds) {
      const raw = own.find(s => s.badge_id === badgeId);
      if (!raw) continue;

      let tierObj, rank, percent, value, mode;

      if (raw.issue_number != null) {
        mode = 'issue';
        tierObj = tierForIssueNumber(raw.issue_number);
        rank = raw.issue_number;
        percent = null;
        value = raw.value;
      } else {
        const board = getLeaderboard(scores, badgeId);
        const entry = board.find(b => b.slug === slug);
        if (!entry) continue;
        mode = 'tiered';
        tierObj = entry.tier;
        rank = entry.rank;
        percent = entry.percent;
        value = entry.value;
      }

      const tierName = tierObj.name;
      const flavorTemplate = BADGE_FLAVOR[badgeId];
      const flavor = flavorTemplate
        ? applyFlavorTemplate(flavorTemplate, { value, partner: raw.partner_name || 'someone' })
        : null;

      badges.push({
        badge_id: badgeId,
        tierKey: tierName,
        mode,
        file: `${badgeId}.svg`,
        name: BADGE_LABELS[badgeId] || badgeId,
        level: tierName.charAt(0).toUpperCase() + tierName.slice(1),
        value,
        rank,
        percent,
        flavor,
        partner_name: raw.partner_name || null,
        awarded_on: raw?.awarded_on || null,
        created_at: raw?.created_at || null,
      });
    }
    return badges;
  }

  /* ── SECRET / ISSUE-TRACKED BADGES ─────────────────
     Not percent-of-floor — worth decays by issue order instead.
     First person to earn it gets issue #1 (allomorphite — same
     "you're literally first" logic as the leaderboard tiers),
     later copies step down. Defaults below are a starting point —
     adjust breakpoints once you've got real secret badges to test. */
  const ISSUE_TIER_BREAKPOINTS = [
    { maxIssue: 1,   tier: 'allomorphite' },
    { maxIssue: 3,   tier: 'prism'        },
    { maxIssue: 7,   tier: 'amethyst'     },
    { maxIssue: 15,  tier: 'ruby'         },
    { maxIssue: 30,  tier: 'orichalcum'   },
    { maxIssue: 60,  tier: 'diamond'      },
    { maxIssue: 120, tier: 'gold'         },
    { maxIssue: 250, tier: 'silver'       },
    { maxIssue: Infinity, tier: 'copper'  },
  ];

  function tierForIssueNumber(issueNumber) {
    const hit = ISSUE_TIER_BREAKPOINTS.find(b => issueNumber <= b.maxIssue);
    const tierName = hit ? hit.tier : 'copper';
    return TIER_CONFIG.find(t => t.name === tierName);
  }

  /* ── COMPLETIONIST / THE TRUE COMPLETIONIST! ───────
     Computed, not stored — see Part 4 of the implementation plan for
     the full reasoning. Two decisions the plan flagged as needing a
     conscious answer rather than an accident; documented here rather
     than buried, so revisiting either one later is a one-line change:

     1. DENOMINATOR — which badges count toward the 75%/100%.
        Implemented here as every badge in BADGE_LABELS from this
        20-badge rollout, exactly as dmac-badge-ideas.md's criteria
        column literally states ("75% of all other badges" / "100% of
        all other badges") — matching the plan's own worked example
        ("with the current 18 other badges, 75% is 14 ... 100% is all
        18"). BADGE_LABELS also carries two pre-existing badges from
        before this rollout (speedtypist, 2fast4u) that the plan's
        "18" doesn't count, so those two are excluded below to keep
        the math matching the plan's own numbers — not a judgment
        call about whether they *should* count, just following the
        plan's stated arithmetic.

        Separately: the eligible set as implemented still includes
        the five situational one-offs (Growth Spurt, Brick Placer,
        Dethroned, Beta Tester, Day One) that most members can never
        earn no matter what they do — meaning 100% may be genuinely
        unreachable for almost everyone. That reads as intentional for
        a badge called "The True Completionist!", but it's a real
        product decision, not a default to leave unexamined. To
        restrict the denominator further, add badge_ids to
        COMPLETIONIST_EXCLUDE below.

     2. LIVE VS. LOCKED-IN — this is a live, recomputed status. A
        member who hits 100% today and loses it tomorrow (because a
        21st badge shipped that they don't have yet) drops back out
        of True Completionist! automatically — nothing is written to
        `scores` when the threshold is crossed. If a permanent,
        earned-once badge is wanted instead, that needs an actual
        scores row written the moment the threshold is first crossed
        (closer to the one-off mechanic than a pure computed one) —
        not implemented here, since it changes the write path, not
        just this read-only check. */
  const COMPLETIONIST_EXCLUDE = ['speedtypist', '2fast4u']; // legacy badges that predate this rollout — see point 1 above

  function getCompletionStatus(scores, slug) {
    const eligible = Object.keys(BADGE_LABELS).filter(id => !COMPLETIONIST_EXCLUDE.includes(id));
    if (!eligible.length) return [];

    const RUBY_OR_ABOVE = ['ruby', 'amethyst', 'prism', 'allomorphite'];
    let qualifying = 0;
    for (const badgeId of eligible) {
      const board = getLeaderboard(scores, badgeId);
      const entry = board.find(b => b.slug === slug);
      if (entry && RUBY_OR_ABOVE.includes(entry.tier.name)) qualifying++;
      else {
        // Issue-tracked badges never show up in getLeaderboard() the
        // way ordinary ones do (see getBadgesForSlug above) — check
        // that path too before concluding this one doesn't qualify.
        const own = scores.find(s => s.slug === slug && s.badge_id === badgeId && s.issue_number != null);
        if (own && RUBY_OR_ABOVE.includes(tierForIssueNumber(own.issue_number).name)) qualifying++;
      }
    }

    const ratio = qualifying / eligible.length;
    const results = [];
    for (const [badgeId, cfg] of Object.entries(COMPUTED_BADGES)) {
      if (ratio >= cfg.threshold) {
        results.push({
          badge_id: badgeId,
          tierKey: 'allomorphite', // meta badges render at the top tier's color/frame — there's no lower tier for a status you either have or don't
          mode: 'computed',
          file: `${badgeId}.svg`,
          name: cfg.name,
          level: '',
          flavor: cfg.flavor || null,
          qualifying,
          eligibleTotal: eligible.length,
          percent: Math.round(ratio * 100),
        });
      }
    }
    return results;
  }

  return {
    fetchScores, getLeaderboard, getBadgesForSlug, getCompletionStatus,
    tierFor, tierForIssueNumber, applyFlavorTemplate,
    TIER_CONFIG, TIER_COLORS, BADGES, BADGE_LABELS, BADGE_FLAVOR, COMPUTED_BADGES,
    parseCSV,
  };
})();

export default Leaderboard;
