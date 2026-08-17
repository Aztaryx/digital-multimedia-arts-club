// supabase/functions/bits-threads-recompute/index.ts
//
// Bits engine — modified Glicko-2 recompute, per bits-threads-spec.md
// §1 and bits-threads-implementation-plan.md Phase 2. Runs in two
// modes:
//
//   1. HOURLY (server-triggered, via pg_cron + pg_net — see the
//      manual cron.schedule() setup this ships alongside, not in this
//      file). No p_session_token in the body. Recomputes every
//      domain-tagged badge's games for every member, writes updated
//      ratings for everyone who actually had activity or a
//      cross-domain trigger this cycle, and refreshes
//      badge_rank_snapshots for next cycle's comparison. Members with
//      zero relevant activity are left untouched — see the
//      [JUDGMENT CALL] note above updateRating() for why that departs
//      from strict textbook Glicko-2.
//
//   2. SELF-REFRESH (client-triggered): body is
//      { p_session_token, scope: 'self' }. Resolves identity via the
//      same _resolve_member_id() RPC every other function/RPC in this
//      project uses, enforces the 5-minute last_forced_refresh_at
//      cooldown from spec §2.4, then runs the exact same
//      game-generation/update logic but only WRITES ratings and
//      snapshot rows for that one member — everyone else's numbers
//      are read as frozen inputs, never touched by a self-refresh
//      call. See "SCOPING SELF-REFRESH" below.
//
// DEPLOY: `supabase functions deploy bits-threads-recompute`
// (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are already available as
// built-in env vars, same as upload-profile-image.)
//
// Also computes Threads (Phase 3) in the same run, chained AFTER the
// Bits step — spec §2.4 needs that cycle's freshly-written Bits
// numbers for the §2.3 specialization discount. Ping is deferred
// (implementation plan §0/§8), so this is currently a 4-factor
// composite (Bandwidth/FLOPS/Commits/Hertz) at weight 0.25 each, not
// the eventual 5-factor 0.2 each.
//
// This is genuinely the highest-risk file in the whole rework — real
// Glicko-2 math plus several judgment calls the spec itself flags as
// open. Treat it as a first pass: run it against a throwaway/staging
// project and sanity-check a few members by hand before trusting it
// on live data.

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

// ═══════════════════════════════════════════════════════════════════
// GLICKO-2 MATH — unmodified textbook implementation (Glickman's
// "Example of the Glicko-2 system" paper). Only game GENERATION
// (further down) is custom; everything in this section is standard.
// ═══════════════════════════════════════════════════════════════════

const GLICKO_SCALE = 173.7178;
const TAU = 0.5;                    // system constant, per spec §1.1
const VOLATILITY_EPSILON = 0.000001;
const DEFAULT_RATING = 1500;
const DEFAULT_RD = 350;
const DEFAULT_VOL = 0.06;
const RD_MAX = 350;                 // RD starts at 350 and nothing in
                                     // the spec says it can grow past
                                     // that — caps both the "no games"
                                     // growth step and the
                                     // cross-domain ×1.15 widen below.

interface RatingState { rating: number; rd: number; vol: number; }
interface Game { oppRating: number; oppRd: number; score: number; }

function toScale(rating: number, rd: number) {
  return { mu: (rating - DEFAULT_RATING) / GLICKO_SCALE, phi: rd / GLICKO_SCALE };
}
function fromScale(mu: number, phi: number) {
  return { rating: mu * GLICKO_SCALE + DEFAULT_RATING, rd: phi * GLICKO_SCALE };
}
function g(phi: number) {
  return 1 / Math.sqrt(1 + (3 * phi * phi) / (Math.PI * Math.PI));
}
function expectedScore(mu: number, muJ: number, phiJ: number) {
  return 1 / (1 + Math.exp(-g(phiJ) * (mu - muJ)));
}

