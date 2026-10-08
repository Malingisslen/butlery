/// Rate limiting models for import operations.
///
/// These models support Firestore-persisted rate limiting with:
/// - Per-minute, per-hour, per-day limits
/// - Separate limits for basic imports vs LLM operations

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Result of a rate limit check.
sealed class RateLimitResult {
  const RateLimitResult();

  bool get isAllowed => this is RateLimitAllowed;
  bool get isDenied => this is RateLimitDenied;
}

/// Rate limit check passed - operation allowed.
class RateLimitAllowed extends RateLimitResult {
  /// Remaining operations in current window
  final int remainingInWindow;

  /// The limit type that was checked
  final LimitType limitType;

  const RateLimitAllowed({
    required this.remainingInWindow,
    required this.limitType,
  });
}

/// Rate limit exceeded - operation denied.
class RateLimitDenied extends RateLimitResult {
  /// User-friendly message explaining the limit
  final String message;

  /// When the user can retry
  final Duration retryAfter;

  /// The limit type that was exceeded
  final LimitType limitType;

  /// Suggested fallback action
  final FallbackAction suggestedAction;

  const RateLimitDenied({
    required this.message,
    required this.retryAfter,
    required this.limitType,
    required this.suggestedAction,
  });

  /// Get localized user-friendly message
  String get swedishMessage {
    final l = AppLocale.current;
    switch (limitType) {
      case LimitType.perMinute:
        return l.rateLimitTooFast(retryAfter.inSeconds);
      case LimitType.perHour:
        return l.rateLimitHourly(retryAfter.inMinutes);
      case LimitType.perDay:
        return l.rateLimitDaily;
      case LimitType.llmDaily:
        return l.rateLimitAiDaily;
      case LimitType.llmMonthly:
        return l.rateLimitAiMonthly;
      case LimitType.costDaily:
        return l.rateLimitBudgetDaily;
      case LimitType.costMonthly:
        return l.rateLimitBudgetMonthly;
    }
  }
}

/// Types of rate limits.
enum LimitType {
  /// Per-minute limit for any import
  perMinute,

  /// Per-hour limit for any import
  perHour,

  /// Per-day limit for any import
  perDay,

  /// Daily limit for LLM operations
  llmDaily,

  /// Monthly limit for LLM operations
  llmMonthly,

  /// Daily cost limit for LLM
  costDaily,

  /// Monthly cost limit for LLM
  costMonthly,
}

/// Actions to take when rate limited.
enum FallbackAction {
  /// Skip LLM enhancement, use rule-based only
  skipLlm,

  /// Fall back to user-assisted import
  useUserAssisted,

  /// Retry later
  retryLater,

  /// Use cached result if available
  useCache,
}

/// Types of LLM operations with different costs.
enum LlmOperationType {
  /// Text enhancement of partial extraction
  enhancement,

  /// Full extraction from HTML/text
  fullExtraction,

  /// Vision-based extraction from image
  vision,

  /// Selective ingredient line re-parsing (CRF→LLM routing)
  ingredientLines,
}

/// The Cloud Function refuses longer input (`structure-recipe.ts`).
const llmMaxInputChars = 50000;

/// Represents an import operation for rate limiting.
class ImportOperation {
  /// Whether this operation requires LLM
  final bool requiresLlm;

  /// Type of LLM operation (if requiresLlm is true)
  final LlmOperationType? llmType;

  /// Source type (website, youtube, etc.)
  final String sourceType;

  const ImportOperation({
    required this.requiresLlm,
    this.llmType,
    required this.sourceType,
  });

  /// Create a basic import operation (no LLM)
  factory ImportOperation.basic(String sourceType) {
    return ImportOperation(
      requiresLlm: false,
      sourceType: sourceType,
    );
  }

  /// Create an LLM-enhanced operation
  factory ImportOperation.withLlm(String sourceType, LlmOperationType llmType) {
    return ImportOperation(
      requiresLlm: true,
      llmType: llmType,
      sourceType: sourceType,
    );
  }
}

/// Current usage statistics for rate limiting.
class UsageLimits {
  // Per-minute counters
  final int importsThisMinute;
  final DateTime? minuteWindowStart;

  // Per-hour counters
  final int importsThisHour;
  final DateTime? hourWindowStart;

  // Per-day counters
  final int importsToday;
  final DateTime? dayWindowStart;

  // LLM operation counters
  final int llmEnhancementsToday;
  final int llmExtractionsToday;
  final int llmVisionToday;

  const UsageLimits({
    this.importsThisMinute = 0,
    this.minuteWindowStart,
    this.importsThisHour = 0,
    this.hourWindowStart,
    this.importsToday = 0,
    this.dayWindowStart,
    this.llmEnhancementsToday = 0,
    this.llmExtractionsToday = 0,
    this.llmVisionToday = 0,
  });

