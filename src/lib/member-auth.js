/* ═══════════════════════════════════════════════════
   member-auth.js — password-based member login (Tier A)
   ═══════════════════════════════════════════════════
   Wraps the RPCs from dmac-member-auth-schema.sql. Sits alongside
   Google OAuth (sb.auth.*), doesn't replace it — a member can
   be logged in via password only, via Google only, or both (password
   session used once to prove identity, then linked).

   LOAD ORDER — same as leaderboard.js:
     1. supabase-js CDN script
     2. js/supabase-client.js   (creates sb)
     3. js/member-auth.js       (this file)

   USAGE
   ------------------------------------------------------
   MemberAuth.restoreSession()        → on page load, checks localStorage
                                         token against the server, returns
                                         the member or null ("welcome back")
   MemberAuth.login(slug, password)   → { success, member? , message? }
   MemberAuth.logout()
   MemberAuth.linkGoogle()            → call AFTER a successful login() AND
                                         AFTER sb.auth signInWithOAuth
                                         has completed (see login screen)
   MemberAuth.fetchRoster('member')   → array of {slug, display_name} for
   MemberAuth.fetchRoster('moderator')  the name dropdown, sorted by name.
                                         'member' bucket = site_role 'member'
                                         (the "member/officer" login button).
                                         'moderator' bucket = site_role
                                         'moderator' or 'admin'.
   MemberAuth.current()               → cached member object, or null
   MemberAuth.hasRole('admin')        → convenience check off the cached member
   MemberAuth.sessionMember           → reactive (Vue ref) mirror of current(),
                                         for components like NavBar that need
                                         to react to login/logout without a
                                         full page navigation happening.
   MemberAuth.getSessionToken()       → raw token string, or null. Exported so
                                         sibling modules (member-profile.js)
                                         can attach it to their own RPC calls
                                         without duplicating localStorage logic.
   ═══════════════════════════════════════════════════ */

import { ref } from 'vue';
import { sb } from './supabase-client.js';

const MemberAuth = (() => {

  const STORAGE_KEY = 'dmac_session_token';
  let cachedMember = null; // { slug, display_name, club_role, site_role }

  // Reactive mirror of cachedMember. Plain closure variables don't trigger
  // Vue re-renders on their own — components that need to know "is someone
  // logged in right now" (NavBar's profile link, route guards) watch this
  // ref instead of polling current().
  const sessionMember = ref(null);

  function setMember(member) {
    cachedMember = member;
    sessionMember.value = member;
  }

  function getToken() {
    return localStorage.getItem(STORAGE_KEY);
  }

  function setToken(token) {
    if (token) localStorage.setItem(STORAGE_KEY, token);
    else localStorage.removeItem(STORAGE_KEY);
  }

  async function restoreSession() {
    const token = getToken();
    if (!token) return null;

    const { data, error } = await sb.rpc('member_session_check', { p_session_token: token });
    if (error || !data || !data.success) {
      setToken(null);
      setMember(null);
      return null;
    }
    setMember(data.member);
    return cachedMember;
  }

  async function login(slug, password) {
    const { data, error } = await sb.rpc('member_login', { p_slug: slug, p_password: password });
    if (error) return { success: false, message: 'Something went wrong — try again.' };
    if (!data.success) return data; // { success: false, message: '...' }

    setToken(data.session_token);
    setMember(data.member);
    return data;
  }

  async function logout() {
    const token = getToken();
    if (token) await sb.rpc('member_logout', { p_session_token: token });
    setToken(null);
    setMember(null);
  }

  async function linkGoogle() {
    const token = getToken();
    if (!token) return { success: false, message: 'Log in with your name and password first.' };

    const { data, error } = await sb.rpc('member_link_google', { p_session_token: token });
    if (error) return { success: false, message: 'Something went wrong — try again.' };
    return data;
  }

  async function changeOwnPassword(oldPassword, newPassword) {
    const token = getToken();
    if (!token) return { success: false, message: 'Not logged in.' };

    const { data, error } = await sb.rpc('member_change_own_password', {
      p_session_token: token, p_old_password: oldPassword, p_new_password: newPassword,
    });
    if (error) return { success: false, message: 'Something went wrong — try again.' };
    return data;
  }

  async function fetchRoster(bucket) {
    const { data, error } = await sb.from('members').select('slug, display_name, site_role');
    if (error || !data) return [];

    const wanted = bucket === 'moderator'
      ? (row) => row.site_role === 'moderator' || row.site_role === 'admin'
      : (row) => row.site_role === 'member';

    return data
      .filter(wanted)
      .map(({ slug, display_name }) => ({ slug, display_name }))
      .sort((a, b) => a.display_name.localeCompare(b.display_name));
  }

  function current() {
    return cachedMember;
  }

  function hasRole(role) {
    if (!cachedMember) return false;
    if (role === 'moderator') return cachedMember.site_role === 'moderator' || cachedMember.site_role === 'admin';
    return cachedMember.site_role === role;
  }

  return {
    restoreSession, login, logout, linkGoogle, changeOwnPassword, fetchRoster, current, hasRole,
    sessionMember,
    getSessionToken: getToken,
  };
})();

export default MemberAuth;