// Illinois algorithm (regula falsi variant) solving for the new
// volatility — step 5 of the Glicko-2 paper, verbatim.
function computeNewVolatility(phi: number, delta: number, v: number, sigma: number): number {
  const a = Math.log(sigma * sigma);
  const f = (x: number) => {
    const ex = Math.exp(x);
    const num = ex * (delta * delta - phi * phi - v - ex);
    const den = 2 * Math.pow(phi * phi + v + ex, 2);
    return num / den - (x - a) / (TAU * TAU);
  };

  let A = a;
  let B: number;
  if (delta * delta > phi * phi + v) {
    B = Math.log(delta * delta - phi * phi - v);
  } else {
    let k = 1;
    while (f(a - k * TAU) < 0) k++;
    B = a - k * TAU;
  }

  let fA = f(A);
  let fB = f(B);

  while (Math.abs(B - A) > VOLATILITY_EPSILON) {
    const C = A + ((A - B) * fA) / (fB - fA);
    const fC = f(C);
    if (fC * fB < 0) {
      A = B;
      fA = fB;
    } else {
      fA = fA / 2;
    }
    B = C;
    fB = fC;
  }

  return Math.exp(A / 2);
}

/* [JUDGMENT CALL] Strict Glicko-2 grows RD for EVERY player every
   rating period, even ones with zero games that period — it's how
   the system models "we're less sure about someone we haven't seen
   play." bits-threads-implementation-plan.md's own "Done when"
   criterion for this phase says the opposite though:
   "member_domain_ratings visibly moves hour to hour for members with
   recent domain-tagged badge activity, and correctly stays flat for
   everyone else." Running strict per-period RD growth on literally
   every member every hour would violate "stays flat" and would mean
   touching ~everyone every cycle forever. This function is only ever
   CALLED for (member, domain) pairs that had a real game or a
   cross-domain trigger this cycle — untouched members are simply
   never passed through it, so they never move. If "growing
   uncertainty over time" is wanted after all, the fix is at the call
   site (call this for every member with an existing ratings row every
   cycle), not in this function. */
function updateRating(state: RatingState, games: Game[]): RatingState {
  const { mu, phi } = toScale(state.rating, state.rd);
  const sigma = state.vol;

  if (games.length === 0) {
    const phiStar = Math.sqrt(phi * phi + sigma * sigma);
    const { rating, rd } = fromScale(mu, phiStar);
    return { rating, rd: Math.min(rd, RD_MAX), vol: sigma };
  }

  let vInvSum = 0;
  let deltaSum = 0;
  for (const game of games) {
    const opp = toScale(game.oppRating, game.oppRd);
    const gPhiJ = g(opp.phi);
    const e = expectedScore(mu, opp.mu, opp.phi);
    vInvSum += gPhiJ * gPhiJ * e * (1 - e);
    deltaSum += gPhiJ * (game.score - e);
  }
  const v = 1 / vInvSum;
  const delta = v * deltaSum;

  const newSigma = computeNewVolatility(phi, delta, v, sigma);
  const phiStar = Math.sqrt(phi * phi + newSigma * newSigma);
  const newPhi = 1 / Math.sqrt(1 / (phiStar * phiStar) + 1 / v);
  const newMu = mu + newPhi * newPhi * deltaSum;

  const { rating, rd } = fromScale(newMu, newPhi);
  return { rating, rd: Math.min(rd, RD_MAX), vol: newSigma };
}

// ═══════════════════════════════════════════════════════════════════
// DOMAIN PLUMBING
// ═══════════════════════════════════════════════════════════════════

const ALL_DOMAINS = ['Digital', 'Multimedia', 'Arts'] as const;
type Domain = typeof ALL_DOMAINS[number];

const DOMAIN_COLUMNS: Record<Domain, { rating: string; deviation: string; volatility: string }> = {
  Digital:    { rating: 'domain_digital',    deviation: 'deviation_digital',    volatility: 'volatility_digital' },
  Multimedia: { rating: 'domain_multimedia', deviation: 'deviation_multimedia', volatility: 'volatility_multimedia' },
  Arts:       { rating: 'domain_arts',       deviation: 'deviation_arts',       volatility: 'volatility_arts' },
};

// Mirrors leaderboard.js's BADGES direction map. No domain-tagged
// badge is currently 'asc' (only 2fast4u is, and it has no domain —
// see badge_domains' seed) but this stays here so a future asc badge
// that DOES get a domain assigned doesn't silently rank backwards.
const BADGE_DIRECTIONS: Record<string, 'asc' | 'desc'> = {
  '2fast4u': 'asc',
};

function clamp(n: number, lo: number, hi: number) {
  return Math.max(lo, Math.min(hi, n));
}

// ═══════════════════════════════════════════════════════════════════
// THREADS COMPOSITE CONSTANTS (Phase 3) — spec §2
// ═══════════════════════════════════════════════════════════════════

