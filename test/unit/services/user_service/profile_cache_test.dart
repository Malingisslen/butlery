import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/user_service/profile_cache.dart';

import '../../../infrastructure/factories/mock_factory.dart';

void main() {
  group('ProfileCache', () {
    final start = DateTime(2026, 11, 13, 10);

    ProfileCache cacheWith(String uid) {
      final cache = ProfileCache();
      withClock(
        Clock.fixed(start),
        () => cache.put(uid, MockFactory.createUserProfile(userId: uid)),
      );
      return cache;
    }

    test('an entry 30 minutes old is still fresh', () {
      final cache = cacheWith('u1');
      final fresh = withClock(
        Clock.fixed(start.add(const Duration(minutes: 30))),
        () => cache.isExpired('u1'),
      );
      expect(fresh, isFalse);
    });

    test('an entry 31 minutes old is expired but still readable', () {
      final cache = cacheWith('u1');
      final expired = withClock(
        Clock.fixed(start.add(const Duration(minutes: 31))),
        () => cache.isExpired('u1'),
      );
      expect(expired, isTrue);
      expect(cache['u1']?.uid, 'u1');
    });

    test('an unknown uid counts as expired', () {
      expect(ProfileCache().isExpired('nobody'), isTrue);
    });

    test('holds at most 200 entries and evicts the oldest first', () {
      final cache = ProfileCache();
      for (var i = 0; i <= 200; i++) {
        cache.put('u$i', MockFactory.createUserProfile(userId: 'u$i'));
      }
      expect(cache.containsKey('u0'), isFalse);
      expect(cache.containsKey('u1'), isTrue);
      expect(cache.containsKey('u200'), isTrue);
    });

    test('put moves an existing entry to newest so it survives eviction', () {
      final cache = ProfileCache();
      for (var i = 0; i < 200; i++) {
        cache.put('u$i', MockFactory.createUserProfile(userId: 'u$i'));
      }
      cache.put('u0', MockFactory.createUserProfile(userId: 'u0'));
      cache.put('new', MockFactory.createUserProfile(userId: 'new'));

      expect(cache.containsKey('u0'), isTrue);
      expect(cache.containsKey('u1'), isFalse);
    });

    test('put refreshes the timestamp of an existing entry', () {
      final cache = cacheWith('u1');
      final later = start.add(const Duration(minutes: 25));
      withClock(
        Clock.fixed(later),
        () => cache.put('u1', MockFactory.createUserProfile(userId: 'u1')),
      );
      final expired = withClock(
        Clock.fixed(start.add(const Duration(minutes: 50))),
        () => cache.isExpired('u1'),
      );
      expect(expired, isFalse);
    });

    test('clear empties the cache', () {
      final cache = cacheWith('u1')..clear();
      expect(cache.containsKey('u1'), isFalse);
      expect(cache.isExpired('u1'), isTrue);
    });
  });
}
