/* login-prompt.js — "please log in" signal with nowhere else to live.
   Singleton ref (same pattern as usePanels.js / member-auth.js's
   sessionMember) so router/index.js's beforeEach guard — which used
   to just redirect to /login — can instead redirect to /home AND ask
   NavBar.vue to pop its corner login open on the next tick, since
   there's no dedicated login page for it to land the visitor on
   anymore. */
import { ref } from 'vue';

export const loginPromptRequested = ref(false);

export function requestLoginPrompt() {
  loginPromptRequested.value = true;
}

export function clearLoginPrompt() {
  loginPromptRequested.value = false;
}