const WINDOW_DAYS = 90;             // "rolling window, not lifetime" — spec §2.1
const THREADS_FACTOR_WEIGHT = 0.25; // Phase 3 (4 factors) — becomes 0.2 once Ping ships (Phase 5)
const DISCOUNT_RATE = 0.13;         // spec §2.3's discount ceiling
const SPECIALIZATION_DIVISOR = 500; // spec §2.3's specialization_index divisor

// [JUDGMENT CALL] contributions.quality is stored as 'low'|'medium'|
// 'high' (see the schema + contribution-logging.js), but spec §2.1
// calls FLOPS "admin-assigned quality score (1–10)". Mapped onto
// evenly-spaced points across that range — a one-line change here if
// a different spread is wanted later.
const QUALITY_SCALE: Record<string, number> = { low: 3, medium: 6, high: 9 };

// ═══════════════════════════════════════════════════════════════════
// MAIN HANDLER
// ═══════════════════════════════════════════════════════════════════

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return json({ success: false, message: 'Method not allowed.' }, 405);

  let body: any = {};
  try {
    body = await req.json();
  } catch {
    body = {}; // cron calls this with no body at all — that's fine
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const isSelfRefresh = body?.scope === 'self' && typeof body?.p_session_token === 'string';
  let scopedMemberId: string | null = null;

  if (isSelfRefresh) {
    const { data: memberId, error: resolveError } = await admin.rpc('_resolve_member_id', {
      p_session_token: body.p_session_token,
    });
    if (resolveError || !memberId) {
      return json({ success: false, message: 'Not logged in.' }, 401);
    }
    scopedMemberId = memberId as string;

    const { data: memberRow, error: memberError } = await admin
      .from('members')
      .select('last_forced_refresh_at')
      .eq('id', scopedMemberId)
      .maybeSingle();
    if (memberError) {
      return json({ success: false, message: 'Could not check refresh cooldown.' }, 500);
    }
    const lastRefresh = memberRow?.last_forced_refresh_at ? new Date(memberRow.last_forced_refresh_at) : null;
    if (lastRefresh && Date.now() - lastRefresh.getTime() < 5 * 60 * 1000) {
      const secondsLeft = Math.ceil((5 * 60 * 1000 - (Date.now() - lastRefresh.getTime())) / 1000);
      return json({ success: false, message: `You can refresh again in ${secondsLeft}s.` }, 429);
    }

    // Set the cooldown timestamp NOW, before the (potentially slow)
    // recompute below — closes the race window where two rapid clicks
    // both pass the check above before either finishes writing.
    await admin.from('members').update({ last_forced_refresh_at: new Date().toISOString() }).eq('id', scopedMemberId);
  } else {
    // Server-triggered (cron) path — no client identity to check, so
    // instead require the caller to actually hold the service-role
    // key, the same key pg_cron's net.http_post call sends as its
    // Bearer token (see the cron.schedule() snippet that ships
    // alongside this function). Stops anyone from hitting this public
    // endpoint and forcing a full sitewide recompute on demand.
    const authHeader = req.headers.get('Authorization') || '';
    const bearer = authHeader.replace(/^Bearer\s+/i, '');
    if (bearer !== SERVICE_ROLE_KEY) {
      return json({ success: false, message: 'Not authorized for a full recompute.' }, 401);
    }
  }

  try {
    const summary = await runRecompute(admin, scopedMemberId);
    return json({ success: true, scope: isSelfRefresh ? 'self' : 'all', ...summary });
  } catch (err) {
    console.error('bits-threads-recompute failed —', err);
    return json({ success: false, message: `Recompute failed: ${(err as Error).message}` }, 500);
  }
});

// ═══════════════════════════════════════════════════════════════════
// RECOMPUTE — Part 1 is Bits (steps 1–5 from
// bits-threads-implementation-plan.md Phase 2), Part 2 is Threads
// (Phase 3), chained after since spec §2.4 needs Part 1's freshly-
// written numbers. Both scope down to a single member when
// scopedMemberId is set (self-refresh).
// ═══════════════════════════════════════════════════════════════════


