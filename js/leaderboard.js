/* ═══════════════════════════════════════════════════
   leaderboard.js — badge leaderboard / tier engine
   ═══════════════════════════════════════════════════
   Reads raw scores from a published Google Sheet (as CSV),
   ranks members per badge, and assigns each member a tier
   based on their percentage of the current #1 holder's value
   (the "floor"). The floor moves automatically as scores change
   — there's nothing to manually recalculate.

   USAGE
   ------------------------------------------------------
   Leaderboard.fetchScores(CSV_URL).then(scores => {
     const board = Leaderboard.getLeaderboard(scores, 'speedtypist');
     // board is an array of ranked entries, see getLeaderboard() below
   });

   SHEET SETUP (do this once in Google Sheets)
   ------------------------------------------------------
   1. Create a tab named exactly "Scores" with these columns
      (header row required, order doesn't matter):

        badge_id | member_id | value | issue_number | date

      - badge_id      e.g. "speedtypist" — matches the id used in code
      - member_id     matches a key in MEMBERS (members.js)
      - value         the raw metric (lines of code, seconds, count, etc.)
      - issue_number  only used for secret/issue-tracked badges — leave
                       blank for standard leaderboard badges
      - date          optional, not used by the engine yet

   2. File → Share → Publish to web → select the "Scores" sheet
      (not "Entire document") → format: Comma-separated values (.csv)
      → Publish. Copy the URL it gives you — that's your CSV_URL.

   3. Anyone with edit access to the Sheet can now add a row to update
      a score. No code changes needed — the site re-fetches on load.
   ═══════════════════════════════════════════════════ */

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

  /* ── CSV PARSING ───────────────────────────────────
     Minimal parser: handles quoted fields with embedded commas.
     Good enough for a Sheet you control the formatting of. */
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

  /* ── FETCH ─────────────────────────────────────────
     Pulls the published CSV and returns parsed score rows with
     `value` and `issue_number` coerced to numbers. */
  async function fetchScores(csvUrl) {
    const res = await fetch(csvUrl);
    if (!res.ok) throw new Error(`Leaderboard fetch failed: ${res.status}`);
    const text = await res.text();
    return parseCSV(text).map(r => ({
      badge_id: r.badge_id,
      member_id: r.member_id,
      value: parseFloat(r.value),
      issue_number: r.issue_number ? parseInt(r.issue_number, 10) : null,
      date: r.date || null,
    })).filter(r => r.badge_id && r.member_id && !isNaN(r.value));
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
        value: entry.value,
        rank: i + 1,
        percent,
        tier: tierFor(percent),
      };
    });
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

  return { fetchScores, getLeaderboard, tierFor, tierForIssueNumber, TIER_CONFIG, TIER_COLORS, BADGES, parseCSV };
})();
