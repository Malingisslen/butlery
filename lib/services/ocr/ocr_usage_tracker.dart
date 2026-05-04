// lib/services/ocr/ocr_usage_tracker.dart

/// Tracks OCR provider usage for cost monitoring and rate limiting.

import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OCRUsageTracker {
  // Only the daily count is persisted — monthly is in-memory because
  // persisting it meaningfully would require a list and the user-facing
  // "X calls left today" only needs the day.
  static const String _prefDailyCountKey = 'ocr_usage_daily_count';
  static const String _prefDailyDateKey = 'ocr_usage_daily_date';

  final DateTime Function()? _timeProvider;

  // Usage counters
  int _dailyRequestCount = 0;
  int _monthlyRequestCount = 0;
  DateTime? _lastRequestDate;
  DateTime? _monthStartDate;
  final Map<String, int> _providerUsage = {
    'ocr_space': 0,
    'google_vision': 0,
    'tesseract': 0,
    'cache_hits': 0,
  };

  // Null until [loadFromPersistence] runs. Server-side limits enforce; this
  // layer exists so the visible "X / Y calls left today" survives restart.
  SharedPreferences? _prefs;

  // Usage limits — based on Cloud Function pricing
  static const int freeMonthlyLimit = 500;
  static const double _warningThreshold = 0.8; // 80% of limit

  // Cost per call in USD (tesseract is free, on-device)
  static const double _ocrSpaceCostPerCall = 0.01;
  static const double _googleVisionCostPerCall = 0.05;

  OCRUsageTracker({DateTime Function()? timeProvider})
      : _timeProvider = timeProvider {
    _monthStartDate = _now;
  }

  DateTime get _now => _timeProvider?.call() ?? clock.now();

  /// Load the persisted daily counter from [SharedPreferences]. Idempotent —
  /// callers should fire this once during service initialization. If the
  /// stored date != today, the persisted value is dropped (no migration of
  /// yesterday's count). Server-side limits remain the enforcement boundary.
  ///
  /// Pass [prefs] in tests; production callers can omit and the method
  /// fetches the singleton internally.
  Future<void> loadFromPersistence({SharedPreferences? prefs}) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
    final storedDate = _prefs!.getString(_prefDailyDateKey);
    final today = _formatDateKey(_now);
    if (storedDate == today) {
      final stored = _prefs!.getInt(_prefDailyCountKey) ?? 0;
      // max() so an unawaited load can't roll back an in-flight increment.
      if (stored > _dailyRequestCount) {
        _dailyRequestCount = stored;
      }
      // Stamp so recordUsage doesn't trip its new-day-reset branch.
      _lastRequestDate = _now;
    }
  }

  static String _formatDateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  void _persistDaily() {
    final prefs = _prefs;
    if (prefs == null) return;
    // Fire-and-forget — server-side limits remain authoritative.
    prefs.setInt(_prefDailyCountKey, _dailyRequestCount);
    prefs.setString(_prefDailyDateKey, _formatDateKey(_now));
  }

  /// Record usage for tracking and cost monitoring.
  void recordUsage(String provider) {
    final now = _now;

    // Reset daily count if new day
    if (_lastRequestDate == null ||
        _lastRequestDate!.day != now.day ||
        _lastRequestDate!.month != now.month ||
        _lastRequestDate!.year != now.year) {
      _dailyRequestCount = 0;
      _lastRequestDate = now;
    }

    // Reset monthly count if new month
    if (_monthStartDate == null ||
        _monthStartDate!.month != now.month ||
        _monthStartDate!.year != now.year) {
      _monthlyRequestCount = 0;
      _monthStartDate = now;
    }

    // Increment counters
    _dailyRequestCount++;
    _monthlyRequestCount++;
    _providerUsage[provider] = (_providerUsage[provider] ?? 0) + 1;

    _persistDaily();
  }

  /// Get usage statistics (for monitoring dashboard).
  Map<String, dynamic> getUsageStats() {
    final total = _providerUsage.values.fold(0, (a, b) => a + b);
    final cacheHitRate =
        total > 0 ? (_providerUsage['cache_hits'] ?? 0) / total : 0.0;

    return {
      'daily_count': _dailyRequestCount,
      'monthly_count': _monthlyRequestCount,
      'monthly_limit': freeMonthlyLimit,
      'usage_percentage': (_monthlyRequestCount / freeMonthlyLimit) * 100,
      'remaining': freeMonthlyLimit - _monthlyRequestCount,
      'provider_usage': Map<String, int>.from(_providerUsage),
      'cache_hit_rate': cacheHitRate,
      'estimated_monthly_cost': _estimateMonthlyCost(),
      'warnings': getUsageWarnings(),
    };
  }

  /// Estimate monthly cost based on current usage.
  double _estimateMonthlyCost() {
    final ocrCalls = _providerUsage['ocr_space'] ?? 0;
    final visionCalls = _providerUsage['google_vision'] ?? 0;
    return (ocrCalls * _ocrSpaceCostPerCall) +
        (visionCalls * _googleVisionCostPerCall);
  }

  /// Get usage warnings.
  List<String> getUsageWarnings() {
    final warnings = <String>[];

    if (_monthlyRequestCount >= freeMonthlyLimit) {
      warnings.add('Exceeded monthly limit - consider reducing usage');
    } else if (_monthlyRequestCount >= (freeMonthlyLimit * _warningThreshold)) {
      final percentUsed =
          ((_monthlyRequestCount / freeMonthlyLimit) * 100).toInt();
      warnings.add('Approaching monthly limit ($percentUsed%)');
    }

    final cacheHitRate = calculateCacheHitRate();
    if (cacheHitRate < 0.2 && _monthlyRequestCount > 100) {
      final hitPercent = (cacheHitRate * 100).toInt();
      warnings
          .add('Low cache hit rate ($hitPercent%) - many duplicate requests');
    }

    return warnings;
  }

  /// Calculate cache hit rate.
  double calculateCacheHitRate() {
    final total = _providerUsage.values.fold(0, (a, b) => a + b);
    return total > 0 ? (_providerUsage['cache_hits'] ?? 0) / total : 0.0;
  }

  /// Get provider usage map.
  Map<String, int> get providerUsage => Map.unmodifiable(_providerUsage);

  /// Get current monthly request count.
  int get monthlyRequestCount => _monthlyRequestCount;

  /// Get current daily request count.
  int get dailyRequestCount => _dailyRequestCount;
}
