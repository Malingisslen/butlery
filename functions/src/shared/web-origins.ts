/**
 * Browser origins allowed to call the callables that set `cors`.
 *
 * One static list for both projects, because the same code deploys to production and
 * staging. Listing another project's host lets that page reach the endpoint and nothing
 * more: the ID token and the App Check token are minted per project. butlery.app stays
 * listed for when the domain is connected; the web.app hosts are where the web app runs
 * until then (BUT-2432).
 */
export const WEB_CALLABLE_ORIGINS: string[] = [
  "https://butlery.app",
  "https://www.butlery.app",
  "https://butlery-prod.web.app",
  "https://butlery-prod.firebaseapp.com",
  "https://butlery-prod-admin.web.app",
  "https://butlery-app-staging.web.app",
  "https://butlery-app-staging.firebaseapp.com",
];
