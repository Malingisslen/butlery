# Cert Pin Rotation Runbook (BUT-427 / BUT-769)

This runbook covers populating and rotating the SHA-256 SPKI fingerprints in
`lib/services/security/cert_pin_config.dart`. Do **not** ship a release build
without running it — `CertPinConfig.assertReleaseModeSafety()` throws on boot
in release mode if any host has an empty pin list.

## Hosts under pinning

| Host | Surface |
| ---- | ------- |
| `butlery-app-dsn.algolia.net` | Algolia search API (DSN) |
| `butlery-app.algolia.net` | Algolia search API (writes) |
| `api.ocr.space` | Primary OCR HTTP fallback |
| `vision.googleapis.com` | Google Vision OCR fallback |
| `www.ica.se` | Recipe URL scrape |
| `www.koket.se` | Recipe URL scrape |
| `www.arla.se` | Recipe URL scrape |
| `www.recept.se` | Recipe URL scrape |

## Capture procedure

For each host, capture the leaf cert fingerprint and at least one backup
(intermediate or next-issuance) fingerprint. Backups are mandatory — pinning
a single cert breaks the app the moment the issuer rotates.

```sh
HOST=www.ica.se

# Leaf fingerprint
echo | openssl s_client -servername "$HOST" -connect "$HOST:443" 2>/dev/null \
  | openssl x509 -fingerprint -sha256 -noout

# Full chain — pull the second cert (intermediate / issuing CA) for the backup
echo | openssl s_client -servername "$HOST" -connect "$HOST:443" -showcerts 2>/dev/null \
  | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/'

# Save each PEM block to a file (cert1.pem = leaf, cert2.pem = intermediate),
# then:
openssl x509 -in cert2.pem -fingerprint -sha256 -noout
```

The output looks like:

```
sha256 Fingerprint=A1:B2:C3:...:F0
```

Drop the `sha256 Fingerprint=` prefix. Copy the colon-separated hex string
into the host's pin list in `cert_pin_config.dart`.

## Rotation cadence

- **Quarterly review.** Issuers rotate certs frequently; verify each pin list
  still contains at least one valid fingerprint by re-running the capture
  above and comparing.
- **Pre-release.** Boot a release build (`flutter build ... --release`) and
  load it on a real device. If the assertion throws on boot, populate the
  missing pins before tagging the release.
- **Cert renewal.** When a host's leaf rotates, the backup pin keeps the app
  working. Update the leaf entry promptly and add a new backup so the next
  rotation also has a valid fallback.

## Smoke test

After populating pins:

1. `flutter test test/unit/services/security/` — unit + lookup tests.
2. Build a release APK: `flutter build apk --release`.
3. Install on a device, open the app, exercise:
   - Recipe search (Algolia)
   - Recipe URL import (one of the recipe-scrape hosts)
   - OCR scan (api.ocr.space or vision.googleapis.com)
4. Inspect logs: a successful pin check produces no warnings. A pin mismatch
   surfaces as `PinnedHttpClient: pin mismatch for <host>` (telemetry event
   `ssl_pin_mismatch` with `host` + `error_kind`).

## Emergency: bypass the assertion

There is no runtime kill-switch by design. Disabling pinning at runtime would
be defeated by an attacker on hostile wifi flipping a remote-config flag. If
you absolutely must ship a hot-fix release without populated pins, treat that
as a controlled regression: temporarily remove the assertion call from
`main.dart`, ship, and immediately re-add it with the populated pins in the
follow-up release. Document the reason in the release commit message.
