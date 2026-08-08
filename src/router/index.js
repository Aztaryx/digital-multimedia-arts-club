import { createRouter, createWebHistory } from 'vue-router';
import MemberAuth from '../lib/member-auth.js';

const routes = [
  {
    path: '/',
    redirect: '/home',
  },
  {
    path: '/home',
    name: 'home',
    component: () => import('../views/HomeView.vue'),
    meta: { title: 'DMAC — Home' },
  },
  {
    path: '/about',
    name: 'about',
    component: () => import('../views/about/AboutView.vue'),
    meta: { title: 'DMAC — About Us' },
  },
  {
    path: '/about/mission',
    name: 'about-mission',
    component: () => import('../views/about/MissionView.vue'),
    meta: { title: 'DMAC — Mission' },
  },
  {
    path: '/about/members',
    name: 'about-members',
    component: () => import('../views/about/MembersView.vue'),
    meta: { title: 'DMAC — Members' },
  },
  {
    path: '/projects',
    name: 'projects',
    component: () => import('../views/ProjectsView.vue'),
    meta: { title: 'DMAC — Projects' },
  },
  {
    path: '/leaderboard',
    name: 'leaderboard',
    component: () => import('../views/LeaderboardView.vue'),
    meta: { title: 'DMAC — Leaderboard' },
  },
  {
    path: '/branding',
    name: 'branding',
    component: () => import('../views/BrandingView.vue'),
    meta: { title: 'DMAC — Branding' },
  },
  {
    path: '/info/newsletters',
    name: 'info-newsletters',
    component: () => import('../views/info/NewslettersView.vue'),
    meta: { title: 'DMAC — Newsletters' },
  },
  {
    path: '/info/announcements',
    name: 'info-announcements',
    component: () => import('../views/info/AnnouncementsView.vue'),
    meta: { title: 'DMAC — Announcements' },
  },
  {
    path: '/info/school-events',
    name: 'info-school-events',
    component: () => import('../views/info/SchoolEventsView.vue'),
    meta: { title: 'DMAC — School Events' },
  },
  {
    path: '/info/update-log',
    name: 'info-update-log',
    component: () => import('../views/info/UpdateLogView.vue'),
    meta: { title: 'DMAC — Update Log' },
  },
  {
    path: '/info/faq',
    name: 'info-faq',
    component: () => import('../views/info/FaqView.vue'),
    meta: { title: 'DMAC — FAQ' },
  },
  {
    path: '/join',
    name: 'join',
    component: () => import('../views/JoinView.vue'),
    meta: { title: 'DMAC — How to Join' },
  },
  {
    path: '/socials',
    name: 'socials',
    component: () => import('../views/SocialsView.vue'),
    meta: { title: 'DMAC — Socials' },
  },
  {
    path: '/login',
    name: 'login',
    component: () => import('../views/LoginView.vue'),
    // The original login/index.html was a standalone page — its own
    // header/footer, no site nav — not a page wrapped in the normal
    // chrome. hideChrome tells App.vue to skip NavBar/FooterSection
    // for this route instead of double-stacking headers.
    meta: { title: 'DMAC — Log In', hideChrome: true },
  },
  {
    path: '/profile',
    name: 'profile',
    component: () => import('../views/ProfileView.vue'),
    meta: { title: 'DMAC — Your Profile', requiresAuth: true },
  },
  {
    path: '/admin',
    name: 'admin',
    component: () => import('../views/AdminView.vue'),
    meta: { title: 'DMAC — Admin Panel', requiresAuth: true, requiresAdmin: true },
  },
  {
    // Catch-all — also the trigger point for the Whoops. secret badge,
    // see views/NotFoundView.vue. Must stay last in this array; Vue
    // Router matches routes in order.
    path: '/:pathMatch(.*)*',
    name: 'not-found',
    component: () => import('../views/NotFoundView.vue'),
    meta: { title: 'DMAC — Page Not Found' },
  },
];

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) return savedPosition;
    return { top: 0 };
  },
});

// Guards any route with meta.requiresAuth (currently just /profile).
// On a hard refresh, MemberAuth's in-memory cache is empty even for a
// genuinely logged-in member — restoreSession() re-checks the stored
// token against the server before we decide to bounce anyone to /login.
router.beforeEach(async (to) => {
  if (to.meta?.requiresAdmin) {
    if (MemberAuth.hasRole('admin')) return true;
    const member = MemberAuth.current() || await MemberAuth.restoreSession();
    if (!member) return '/login';
    return member.site_role === 'admin' ? true : '/home';
  }
  if (!to.meta?.requiresAuth) return true;

  let member = MemberAuth.current();
  if (!member) member = await MemberAuth.restoreSession();
  if (!member) return '/login';

  if (to.meta?.requiresAdmin && member.site_role !== 'admin') return '/home';
  return true;
});

router.afterEach((to) => {
  if (to.meta?.title) document.title = to.meta.title;
});

export default router;
