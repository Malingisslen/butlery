// lib/repositories/mixins/permission_caching_mixin.dart

import 'package:butlery/services/cache/permission_cache_service.dart';

/// Mixin providing cached permission checking methods.
///
/// Repositories that extend BaseFirebaseRepository can use this mixin
/// to automatically cache permission check results, reducing Firestore reads.
///
/// Usage:
/// ```dart
/// class MyRepository extends BaseFirebaseRepository<MyModel>
///     with PermissionCachingMixin {
///
///   @override
///   PermissionCacheService? get permissionCache => _cacheService;
///
///   @override
///   String get resourceType => 'my_resource';
///
///   Future<bool> canRead(String userId, String resourceId) async {
///     return checkCachedPermission(
///       userId: userId,
///       resourceId: resourceId,
///       operation: 'read',
///       permissionCheck: () => _actualPermissionCheck(userId, resourceId),
///     );
///   }
/// }
/// ```
mixin PermissionCachingMixin {
  /// Override to provide the cache service instance.
  PermissionCacheService? get permissionCache;

  /// Override to provide the resource type for cache keys.
  String get resourceType;

  /// Check permission with caching.
  ///
  /// Returns cached result if available and not expired.
  /// Otherwise, executes [permissionCheck] and caches the result.
  Future<bool> checkCachedPermission({
    required String userId,
    required String resourceId,
    required String operation,
    required Future<bool> Function() permissionCheck,
    String? reason,
  }) async {
    final cache = permissionCache;
    if (cache == null || !cache.isEnabled) {
      return permissionCheck();
    }

    // Try cache first
    final cached = cache.get(
      userId: userId,
      resourceType: resourceType,
      resourceId: resourceId,
      operation: operation,
    );

    if (cached != null) {
      return cached.allowed;
    }

    // Execute actual permission check
    final allowed = await permissionCheck();

    // Cache the result
    cache.set(
      userId: userId,
      resourceType: resourceType,
      resourceId: resourceId,
      operation: operation,
      allowed: allowed,
      reason: reason,
    );

    return allowed;
  }

  /// Check multiple permissions with caching.
  ///
  /// Useful for batch operations where multiple resources need checking.
  Future<Map<String, bool>> checkCachedPermissions({
    required String userId,
    required List<String> resourceIds,
    required String operation,
    required Future<bool> Function(String resourceId) permissionCheck,
  }) async {
    final results = <String, bool>{};
    final cache = permissionCache;

    for (final resourceId in resourceIds) {
      if (cache != null && cache.isEnabled) {
        final cached = cache.get(
          userId: userId,
          resourceType: resourceType,
          resourceId: resourceId,
          operation: operation,
        );

        if (cached != null) {
          results[resourceId] = cached.allowed;
          continue;
        }
      }

      // Cache miss - execute actual check
      final allowed = await permissionCheck(resourceId);
      results[resourceId] = allowed;

      // Cache the result
      if (cache != null && cache.isEnabled) {
        cache.set(
          userId: userId,
          resourceType: resourceType,
          resourceId: resourceId,
          operation: operation,
          allowed: allowed,
        );
      }
    }

    return results;
  }

  /// Invalidate cached permissions for a specific resource.
  ///
  /// Call this when resource permissions change (e.g., sharing, unsharing).
  void invalidateResourcePermissions(String resourceId) {
    permissionCache?.invalidateResource(
      resourceType: resourceType,
      resourceId: resourceId,
    );
  }

  /// Invalidate all cached permissions for a user.
  ///
  /// Call this when user's global permissions change (e.g., role change).
  void invalidateUserPermissions(String userId) {
    permissionCache?.invalidateUser(userId);
  }
}

/// Extension to make permission cache accessible from GetIt.
extension PermissionCacheAccess on PermissionCacheService {
  /// Get cache statistics formatted as string for logging.
  String get statsString {
    final stats = getStatistics();
    return 'PermissionCache: ${stats['size']}/${stats['maxSize']} entries, '
        'hit rate: ${stats['hitRate']}, '
        'hits: ${stats['hits']}, misses: ${stats['misses']}';
  }
}
