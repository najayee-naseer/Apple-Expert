import { Capacitor } from '@capacitor/core'

/**
 * The customer app's way into the admin panel.
 *
 * Under Capacitor, a page load of any path whose last segment has no "." gets
 * index.html, the customer home, so a plain link to /admin/login would never reach
 * admin. Moving between the (shop) and (admin) root layouts is always a page load,
 * so the APK has to ask for the exported file by name. `next dev` has no such file.
 *
 * Going here grants nothing: AdminGuard and the database decide what happens after
 * sign-in. The destination is fixed on purpose, so there is no redirect parameter
 * for a crafted link to abuse.
 */
const WEB_PATH = '/admin/login'
const NATIVE_PATH = '/admin/login.html'

export function adminLoginPath(isNative: boolean = Capacitor.isNativePlatform()): string {
  return isNative ? NATIVE_PATH : WEB_PATH
}

/**
 * Leaves the customer app for the admin sign-in page. For a click handler, not an
 * href: the path depends on the platform, which prerendered HTML cannot know.
 */
export function openAdminLogin(): void {
  window.location.assign(adminLoginPath())
}