  /// Total LLM operations today
  int get totalLlmToday =>
      llmEnhancementsToday + llmExtractionsToday + llmVisionToday;

  /// Create empty usage
  factory UsageLimits.empty() => const UsageLimits();

  /// Create from Firestore data
  factory UsageLimits.fromFirestore(Map<String, dynamic> data) {
    return UsageLimits(
      importsThisMinute: data['importsThisMinute'] as int? ?? 0,
      minuteWindowStart: SerializationUtils.parseDateTimeValue(
        data['minuteWindowStart'],
      ),
      importsThisHour: data['importsThisHour'] as int? ?? 0,
      hourWindowStart: SerializationUtils.parseDateTimeValue(
        data['hourWindowStart'],
      ),
      importsToday: data['importsToday'] as int? ?? 0,
      dayWindowStart: SerializationUtils.parseDateTimeValue(
        data['dayWindowStart'],
      ),
      llmEnhancementsToday: data['llmEnhancementsToday'] as int? ?? 0,
      llmExtractionsToday: data['llmExtractionsToday'] as int? ?? 0,
      llmVisionToday: data['llmVisionToday'] as int? ?? 0,
    );
  }

  /// Convert to Firestore data. `firestore.rules` admits these keys on
  /// `rate_limits/imports`; the AI cost lives in [ServerLlmCost].
  Map<String, dynamic> toFirestore() {
    return {
      'importsThisMinute': importsThisMinute,
      'minuteWindowStart': minuteWindowStart,
      'importsThisHour': importsThisHour,
      'hourWindowStart': hourWindowStart,
      'importsToday': importsToday,
      'dayWindowStart': dayWindowStart,
      'llmEnhancementsToday': llmEnhancementsToday,
      'llmExtractionsToday': llmExtractionsToday,
      'llmVisionToday': llmVisionToday,
      'expireAt': Timestamp.fromDate(clock.now().add(const Duration(days: 90))),
    };
  }
}

/// The AI cost ledger at `users/{uid}/rate_limits/llm_cost` (BUT-2243).
///
/// Written only by the Cloud Functions (`llm_cost_ledger.ts`); the app reads
/// it to warn early. The server decides: it refuses the call itself when a
/// ceiling is reached. Days and months are UTC calendar windows, keyed exactly
/// as the server keys them.
class ServerLlmCost {
  static const docId = 'llm_cost';

  /// Spend in the current UTC day and month; 0 when the stored key is stale.
  final double costToday;
  final double costThisMonth;

  const ServerLlmCost({this.costToday = 0.0, this.costThisMonth = 0.0});

  factory ServerLlmCost.fromFirestore(
    Map<String, dynamic>? data,
    DateTime now,
  ) {
    if (data == null) return const ServerLlmCost();
    double read(String key) => (data[key] as num?)?.toDouble() ?? 0.0;
    return ServerLlmCost(
      costToday: data['dayKey'] == dayKeyOf(now) ? read('costToday') : 0.0,
      costThisMonth: data['monthKey'] == monthKeyOf(now)
          ? read('costThisMonth')
          : 0.0,
    );
  }

  /// `YYYY-MM-DD` in UTC, the server's `utcDayKey`.
  static String dayKeyOf(DateTime instant) =>
      instant.toUtc().toIso8601String().substring(0, 10);

  /// `YYYY-MM` in UTC, the server's `utcMonthKey`.
  static String monthKeyOf(DateTime instant) =>
      instant.toUtc().toIso8601String().substring(0, 7);

  /// The next UTC midnight after [now].
  static DateTime dayResetAfter(DateTime now) {
    final u = now.toUtc();
    return DateTime.utc(u.year, u.month, u.day + 1);
  }

  /// The first instant of the next UTC month after [now].
  static DateTime monthResetAfter(DateTime now) {
    final u = now.toUtc();
    return DateTime.utc(u.year, u.month + 1);
  }
}

/// Rate limit configuration constants.
class ImportRateLimits {
  ImportRateLimits._();

  // Basic import limits
  static const int importsPerMinute = 10;
  static const int importsPerHour = 30;
  static const int importsPerDay = 100;

  // LLM operation limits
  static const int llmEnhancementsPerDay = 20;
  static const int llmExtractionsPerDay = 10;
  static const int llmVisionPerDay = 10;

  // Cost limits (in USD). The server's `LLM_COST_CEILINGS` enforces them.
  static const double llmCostPerDay = 0.50;
  static const double llmCostPerMonth = 10.00;

  // Per-minute limits for LLM (burst protection)
  static const int llmOperationsPerMinute = 3;
  static const int llmOperationsPerHour = 10;
}
