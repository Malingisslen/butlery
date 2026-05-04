/// BUT-544: predicate / filter tests for `BlockedUserFilter`.
///
/// The filter is the seam where comment + chat read paths drop content from
/// users the viewer has blocked. Tests cover the static helpers; cache
/// behavior is covered indirectly by the integration-style tests in
/// `comment_crud_operations_test.dart` (and similar for messaging).
library;

import 'package:butlery/services/social/blocking/blocked_user_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlockedUserFilter.shouldHide', () {
    test('returns true when authorId is in the blocked set', () {
      expect(
        BlockedUserFilter.shouldHide('alice', {'alice', 'bob'}),
        isTrue,
      );
    });

    test('returns false when authorId is not in the blocked set', () {
      expect(
        BlockedUserFilter.shouldHide('charlie', {'alice', 'bob'}),
        isFalse,
      );
    });

    test('empty blocked set never hides', () {
      expect(
        BlockedUserFilter.shouldHide('alice', const <String>{}),
        isFalse,
      );
    });
  });

  group('BlockedUserFilter.filter', () {
    test('empty blocked set is a no-op (returns all items)', () {
      final input = ['alice:1', 'bob:2', 'charlie:3'];
      final result = BlockedUserFilter.filter<String>(
        input,
        authorOf: (s) => s.split(':').first,
        blockedIds: const <String>{},
      );
      expect(result, equals(input));
    });

    test('drops items whose author is blocked, preserves order', () {
      final input = ['alice:1', 'bob:2', 'charlie:3', 'alice:4'];
      final result = BlockedUserFilter.filter<String>(
        input,
        authorOf: (s) => s.split(':').first,
        blockedIds: const {'alice'},
      );
      expect(result, equals(['bob:2', 'charlie:3']));
    });

    test('returns a fresh list — does not mutate input', () {
      final input = ['alice:1', 'bob:2'];
      final result = BlockedUserFilter.filter<String>(
        input,
        authorOf: (s) => s.split(':').first,
        blockedIds: const {'alice'},
      );
      expect(result, isNot(same(input)),
          reason: 'Filter must not return the same instance — callers may '
              'rely on input being untouched (streams, shared caches).');
    });

    test('blocking every author yields an empty list', () {
      final input = ['alice:1', 'bob:2'];
      final result = BlockedUserFilter.filter<String>(
        input,
        authorOf: (s) => s.split(':').first,
        blockedIds: const {'alice', 'bob'},
      );
      expect(result, isEmpty);
    });

    test('handles arbitrary item types via authorOf', () {
      final items = [
        _Item('alice', 1),
        _Item('bob', 2),
      ];
      final result = BlockedUserFilter.filter<_Item>(
        items,
        authorOf: (i) => i.author,
        blockedIds: const {'alice'},
      );
      expect(result.map((i) => i.id), equals([2]));
    });
  });
}

class _Item {
  _Item(this.author, this.id);
  final String author;
  final int id;
}
