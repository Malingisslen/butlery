import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/crypto_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/parsing/parsing_correction.dart';
import 'package:butlery/repositories/firebase/firebase_analytics_repository.dart';

/// Maximum chars for fromValue/toValue. Server enforces the same limit
/// (defence in depth). Long ingredient/instruction blocks are truncated
/// at this point on the client too.
const int kMaxCorrectionValueChars = 500;

/// Server-side accepted tier identifiers. The server callable rejects
/// anything outside this set. Dart uses CamelCase tier names — we map
/// here so the contract lives in one place.
const Map<String, String> _dartToServerTier = {
  'SchemaOrg': 'schema_org',
  'SiteConfig': 'site_config',
  'RuleBased': 'rule_based',
  'LLM': 'llm',
  'SelectiveEnhance': 'selective_enhance',
  'StructuredExtraction': 'structured_extraction',
  'WebScraper': 'web_scraper',
  'HtmlTextParse': 'html_text_parse',
  'UserAssisted': 'user_assisted',
};

/// Per-field correction payload sent to the `logParseCorrection` callable.
/// One [ParsingCorrection] expands to N of these (one per corrected field)
/// so the resulting Firestore docs are aggregatable at the field level.
class PerFieldCorrection {
  final String correctedField;
  final String fromValue;
  final String toValue;

  const PerFieldCorrection({
    required this.correctedField,
    required this.fromValue,
    required this.toValue,
  });
}

/// Type signature for the function that actually invokes the callable.
/// Injected in tests; defaults to a real `FirebaseFunctions.httpsCallable`
/// invocation in production.
typedef CallableInvoker =
    Future<void> Function(
      String name,
      Map<String, dynamic> body,
    );

/// Fan-out a [ParsingCorrection] aggregate into per-field upload jobs and
/// fire each one through the `logParseCorrection` Cloud Function.
///
/// Failures are silent: telemetry must never block a recipe save. Whitespace-
/// only and case-only diffs are dropped client-side too — the server applies
/// the same rule but skipping locally avoids the round trip.
class ParseCorrectionUploader {
  /// Lazy callable invoker. Production uses the real Firebase Functions
  /// instance; tests override [invoker] to capture invocations without
  /// initialising Firebase.
  final CallableInvoker _invoker;

  ParseCorrectionUploader({CallableInvoker? invoker})
    : _invoker = invoker ?? _defaultInvoker;

  static Future<void> _defaultInvoker(
    String name,
    Map<String, dynamic> body,
  ) async {
    await FirebaseFunctions.instance
        .httpsCallable(name)
        .call<Map<String, dynamic>>(body);
  }

  /// Hash an identifier the same way [FirebaseAnalyticsRepository] hashes
  /// PII for analytics (BUT-421). The salt prefix mirrors that pipeline so
  /// hashes are not re-identifiable across telemetry surfaces.
  ///
  /// Exposed for tests; not part of the public contract.
  static String hashId(String id, String salt) =>
      CryptoUtils.sha256Hash('$salt|$id');

  /// Truncate to [kMaxCorrectionValueChars] without surrogate-pair surprises.
  static String truncate(String input) {
    if (input.length <= kMaxCorrectionValueChars) return input;
    return input.substring(0, kMaxCorrectionValueChars);
  }

  /// Returns true if the diff is whitespace-only or case-only. Such diffs
  /// have no quality signal — skipping them keeps the dataset focused.
  static bool isWhitespaceOrCaseOnly(String from, String to) {
    String collapse(String s) =>
        s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    return collapse(from) == collapse(to);
  }

