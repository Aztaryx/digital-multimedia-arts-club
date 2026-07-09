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

  // In-memory fallback for when localStorage is blocked or unavailable —
  // notably some Android in-app browsers (Facebook/Messenger/Instagram),
  // Samsung Internet with strict storage blocking, and Chrome Incognito
  // with a zero-quota localStorage all throw on setItem/getItem. Without
  // this fallback, that throw happened right after a *successful* login
  // RPC and bubbled up as a generic "Something went wrong" error — so
  // people with correct passwords were being told to try again.
  // With the fallback, the session still works for the current page
  // load; it just won't survive a hard refresh on those browsers.
  let memoryToken = null;

  // Reactive mirror of cachedMember. Plain closure variables don't trigger
  // Vue re-renders on their own — components that need to know "is someone
  // logged in right now" (NavBar's profile link, route guards) watch this
  // ref instead of polling current().
  const sessionMember = ref(null);

  function setMember(member) {
    cachedMember = member;
    sessionMember.value = member;
  }

  async function hydrateMember(member) {
    if (!member?.slug) return member;

    const { data, error } = await sb
      .from('members')
      .select('nickname, avatar_url, banner_url, banner_color, year_joined')
      .eq('slug', member.slug)
      .maybeSingle();

    if (error) {
      console.error('MemberAuth.hydrateMember error:', error);
      return member;
    }

    return { ...member, ...(data || {}) };
  }

  // Temporary diagnostic helper — the UI has been showing a single generic
  // "Something went wrong" for every RPC failure, which makes it impossible
  // to tell a network problem from a CORS problem from an auth problem
  // without console access. This surfaces the real reason inline instead,
  // so it can be read directly off a phone screen. Safe to strip back down
  // to a plain friendly string once the actual cause is confirmed.
  function describeError(error) {
    const parts = [];
    if (error?.message) parts.push(error.message);
    if (error?.code) parts.push(`code: ${error.code}`);
    if (error?.status) parts.push(`status: ${error.status}`);
    const detail = parts.join(' — ') || 'unknown error';
    return `Something went wrong — try again. (${detail})`;
  }

  function getToken() {
    try {
      return localStorage.getItem(STORAGE_KEY) ?? memoryToken;
    } catch (_) {
      return memoryToken;
    }
  }

  function setToken(token) {
    memoryToken = token || null;
    try {
      if (token) localStorage.setItem(STORAGE_KEY, token);
      else localStorage.removeItem(STORAGE_KEY);
    } catch (_) {
      // Storage blocked — memoryToken above already covers the current
      // page load. Session just won't persist across a refresh here.
    }
  }

  async function restoreSession() {
    const token = getToken();
    if (!token) return null;

    const { data, error } = await sb.rpc('member_session_check', { p_session_token: token });
    if (error || !data || !data.success) {
      if (error) console.error('MemberAuth.restoreSession RPC error:', error);
      setToken(null);
      setMember(null);
      return null;
    }
    setMember(await hydrateMember(data.member));
    return cachedMember;
  }

  async function login(slug, password) {
    const { data, error } = await sb.rpc('member_login', { p_slug: slug, p_password: password });
    if (error) {
      console.error('MemberAuth.login RPC error:', error);
      return { success: false, message: describeError(error) };
    }
    if (!data.success) return data; // { success: false, message: '...' }

    setToken(data.session_token);
    setMember(await hydrateMember(data.member));
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
    if (error) {
      console.error('MemberAuth.linkGoogle RPC error:', error);
      return { success: false, message: describeError(error) };
    }
    return data;
  }

  async function changeOwnPassword(oldPassword, newPassword) {
    const token = getToken();
    if (!token) return { success: false, message: 'Not logged in.' };

    const { data, error } = await sb.rpc('member_change_own_password', {
      p_session_token: token, p_old_password: oldPassword, p_new_password: newPassword,
    });
    if (error) {
      console.error('MemberAuth.changeOwnPassword RPC error:', error);
      return { success: false, message: describeError(error) };
    }
    return data;
  }

  async function fetchRoster(bucket) {
    const { data, error } = await sb.from('members').select('slug, display_name, site_role');
    if (error || !data) {
      if (error) console.error('MemberAuth.fetchRoster error:', error);
      return [];
    }

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
