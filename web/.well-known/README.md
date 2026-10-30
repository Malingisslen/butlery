# .well-known — deep-link verification files

- `assetlinks.json` — Android App Links verification (Google Digital
  Asset Links). Unblocks `autoVerify=true` in `AndroidManifest.xml`.
- `apple-app-site-association` — iOS universal links. **No file extension.**
- `security.txt` — RFC 9116 contact for security researchers. Its `Expires`
  date must stay in the future (at most a year out); the workflow below
  refuses to publish an expired one.

The `Deploy app link files` workflow publishes them on the `app` Hosting
site, which serves `butlery.se`, `butlery-prod.web.app` and
`butlery-prod.firebaseapp.com`; the last is
the domain the "glömt lösenord" link opens the app through (BUT-2170).
`firebase deploy` does not publish them, since `firebase.json` ignores
`**/.*`, and a full republish of the `app` site drops them: run the
workflow again after one.
