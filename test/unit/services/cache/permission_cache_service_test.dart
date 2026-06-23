/// Unit tests for PermissionCacheService (CachedPermission + PermissionCacheKey + the service itself).
///
/// Service depends on FeatureFlagService which depends on FirebaseRemoteConfig.
/// We mock the FeatureFlagService with mocktail so we can drive isEnabled,
/// TTL, and maxSize values deterministically.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/cache/permission_cache_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

PermissionCacheService _service({
  bool enabled = true,
  int ttlSeconds = 300,
  int maxSize = 100,
}) {
  final flags = _MockFeatureFlags();
  when(
    () => flags.isEnabled(FeatureFlags.enablePermissionCaching),
  ).thenReturn(enabled);
  when(
    () => flags.getInt(FeatureFlags.permissionCacheTtlSeconds),
  ).thenReturn(ttlSeconds);
  when(
    () => flags.getInt(FeatureFlags.permissionCacheMaxSize),
  ).thenReturn(maxSize);
  return PermissionCacheService(featureFlags: flags);
}

void main() {
  group('CachedPermission', () {
    test('isExpired returns true when now - cachedAt > ttl', () {
      final entry = CachedPermission(
        allowed: true,
        cachedAt: DateTime.utc(2026, 1, 1),
      );
      withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 0, 0, 31)), () {
        expect(entry.isExpired(const Duration(seconds: 30)), isTrue);
      });
    });

    test('isExpired returns false within TTL', () {
      final entry = CachedPermission(
        allowed: true,
        cachedAt: DateTime.utc(2026, 1, 1),
      );
      withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 0, 0, 29)), () {
        expect(entry.isExpired(const Duration(seconds: 30)), isFalse);
      });
    });
  });

  group('PermissionCacheKey', () {
    test('equality across instances with same 4-tuple', () {
      final a = PermissionCacheKey(
        userId: 'u',
        resourceType: 't',
        resourceId: 'r',
        operation: 'read',
      );
      final b = PermissionCacheKey(
        userId: 'u',
        resourceType: 't',
        resourceId: 'r',
        operation: 'read',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different userId → unequal', () {
      final a = PermissionCacheKey(
        userId: 'u1',
        resourceType: 't',
        resourceId: 'r',
        operation: 'read',
      );
      final b = PermissionCacheKey(
        userId: 'u2',
        resourceType: 't',
        resourceId: 'r',
        operation: 'read',
      );
      expect(a, isNot(b));
    });

    test('identical short-circuit', () {
      final a = PermissionCacheKey(
        userId: 'u',
        resourceType: 't',
        resourceId: 'r',
        operation: 'read',
      );
      expect(a == a, isTrue);
    });

    test('toString format is "operation:type:id:user"', () {
      expect(
        PermissionCacheKey(
          userId: 'alice',
          resourceType: 'recipe',
          resourceId: 'r1',
          operation: 'read',
        ).toString(),
        'read:recipe:r1:alice',
      );
    });
  });

  group('PermissionCacheService', () {
    tearDown(() {
      // Services start cleanup timers; nothing to assert but no leaks either.
    });

    test('disabled service: get returns null, set is a no-op', () {
      final service = _service(enabled: false);
      service.set(
        userId: 'u',
        resourceType: 't',
        resourceId: 'r',
        operation: 'read',
        allowed: true,
      );
      expect(
        service.get(
          userId: 'u',
          resourceType: 't',
          resourceId: 'r',
          operation: 'read',
        ),
        isNull,
      );
      service.dispose();
    });

    test('enabled service: set then get returns the cached value', () {
      final service = _service();
      service.set(
        userId: 'u',
        resourceType: 't',
        resourceId: 'r',
        operation: 'read',
        allowed: true,
        reason: 'owner',
      );
      final cached = service.get(
        userId: 'u',
        resourceType: 't',
        resourceId: 'r',
        operation: 'read',
      );
      expect(cached, isNotNull);
      expect(cached!.allowed, isTrue);
      expect(cached.reason, 'owner');
      service.dispose();
    });

    test('miss path: get returns null on first lookup', () {
      final service = _service();
      expect(
        service.get(
          userId: 'u',
          resourceType: 't',
          resourceId: 'r',
          operation: 'read',
        ),
        isNull,
      );
      service.dispose();
    });

    test('expired entry returns null and is removed from cache', () {
      withClock(Clock.fixed(DateTime.utc(2026, 1, 1)), () {
        final service = _service(ttlSeconds: 30);
        service.set(
          userId: 'u',
          resourceType: 't',
          resourceId: 'r',
          operation: 'read',
          allowed: true,
        );

        withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 0, 0, 31)), () {
          expect(
            service.get(
              userId: 'u',
              resourceType: 't',
              resourceId: 'r',
              operation: 'read',
            ),
            isNull,
          );
          // Subsequent get is still a miss — entry was evicted.
          expect(
            service.get(
              userId: 'u',
              resourceType: 't',
              resourceId: 'r',
              operation: 'read',
            ),
            isNull,
          );
        });
        service.dispose();
      });
    });

    test('invalidateResource removes entries matching (type, id)', () {
      final service = _service();
      service.set(
        userId: 'u1',
        resourceType: 'recipe',
        resourceId: 'r1',
        operation: 'read',
        allowed: true,
      );
      service.set(
        userId: 'u2',
        resourceType: 'recipe',
        resourceId: 'r1',
        operation: 'read',
        allowed: true,
      );
      service.set(
        userId: 'u1',
        resourceType: 'recipe',
        resourceId: 'r2',
        operation: 'read',
        allowed: true,
      );

      service.invalidateResource(resourceType: 'recipe', resourceId: 'r1');

      expect(
        service.get(
          userId: 'u1',
          resourceType: 'recipe',
          resourceId: 'r1',
          operation: 'read',
        ),
        isNull,
      );
      expect(
        service.get(
          userId: 'u2',
          resourceType: 'recipe',
          resourceId: 'r1',
          operation: 'read',
        ),
        isNull,
      );
      // r2 entry untouched
      expect(
        service.get(
          userId: 'u1',
          resourceType: 'recipe',
          resourceId: 'r2',
          operation: 'read',
        ),
        isNotNull,
      );
      service.dispose();
    });

    test('invalidateUser removes all entries for a userId', () {
      final service = _service();
      service.set(
        userId: 'u1',
        resourceType: 't',
        resourceId: 'r1',
        operation: 'read',
        allowed: true,
      );
      service.set(
        userId: 'u1',
        resourceType: 't',
        resourceId: 'r2',
        operation: 'read',
        allowed: true,
      );
      service.set(
        userId: 'u2',
        resourceType: 't',
        resourceId: 'r1',
        operation: 'read',
        allowed: true,
      );

      service.invalidateUser('u1');

      expect(
        service.get(
          userId: 'u1',
          resourceType: 't',
          resourceId: 'r1',
          operation: 'read',
        ),
        isNull,
      );
      expect(
        service.get(
          userId: 'u1',
          resourceType: 't',
          resourceId: 'r2',
          operation: 'read',
        ),
        isNull,
      );
      // u2 entry untouched
      expect(
        service.get(
          userId: 'u2',
          resourceType: 't',
          resourceId: 'r1',
          operation: 'read',
        ),
        isNotNull,
      );
      service.dispose();
    });

    test('invalidateAll empties the cache', () {
      final service = _service();
      for (var i = 0; i < 5; i++) {
        service.set(
          userId: 'u',
          resourceType: 't',
          resourceId: 'r$i',
          operation: 'read',
          allowed: true,
        );
      }
      service.invalidateAll();
      for (var i = 0; i < 5; i++) {
        expect(
          service.get(
            userId: 'u',
            resourceType: 't',
            resourceId: 'r$i',
            operation: 'read',
          ),
          isNull,
        );
      }
      service.dispose();
    });

    test('invalidate methods are no-ops when service is disabled', () {
      final service = _service(enabled: false);
      service.invalidateResource(resourceType: 't', resourceId: 'r');
      service.invalidateUser('u');
      // No throw → contract met.
      service.dispose();
    });

    test('getStatistics reports hits + misses + hitRate', () {
      final service = _service();
      service.set(
        userId: 'u',
        resourceType: 't',
        resourceId: 'r1',
        operation: 'read',
        allowed: true,
      );
      // 1 hit, 1 miss
      service.get(
        userId: 'u',
        resourceType: 't',
        resourceId: 'r1',
        operation: 'read',
      );
      service.get(
        userId: 'u',
        resourceType: 't',
        resourceId: 'r2',
        operation: 'read',
      );

      final stats = service.getStatistics();
      expect(stats['enabled'], isTrue);
      expect(stats['hits'], 1);
      expect(stats['misses'], 1);
      expect(stats['hitRate'], '50.0%');
      expect(stats['size'], 1);
      service.dispose();
    });

    test('resetStatistics zeroes hits + misses', () {
      final service = _service();
      service.set(
        userId: 'u',
        resourceType: 't',
        resourceId: 'r1',
        operation: 'read',
        allowed: true,
      );
      service.get(
        userId: 'u',
        resourceType: 't',
        resourceId: 'r1',
        operation: 'read',
      );
      service.resetStatistics();
      expect(service.getStatistics()['hits'], 0);
      expect(service.getStatistics()['misses'], 0);
      service.dispose();
    });

    test('hitRate is "0%" when total is 0', () {
      final service = _service();
      expect(service.getStatistics()['hitRate'], '0%');
      service.dispose();
    });
  });
}
