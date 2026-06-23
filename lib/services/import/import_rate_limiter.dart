import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firestore-persisted rate limiter for import operations.
///
/// Tracks usage across:
/// - Basic imports (per-minute, per-hour, per-day)
/// - LLM operations (enhancement, extraction, vision)
/// - LLM costs (daily and monthly budgets)
///
/// Usage is persisted to Firestore under /users/{userId}/rateLimits/imports
class ImportRateLimiter extends BaseService {
  @override
  String get serviceName => 'ImportRateLimiter';

  final FirestoreRepository _firestoreRepo;
  final auth.AuthRepository _authRepo;

  /// In-memory cache of current usage (refreshed on each check)
  UsageLimits? _cachedUsage;
  DateTime? _cacheTimestamp;

  /// Cache duration before refreshing from Firestore
  static const _cacheDuration = Duration(seconds: 30);

  ImportRateLimiter({
    required FirestoreRepository firestoreRepository,
    required auth.AuthRepository authRepository,
  }) : _firestoreRepo = firestoreRepository,
       _authRepo = authRepository;

  /// Check if an import operation is allowed.
  ///
  /// Returns [RateLimitAllowed] if the operation can proceed,
  /// or [RateLimitDenied] with details about the limit.
  Future<RateLimitResult> checkLimit(ImportOperation operation) async {
    final userId = _authRepo.currentUserId;
    if (userId == null) {
      // Not authenticated - allow but don't track
      return const RateLimitAllowed(
        remainingInWindow: 999,
        limitType: LimitType.perMinute,
      );
    }

    try {
      final usage = await _getCurrentUsage(userId);
      final now = clock.now();

      // Check basic import limits first
      final basicResult = _checkBasicLimits(usage, now);
      if (basicResult != null) {
        return basicResult;
      }

      // Check LLM limits if operation requires LLM
      if (operation.requiresLlm) {
        final llmResult = _checkLlmLimits(usage, operation, now);
        if (llmResult != null) {
          return llmResult;
        }
      }

      // Calculate remaining in most restrictive window
      final remaining = _calculateRemaining(usage, operation, now);

      return RateLimitAllowed(
        remainingInWindow: remaining,
        limitType: LimitType.perMinute,
      );
    } catch (e) {
      AppLogger.warning('ImportRateLimiter: Error checking limit: $e');
      // Fail closed — deny on Firestore errors to prevent abuse
      return const RateLimitDenied(
        message: 'Rate limit check unavailable. Please try again shortly.',
        retryAfter: Duration(seconds: 30),
        limitType: LimitType.perMinute,
        suggestedAction: FallbackAction.retryLater,
      );
    }
  }

  /// Record a completed import operation.
  ///
  /// Call this after a successful import to update usage counters.
  Future<void> recordUsage(
    ImportOperation operation, {
    double? llmCost,
  }) async {
    final userId = _authRepo.currentUserId;
    if (userId == null) return;

    try {
      final now = clock.now();
      final docRef = _getRateLimitDoc(userId);

      // Use a transaction to safely update counters
      await _firestoreRepo.firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        final currentData = doc.exists ? doc.data()! : <String, dynamic>{};
        final usage = UsageLimits.fromFirestore(currentData);

        // Calculate updated usage with window resets
        final updated = _updateUsage(usage, operation, now, llmCost);

        transaction.set(docRef, updated.toFirestore(), SetOptions(merge: true));
      });

      // Invalidate cache
      _cachedUsage = null;
      _cacheTimestamp = null;

