/// Direct unit tests for [ConflictDiff] (BUT-1149 coverage burndown — previously
/// zero direct coverage).
///
/// The Firebase-free field-level diff (BUT-1163) between two serialized resource
/// snapshots, used to render local-vs-remote conflict columns. Covers
/// fromMaps: identical → empty, differing scalar fields, bookkeeping keys
/// ignored, key-sorted output, one-sided fields (null on the absent side), and
/// the _stringify handling of lists/maps/scalars (via the diff texts).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/realtime/realtime_types.dart';

void main() {
  group('ConflictDiff.fromMaps', () {
    test('identical snapshots produce an empty diff', () {
      final d = ConflictDiff.fromMaps(
        {'title': 'Pasta', 'portions': 4},
        {'title': 'Pasta', 'portions': 4},
      );
      expect(d.isEmpty, isTrue);
      expect(d.isNotEmpty, isFalse);
    });

    test('a differing scalar field becomes one diff entry', () {
      final d = ConflictDiff.fromMaps(
        {'title': 'Pasta'},
        {'title': 'Pizza'},
      );
      expect(d.changedFields, hasLength(1));
      final f = d.changedFields.single;
      expect(f.fieldKey, 'title');
      expect(f.localText, 'Pasta');
      expect(f.remoteText, 'Pizza');
    });

    test('bookkeeping keys are ignored even when they differ', () {
      final d = ConflictDiff.fromMaps(
        {'title': 'Pasta', 'editCount': 1, 'lastEditedAt': 'mon'},
        {'title': 'Pasta', 'editCount': 9, 'lastEditedAt': 'tue'},
      );
      expect(d.isEmpty, isTrue);
    });

    test('changed fields are sorted by key', () {
      final d = ConflictDiff.fromMaps(
        {'b': '1', 'a': '1'},
        {'b': '2', 'a': '2'},
      );
      expect(d.changedFields.map((f) => f.fieldKey).toList(), ['a', 'b']);
    });

    test('a field present on only one side is null on the absent side', () {
      final d = ConflictDiff.fromMaps(
        {'note': 'local only'},
        const {},
      );
      final f = d.changedFields.single;
      expect(f.fieldKey, 'note');
      expect(f.localText, 'local only');
      expect(f.remoteText, isNull);
    });

    test('stringifies a list field as newline-joined values', () {
      final d = ConflictDiff.fromMaps(
        {
          'ingredients': ['salt', 'peppar'],
        },
        {
          'ingredients': ['salt', 'socker'],
        },
      );
      final f = d.changedFields.single;
      expect(f.localText, 'salt\npeppar');
      expect(f.remoteText, 'salt\nsocker');
    });

    test('stringifies scalar (int) fields', () {
      final d = ConflictDiff.fromMaps({'portions': 4}, {'portions': 6});
      final f = d.changedFields.single;
      expect(f.localText, '4');
      expect(f.remoteText, '6');
    });
  });
}
