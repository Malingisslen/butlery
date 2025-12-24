// lib/services/ocr/ocr_usage_tracker.dart

import 'package:flutter/foundation.dart';

/// Tracks OCR API usage for cost monitoring and rate limiting.
/// Provides usage statistics, warnings, and cost estimates.
class OCRUsageTracker {
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

  // Usage limits
  static const int freeMonthlyLimit = 25000; // OCR.space free tier
  static const double _warningThreshold = 0.8; // 80% of limit

  OCRUsageTracker({DateTime Function()? timeProvider})
      : _timeProvider = timeProvider {
    _monthStartDate = _now;
  }

  DateTime get _now => _timeProvider?.call() ?? DateTime.now();

  /// Record OCR usage for tracking and cost monitoring.
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
      debugPrint('[OCR] New month started - usage counters reset');
    }

    // Increment counters
    _dailyRequestCount++;
    _monthlyRequestCount++;
    _providerUsage[provider] = (_providerUsage[provider] ?? 0) + 1;

    // Log usage and check warnings
    _logUsageStats();
    _checkUsageWarnings();
  }

  /// Log current usage statistics.
  void _logUsageStats() {
    if (kDebugMode) {
      final total = _providerUsage.values.fold(0, (a, b) => a + b);
      debugPrint(
        '[OCR Usage] Today: $_dailyRequestCount | Month: $_monthlyRequestCount/$freeMonthlyLimit',
      );
      if (total > 0) {
        final cacheHitPercent =
            ((_providerUsage['cache_hits'] ?? 0) / total * 100).toInt();
        debugPrint(
          '[OCR Providers] OCR.space: ${_providerUsage['ocr_space']} | '
          'Google Vision: ${_providerUsage['google_vision']} | '
          'Tesseract: ${_providerUsage['tesseract']} | '
          'Cache hits: ${_providerUsage['cache_hits']} ($cacheHitPercent%)',
        );
      }
    }
  }

  /// Check and warn about approaching usage limits.
  void _checkUsageWarnings() {
    if (_monthlyRequestCount >= freeMonthlyLimit) {
      debugPrint(
        '[OCR] EXCEEDED FREE TIER! Monthly usage: $_monthlyRequestCount/$freeMonthlyLimit',
      );
      debugPrint(
        '[OCR] Action required: Upgrade to paid tier (\$19/month) or add fallback provider',
      );
    } else if (_monthlyRequestCount >= (freeMonthlyLimit * _warningThreshold)) {
      final percentUsed =
          ((_monthlyRequestCount / freeMonthlyLimit) * 100).toInt();
      debugPrint(
        '[OCR] Approaching limit: $_monthlyRequestCount/$freeMonthlyLimit ($percentUsed%)',
      );
      debugPrint('[OCR] Consider: Upgrade soon or optimize caching');
    }
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
    if (_monthlyRequestCount <= freeMonthlyLimit) {
      return 0.0; // Free tier
    }

    // OCR.space paid tier: $19/month for 100k requests
    if (_monthlyRequestCount <= 100000) {
      return 19.0;
    }

    // Google Vision overflow: $1.50 per 1000 after 100k
    final overflow = _monthlyRequestCount - 100000;
    final googleVisionCost = (overflow / 1000) * 1.50;
    return 19.0 + googleVisionCost;
  }

  /// Get usage warnings.
  List<String> getUsageWarnings() {
    final warnings = <String>[];

    if (_monthlyRequestCount >= freeMonthlyLimit) {
      warnings
          .add('Exceeded free tier - upgrade to paid tier or add fallback');
    } else if (_monthlyRequestCount >= (freeMonthlyLimit * _warningThreshold)) {
      final percentUsed =
          ((_monthlyRequestCount / freeMonthlyLimit) * 100).toInt();
      warnings.add('Approaching monthly limit ($percentUsed%)');
    }

    if (_providerUsage['ocr_space'] == 0 && _monthlyRequestCount > 0) {
      warnings.add('OCR.space not being used - check API key configuration');
    }

    final cacheHitRate = calculateCacheHitRate();
    if (cacheHitRate < 0.2 && _monthlyRequestCount > 100) {
      final hitPercent = (cacheHitRate * 100).toInt();
      warnings.add('Low cache hit rate ($hitPercent%) - many duplicate requests');
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
