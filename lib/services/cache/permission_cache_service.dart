// lib/services/cache/permission_cache_service.dart

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:butlery/core/utils/logger.dart';
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

  /// In-memory cache storage with LRU ordering
  final Map<PermissionCacheKey, CachedPermission> _cache = {};

  /// Order of keys for LRU eviction (most recently used at end)
  final List<PermissionCacheKey> _lruOrder = [];

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

    final cached = _cache[key];
    if (cached == null) {
      _misses++;
      return null;
    }

    if (cached.isExpired(_ttl)) {
      _cache.remove(key);
      _lruOrder.remove(key);
      _misses++;
      return null;
    }

    // Move to end of LRU list (most recently used)
    _lruOrder.remove(key);
    _lruOrder.add(key);

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

    // Evict if at max size
    while (_cache.length >= _maxSize && _lruOrder.isNotEmpty) {
      final evictKey = _lruOrder.removeAt(0);
      _cache.remove(evictKey);
    }

    final permission = CachedPermission(
      allowed: allowed,
      cachedAt: clock.now(),
      reason: reason,
    );

    _cache[key] = permission;
    _lruOrder.remove(key); // Remove if exists
    _lruOrder.add(key); // Add to end (most recent)
  }

  /// Invalidate cache entries for a specific resource.
  /// Called when a resource's permissions change.
  void invalidateResource({
    required String resourceType,
    required String resourceId,
  }) {
    if (!isEnabled) return;

    final keysToRemove = _cache.keys
        .where(
            (k) => k.resourceType == resourceType && k.resourceId == resourceId)
        .toList();

    for (final key in keysToRemove) {
      _cache.remove(key);
      _lruOrder.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      AppLogger.debug(
          'Permission cache: invalidated ${keysToRemove.length} entries for $resourceType:$resourceId');
    }
  }

  /// Invalidate all cache entries for a specific user.
  /// Called when a user's permissions change globally.
  void invalidateUser(String userId) {
    if (!isEnabled) return;

    final keysToRemove = _cache.keys.where((k) => k.userId == userId).toList();

    for (final key in keysToRemove) {
      _cache.remove(key);
      _lruOrder.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      AppLogger.debug(
          'Permission cache: invalidated ${keysToRemove.length} entries for user $userId');
    }
  }

  /// Invalidate all cache entries.
  void invalidateAll() {
    final count = _cache.length;
    _cache.clear();
    _lruOrder.clear();

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
    final expiredKeys = <PermissionCacheKey>[];

    for (final entry in _cache.entries) {
      if (entry.value.isExpired(ttl)) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
      _lruOrder.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      AppLogger.debug(
          'Permission cache: cleaned up ${expiredKeys.length} expired entries');
    }
  }

  /// Dispose of resources.
  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
    _lruOrder.clear();
  }
}
