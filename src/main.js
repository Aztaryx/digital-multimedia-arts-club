import { createApp } from 'vue';
import App from './App.vue';
import router from './router/index.js';
import { installDirectives } from './directives/index.js';

import './assets/css/global.css';
import './assets/css/animations.css';

const app = createApp(App);
installDirectives(app);
app.use(router);
app.mount('#app');
