/// Helpers extracted from [FirebaseAnalyticsRepository] to keep that file
/// under the 500-line cap. Pure functions + the salt manager. No public API
/// surface — consumed only by the parent repository.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';

/// Manages the per-install PII hashing salt: lazy SharedPreferences load,
/// in-flight dedupe, and an ephemeral fallback when SharedPreferences is
/// unavailable (test runners without the binding bound).
class AnalyticsSaltManager {
  /// SharedPreferences key for the per-install salt. Public so other
  /// PII-hashing surfaces can hash IDs against the same salt.
  static const String saltPrefsKey = 'analytics_pii_salt_v1';

  final String? _override;
  String? _cached;
  Future<String>? _loading;

  AnalyticsSaltManager({String? override}) : _override = override;

  /// Resolve the salt — override > cached > loaded > newly-generated.
  /// Concurrent callers share a single in-flight load.
  Future<String> get() {
    if (_override != null) return Future.value(_override);
    if (_cached != null) return Future.value(_cached!);
    return _loading ??= _loadOrCreate();
  }

  Future<String> _loadOrCreate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var salt = prefs.getString(saltPrefsKey);
      if (salt == null || salt.isEmpty) {
        salt = generateSalt();
        await prefs.setString(saltPrefsKey, salt);
      }
      _cached = salt;
      return salt;
    } catch (e) {
      AppLogger.warning(
        'Analytics salt: SharedPreferences unavailable ($e); '
        'using ephemeral in-memory salt',
      );
      _cached = generateSalt();
      return _cached!;
    }
  }

  /// Cryptographically-random 32-byte salt, base64url-encoded.
  static String generateSalt() {
    final rnd = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return base64Url.encode(bytes);
  }
}

/// Pure helpers — bucket boundaries duplicated here from the repo on purpose
/// so the helper file has zero dependencies on the parent class.
class AnalyticsBuckets {
  AnalyticsBuckets._();

  /// `search_query.length` → coarse bucket (replaces the raw query in events).
  static String lengthBucket(int len) {
    if (len <= 3) return '1-3';
    if (len <= 10) return '4-10';
    if (len <= 20) return '11-20';
    return '21+';
  }

  /// Free-text error string → coarse category. Swedish substrings are
  /// historical — most extraction errors bubble up localized.
  static String categorizeError(String error) {
    final errorLower = error.toLowerCase();
    if (errorLower.contains('timeout')) return 'timeout';
    if (errorLower.contains('ingen text')) return 'no_content_found';
    if (errorLower.contains('kunde inte ladda')) return 'page_load_error';
    if (errorLower.contains('okänd plattform')) return 'unknown_platform';
    if (errorLower.contains('tekniskt fel')) return 'technical_error';
    if (errorLower.contains('cors') || errorLower.contains('webben')) {
      return 'web_limitation';
    }
    return 'other';
  }

  /// Recipe-count → user-segmentation bucket label.
  static String recipeCountRange(int count) {
    if (count == 0) return '0';
    if (count <= 5) return '1-5';
    if (count <= 10) return '6-10';
    if (count <= 20) return '11-20';
    if (count <= 50) return '21-50';
    return '50+';
  }
}
