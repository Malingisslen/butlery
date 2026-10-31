// lib/services/ocr/ocr_usage_tracker.dart

/// Counts OCR outcomes per provider key, for the monitoring stats.
class OCRUsageTracker {
  final Map<String, int> _providerUsage = {
    'on_device': 0,
    'on_device_rejected': 0,
    'on_device_error': 0,
    'cache_hits': 0,
  };

  void recordUsage(String provider) {
    _providerUsage[provider] = (_providerUsage[provider] ?? 0) + 1;
  }

  Map<String, dynamic> getUsageStats() => {
    'provider_usage': Map<String, int>.from(_providerUsage),
    'cache_hit_rate': calculateCacheHitRate(),
  };

  double calculateCacheHitRate() {
    final total = _providerUsage.values.fold(0, (a, b) => a + b);
    return total > 0 ? (_providerUsage['cache_hits'] ?? 0) / total : 0.0;
  }

  Map<String, int> get providerUsage => Map.unmodifiable(_providerUsage);
}