  /// Project [correction] into N per-field payloads. Public so call sites
  /// can inspect what's about to be uploaded (used in tests).
  List<PerFieldCorrection> expandFields(ParsingCorrection correction) {
    final out = <PerFieldCorrection>[];

    void addField(String field, String? from, String? to) {
      final fromVal = truncate(from.orEmpty());
      final toVal = truncate(to.orEmpty());
      if (isWhitespaceOrCaseOnly(fromVal, toVal)) return;
      out.add(
        PerFieldCorrection(
          correctedField: field,
          fromValue: fromVal,
          toValue: toVal,
        ),
      );
    }

    if (correction.titleCorrection != null) {
      addField(
        'title',
        correction.titleCorrection!.originalValue,
        correction.titleCorrection!.correctedValue,
      );
    }
    if (correction.portionsCorrection != null) {
      addField(
        'portions',
        correction.portionsCorrection!.originalValue,
        correction.portionsCorrection!.correctedValue,
      );
    }
    if (correction.timeCorrection != null) {
      addField(
        'time',
        correction.timeCorrection!.originalValue,
        correction.timeCorrection!.correctedValue,
      );
    }

    // Ingredient & instruction lists: roll up the per-line diffs into a
    // single field-level "before vs after" summary. We don't fan-out per
    // ingredient — that would explode the document count and the
    // aggregation cares about which fields fail, not which line.
    if (correction.ingredientCorrections.isNotEmpty) {
      final from = correction.ingredientCorrections
          .map((c) => c.originalLine.orEmpty())
          .where((s) => s.isNotEmpty)
          .join('\n');
      final to = correction.ingredientCorrections
          .map((c) => c.correctedLine.orEmpty())
          .where((s) => s.isNotEmpty)
          .join('\n');
      addField('ingredients', from, to);
    }

    if (correction.instructionCorrections.isNotEmpty) {
      final from = correction.instructionCorrections
          .map((c) => c.originalText.orEmpty())
          .where((s) => s.isNotEmpty)
          .join('\n');
      final to = correction.instructionCorrections
          .map((c) => c.correctedText.orEmpty())
          .where((s) => s.isNotEmpty)
          .join('\n');
      addField('instructions', from, to);
    }

    return out;
  }

  /// Fire-and-forget upload. Returns the count of payloads enqueued (after
  /// whitespace/case-only filtering). The actual callable invocations are
  /// `unawaited` — failures land in [AppLogger.debug], never propagate.
  ///
  /// [salt] should be the same per-install analytics salt used elsewhere
  /// (BUT-421). The uploader does NOT manage the salt — the caller resolves
  /// it from the analytics repository. This keeps the salt rotation policy
  /// single-sourced.
  int upload({
    required ParsingCorrection correction,
    required String salt,
    String? promptVersion,
  }) {
    try {
      final payloads = expandFields(correction);
      if (payloads.isEmpty) return 0;

      final serverTier = _dartToServerTier[correction.successfulTier];
      // Gracefully drop if the tier isn't on the allowlist — we'd just get
      // an invalid-argument back from the server.
      if (serverTier == null) {
        AppLogger.debug(
          '📊 ParseCorrectionUploader: unknown tier '
          '${correction.successfulTier}; skipping ${payloads.length} corrections',
        );
        return 0;
      }

      final userIdHash = hashId(correction.userId, salt);
      final recipeIdHash = hashId(correction.recipeId, salt);

      for (final payload in payloads) {
        final body = <String, dynamic>{
          'correctedField': payload.correctedField,
          'fromValue': payload.fromValue,
          'toValue': payload.toValue,
          'sourceTier': serverTier,
          if (serverTier == 'llm' && promptVersion != null)
            'promptVersion': promptVersion,
          if (correction.domain != null && correction.domain!.isNotEmpty)
            'domain': correction.domain,
          'userIdHash': userIdHash,
          'recipeIdHash': recipeIdHash,
        };

        unawaited(
          _invoker('logParseCorrection', body).catchError((Object e) {
            AppLogger.debug('ParseCorrectionUploader: upload failed: $e');
          }),
        );
      }

      AppLogger.debug(
        '📊 Enqueued ${payloads.length} parse-correction uploads '
        '(${correction.domain ?? 'no-domain'}, tier=$serverTier)',
      );
      return payloads.length;
    } catch (e) {
      // Telemetry must never block the user — swallow & log.
      AppLogger.debug('ParseCorrectionUploader: payload error: $e');
      return 0;
    }
  }

  /// Convenience wrapper that resolves the per-install PII salt from the
  /// same SharedPreferences key the analytics repository uses (BUT-421) and
  /// then dispatches the upload. Returns 0 if the salt isn't loaded yet —
  /// in that case the user has not exercised analytics enough to seed it,
  /// and we'd rather skip telemetry than emit unsalted hashes.
  Future<int> uploadWithSharedSalt({
    required ParsingCorrection correction,
    String? promptVersion,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salt = prefs
          .getString(FirebaseAnalyticsRepository.saltPrefsKey)
          .orEmpty();
      if (salt.isEmpty) {
        AppLogger.debug(
          '📊 No analytics salt available yet — skipping per-field upload',
        );
        return 0;
      }
      return upload(
        correction: correction,
        salt: salt,
        promptVersion: promptVersion,
      );
    } catch (e) {
      AppLogger.debug('ParseCorrectionUploader.uploadWithSharedSalt: $e');
      return 0;
    }
  }
}
