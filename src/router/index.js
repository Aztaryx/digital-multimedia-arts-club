import { createRouter, createWebHistory } from 'vue-router';

const routes = [
  {
    path: '/',
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
    path: '/info/newsletters',
    name: 'info-newsletters',
    component: () => import('../views/info/NewslettersView.vue'),
    meta: { title: 'DMAC — Newsletters' },
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
];

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) return savedPosition;
    return { top: 0 };
  },
});

router.afterEach((to) => {
  if (to.meta?.title) document.title = to.meta.title;
});

export default router;
