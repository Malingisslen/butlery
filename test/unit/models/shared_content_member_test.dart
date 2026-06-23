/// Unit tests for SharedContentMember.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/shared_content_member.dart';

SharedContentMember _member({
  String userId = 'alice',
  String displayName = 'Alice',
  String? avatarUrl,
  DateTime? addedAt,
  String addedBy = 'bob',
  String role = 'viewer',
  bool hasViewed = false,
}) {
  return SharedContentMember(
    userId: userId,
    displayName: displayName,
    avatarUrl: avatarUrl,
    addedAt: addedAt ?? DateTime.utc(2026, 1, 1),
    addedBy: addedBy,
    role: role,
    hasViewed: hasViewed,
  );
}

void main() {
  group('initials', () {
    test('first two chars when single word ≥2 chars', () {
      expect(_member(displayName: 'Alice').initials, 'AL');
    });

    test('single first char when single word of length 1', () {
      expect(_member(displayName: 'A').initials, 'A');
    });

    test('first chars of first two words when multi-word', () {
      expect(_member(displayName: 'Alice Svensson').initials, 'AS');
    });

    test('handles 3+ words by using first two', () {
      expect(_member(displayName: 'Alice Maria Svensson').initials, 'AM');
    });

    test('"?" when displayName is empty', () {
      expect(_member(displayName: '').initials, '?');
    });

    test('always uppercases', () {
      expect(_member(displayName: 'alice').initials, 'AL');
      expect(_member(displayName: 'alice svensson').initials, 'AS');
    });
  });

  group('serialization', () {
    test('toFirestore omits avatarUrl key when null', () {
      final payload = _member().toFirestore();
      expect(payload.containsKey('avatarUrl'), isFalse);
    });

    test('toFirestore includes avatarUrl when set', () {
      final payload = _member(avatarUrl: 'https://x').toFirestore();
      expect(payload['avatarUrl'], 'https://x');
    });

    test('toFirestore uses millisecondsSinceEpoch for addedAt', () {
      final payload = _member().toFirestore();
      expect(
        payload['addedAt'],
        DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
      );
    });

    test('fromFirestore round-trips via toFirestore', () {
      final original = _member(
        avatarUrl: 'https://avatar/a',
        role: 'admin',
        hasViewed: true,
      );
      final restored = SharedContentMember.fromFirestore(
        original.toFirestore(),
      );
      expect(restored.userId, original.userId);
      expect(restored.displayName, original.displayName);
      expect(restored.avatarUrl, original.avatarUrl);
      expect(restored.addedBy, original.addedBy);
      expect(restored.role, original.role);
      expect(restored.hasViewed, original.hasViewed);
    });

    test('fromFirestore safe defaults', () {
      final m = SharedContentMember.fromFirestore({});
      expect(m.userId, '');
      expect(m.displayName, '?'); // default
      expect(m.role, 'viewer'); // default
      expect(m.hasViewed, isFalse);
      expect(m.avatarUrl, isNull);
    });

    test('fromFirestore uses clock.now() when addedAt missing', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 23)), () {
        final m = SharedContentMember.fromFirestore({});
        expect(m.addedAt, DateTime.utc(2026, 5, 23));
      });
    });
  });

  group('copyWith', () {
    test('preserves userId / addedAt / addedBy', () {
      final base = _member();
      final copy = base.copyWith(displayName: 'Renamed');
      expect(copy.userId, base.userId);
      expect(copy.addedAt, base.addedAt);
      expect(copy.addedBy, base.addedBy);
      expect(copy.displayName, 'Renamed');
    });

    test('replaces role / hasViewed / avatarUrl', () {
      final copy = _member().copyWith(
        role: 'admin',
        hasViewed: true,
        avatarUrl: 'https://x',
      );
      expect(copy.role, 'admin');
      expect(copy.hasViewed, isTrue);
      expect(copy.avatarUrl, 'https://x');
    });
  });

  group('equality + hash', () {
    test('userId-only equality', () {
      final a = _member(displayName: 'Alice', role: 'viewer');
      final b = _member(displayName: 'Alicia', role: 'admin');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different userId → unequal', () {
      expect(_member(userId: 'a'), isNot(_member(userId: 'b')));
    });

    test('identical short-circuit', () {
      final m = _member();
      expect(m == m, isTrue);
    });
  });

  test('toString includes userId, displayName, role', () {
    final s = _member(role: 'admin').toString();
    expect(s, contains('alice'));
    expect(s, contains('Alice'));
    expect(s, contains('admin'));
  });
}
