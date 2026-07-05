/* ═══════════════════════════════════════════════════
   supabase-client.js — shared Supabase client singleton
   ═══════════════════════════════════════════════════
   One client, reused by any script that needs Supabase (leaderboard,
   login, member profiles, etc.) instead of each file creating its own
   and duplicating the URL/key.

   LOAD ORDER — on any page that needs Supabase, include these
   two script tags BEFORE anything that uses window.sb:

     <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js"></script>
     <script src="js/supabase-client.js"></script>
     <!-- then whatever needs it, e.g. js/leaderboard.js -->

   The publishable key below is safe to expose in client-side code —
   that's what it's for. It has no elevated privileges; every table
   it can reach is governed by the RLS policies on that table.
   NEVER put a secret/service_role key anywhere in this repo.
   ═══════════════════════════════════════════════════ */

const SUPABASE_URL = 'https://ylhmidtwnvojawogbvhh.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_mxjbouATop0KhOZObpWMoA_FeHQWXag';

window.sb = supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
