/// Unit tests for PermissionCachingMixin.
///
/// The mixin sits between repository code and the
/// `PermissionCacheService`: cache miss → execute permission check →
/// store result. Tests use a mocktail-backed mock of the service so we
/// can verify the cache get/set call pattern, the bypass when the
/// service is disabled or absent, and the batch + invalidation paths
/// without standing up `FeatureFlagService` / `FirebaseRemoteConfig`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/mixins/permission_caching_mixin.dart';
import 'package:butlery/services/cache/permission_cache_service.dart';

class _MockCache extends Mock implements PermissionCacheService {}

class _Subject with PermissionCachingMixin {
  _Subject(this._cache);
  final PermissionCacheService? _cache;

  @override
  PermissionCacheService? get permissionCache => _cache;

  @override
  String get resourceType => 'recipe';
}

CachedPermission _entry({required bool allowed}) =>
    CachedPermission(allowed: allowed, cachedAt: DateTime.utc(2026, 1, 1));

void main() {
  group('checkCachedPermission', () {
    test('bypasses cache when service is null', () async {
      var checked = 0;
      final subject = _Subject(null);
      final allowed = await subject.checkCachedPermission(
        userId: 'u',
        resourceId: 'r',
        operation: 'read',
        permissionCheck: () async {
          checked++;
          return true;
        },
      );
      expect(allowed, isTrue);
      expect(checked, 1);
    });

    test('bypasses cache when service.isEnabled is false', () async {
      final cache = _MockCache();
      when(() => cache.isEnabled).thenReturn(false);
      var checked = 0;
      final subject = _Subject(cache);

      final allowed = await subject.checkCachedPermission(
        userId: 'u',
        resourceId: 'r',
        operation: 'read',
        permissionCheck: () async {
          checked++;
          return false;
        },
      );
      expect(allowed, isFalse);
      expect(checked, 1);
      verifyNever(
        () => cache.get(
          userId: any(named: 'userId'),
          resourceType: any(named: 'resourceType'),
          resourceId: any(named: 'resourceId'),
          operation: any(named: 'operation'),
        ),
      );
    });

    test(
      'returns cached value without invoking permissionCheck on hit',
      () async {
        final cache = _MockCache();
        when(() => cache.isEnabled).thenReturn(true);
        when(
          () => cache.get(
            userId: 'u',
            resourceType: 'recipe',
            resourceId: 'r',
            operation: 'read',
          ),
        ).thenReturn(_entry(allowed: true));

        var checked = 0;
        final subject = _Subject(cache);
        final allowed = await subject.checkCachedPermission(
          userId: 'u',
          resourceId: 'r',
          operation: 'read',
          permissionCheck: () async {
            checked++;
            return false;
          },
        );
        expect(allowed, isTrue);
        expect(checked, 0);
      },
    );

    test('on cache miss: executes check, stores result, returns it', () async {
      final cache = _MockCache();
      when(() => cache.isEnabled).thenReturn(true);
      when(
        () => cache.get(
          userId: any(named: 'userId'),
          resourceType: any(named: 'resourceType'),
          resourceId: any(named: 'resourceId'),
          operation: any(named: 'operation'),
        ),
      ).thenReturn(null);
      when(
        () => cache.set(
          userId: any(named: 'userId'),
          resourceType: any(named: 'resourceType'),
          resourceId: any(named: 'resourceId'),
          operation: any(named: 'operation'),
          allowed: any(named: 'allowed'),
          reason: any(named: 'reason'),
        ),
      ).thenReturn(null);

      final subject = _Subject(cache);
      final allowed = await subject.checkCachedPermission(
        userId: 'u',
        resourceId: 'r',
        operation: 'write',
        permissionCheck: () async => true,
        reason: 'owner',
      );
      expect(allowed, isTrue);
      verify(
        () => cache.set(
          userId: 'u',
          resourceType: 'recipe',
          resourceId: 'r',
          operation: 'write',
          allowed: true,
          reason: 'owner',
        ),
      ).called(1);
    });
  });

  group('checkCachedPermissions (batch)', () {
    test('mixes cache hits and fresh checks per id', () async {
      final cache = _MockCache();
      when(() => cache.isEnabled).thenReturn(true);
      // r1 is cached, r2 is a miss
      when(
        () => cache.get(
          userId: 'u',
          resourceType: 'recipe',
          resourceId: 'r1',
          operation: 'read',
        ),
      ).thenReturn(_entry(allowed: true));
      when(
        () => cache.get(
          userId: 'u',
          resourceType: 'recipe',
          resourceId: 'r2',
          operation: 'read',
        ),
      ).thenReturn(null);
      when(
        () => cache.set(
          userId: any(named: 'userId'),
          resourceType: any(named: 'resourceType'),
          resourceId: any(named: 'resourceId'),
          operation: any(named: 'operation'),
          allowed: any(named: 'allowed'),
          reason: any(named: 'reason'),
        ),
      ).thenReturn(null);

      final invoked = <String>[];
      final subject = _Subject(cache);
      final results = await subject.checkCachedPermissions(
        userId: 'u',
        resourceIds: const ['r1', 'r2'],
        operation: 'read',
        permissionCheck: (id) async {
          invoked.add(id);
          return id == 'r2';
        },
      );

      expect(results, {'r1': true, 'r2': true});
      expect(invoked, ['r2']); // r1 was a cache hit, not invoked
      verify(
        () => cache.set(
          userId: 'u',
          resourceType: 'recipe',
          resourceId: 'r2',
          operation: 'read',
          allowed: true,
        ),
      ).called(1);
    });

    test(
      'skips cache entirely when service disabled — still returns results',
      () async {
        final cache = _MockCache();
        when(() => cache.isEnabled).thenReturn(false);

        final subject = _Subject(cache);
        final results = await subject.checkCachedPermissions(
          userId: 'u',
          resourceIds: const ['r1', 'r2'],
          operation: 'read',
          permissionCheck: (id) async => id == 'r1',
        );
        expect(results, {'r1': true, 'r2': false});
        verifyNever(
          () => cache.set(
            userId: any(named: 'userId'),
            resourceType: any(named: 'resourceType'),
            resourceId: any(named: 'resourceId'),
            operation: any(named: 'operation'),
            allowed: any(named: 'allowed'),
            reason: any(named: 'reason'),
          ),
        );
      },
    );

    test('works with null cache (no service registered)', () async {
      final subject = _Subject(null);
      final results = await subject.checkCachedPermissions(
        userId: 'u',
        resourceIds: const ['r1'],
        operation: 'read',
        permissionCheck: (_) async => true,
      );
      expect(results, {'r1': true});
    });
  });

  group('invalidation', () {
    test('invalidateResourcePermissions forwards to cache', () {
      final cache = _MockCache();
      when(
        () => cache.invalidateResource(
          resourceType: any(named: 'resourceType'),
          resourceId: any(named: 'resourceId'),
        ),
      ).thenReturn(null);

      _Subject(cache).invalidateResourcePermissions('r1');

      verify(
        () => cache.invalidateResource(
          resourceType: 'recipe',
          resourceId: 'r1',
        ),
      ).called(1);
    });

    test('invalidateUserPermissions forwards to cache', () {
      final cache = _MockCache();
      when(() => cache.invalidateUser(any())).thenReturn(null);

      _Subject(cache).invalidateUserPermissions('u');

      verify(() => cache.invalidateUser('u')).called(1);
    });

    test('null cache: invalidation methods no-op', () {
      // Just verify no throw — null-safety on permissionCache?.
      _Subject(null).invalidateResourcePermissions('r');
      _Subject(null).invalidateUserPermissions('u');
    });
  });

  group('PermissionCacheAccess.statsString', () {
    test('formats getStatistics output into a readable line', () {
      final cache = _MockCache();
      when(() => cache.getStatistics()).thenReturn({
        'size': 42,
        'maxSize': 1000,
        'hitRate': '0.75',
        'hits': 30,
        'misses': 10,
      });
      expect(
        cache.statsString,
        'PermissionCache: 42/1000 entries, hit rate: 0.75, hits: 30, misses: 10',
      );
    });
  });
}
