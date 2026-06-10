/// Unit tests for CookSnap.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/cook_snap.dart';

void main() {
  group('CookSnap.create', () {
    test('generates a non-empty UUID id', () {
      final snap = CookSnap.create(
        recipeId: 'r1',
        userId: 'alice',
        userDisplayName: 'Alice',
        photoUrl: 'https://s/x.jpg',
      );
      expect(snap.id, isNotEmpty);
      expect(snap.id, hasLength(36)); // UUID v4
    });

    test('stamps createdAt from clock.now()', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 23, 12)), () {
        final snap = CookSnap.create(
          recipeId: 'r1',
          userId: 'alice',
          userDisplayName: 'Alice',
          photoUrl: 'https://s/x.jpg',
        );
        expect(snap.createdAt, DateTime.utc(2026, 5, 23, 12));
      });
    });

    test('produces distinct ids on rapid successive calls', () {
      final ids = List.generate(
        10,
        (_) => CookSnap.create(
          recipeId: 'r1',
          userId: 'alice',
          userDisplayName: 'Alice',
          photoUrl: 'https://s/x.jpg',
        ).id,
      ).toSet();
      expect(ids.length, 10);
    });
  });

  group('caption sanitization', () {
    test('trims whitespace', () {
      final snap = CookSnap.create(
        recipeId: 'r',
        userId: 'u',
        userDisplayName: 'U',
        photoUrl: 'p',
        caption: '   hello   ',
      );
      expect(snap.caption, 'hello');
    });

    test('null caption stays null', () {
      final snap = CookSnap.create(
        recipeId: 'r',
        userId: 'u',
        userDisplayName: 'U',
        photoUrl: 'p',
      );
      expect(snap.caption, isNull);
    });

    test('whitespace-only caption becomes null', () {
      final snap = CookSnap.create(
        recipeId: 'r',
        userId: 'u',
        userDisplayName: 'U',
        photoUrl: 'p',
        caption: '   ',
      );
      expect(snap.caption, isNull);
    });

    test('truncates at maxCaptionLength', () {
      final long = 'a' * 300;
      final snap = CookSnap.create(
        recipeId: 'r',
        userId: 'u',
        userDisplayName: 'U',
        photoUrl: 'p',
        caption: long,
      );
      expect(snap.caption!.length, CookSnap.maxCaptionLength);
    });

    test('preserves caption exactly at the limit', () {
      final exactly = 'a' * CookSnap.maxCaptionLength;
      final snap = CookSnap.create(
        recipeId: 'r',
        userId: 'u',
        userDisplayName: 'U',
        photoUrl: 'p',
        caption: exactly,
      );
      expect(snap.caption, exactly);
    });
  });

  group('serialization', () {
    test('toFirestore + fromMap round-trip', () {
      final original = CookSnap(
        id: 'snap-1',
        recipeId: 'r1',
        userId: 'alice',
        userDisplayName: 'Alice',
        userAvatarUrl: 'https://avatar/a',
        photoUrl: 'https://s/x.jpg',
        thumbnailUrl: 'https://s/x_thumb.jpg',
        caption: 'tasty',
        createdAt: DateTime.utc(2026, 1, 1, 10),
      );

      final payload = original.toFirestore();
      final restored = CookSnap.fromMap('snap-1', payload);

      expect(restored.id, 'snap-1');
      expect(restored.recipeId, original.recipeId);
      expect(restored.userId, original.userId);
      expect(restored.userDisplayName, original.userDisplayName);
      expect(restored.userAvatarUrl, original.userAvatarUrl);
      expect(restored.photoUrl, original.photoUrl);
      expect(restored.thumbnailUrl, original.thumbnailUrl);
      expect(restored.caption, original.caption);
      expect(restored.createdAt.toUtc(), original.createdAt);
    });

    test('fromMap falls back to defaults for missing fields', () {
      final snap = CookSnap.fromMap('snap-2', {});
      expect(snap.id, 'snap-2');
      expect(snap.recipeId, '');
      expect(snap.userId, '');
      expect(snap.userDisplayName, '?');
      expect(snap.userAvatarUrl, isNull);
      expect(snap.thumbnailUrl, isNull);
      expect(snap.caption, isNull);
      expect(snap.createdAt, isA<DateTime>());
    });
  });

  // BUT-1214: per-snap visibility override. Legacy docs (no field) and
  // unknown wire values MUST resolve to sameAsRecipe so pre-1214 snaps keep
  // their inherited behaviour.
  group('visibility (BUT-1214)', () {
    test('defaults to sameAsRecipe on create and constructor', () {
      final created = CookSnap.create(
        recipeId: 'r',
        userId: 'u',
        userDisplayName: 'U',
        photoUrl: 'p',
      );
      expect(created.visibility, CookSnapVisibility.sameAsRecipe);
    });

    test('onlyMe round-trips through toFirestore + fromMap', () {
      final snap = CookSnap.create(
        recipeId: 'r',
        userId: 'u',
        userDisplayName: 'U',
        photoUrl: 'p',
        visibility: CookSnapVisibility.onlyMe,
      );
      final payload = snap.toFirestore();
      expect(payload['visibility'], 'onlyMe');
      final restored = CookSnap.fromMap(snap.id, payload);
      expect(restored.visibility, CookSnapVisibility.onlyMe);
    });

    test('toFirestore always writes the field (sameAsRecipe explicit)', () {
      // The friends-gallery query filters on visibility == sameAsRecipe;
      // a new doc missing the field would vanish from friends' galleries.
      final snap = CookSnap.create(
        recipeId: 'r',
        userId: 'u',
        userDisplayName: 'U',
        photoUrl: 'p',
      );
      expect(snap.toFirestore()['visibility'], 'sameAsRecipe');
    });

    test('legacy doc without visibility deserializes to sameAsRecipe', () {
      final snap = CookSnap.fromMap('legacy', {'recipeId': 'r'});
      expect(snap.visibility, CookSnapVisibility.sameAsRecipe);
    });

    test('unknown wire value resolves to sameAsRecipe', () {
      expect(CookSnapVisibility.fromWire('everyone'),
          CookSnapVisibility.sameAsRecipe);
      expect(
          CookSnapVisibility.fromWire(null), CookSnapVisibility.sameAsRecipe);
      expect(CookSnapVisibility.fromWire('onlyMe'), CookSnapVisibility.onlyMe);
    });
  });

  group('equality + hash', () {
    test('two CookSnaps with same id are equal', () {
      final a = CookSnap(
          id: 'x',
          recipeId: 'r1',
          userId: 'a',
          userDisplayName: 'A',
          photoUrl: 'p1');
      final b = CookSnap(
          id: 'x',
          recipeId: 'r2', // different recipe — equality is id-only
          userId: 'b',
          userDisplayName: 'B',
          photoUrl: 'p2');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different ids → unequal', () {
      final a = CookSnap(
          id: 'x',
          recipeId: 'r1',
          userId: 'a',
          userDisplayName: 'A',
          photoUrl: 'p');
      final b = CookSnap(
          id: 'y',
          recipeId: 'r1',
          userId: 'a',
          userDisplayName: 'A',
          photoUrl: 'p');
      expect(a, isNot(b));
    });

    test('identical short-circuit', () {
      final a = CookSnap(
          id: 'x',
          recipeId: 'r1',
          userId: 'a',
          userDisplayName: 'A',
          photoUrl: 'p');
      expect(a == a, isTrue);
    });
  });

  test('toString includes id, user, recipe', () {
    final s = CookSnap(
      id: 'snap-x',
      recipeId: 'r1',
      userId: 'alice',
      userDisplayName: 'Alice',
      photoUrl: 'p',
    );
    final str = s.toString();
    expect(str, contains('snap-x'));
    expect(str, contains('Alice'));
    expect(str, contains('r1'));
  });
}