      AppLogger.debug(
        'ImportRateLimiter: Recorded ${operation.sourceType} import'
        '${operation.requiresLlm ? ' (LLM: ${operation.llmType?.name})' : ''}',
      );
    } catch (e) {
      AppLogger.warning('ImportRateLimiter: Error recording usage: $e');
    }
  }

  /// Get current usage statistics (for UI display).
  Future<UsageLimits> getUsageStats() async {
    final userId = _authRepo.currentUserId;
    if (userId == null) return UsageLimits.empty();

    return _getCurrentUsage(userId);
  }

  /// Check if LLM is available (not over quota).
  Future<bool> isLlmAvailable() async {
    final result = await checkLimit(
      ImportOperation.withLlm('check', LlmOperationType.enhancement),
    );
    return result.isAllowed;
  }

  /// Get the rate limit document reference for a user.
  DocumentReference<Map<String, dynamic>> _getRateLimitDoc(String userId) {
    return _firestoreRepo.firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.userRateLimits)
        .doc('imports');
  }

  /// Get current usage, using cache if valid.
  Future<UsageLimits> _getCurrentUsage(String userId) async {
    // Check cache
    if (_cachedUsage != null &&
        _cacheTimestamp != null &&
        clock.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedUsage!;
    }

    // Fetch from Firestore
    final doc = await _getRateLimitDoc(userId).get();
    if (!doc.exists) {
      _cachedUsage = UsageLimits.empty();
    } else {
      _cachedUsage = UsageLimits.fromFirestore(doc.data()!);
    }
    _cacheTimestamp = clock.now();

    return _cachedUsage!;
  }

  /// Check basic import rate limits.
  RateLimitDenied? _checkBasicLimits(UsageLimits usage, DateTime now) {
    // Check per-minute limit
    if (_isInWindow(usage.minuteWindowStart, now, const Duration(minutes: 1))) {
      if (usage.importsThisMinute >= ImportRateLimits.importsPerMinute) {
        final retryAfter = _timeUntilWindowReset(
          usage.minuteWindowStart!,
          const Duration(minutes: 1),
          now,
        );
        AppLogger.analytics('rate_limit_denied', {
          'limitType': 'perMinute',
          'currentCount': usage.importsThisMinute,
          'limit': ImportRateLimits.importsPerMinute,
        });
        return RateLimitDenied(
          message: 'Too many imports per minute',
          retryAfter: retryAfter,
          limitType: LimitType.perMinute,
          suggestedAction: FallbackAction.retryLater,
        );
      }
    }

    // Check per-hour limit
    if (_isInWindow(usage.hourWindowStart, now, const Duration(hours: 1))) {
      if (usage.importsThisHour >= ImportRateLimits.importsPerHour) {
        final retryAfter = _timeUntilWindowReset(
          usage.hourWindowStart!,
          const Duration(hours: 1),
          now,
        );
        AppLogger.analytics('rate_limit_denied', {
          'limitType': 'perHour',
          'currentCount': usage.importsThisHour,
          'limit': ImportRateLimits.importsPerHour,
        });
        return RateLimitDenied(
          message: 'Too many imports per hour',
          retryAfter: retryAfter,
          limitType: LimitType.perHour,
          suggestedAction: FallbackAction.retryLater,
        );
      }
    }

    // Check per-day limit
    if (_isInWindow(usage.dayWindowStart, now, const Duration(days: 1))) {
      if (usage.importsToday >= ImportRateLimits.importsPerDay) {
        final retryAfter = _timeUntilWindowReset(
          usage.dayWindowStart!,
          const Duration(days: 1),
          now,
        );
        AppLogger.analytics('rate_limit_denied', {
          'limitType': 'perDay',
          'currentCount': usage.importsToday,
          'limit': ImportRateLimits.importsPerDay,
        });
        return RateLimitDenied(
          message: 'Daily import limit reached',
          retryAfter: retryAfter,
          limitType: LimitType.perDay,
          suggestedAction: FallbackAction.retryLater,
        );
      }
    }

    return null; // All basic limits OK
  }

  /// Check LLM-specific rate limits.
  RateLimitDenied? _checkLlmLimits(
    UsageLimits usage,
    ImportOperation operation,
    DateTime now,
  ) {
    // Check daily LLM operation limits by type
    if (_isInWindow(usage.dayWindowStart, now, const Duration(days: 1))) {
      switch (operation.llmType) {
        case LlmOperationType.enhancement:
        case LlmOperationType.ingredientLines:
          if (usage.llmEnhancementsToday >=
              ImportRateLimits.llmEnhancementsPerDay) {
            return _createLlmDenied(usage.dayWindowStart!, now);
          }
          break;
        case LlmOperationType.fullExtraction:
          if (usage.llmExtractionsToday >=
              ImportRateLimits.llmExtractionsPerDay) {
            return _createLlmDenied(usage.dayWindowStart!, now);
          }
          break;
        case LlmOperationType.vision:
          if (usage.llmVisionToday >= ImportRateLimits.llmVisionPerDay) {
            return _createLlmDenied(usage.dayWindowStart!, now);
          }
          break;
        case null:
          break;
      }

      // Check daily cost limit
      final estimatedCost = operation.estimatedCost ?? 0.0;
      if (usage.llmCostToday + estimatedCost > ImportRateLimits.llmCostPerDay) {
        AppLogger.analytics('rate_limit_denied', {
          'limitType': 'costDaily',
          'currentCost': usage.llmCostToday,
          'limit': ImportRateLimits.llmCostPerDay,
        });
        return RateLimitDenied(
          message: 'Daily AI budget exceeded',
          retryAfter: _timeUntilWindowReset(
            usage.dayWindowStart!,
            const Duration(days: 1),
            now,
          ),
          limitType: LimitType.costDaily,
          suggestedAction: FallbackAction.skipLlm,
        );
      }
    }

    // Check monthly cost limit
    if (_isInWindow(usage.monthWindowStart, now, const Duration(days: 30))) {
      final estimatedCost = operation.estimatedCost ?? 0.0;
      if (usage.llmCostThisMonth + estimatedCost >
          ImportRateLimits.llmCostPerMonth) {
        AppLogger.analytics('rate_limit_denied', {
          'limitType': 'costMonthly',
          'currentCost': usage.llmCostThisMonth,
          'limit': ImportRateLimits.llmCostPerMonth,
        });
        return RateLimitDenied(
          message: 'Monthly AI budget exceeded',
          retryAfter: _timeUntilWindowReset(
            usage.monthWindowStart!,
            const Duration(days: 30),
            now,
          ),
          limitType: LimitType.costMonthly,
          suggestedAction: FallbackAction.skipLlm,
        );
      }
    }

    return null; // All LLM limits OK
  }

  RateLimitDenied _createLlmDenied(DateTime windowStart, DateTime now) {
    return RateLimitDenied(
      message: 'Daily AI operation limit reached',
      retryAfter: _timeUntilWindowReset(
        windowStart,
        const Duration(days: 1),
        now,
      ),
      limitType: LimitType.llmDaily,
      suggestedAction: FallbackAction.skipLlm,
    );
  }

  /// Check if we're still in a time window.
  bool _isInWindow(DateTime? windowStart, DateTime now, Duration windowSize) {
    if (windowStart == null) return false;
    return now.difference(windowStart) < windowSize;
  }

  /// Calculate time until a window resets.
  Duration _timeUntilWindowReset(
    DateTime windowStart,
    Duration windowSize,
    DateTime now,
  ) {
    final windowEnd = windowStart.add(windowSize);
    final remaining = windowEnd.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Calculate remaining operations in the most restrictive window.
  int _calculateRemaining(
    UsageLimits usage,
    ImportOperation operation,
    DateTime now,
  ) {
    int minRemaining = 999;

    // Check minute window
    if (_isInWindow(usage.minuteWindowStart, now, const Duration(minutes: 1))) {
      minRemaining =
          ImportRateLimits.importsPerMinute - usage.importsThisMinute;
    }

    // Check hour window
    if (_isInWindow(usage.hourWindowStart, now, const Duration(hours: 1))) {
      final hourRemaining =
          ImportRateLimits.importsPerHour - usage.importsThisHour;
      if (hourRemaining < minRemaining) minRemaining = hourRemaining;
    }

    // Check day window
    if (_isInWindow(usage.dayWindowStart, now, const Duration(days: 1))) {
      final dayRemaining = ImportRateLimits.importsPerDay - usage.importsToday;
      if (dayRemaining < minRemaining) minRemaining = dayRemaining;
    }

    return minRemaining < 0 ? 0 : minRemaining;
  }

  /// Update usage counters with proper window resets.
  UsageLimits _updateUsage(
    UsageLimits current,
    ImportOperation operation,
    DateTime now,
    double? llmCost,
  ) {
    // Reset windows if expired
    final minuteWindow =
        _isInWindow(current.minuteWindowStart, now, const Duration(minutes: 1))
        ? current.minuteWindowStart
        : now;
    final hourWindow =
        _isInWindow(current.hourWindowStart, now, const Duration(hours: 1))
        ? current.hourWindowStart
        : now;
    final dayWindow =
        _isInWindow(current.dayWindowStart, now, const Duration(days: 1))
        ? current.dayWindowStart
        : now;
    final monthWindow =
        _isInWindow(current.monthWindowStart, now, const Duration(days: 30))
        ? current.monthWindowStart
        : now;

    // Calculate new counters (reset if window changed)
    final newMinuteCount = minuteWindow == current.minuteWindowStart
        ? current.importsThisMinute + 1
        : 1;
    final newHourCount = hourWindow == current.hourWindowStart
        ? current.importsThisHour + 1
        : 1;
    final newDayCount = dayWindow == current.dayWindowStart
        ? current.importsToday + 1
        : 1;

    // LLM counters
    int newEnhancements = dayWindow == current.dayWindowStart
        ? current.llmEnhancementsToday
        : 0;
    int newExtractions = dayWindow == current.dayWindowStart
        ? current.llmExtractionsToday
        : 0;
    int newVision = dayWindow == current.dayWindowStart
        ? current.llmVisionToday
        : 0;

    if (operation.requiresLlm) {
      switch (operation.llmType) {
        case LlmOperationType.enhancement:
        case LlmOperationType.ingredientLines:
          newEnhancements++;
          break;
        case LlmOperationType.fullExtraction:
          newExtractions++;
          break;
        case LlmOperationType.vision:
          newVision++;
          break;
        case null:
          break;
      }
    }

    // Cost tracking
    final newDayCost = dayWindow == current.dayWindowStart
        ? current.llmCostToday + (llmCost ?? 0.0)
        : (llmCost ?? 0.0);
    final newMonthCost = monthWindow == current.monthWindowStart
        ? current.llmCostThisMonth + (llmCost ?? 0.0)
        : (llmCost ?? 0.0);
    final newMonthOps = monthWindow == current.monthWindowStart
        ? current.llmOperationsThisMonth + (operation.requiresLlm ? 1 : 0)
        : (operation.requiresLlm ? 1 : 0);

    return UsageLimits(
      importsThisMinute: newMinuteCount,
      minuteWindowStart: minuteWindow,
      importsThisHour: newHourCount,
      hourWindowStart: hourWindow,
      importsToday: newDayCount,
      dayWindowStart: dayWindow,
      llmEnhancementsToday: newEnhancements,
      llmExtractionsToday: newExtractions,
      llmVisionToday: newVision,
      llmCostToday: newDayCost,
      llmCostThisMonth: newMonthCost,
      llmOperationsThisMonth: newMonthOps,
      monthWindowStart: monthWindow,
    );
  }
}
