/* ═══════════════════════════════════════════════════
   supabase-client.js — shared Supabase client singleton
   ═══════════════════════════════════════════════════
   One client, reused by anything that needs Supabase (leaderboard,
   login, member profiles, etc.) instead of each module creating its
   own and duplicating the URL/key.

   SPA NOTE: this now goes through the real @supabase/supabase-js
   npm package (bundled by Vite) instead of the old CDN <script> tag +
   window.sb global. Import { sb } from './supabase-client.js' wherever
   the old code referenced window.sb.

   The publishable key below is safe to expose in client-side code —
   that's what it's for. It has no elevated privileges; every table
   it can reach is governed by the RLS policies on that table.
   NEVER put a secret/service_role key anywhere in this repo.
   ═══════════════════════════════════════════════════ */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://ylhmidtwnvojawogbvhh.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_mxjbouATop0KhOZObpWMoA_FeHQWXag';

export const sb = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);

/* Alias kept for backward compatibility — a handful of newer files
   (LeaderboardView.vue, AnnouncementsView.vue, SchoolEventsView.vue,
   lib/contribution-logging.js, lib/season-reset.js) were written
   importing `{ supabase }` instead of `{ sb }`, which this module
   never exported, so every one of those was silently `undefined` at
   the call site — the first `.from(...)` call on any of them threw.
   Rather than hunt down and rename every import across five files
   (and risk missing a sixth later), this file now exports both names
   for the same client. New code should still prefer `sb`, matching
   every other file in this codebase — this alias exists purely so
   the files already using `supabase` actually work. */
export const supabase = sb;
