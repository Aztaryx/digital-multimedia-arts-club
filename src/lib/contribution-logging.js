/** contribution-logging.js — Admin contribution logging workflow
 *  Handles logging contributions as drafts and submitting in batch.
 */

import { supabase } from './supabase-client.js';

export const contributionLogging = {
  /**
   * Create a new contribution draft
   * @param {UUID} sessionToken - Admin session token
   * @param {UUID} memberId - Member this contribution is for
   * @param {string} domain - 'Arts' | 'Multimedia' | 'Digital'
   * @param {number} weight - multiplier (default 1.0)
   * @param {string} quality - 'low' | 'medium' | 'high'
   * @param {string} description - Description of contribution
   * @param {Object} contributorSplits - {memberId: percent, ...} for splits
   */
  async createContribution(
    sessionToken,
    memberId,
    domain,
    weight = 1.0,
    quality = 'medium',
    description = null,
    contributorSplits = {}
  ) {
    try {
      const { data, error } = await supabase.rpc('admin_log_contribution', {
        p_session_token: sessionToken,
        p_member_id: memberId,
        p_domain: domain,
        p_weight: weight,
        p_quality: quality,
        p_description: description,
        p_contributor_splits: contributorSplits,
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
   * List all contributions (with optional filtering)
   * @param {UUID} sessionToken
   * @param {string} status - Filter by status ('draft' | 'submitted' | 'archived')
   * @param {number} limit
   */
  async listContributions(sessionToken, status = null, limit = 100) {
    try {
      const { data, error } = await supabase.rpc('admin_list_contributions', {
        p_session_token: sessionToken,
        p_status: status,
        p_limit: limit,
      });

      if (error) {
        return { success: false, error: error.message };
      }

      return { success: true, data: data?.contributions || [] };
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  /**
   * Update a contribution draft
   */
  async updateContribution(contributionId, updates) {
    try {
      const { data, error } = await supabase
        .from('contributions')
        .update(updates)
        .eq('id', contributionId)
        .select();

      if (error) {
        return { success: false, error: error.message };
      }

      return { success: true, data: data?.[0] };
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  /**
   * Delete a contribution (draft)
   */
  async deleteContribution(contributionId) {
    try {
      const { error } = await supabase
        .from('contributions')
        .delete()
        .eq('id', contributionId);

      if (error) {
        return { success: false, error: error.message };
      }

      return { success: true };
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  /**
   * Submit multiple contributions at once (batch update status to 'submitted')
   */
  async submitBatch(contributionIds) {
    try {
      const { data, error } = await supabase
        .from('contributions')
        .update({ status: 'submitted', submitted_at: new Date().toISOString() })
        .in('id', contributionIds)
        .select();

      if (error) {
        return { success: false, error: error.message };
      }

      return { success: true, data };
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  /**
   * Get drafts ready to submit
   */
  async getDrafts() {
    try {
      const { data, error } = await supabase
        .from('contributions')
        .select('*')
        .eq('status', 'draft')
        .order('created_at', { ascending: false });

      if (error) {
        return { success: false, error: error.message };
      }

      return { success: true, data: data || [] };
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  /**
   * Get all available members for logging contributions
   */
  async getAvailableMembers() {
    try {
      const { data, error } = await supabase
        .from('members')
        .select('id, display_name, slug')
        .eq('site_role', 'member')
        .order('display_name');

      if (error) {
        return { success: false, error: error.message };
      }

      return { success: true, data: data || [] };
    } catch (err) {
      return { success: false, error: err.message };
    }
  },
};

export default contributionLogging;
