/**
 * Browser origins allowed to call the callables that set `cors`.
 *
 * One static list for both projects, because the same code deploys to production and
 * staging. Listing another project's host lets that page reach the endpoint and nothing
 * more: the ID token and the App Check token are minted per project.
 */
export const WEB_CALLABLE_ORIGINS: string[] = [
  "https://butlery.se",
  "https://www.butlery.se",
  "https://butlery-prod.web.app",
  "https://butlery-prod.firebaseapp.com",
  "https://butlery-prod-admin.web.app",
  "https://butlery-app-staging.web.app",
  "https://butlery-app-staging.firebaseapp.com",
];
