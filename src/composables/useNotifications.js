import Notifications from '../lib/notifications.js';

/**
 * Thin wrapper so components don't import the notifications engine
 * directly — mirrors useSfx.js's relationship to lib/sfx.js.
 */
export function useNotifications() {
  return Notifications;
}
