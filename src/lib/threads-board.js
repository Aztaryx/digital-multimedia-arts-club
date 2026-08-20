/* threads-board.js — shared "everyone's Threads row, ranked" fetch.
   Used by ProfileView.vue (their own rank) and about/MembersView.vue
   (whichever member's card is currently open) so both read the same
   live standings off one query shape instead of two that could drift
   apart. Requires schema-additions-v2-rework.sql's `threads` table —
   a query error here is handled by the caller, not thrown past it. */
import { sb } from './supabase-client.js';

export async function fetchThreadsBoard() {
  const { data, error } = await sb
    .from('threads')
    .select('member_id, score, ping_factor, bandwidth_factor, flops_factor, commits_factor, hertz_factor, members!inner(slug)')
    .order('score', { ascending: false });

  if (error) throw new Error(`Threads board fetch failed: ${error.message}`);

  return (data || [])
    .map((row, i) => ({
      slug: row.members?.slug || null,
      score: row.score,
      factors: {
        ping: row.ping_factor,
        bandwidth: row.bandwidth_factor,
        flops: row.flops_factor,
        commits: row.commits_factor,
        hertz: row.hertz_factor,
      },
      rank: i + 1,
    }))
    .filter((r) => r.slug);
}

// Badge-count rank across everyone who holds at least one badge —
// shared the same way, off Leaderboard.fetchScores()' output, so
// ProfileView and MemberCard usages agree on "top N/total" too.
export function rankByBadgeCount(scores, slug) {
  const bySlug = {};
  for (const s of scores) {
    if (!s.slug) continue;
    if (!bySlug[s.slug]) bySlug[s.slug] = new Set();
    bySlug[s.slug].add(s.badge_id);
  }
  const counts = Object.entries(bySlug)
    .map(([s, set]) => ({ slug: s, count: set.size }))
    .sort((a, b) => b.count - a.count);
  const idx = counts.findIndex((c) => c.slug === slug);
  return { rank: idx !== -1 ? idx + 1 : null, rosterCount: counts.length };
}
