// lib/core/cache_config.dart

import 'package:flutter/material.dart'; // ✅ LÄGG TILL DENNA IMPORT
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CacheConfig {
  static const int maxCacheAge = 7; // dagar
  static const int maxCacheObjects = 100;

  static CacheManager get customCacheManager => CacheManager(
    Config(
      'recipeCacheKey',
      stalePeriod: const Duration(days: maxCacheAge),
      maxNrOfCacheObjects: maxCacheObjects,
    ),
  );

  /// Rensa bildcache (använd vid behov)
  static Future<void> clearCache() async {
    await customCacheManager.emptyCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
