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

  /// Per-host pin lists, keyed by lowercase host. A host's presence here means
  /// "enforce pinning against this list"; absence means "fall through to the
  /// platform trust store". An empty list for a present host would trip
  /// [assertReleaseModeSafety] in release builds (a listed-but-unpinned host is
  /// a silent security hole), so only add a host once you have real pins.
  ///
  /// **Intentionally empty (BUT-814).** The original BUT-427 design listed 8
  /// third-party hosts (Algolia, OCR.space, Google Vision, and the ICA / Köket /
  /// Arla / Recept scrape targets) as wired-but-inactive, to be pinned later by
  /// an ops rotation task. That plan was wrong: pinning the leaf/intermediate
  /// certificates of hosts we do NOT operate creates rotation time-bombs —
  /// when any of them rotates its cert on its own schedule (Let's Encrypt =
  /// 90 days), the app would refuse the connection and break recipe import /
  /// OCR with no server-side recovery, only a forced app release. The standard
  /// guidance (OWASP) is to pin only endpoints you control. Our controlled
  /// backends (Firebase / Firestore) ride the SDK, not this HTTP layer, so
  /// there is currently nothing here that is both ours and routed through
  /// [PinnedHttpClient] / [PinningDioInterceptor]. Both wrappers stay installed
  /// (empty map → graceful platform-trust fall-through), so adding a genuinely
  /// controlled host later is a one-entry change, not a re-wire.
  ///
  /// To add a controlled host: add `'host': ['<leaf SHA-256>', '<backup>']`
  /// (colon-separated uppercase hex, openssl default) per
  /// `docs/operations/cert-pin-rotation.md`. Never add an un-controlled
  /// third-party host.
  static const Map<String, List<String>> hostPins = <String, List<String>>{};

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
