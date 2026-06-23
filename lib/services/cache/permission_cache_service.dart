// lib/services/cache/permission_cache_service.dart

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:butlery/core/cache/lru_map.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';

/// Permission check result that can be cached.
class CachedPermission {
  final bool allowed;
  final DateTime cachedAt;
  final String? reason;

  CachedPermission({
    required this.allowed,
    required this.cachedAt,
    this.reason,
  });

  /// Check if this cached permission has expired.
  bool isExpired(Duration ttl) {
    return clock.now().difference(cachedAt) > ttl;
  }
}

/// Cache key for permission lookups.
class PermissionCacheKey {
  final String userId;
  final String resourceType;
  final String resourceId;
  final String operation;

  PermissionCacheKey({
    required this.userId,
    required this.resourceType,
    required this.resourceId,
    required this.operation,
  });

  @override
  int get hashCode => Object.hash(userId, resourceType, resourceId, operation);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionCacheKey &&
        other.userId == userId &&
        other.resourceType == resourceType &&
        other.resourceId == resourceId &&
        other.operation == operation;
  }

  @override
  String toString() => '$operation:$resourceType:$resourceId:$userId';
}

/// TTL-based in-memory cache for permission checks.
///
/// Reduces Firestore reads by caching permission check results.
/// Uses LRU eviction when max size is exceeded.
///
/// Features:
/// - Configurable TTL (default 5 minutes)
/// - LRU eviction when max entries exceeded
/// - Background cleanup of expired entries
/// - Real-time invalidation support
/// - Feature flag controlled
class PermissionCacheService {
  final FeatureFlagService _featureFlags;

  /// BUT-817: in-memory LRU cache storage. [LruMap] subsumes the previous
  /// `Map<K,V> + List<K>` pair that hand-tracked recency, removing ~30 lines
  /// of bookkeeping.
  ///
  /// Late init so [_maxSize] (resolved from feature flags) is consulted at
  /// construction time. The bound is fixed for the service lifetime — runtime
  /// flag changes don't resize an existing cache (acceptable; the cache
  /// repopulates on the next read).
  late final LruMap<PermissionCacheKey, CachedPermission> _cache = LruMap(
    maxSize: _maxSize,
    onEvict: (key, _) => AppLogger.info(
      'cache_eviction service=PermissionCacheService key=$key bound=$_maxSize',
    ),
  );

  /// Cleanup timer
  Timer? _cleanupTimer;

  /// Statistics for monitoring
  int _hits = 0;
  int _misses = 0;

  PermissionCacheService({
    required FeatureFlagService featureFlags,
  }) : _featureFlags = featureFlags {
    _startCleanupTimer();
  }

  /// Check if caching is enabled via feature flag.
  bool get isEnabled =>
      _featureFlags.isEnabled(FeatureFlags.enablePermissionCaching);

  /// Get TTL from feature flags (in seconds).
  Duration get _ttl => Duration(
    seconds: _featureFlags.getInt(FeatureFlags.permissionCacheTtlSeconds),
  );

  /// Get max cache size from feature flags.
  int get _maxSize => _featureFlags.getInt(FeatureFlags.permissionCacheMaxSize);

  /// Get a cached permission result if available and not expired.
  CachedPermission? get({
    required String userId,
    required String resourceType,
    required String resourceId,
    required String operation,
  }) {
    if (!isEnabled) return null;

    final key = PermissionCacheKey(
      userId: userId,
      resourceType: resourceType,
      resourceId: resourceId,
      operation: operation,
    );

    // operator[] promotes recency in LruMap — exactly the previous behaviour
    // (manual _lruOrder bump after a successful read).
    final cached = _cache[key];
    if (cached == null) {
      _misses++;
      return null;
    }

    if (cached.isExpired(_ttl)) {
      _cache.remove(key);
      _misses++;
      return null;
    }

    _hits++;
    return cached;
  }

  /// Cache a permission check result.
  void set({
    required String userId,
    required String resourceType,
    required String resourceId,
    required String operation,
    required bool allowed,
    String? reason,
  }) {
    if (!isEnabled) return;

    final key = PermissionCacheKey(
      userId: userId,
      resourceType: resourceType,
      resourceId: resourceId,
      operation: operation,
    );

    _cache[key] = CachedPermission(
      allowed: allowed,
      cachedAt: clock.now(),
      reason: reason,
    );
  }

  /// Invalidate cache entries for a specific resource.
  /// Called when a resource's permissions change.
  void invalidateResource({
    required String resourceType,
    required String resourceId,
  }) {
    if (!isEnabled) return;

    final count = _cache.removeWhere(
      (k, _) => k.resourceType == resourceType && k.resourceId == resourceId,
    );

    if (count > 0) {
      AppLogger.debug(
        'Permission cache: invalidated $count entries for $resourceType:$resourceId',
      );
    }
  }

  /// Invalidate all cache entries for a specific user.
  /// Called when a user's permissions change globally.
  void invalidateUser(String userId) {
    if (!isEnabled) return;

    final count = _cache.removeWhere((k, _) => k.userId == userId);

    if (count > 0) {
      AppLogger.debug(
        'Permission cache: invalidated $count entries for user ${userId.maskedUserId}',
      );
    }
  }

  /// Invalidate all cache entries.
  void invalidateAll() {
    final count = _cache.length;
    _cache.clear();

    if (count > 0) {
      AppLogger.debug('Permission cache: invalidated all $count entries');
    }
  }

  /// Get cache statistics for monitoring.
  Map<String, dynamic> getStatistics() {
    final total = _hits + _misses;
    final hitRate = total > 0 ? (_hits / total * 100).toStringAsFixed(1) : '0';

    return {
      'enabled': isEnabled,
      'size': _cache.length,
      'maxSize': _maxSize,
      'ttlSeconds': _ttl.inSeconds,
      'hits': _hits,
      'misses': _misses,
      'hitRate': '$hitRate%',
    };
  }

  /// Reset statistics (useful for testing or monitoring windows).
  void resetStatistics() {
    _hits = 0;
    _misses = 0;
  }

  /// Start background cleanup timer.
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _cleanupExpired(),
    );
  }

  /// Remove expired entries in background.
  void _cleanupExpired() {
    if (!isEnabled || _cache.isEmpty) return;

    final ttl = _ttl;
    final count = _cache.removeWhere((_, v) => v.isExpired(ttl));

    if (count > 0) {
      AppLogger.debug('Permission cache: cleaned up $count expired entries');
    }
  }

  /// Dispose of resources.
  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}
