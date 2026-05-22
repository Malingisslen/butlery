/// Unit tests for MenuSlotVote + VoteOption.
///
/// Pure-Dart; targets the 81 unhit lines in lib/models/realtime/menu_slot_vote.dart.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/realtime/menu_slot_vote.dart';

VoteOption _opt(String id, {String name = 'Recipe'}) => VoteOption(
      id: id,
      recipeId: 'r-$id',
      recipeName: name,
      recipeImageUrl: 'https://x/$id.jpg',
      suggestedByUserId: 'u1',
    );

MenuSlotVote _vote({
  String id = 'v1',
  List<VoteOption>? alternatives,
  Map<String, String>? votes,
  bool isResolved = false,
  String? winningOptionId,
  DateTime? deadline,
}) {
  return MenuSlotVote(
    id: id,
    menuId: 'menu-1',
    category: 'dinner',
    slotIndex: 0,
    alternatives: alternatives ?? [_opt('a'), _opt('b')],
    votes: votes ?? const {},
    deadline: deadline ?? DateTime.utc(2030, 1, 1),
    isResolved: isResolved,
    winningOptionId: winningOptionId,
    createdByUserId: 'u1',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('VoteOption serialization', () {
    test('toFirestore + fromMap round-trip', () {
      const o = VoteOption(
        id: 'opt-1',
        recipeId: 'r-1',
        recipeName: 'Pasta',
        recipeImageUrl: 'https://x/img.jpg',
        suggestedByUserId: 'u1',
      );
      final restored = VoteOption.fromMap(o.toFirestore());
      expect(restored.id, 'opt-1');
      expect(restored.recipeId, 'r-1');
      expect(restored.recipeName, 'Pasta');
      expect(restored.recipeImageUrl, 'https://x/img.jpg');
      expect(restored.suggestedByUserId, 'u1');
    });

    test('fromMap handles missing recipeImageUrl as null', () {
      final o = VoteOption.fromMap(const {
        'id': 'x',
        'recipeId': 'r',
        'recipeName': 'X',
        'suggestedByUserId': 'u',
      });
      expect(o.recipeImageUrl, isNull);
    });
  });

  group('MenuSlotVote.create', () {
    test('generates id + deadline = now + window', () {
      final fixed = DateTime.utc(2026, 1, 1, 12);
      withClock(Clock.fixed(fixed), () {
        final v = MenuSlotVote.create(
          menuId: 'm1',
          category: 'dinner',
          slotIndex: 2,
          alternatives: [_opt('a')],
          votingWindow: const Duration(hours: 24),
          createdByUserId: 'u1',
        );
        expect(v.id, isNotEmpty);
        expect(v.menuId, 'm1');
        expect(v.slotIndex, 2);
        expect(v.deadline, fixed.add(const Duration(hours: 24)));
        expect(v.createdAt, fixed);
      });
    });
  });

  group('computed getters', () {
    test('isExpired true after deadline', () {
      withClock(Clock.fixed(DateTime.utc(2030, 6, 1)), () {
        final v = _vote(deadline: DateTime.utc(2030, 5, 1));
        expect(v.isExpired, isTrue);
        expect(v.isActive, isFalse);
      });
    });

    test('isActive true while pending and not expired', () {
      withClock(Clock.fixed(DateTime.utc(2026, 6, 1)), () {
        final v = _vote(deadline: DateTime.utc(2030, 1, 1));
        expect(v.isActive, isTrue);
        expect(v.isExpired, isFalse);
      });
    });

    test('isActive false when resolved even if not expired', () {
      withClock(Clock.fixed(DateTime.utc(2026, 6, 1)), () {
        final v = _vote(deadline: DateTime.utc(2030, 1, 1), isResolved: true);
        expect(v.isActive, isFalse);
      });
    });

    test('hasVoted true for users in votes map', () {
      final v = _vote(votes: const {'u1': 'a'});
      expect(v.hasVoted('u1'), isTrue);
      expect(v.hasVoted('u2'), isFalse);
    });

    test('totalVotes returns map size', () {
      expect(_vote(votes: const {'u1': 'a', 'u2': 'b'}).totalVotes, 2);
    });
  });

  group('tallies', () {
    test('counts votes per option', () {
      final v = _vote(votes: const {'u1': 'a', 'u2': 'a', 'u3': 'b'});
      expect(v.tallies, {'a': 2, 'b': 1});
    });

    test('empty when no votes', () {
      expect(_vote().tallies, isEmpty);
    });
  });

  group('leadingOption', () {
    test('returns option with most votes', () {
      final v = _vote(votes: const {'u1': 'a', 'u2': 'a', 'u3': 'b'});
      expect(v.leadingOption?.id, 'a');
    });

    test('returns null when no votes', () {
      expect(_vote().leadingOption, isNull);
    });

    test('returns null when leading option id is unknown', () {
      final v = _vote(votes: const {'u1': 'missing-option'});
      expect(v.leadingOption, isNull);
    });
  });

  group('winningOption', () {
    test('returns alternative matching winningOptionId', () {
      final v = _vote(winningOptionId: 'b');
      expect(v.winningOption?.id, 'b');
    });

    test('returns null when no winner', () {
      expect(_vote().winningOption, isNull);
    });

    test('returns null when winningOptionId not in alternatives', () {
      final v = _vote(winningOptionId: 'unknown');
      expect(v.winningOption, isNull);
    });
  });

  group('copyWith', () {
    test('updates votes + isResolved while keeping immutable fields', () {
      final original = _vote(id: 'v-99');
      final updated = original.copyWith(
        votes: const {'u1': 'a'},
        isResolved: true,
        winningOptionId: 'a',
      );
      expect(updated.id, 'v-99');
      expect(updated.menuId, original.menuId);
      expect(updated.votes, {'u1': 'a'});
      expect(updated.isResolved, isTrue);
      expect(updated.winningOptionId, 'a');
    });
  });

  group('toFirestore + fromMap round-trip', () {
    test('preserves all fields', () {
      final original = _vote(
        votes: const {'u1': 'a', 'u2': 'b'},
        isResolved: true,
        winningOptionId: 'a',
      );
      final json = original.toFirestore();
      final restored = MenuSlotVote.fromMap('v-restored', json);

      expect(restored.menuId, original.menuId);
      expect(restored.category, original.category);
      expect(restored.slotIndex, original.slotIndex);
      expect(restored.alternatives.map((o) => o.id),
          original.alternatives.map((o) => o.id));
      expect(restored.votes, {'u1': 'a', 'u2': 'b'});
      expect(restored.isResolved, isTrue);
      expect(restored.winningOptionId, 'a');
      expect(restored.createdByUserId, 'u1');
    });

    test('fromMap handles missing alternatives + votes', () {
      final v = MenuSlotVote.fromMap('v', {
        'menuId': 'm',
        'category': 'c',
        'slotIndex': 0,
        'deadline': DateTime.utc(2030, 1, 1).toIso8601String(),
        'createdByUserId': 'u',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });
      expect(v.alternatives, isEmpty);
      expect(v.votes, isEmpty);
    });

    test('fromMap converts non-string vote keys/values', () {
      final v = MenuSlotVote.fromMap('v', {
        'menuId': 'm',
        'category': 'c',
        'slotIndex': 0,
        'votes': {123: 456},
        'deadline': DateTime.utc(2030, 1, 1).toIso8601String(),
        'createdByUserId': 'u',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });
      expect(v.votes, {'123': '456'});
    });
  });

  test('toString includes id + menu + alternative/vote counts', () {
    final v = _vote(votes: const {'u1': 'a'});
    final s = v.toString();
    expect(s, contains('v1'));
    expect(s, contains('menu-1'));
    expect(s, contains('1 votes'));
  });
}
