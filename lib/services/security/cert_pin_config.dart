/// Per-host SHA-256 SPKI fingerprint configuration for outbound HTTPS pinning.
///
/// BUT-427: third-party HTTPS calls (Algolia, OCR fallbacks, web scraping for
/// recipe import) are pinned at the HTTP-client layer. The pins themselves are
/// rotated by an ops task — this file is the wiring contract.
///
/// **Pin lifecycle:**
/// - Pins are SHA-256 fingerprints of the leaf or intermediate certificate.
/// - Always include AT LEAST one backup pin (pinning a single cert breaks the
///   app the moment the issuer rotates). The first entry is the active pin;
///   the second is the next-issuance backup.
/// - When `hostPins[host]` is empty, [PinnedHttpClientFactory] falls back to
///   the platform trust store — the wrapper is still installed (so a future
///   pin update activates without redeploy), but no pinning happens yet.
///
/// **NOT a runtime kill-switch.** Disabling pinning at runtime would defeat
/// the point of pinning (an attacker on hostile wifi could simply flip the
/// flag from a malicious config response). Pin updates are a code change.
library;

import 'package:flutter/foundation.dart';

/// Map of host (lowercase, no scheme/port) → list of allowed SHA-256
/// fingerprints in colon-separated uppercase hex form (the openssl default
/// for `openssl x509 -fingerprint -sha256`).
///
/// Example fingerprint format:
/// `'59:58:57:5A:5B:5C:5D:59:58:57:5A:5B:5C:5D:59:58:57:5A:5B:5C:5D:59:58:57:5A:5B:5C:5D'`
class CertPinConfig {
  const CertPinConfig._();

  /// Per-host pin lists. Empty list = wired but inactive (logs warning, falls
  /// through to platform trust store). Real fingerprints land via the ops
  /// rotation task — keep the wiring live so the rollout is a values change,
  /// not a code change.
  static const Map<String, List<String>> hostPins = <String, List<String>>{
    // Algolia search API host. The Algolia SDK builds its own internal URLs
    // for `*.algolianet.com` and `*.algolia.net` — both should be pinned in
    // the same op when the real fingerprints land.
    'butlery-app-dsn.algolia.net': <String>[
      // TODO(BUT-427-ops, by 2026-Q3): leaf cert SHA-256 fingerprint
      // TODO(BUT-427-ops, by 2026-Q3): backup cert SHA-256 fingerprint
    ],
    'butlery-app.algolia.net': <String>[
      // TODO(BUT-427-ops, by 2026-Q3): leaf + backup
    ],

    // OCR.space — primary OCR HTTP fallback.
    'api.ocr.space': <String>[
      // TODO(BUT-427-ops, by 2026-Q3): leaf + backup
    ],

    // Google Vision API — secondary OCR HTTP fallback.
    'vision.googleapis.com': <String>[
      // TODO(BUT-427-ops, by 2026-Q3): leaf + backup
    ],

    // Recipe URL scraping — pin the public sites we explicitly support.
    // Sites not listed fall through to platform trust (still safer than no
    // pinning because most attacks target high-value endpoints).
    'www.ica.se': <String>[
      // TODO(BUT-427-ops, by 2026-Q3): leaf + backup
    ],
    'www.koket.se': <String>[
      // TODO(BUT-427-ops, by 2026-Q3): leaf + backup
    ],
    'www.arla.se': <String>[
      // TODO(BUT-427-ops, by 2026-Q3): leaf + backup
    ],
    'www.recept.se': <String>[
      // TODO(BUT-427-ops, by 2026-Q3): leaf + backup
    ],
  };

  /// Returns the pin list for the given URL's host, or an empty list when
  /// no pin is configured. Hostname lookup is case-insensitive (DNS is).
  ///
  /// Returns empty list (NOT null) when the host has no entry — callers
  /// treat empty as "no pinning required, fall through to platform trust"
  /// to keep the call-site code uniform.
  static List<String> pinsForUrl(String url) {
    final host = _hostOf(url);
    if (host == null) return const <String>[];
    return pinsForHost(host);
  }

  /// Returns the pin list for the given host (lowercased), or an empty list
  /// when no pin is configured.
  static List<String> pinsForHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) return const <String>[];
    return hostPins[normalized] ?? const <String>[];
  }

  /// Returns true when the host has at least one active pin configured.
  static bool isPinnedHost(String host) => pinsForHost(host).isNotEmpty;

  /// BUT-769: throw on boot in release mode if any configured host has an
  /// empty pin list. Cert pinning is a defense-in-depth control; a release
  /// build with empty pins is silently insecure (the wrapper falls through
  /// to platform trust). Failing loud here forces the ops fingerprint-rotation
  /// procedure (`docs/operations/cert-pin-rotation.md`) to run before each
  /// release.
  ///
  /// Intentionally a runtime `throw` rather than a Dart `assert` — `assert`
  /// statements are stripped in release builds, which would defeat the whole
  /// point of a release-mode safety check.
  ///
  /// Debug + profile builds skip the check (developers regularly run with
  /// empty pin maps; the check would block daily work for no security gain).
  ///
  /// Test injection: pass a pre-built pin map via [pinsForTest] to validate
  /// the method without touching the global config.
  static void assertReleaseModeSafety({
    Map<String, List<String>>? pinsForTest,
    bool? releaseModeOverrideForTest,
  }) {
    final isRelease = releaseModeOverrideForTest ?? kReleaseMode;
    if (!isRelease) return;
    final pins = pinsForTest ?? hostPins;
    final empties =
        pins.entries.where((e) => e.value.isEmpty).map((e) => e.key).toList();
    if (empties.isEmpty) return;
    throw StateError(
      'Cert pin lists empty in release build for ${empties.length} host(s): '
      '${empties.join(', ')}. '
      'Run the rotation procedure in docs/operations/cert-pin-rotation.md '
      'before shipping. Pinning is non-functional until pins are populated.',
    );
  }

  static String? _hostOf(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.isEmpty) return null;
      return uri.host.toLowerCase();
    } catch (_) {
      return null;
    }
  }
}
