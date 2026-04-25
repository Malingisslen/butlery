import 'package:butlery/services/analytics/trackers/base_tracker.dart';

/// Tracks per-tier parse outcomes for the 3-tier import pipeline (BUT-552).
///
/// Mirrors the cloud-function `logParseEvent` per-tier semantics into Firebase
/// Analytics so we can answer cost-sensitive funnel questions like "what % of
/// imports required LLM fallback?". Cloud-function logging continues unchanged
/// — these events are additive.
class ParseEventsTracker extends BaseTracker {
  ParseEventsTracker({required super.repository});

  static const String eventTierSucceeded = 'import_tier_succeeded';
  static const String eventTierFailed = 'import_tier_failed';

  /// Internal tier identifiers used in event params.
  ///
  /// Production has 4 tiers but the task spec calls out three buckets
  /// (`site_config`, `regex`, `llm`). `schema_org` is added for the JSON-LD
  /// path so the funnel shows where imports actually land.
  static const String tierSchemaOrg = 'schema_org';
  static const String tierSiteConfig = 'site_config';
  static const String tierRegex = 'regex';
  static const String tierLlm = 'llm';

  /// Emit a tier-success event.
  ///
  /// [sessionId] is optional. TODO(BUT-552 sibling): wire a real
  /// import-session-id once the session-correlation ticket lands so this
  /// can join with `import_started` / `import_success` in BigQuery.
  Future<void> logTierSucceeded({
    required String tier,
    required int durationMs,
    required String platformBucket,
    String? sessionId,
  }) async {
    await logEvent(
      name: eventTierSucceeded,
      parameters: _buildParams(
        tier: tier,
        durationMs: durationMs,
        platformBucket: platformBucket,
        sessionId: sessionId,
      ),
    );
  }

  /// Emit a tier-failure event (tier produced no usable result).
  Future<void> logTierFailed({
    required String tier,
    required int durationMs,
    required String platformBucket,
    String? sessionId,
  }) async {
    await logEvent(
      name: eventTierFailed,
      parameters: _buildParams(
        tier: tier,
        durationMs: durationMs,
        platformBucket: platformBucket,
        sessionId: sessionId,
      ),
    );
  }

  Map<String, Object> _buildParams({
    required String tier,
    required int durationMs,
    required String platformBucket,
    String? sessionId,
  }) {
    return {
      'tier': tier,
      'duration_ms': durationMs < 0 ? 0 : durationMs,
      'platform_bucket': platformBucket,
      if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
    };
  }
}
