# .well-known — deep-link verification files

These files must be served from `https://butlery.app/.well-known/`.
Full hosting instructions, placeholder fill-in steps, and verification
commands live in [`docs/ops/deep-link-setup.md`](../../docs/ops/deep-link-setup.md).

- `assetlinks.json` — Android App Links verification (Google Digital
  Asset Links). Unblocks `autoVerify=true` in `AndroidManifest.xml`.
- `apple-app-site-association` — iOS universal links. Unblocks the
  `applinks:butlery.app` entitlement. **No file extension.**

Both files currently contain placeholder values
(`REPLACE_ME_SHA256_PRODUCTION_KEYSTORE`, `REPLACE_ME_TEAMID`) — fill
them in before deploying to the marketing site.

Note: this repo's `web/` directory is Flutter's web build target. The
marketing site at `butlery.app` is hosted separately; these files are
kept here as the canonical source — copy them into whatever deployment
pipeline serves the marketing site when deep-link paths change.
