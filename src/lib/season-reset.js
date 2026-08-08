/** season-reset.js — Admin season reset workflow
 *  Manages the complex season reset process including legacy curation.
 */

import { supabase } from './supabase-client.js';

export const seasonReset = {
  /**
   * Initiate a new season with legacy record curation.
   * @param {UUID} sessionToken - Admin session token
   * @param {number} seasonNumber - New season number
   * @param {Array} legacyData - [{memberId, bestBadges, bestWorks, finalThreadsScore}, ...]
   */
  async startNewSeason(sessionToken, seasonNumber, legacyData = []) {
    try {
      // Call the RPC to perform the reset
      const { data, error } = await supabase.rpc('admin_start_new_season', {
        p_session_token: sessionToken,
        p_season_number: seasonNumber,
        p_legacy_data: JSON.stringify(legacyData),
      });

      if (error) {
        return { success: false, error: error.message };
      }

      return { success: true, data };
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  /**
   * Save legacy records for a member before reset
   * @param {UUID} memberId 
   * @param {number} seasonNumber 
   * @param {Array} bestBadges - [{badge_id, value}, ...]
   * @param {Array} bestWorks - [{work_id, title}, ...]
   * @param {number} finalThreadsScore 
   */
  async saveLegacyRecord(memberId, seasonNumber, bestBadges, bestWorks, finalThreadsScore) {
    try {
      const { data, error } = await supabase
        .from('legacy_records')
        .insert([{
          member_id: memberId,
          season_number: seasonNumber,
          best_badges: bestBadges,
          best_works: bestWorks,
          final_threads_score: finalThreadsScore,
        }]);

      if (error) {
        return { success: false, error: error.message };
      }

      return { success: true, data };
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  /**
   * Get all members for legacy curation
   */
  async getAllMembers() {
    try {
      const { data, error } = await supabase
        .from('members')
        .select('id, display_name, slug')
        .eq('site_role', 'member')
        .order('display_name');

      if (error) {
        return { success: false, error: error.message };
      }

      return { success: true, data };
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  /**
   * Get current standings for a member (Threads score + best badges/works)
   */
  async getMemberStandings(memberId) {
    try {
      // Get Threads score
      const { data: threads, error: threadsError } = await supabase
        .from('threads')
        .select('score')
        .eq('member_id', memberId)
        .single();

      if (threadsError && threadsError.code !== 'PGRST116') {
        throw threadsError;
      }

      // Get top 3 badges
      const { data: badges, error: badgesError } = await supabase
        .from('scores')
        .select('badge_id, value')
        .eq('member_id', memberId)
        .order('value', { ascending: false })
        .limit(3);

      if (badgesError) throw badgesError;

      // Get top 2 works
      const { data: works, error: worksError } = await supabase
        .from('works')
        .select('id, title')
        .eq('member_id', memberId)
        .order('created_at', { ascending: false })
        .limit(2);

      if (worksError) throw worksError;

      return {
        success: true,
        standings: {
          threadsScore: threads?.score || 1500,
          bestBadges: badges || [],
          bestWorks: works || [],
        },
      };
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  /**
   * Preview what will be wiped in the reset
   */
  async getResetPreview() {
    try {
      const [scoresRes, waysRes, contribRes] = await Promise.all([
        supabase.from('scores').select('count', { count: 'exact' }),
        supabase.from('works').select('count', { count: 'exact' }).eq('is_legacy', false),
        supabase.from('contributions').select('count', { count: 'exact' }).neq('status', 'archived'),
      ]);

      return {
        success: true,
        preview: {
          scoresWiped: scoresRes.count || 0,
          worksWiped: waysRes.count || 0,
          contributionsArchived: contribRes.count || 0,
        },
      };
    } catch (err) {
      return { success: false, error: err.message };
    }
  },
};

export default seasonReset;
