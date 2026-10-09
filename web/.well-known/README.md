# .well-known — deep-link verification files

These files must be served from `https://butlery.app/.well-known/`.

- `assetlinks.json` — Android App Links verification (Google Digital
  Asset Links). Unblocks `autoVerify=true` in `AndroidManifest.xml`.
- `apple-app-site-association` — iOS universal links. Unblocks the
  `applinks:butlery.app` entitlement. **No file extension.**

The `Deploy app link files` workflow publishes them on
`butlery-app-1.web.app` and `butlery-app-1.firebaseapp.com`; the second is
the domain the "glömt lösenord" link opens the app through (BUT-2170).
`firebase deploy` does not publish them, since `firebase.json` ignores
`**/.*`, and a full republish of the `app` site drops them: run the
workflow again after one.

Note: this repo's `web/` directory is Flutter's web build target. The
marketing site at `butlery.app` is hosted separately; these files are
kept here as the canonical source — copy them into whatever deployment
pipeline serves the marketing site when deep-link paths change.
