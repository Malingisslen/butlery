# Deep-Link Hosting — butlery.app

**Linear:** BUT-575
**Files:** `web/.well-known/assetlinks.json`, `web/.well-known/apple-app-site-association`
**Unblocks:** BUT-434 (receive_intent → app_links migration), Android `autoVerify=true` (already set in `AndroidManifest.xml`), iOS universal links (entitlement already set in `Runner.entitlements` / `Release.entitlements`).

## What these files do

- **`assetlinks.json`** (Google Digital Asset Links) tells Android that
  `se.butlery.app`, signed with a specific certificate, is allowed to
  intercept `https://butlery.app/*` links without showing the "open with"
  disambiguation dialog. Required by `android:autoVerify="true"`.
- **`apple-app-site-association`** (AASA) tells iOS that the app bundle
  `TEAMID.se.butlery.app` handles the `/invite/*`, `/recipe/*`,
  `/menu/*`, `/shopping/*`, `/profile/*` paths on `butlery.app`. Required
  by the `applinks:butlery.app` associated-domain entitlement.

## Placeholders that MUST be filled before hosting

Both files are committed with placeholder values so the structure/paths
are reviewable. Before deploying:

### 1. Android SHA-256 production cert fingerprint

Run on the machine that holds the production keystore (`android/app/key.properties` points to it):

```bash
keytool -list -v \
  -keystore /path/to/butlery-release.keystore \
  -alias <keyAlias>
```

Copy the line labelled `SHA256:` — it looks like `AB:CD:EF:...` with
colons. Paste it into `assetlinks.json` replacing
`REPLACE_ME_SHA256_PRODUCTION_KEYSTORE`. The colons MUST be kept.

If the app is also distributed through Play App Signing, add a SECOND
entry to `sha256_cert_fingerprints` using the app-signing cert shown in
Play Console → Release → Setup → App integrity → App signing.

### 2. iOS Team ID

The 10-character Team ID is shown in Apple Developer → Membership, or in
Xcode → Runner target → Signing & Capabilities → Team dropdown
(displayed after the team name). Paste it into
`apple-app-site-association` replacing `REPLACE_ME_TEAMID`. Example
shape: `A1B2C3D4E5.se.butlery.app`.

The Team ID is NOT currently set in `ios/Runner.xcodeproj/project.pbxproj`
— it will need to be set in Xcode when signing configs are wired up
(likely part of the BUT-485 follow-up). The AASA file's `appID` must
match what Xcode signs with.

## Hosting requirements

Both files must be served from `butlery.app` — the apex domain, not a
subdomain, unless the app's associated-domains entitlement uses
`applinks:www.butlery.app` or similar (currently it does not).

| Requirement | `assetlinks.json` | `apple-app-site-association` |
|---|---|---|
| URL path | `https://butlery.app/.well-known/assetlinks.json` | `https://butlery.app/.well-known/apple-app-site-association` |
| HTTPS | **required** (no HTTP fallback) | **required** |
| Content-Type | `application/json` | `application/json` (NOT `application/pkcs7-mime` — that's the legacy signed form, iOS no longer requires it) |
| HTTP status | `200 OK` | `200 OK` |
| Redirects | **NOT allowed** — must serve directly | **NOT allowed** |
| File extension | `.json` | **no extension** (literally `apple-app-site-association`) |
| Cache | short TTL acceptable (e.g., 1h) — Apple caches server-side | same |

Where to host depends on how `butlery.app` is served:

- **Firebase Hosting:** drop both files in the `public/.well-known/`
  directory of the hosting site and ensure `firebase.json` does NOT
  rewrite `/.well-known/**` to `index.html`. Firebase serves unknown
  extensions as `application/octet-stream` by default — add an explicit
  `headers` rule to set `Content-Type: application/json` on the AASA
  file (it has no extension, so auto-detection fails).
- **Static site host (Netlify/Vercel/Cloudflare Pages):** put the files
  in `/.well-known/` at the site root and add a `_headers` (Netlify) or
  equivalent rule:
  ```
  /.well-known/apple-app-site-association
    Content-Type: application/json
  ```
- **Own server (nginx):**
  ```nginx
  location = /.well-known/apple-app-site-association {
    default_type application/json;
    add_header Cache-Control "public, max-age=3600";
  }
  ```

The website for `butlery.app` is NOT hosted from this repository's `web/`
directory (that's the Flutter web build target). Copy the two files from
`web/.well-known/` into whatever deployment pipeline serves the marketing
site. Keep this repo's copy as the canonical source — when deep-link
paths change, update here first and re-deploy.

## Verification

Once hosted, run:

```bash
# assetlinks — expect 200 + application/json
curl -I https://butlery.app/.well-known/assetlinks.json

# AASA — expect 200 + application/json
curl -I https://butlery.app/.well-known/apple-app-site-association

# content sanity check
curl -s https://butlery.app/.well-known/assetlinks.json | python -m json.tool
curl -s https://butlery.app/.well-known/apple-app-site-association | python -m json.tool
```

### Google's Digital Asset Links validator

https://developers.google.com/digital-asset-links/tools/generator — paste:

- Hosting site: `https://butlery.app`
- App package: `se.butlery.app`
- App cert fingerprint: the SHA-256 you filled in

It should render a green check.

### Apple's AASA CDN / validator

Apple fronts AASA through its own CDN:

```
https://app-site-association.cdn-apple.com/a/v1/butlery.app
```

This URL returns what Apple's CDN has cached. First fetch can take up to
24h after the file is live. If it does not match the committed file,
Apple's cache is stale — bump the file (touch the deploy) and wait.

Apple also exposes a Branch-style deep-link debugger on iOS 15+: with the
device in Developer Mode, install a build signed with the updated
entitlement and open `https://butlery.app/recipe/xyz` from Notes. It
should open the app directly without a Safari bounce.

### Android autoVerify check

On a device with the release build installed:

```bash
adb shell pm get-app-links se.butlery.app
```

Expected output contains `verified` for `butlery.app`. If it shows
`legacy_failure`, the asset links file is unreachable, wrong
fingerprint, or wrong package name.

## What is still gated on external work

- Hosting `butlery.app` with the two files reachable over HTTPS.
- Filling in the SHA-256 fingerprint (needs production keystore access).
- Filling in the iOS Team ID (needs Apple Developer membership active
  for the signing identity).

None of those are blocking for the sprint's code-side work — the app
will fall back to custom-scheme / browser-bounce behaviour until the
asset files are live.