async function runRecompute(admin: any, scopedMemberId: string | null) {
  // ══════════════════════════════════════════════════════════════
  // PART 1 — BITS (Glicko-2). No longer short-circuits with an early
  // `return` on a quiet cycle — Part 2 (Threads) below needs to run
  // even when there's nothing for Bits to do (e.g. a fresh club with
  // contributions logged but no badges awarded yet).
  // ══════════════════════════════════════════════════════════════

  const { data: domainRows, error: domainError } = await admin
    .from('badge_domains')
    .select('badge_id, domain')
    .not('domain', 'is', null);
  if (domainError) throw domainError;

  const badgeDomains = new Map<string, Domain>();
  for (const row of domainRows || []) badgeDomains.set(row.badge_id, row.domain as Domain);
  const domainTaggedBadgeIds = [...badgeDomains.keys()];

  const holdersByBadge = new Map<string, { member_id: string; value: number }[]>();
  if (domainTaggedBadgeIds.length > 0) {
    const { data: scoreRows, error: scoreError } = await admin
      .from('scores')
      .select('badge_id, member_id, value, issue_number')
      .in('badge_id', domainTaggedBadgeIds)
      .is('issue_number', null);
    if (scoreError) throw scoreError;

    for (const row of scoreRows || []) {
      if (!row.member_id) continue;
      const list = holdersByBadge.get(row.badge_id) || [];
      list.push({ member_id: row.member_id, value: Number(row.value) });
      holdersByBadge.set(row.badge_id, list);
    }
  }

  // Every member holding ANY domain-tagged badge — used for the
  // cross-domain "current domain set" check, independent of whether
  // that particular badge has enough holders to generate a game.
  const currentDomainSet = new Map<string, Set<Domain>>();
  for (const [badgeId, holders] of holdersByBadge) {
    const domain = badgeDomains.get(badgeId)!;
    for (const h of holders) {
      const set = currentDomainSet.get(h.member_id) || new Set<Domain>();
      set.add(domain);
      currentDomainSet.set(h.member_id, set);
    }
  }

  // Rank each badge with ≥2 holders (Leaderboard.getLeaderboard(),
  // re-implemented server-side — an Edge Function can't import the
  // Vue app's client code).
  type BoardEntry = { member_id: string; rank: number; percent: number; value: number };
  const boards = new Map<string, BoardEntry[]>();
  for (const [badgeId, holders] of holdersByBadge) {
    if (holders.length < 2) continue; // sole holder — skipped entirely per spec §1.4
    const direction = BADGE_DIRECTIONS[badgeId] || 'desc';
    const sorted = [...holders].sort((a, b) => (direction === 'desc' ? b.value - a.value : a.value - b.value));
    const floor = sorted[0].value;
    const board: BoardEntry[] = sorted.map((h, i) => {
      const raw = direction === 'desc' ? (h.value / floor) * 100 : (floor / h.value) * 100;
      return { member_id: h.member_id, rank: i + 1, percent: Math.min(100, Math.round(raw)), value: h.value };
    });
    boards.set(badgeId, board);
  }
  const scorableBadgeIds = [...boards.keys()];

  const snapshotMap = new Map<string, { rank: number; percent: number }>();
  const badgeIdsWithPriorSnapshot = new Set<string>();
  const priorDomainSet = new Map<string, Set<Domain>>();
  if (scorableBadgeIds.length > 0) {
    const { data: snapshotRows, error: snapshotError } = await admin
      .from('badge_rank_snapshots')
      .select('badge_id, member_id, rank, percent')
      .in('badge_id', scorableBadgeIds);
    if (snapshotError) throw snapshotError;

    for (const row of snapshotRows || []) {
      snapshotMap.set(`${row.badge_id}:${row.member_id}`, { rank: row.rank, percent: row.percent });
      badgeIdsWithPriorSnapshot.add(row.badge_id);
      const domain = badgeDomains.get(row.badge_id);
      if (domain) {
        const set = priorDomainSet.get(row.member_id) || new Set<Domain>();
        set.add(domain);
        priorDomainSet.set(row.member_id, set);
      }
    }
  }

  const involvedMemberIds = [...currentDomainSet.keys()];
  const ratingsByMember = new Map<string, Record<string, any>>();
  if (involvedMemberIds.length > 0) {
    const { data: ratingRows, error: ratingError } = await admin
      .from('member_domain_ratings')
      .select('member_id, domain_arts, deviation_arts, volatility_arts, domain_multimedia, deviation_multimedia, volatility_multimedia, domain_digital, deviation_digital, volatility_digital')
      .in('member_id', involvedMemberIds);
    if (ratingError) throw ratingError;
    for (const row of ratingRows || []) ratingsByMember.set(row.member_id, row);
  }

  function getState(memberId: string, domain: Domain): RatingState {
    const row = ratingsByMember.get(memberId);
    const cols = DOMAIN_COLUMNS[domain];
    if (!row) return { rating: DEFAULT_RATING, rd: DEFAULT_RD, vol: DEFAULT_VOL };
    return {
      rating: row[cols.rating] ?? DEFAULT_RATING,
      rd: row[cols.deviation] ?? DEFAULT_RD,
      vol: row[cols.volatility] ?? DEFAULT_VOL,
    };
  }

  const gamesByMemberDomain = new Map<string, Map<Domain, Game[]>>();
  const touched = new Map<string, Set<Domain>>(); // member -> domains with a real game this cycle

  function pushGame(memberId: string, domain: Domain, game: Game) {
    const byDomain = gamesByMemberDomain.get(memberId) || new Map<Domain, Game[]>();
    const list = byDomain.get(domain) || [];
    list.push(game);
    byDomain.set(domain, list);
    gamesByMemberDomain.set(memberId, byDomain);

    const t = touched.get(memberId) || new Set<Domain>();
    t.add(domain);
    touched.set(memberId, t);
  }

  for (const [badgeId, board] of boards) {
    // First-ever cycle for this badge — write the baseline snapshot
    // (below) and generate no games, per implementation plan §0.
    if (!badgeIdsWithPriorSnapshot.has(badgeId)) continue;

    const domain = badgeDomains.get(badgeId)!;
    const top = board[0];
    const topState = getState(top.member_id, domain);

    for (let i = 1; i < board.length; i++) {
      const entry = board[i];
      const prior = snapshotMap.get(`${badgeId}:${entry.member_id}`);
      let score: number | null;
      if (!prior) score = 1;                              // newly on the leaderboard for this badge
      else if (entry.rank < prior.rank) score = 1;         // rank improved (lower number = better)
      else if (entry.rank > prior.rank) score = 0;         // rank got worse
      else if (entry.percent < prior.percent) score = 0;   // same rank, but value dropped — reads as
                                                             // an admin correction per spec's "tier was
                                                             // administratively corrected downward"
      else score = null;                                   // unchanged — no game

      if (score !== null) {
        pushGame(entry.member_id, domain, { oppRating: topState.rating, oppRd: topState.rd, score });
      }
    }

    // #1 vs synthetic #2, margin-scaled — spec §1.2
    if (board.length >= 2) {
      const second = board[1];
      const secondState = getState(second.member_id, domain);
      const s = 0.5 + 0.5 * clamp((100 - second.percent) / 100, 0, 1);
      pushGame(top.member_id, domain, { oppRating: secondState.rating, oppRd: secondState.rd, score: s });
    }
  }

  // Cross-domain volatility rule (spec §1.3). [JUDGMENT CALL] Only
  // triggers for a member who already had an established domain
  // (priorDomainSet.size > 0) and has now picked up a genuinely new
  // one — a brand-new member's very first domain ever doesn't count
  // as "surprising," since there's no existing profile yet to cast
  // doubt on.
  const widenTargets = new Map<string, Set<Domain>>();
  for (const [memberId, current] of currentDomainSet) {
    const prior = priorDomainSet.get(memberId) ?? new Set<Domain>();
    if (prior.size === 0) continue;
    const newlyEntered = ALL_DOMAINS.filter((d) => current.has(d) && !prior.has(d));
    if (newlyEntered.length === 0) continue;
    const targets = widenTargets.get(memberId) || new Set<Domain>();
    for (const d of ALL_DOMAINS) {
      if (!newlyEntered.includes(d)) targets.add(d);
    }
    widenTargets.set(memberId, targets);
  }

  // SCOPING SELF-REFRESH: board/game generation above always runs
  // over EVERYONE, since a member's own games depend on the current
  // #1/#2 holders' ratings regardless of who asked for this run. Only
  // the WRITE step below is narrowed — everyone else's ratings and
  // snapshot rows are left exactly as they were until the next hourly
  // cycle picks them up.
  const bitsMemberIdsToUpdate = new Set<string>([...touched.keys(), ...widenTargets.keys()]);
  const finalBitsMemberIds = scopedMemberId
    ? [...bitsMemberIdsToUpdate].filter((id) => id === scopedMemberId)
    : [...bitsMemberIdsToUpdate];

  let membersUpdated = 0;
  for (const memberId of finalBitsMemberIds) {
    const row = ratingsByMember.get(memberId) || {};
    const patch: Record<string, number> = {};
    let anyDomainTouched = false;

    for (const domain of ALL_DOMAINS) {
      const games = gamesByMemberDomain.get(memberId)?.get(domain) || [];
      const isWiden = widenTargets.get(memberId)?.has(domain) || false;
      if (games.length === 0 && !isWiden) continue; // nothing happened in this domain this cycle

      const existing = getState(memberId, domain);
      let updated = updateRating(existing, games);
      if (isWiden) updated = { ...updated, rd: Math.min(updated.rd * 1.15, RD_MAX) };

      const cols = DOMAIN_COLUMNS[domain];
      patch[cols.rating] = updated.rating;
      patch[cols.deviation] = updated.rd;
      patch[cols.volatility] = updated.vol;
      anyDomainTouched = true;
    }

    if (!anyDomainTouched) continue;

    const fullRow = {
      member_id: memberId,
      domain_arts: row.domain_arts ?? DEFAULT_RATING,
      deviation_arts: row.deviation_arts ?? DEFAULT_RD,
      volatility_arts: row.volatility_arts ?? DEFAULT_VOL,
      domain_multimedia: row.domain_multimedia ?? DEFAULT_RATING,
      deviation_multimedia: row.deviation_multimedia ?? DEFAULT_RD,
      volatility_multimedia: row.volatility_multimedia ?? DEFAULT_VOL,
      domain_digital: row.domain_digital ?? DEFAULT_RATING,
      deviation_digital: row.deviation_digital ?? DEFAULT_RD,
      volatility_digital: row.volatility_digital ?? DEFAULT_VOL,
      updated_at: new Date().toISOString(),
      ...patch,
    };

    const { error: upsertError } = await admin
      .from('member_domain_ratings')
      .upsert(fullRow, { onConflict: 'member_id' });
    if (upsertError) throw upsertError;
    membersUpdated++;
  }

  if (scorableBadgeIds.length > 0) {
    const snapshotWrites: { badge_id: string; member_id: string; rank: number; percent: number }[] = [];
    for (const [badgeId, board] of boards) {
      for (const entry of board) {
        if (scopedMemberId && entry.member_id !== scopedMemberId) continue;
        snapshotWrites.push({ badge_id: badgeId, member_id: entry.member_id, rank: entry.rank, percent: entry.percent });
      }
    }
    if (snapshotWrites.length) {
      const { error: snapWriteError } = await admin
        .from('badge_rank_snapshots')
        .upsert(snapshotWrites.map((s) => ({ ...s, snapshot_at: new Date().toISOString() })), { onConflict: 'badge_id,member_id' });
      if (snapWriteError) throw snapWriteError;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // PART 2 — THREADS COMPOSITE (Phase 3). Chained after Bits above
  // — spec §2.4 needs THIS cycle's freshly-written Bits numbers for
  // the §2.3 discount.
  // ══════════════════════════════════════════════════════════════

  const windowStart = new Date(Date.now() - WINDOW_DAYS * 24 * 60 * 60 * 1000).toISOString();

  const { data: contribRows, error: contribError } = await admin
    .from('contributions')
    .select('member_id, domain, weight, quality, created_at')
    .gte('created_at', windowStart)
    .neq('status', 'archived');
  if (contribError) throw contribError;

  const contribsByMember = new Map<string, { domain: Domain; weight: number; quality: string }[]>();
  for (const row of contribRows || []) {
    if (!row.member_id) continue;
    const list = contribsByMember.get(row.member_id) || [];
    list.push({ domain: row.domain, weight: Number(row.weight), quality: row.quality });
    contribsByMember.set(row.member_id, list);
  }

  // Full cron run → everyone with ≥1 contribution in the window (so
  // Threads keeps moving as old contributions age out of the window,
  // even with zero brand-new activity this cycle). Self-refresh →
  // just the scoped member, computed even at zero activity, so
  // "recompute me" reflects reality either way.
  const threadsMemberIds = scopedMemberId ? [scopedMemberId] : [...contribsByMember.keys()];

  // Re-read ratings fresh rather than reusing ratingsByMember above —
  // the Bits step in this same run may have just changed some of
  // these members' numbers, and §2.3's "strongest domain" has to
  // reflect that, not the pre-cycle snapshot loaded earlier.
  const freshRatings = new Map<string, { domain_arts: number; domain_multimedia: number; domain_digital: number }>();
  if (threadsMemberIds.length > 0) {
    const { data: freshRatingRows, error: freshRatingError } = await admin
      .from('member_domain_ratings')
      .select('member_id, domain_arts, domain_multimedia, domain_digital')
      .in('member_id', threadsMemberIds);
    if (freshRatingError) throw freshRatingError;
    for (const row of freshRatingRows || []) {
      freshRatings.set(row.member_id, {
        domain_arts: row.domain_arts ?? DEFAULT_RATING,
        domain_multimedia: row.domain_multimedia ?? DEFAULT_RATING,
        domain_digital: row.domain_digital ?? DEFAULT_RATING,
      });
    }
  }

  let threadsUpdated = 0;
  for (const memberId of threadsMemberIds) {
    const contribs = contribsByMember.get(memberId) || [];
    const n = contribs.length;

    // ── Raw factors — spec §2.1 ─────────────────────────────────
    const bandwidth = n ? contribs.reduce((sum, c) => sum + c.weight, 0) / n : 0;
    const flops = n ? contribs.reduce((sum, c) => sum + (QUALITY_SCALE[c.quality] ?? 0), 0) / n : 0;
    // Commits = sum(weight × share%); share% = 100% per member until
    // real contributor-splitting UI exists (implementation plan §0)
    // — so this differs from Bandwidth only in sum-vs-average, exactly
    // as that section calls out.
    const commits = contribs.reduce((sum, c) => sum + c.weight * 1.0, 0);
    const hertz = n ? n / (WINDOW_DAYS / 7) : 0;

    // ── Majority domain — spec §2.3 step 2 ──────────────────────
    // All 4 factors this phase derive from the same Contributions
    // set, so they share one majority domain — stops being true once
    // Ping (a different table entirely) goes live in Phase 5.
    const domainCounts = new Map<Domain, number>();
    for (const c of contribs) {
      if (!c.domain) continue;
      domainCounts.set(c.domain, (domainCounts.get(c.domain) || 0) + 1);
    }
    let majorityDomain: Domain | null = null;
    let majorityCount = 0;
    let tie = false;
    for (const [domain, count] of domainCounts) {
      if (count > majorityCount) {
        majorityDomain = domain;
        majorityCount = count;
        tie = false;
      } else if (count === majorityCount) {
        tie = true;
      }
    }
    if (tie) majorityDomain = null; // no clear plurality — no discount applied this cycle

    // ── Strongest Bits domain + discount — spec §2.3 steps 1 & 3 ─
    const ratings = freshRatings.get(memberId) || { domain_arts: DEFAULT_RATING, domain_multimedia: DEFAULT_RATING, domain_digital: DEFAULT_RATING };
    const domainValues: [Domain, number][] = [
      ['Arts', ratings.domain_arts],
      ['Multimedia', ratings.domain_multimedia],
      ['Digital', ratings.domain_digital],
    ];
    domainValues.sort((a, b) => b[1] - a[1]);
    const [topDomain, topValue] = domainValues[0];
    const avgOtherTwo = (domainValues[1][1] + domainValues[2][1]) / 2;
    const specializationIndex = clamp((topValue - avgOtherTwo) / SPECIALIZATION_DIVISOR, 0, 1);
    const discount = 1 - DISCOUNT_RATE * specializationIndex;
    const applyDiscount = majorityDomain !== null && majorityDomain === topDomain;
    const factorMultiplier = THREADS_FACTOR_WEIGHT * (applyDiscount ? discount : 1);

    const bandwidthTerm = factorMultiplier * bandwidth;
    const flopsTerm = factorMultiplier * flops;
    const commitsTerm = factorMultiplier * commits;
    const hertzTerm = factorMultiplier * hertz;
    const score = bandwidthTerm + flopsTerm + commitsTerm + hertzTerm;

    const { error: threadsUpsertError } = await admin
      .from('threads')
      .upsert({
        member_id: memberId,
        score,
        ping_factor: 0, // not computed until Phase 5 — implementation plan §8
        bandwidth_factor: bandwidthTerm,
        flops_factor: flopsTerm,
        commits_factor: commitsTerm,
        hertz_factor: hertzTerm,
        last_updated: new Date().toISOString(),
      }, { onConflict: 'member_id' });
    if (threadsUpsertError) throw threadsUpsertError;
    threadsUpdated++;
  }

  return {
    badges_processed: scorableBadgeIds.length,
    members_updated: membersUpdated,
    threads_updated: threadsUpdated,
  };
}
