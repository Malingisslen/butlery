/// BUT-1163: unit tests for [ConflictDiff] — the deterministic field-level diff
/// that powers the conflict diff view.
///
/// These pin the contract the view relies on: only genuinely-changed user
/// fields surface (metadata bookkeeping is suppressed), values are stringified
/// stably regardless of input type, and identical snapshots produce an empty
/// diff. A regression here would either hide a real edit-loss from the user or
/// flood the diff with noise — both defeat the feature's purpose.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/realtime/realtime_types.dart';

void main() {
  group('ConflictDiff.fromMaps', () {
    test('reports only fields that differ, sorted by key', () {
      final diff = ConflictDiff.fromMaps(
        {'title': 'Soppa', 'portions': 4, 'note': 'same'},
        {'title': 'Gryta', 'portions': 6, 'note': 'same'},
      );

      expect(diff.isNotEmpty, isTrue);
      expect(diff.changedFields.map((f) => f.fieldKey).toList(),
          ['portions', 'title']);

      final title = diff.changedFields.firstWhere((f) => f.fieldKey == 'title');
      expect(title.localText, 'Soppa');
      expect(title.remoteText, 'Gryta');
    });

    test('returns an empty diff for identical snapshots', () {
      final diff = ConflictDiff.fromMaps(
        {'title': 'Soppa', 'portions': 4},
        {'title': 'Soppa', 'portions': 4},
      );
      expect(diff.isEmpty, isTrue);
      expect(diff.changedFields, isEmpty);
    });

    test('suppresses metadata bookkeeping fields that change every save', () {
      final diff = ConflictDiff.fromMaps(
        {
          'title': 'Soppa',
          'editCount': 3,
          'lastEditedBy': 'userA',
          'lastEditedAt': '2026-06-13T10:00:00Z',
        },
        {
          'title': 'Soppa',
          'editCount': 4,
          'lastEditedBy': 'userB',
          'lastEditedAt': '2026-06-13T10:00:05Z',
        },
      );
      // editCount / lastEditedBy / lastEditedAt all differ but must be ignored;
      // title is identical, so the diff is empty.
      expect(diff.isEmpty, isTrue);
    });

    test('stringifies lists element-by-element so list edits surface', () {
      final diff = ConflictDiff.fromMaps(
        {
          'instructions': ['Koka', 'Servera']
        },
        {
          'instructions': ['Koka', 'Krydda', 'Servera']
        },
      );
      expect(diff.changedFields, hasLength(1));
      final field = diff.changedFields.single;
      expect(field.fieldKey, 'instructions');
      expect(field.localText, 'Koka\nServera');
      expect(field.remoteText, 'Koka\nKrydda\nServera');
    });

    test('represents a field present on one side only as null vs value', () {
      final diff = ConflictDiff.fromMaps(
        {'title': 'Soppa'},
        {'title': 'Soppa', 'subtitle': 'Vegetarisk'},
      );
      expect(diff.changedFields, hasLength(1));
      final field = diff.changedFields.single;
      expect(field.fieldKey, 'subtitle');
      expect(field.localText, isNull);
      expect(field.remoteText, 'Vegetarisk');
    });

    test('stringifies nested maps with sorted keys for stable output', () {
      final diff = ConflictDiff.fromMaps(
        {
          'participants': {'b': 'editor', 'a': 'owner'}
        },
        {
          'participants': {'a': 'owner', 'b': 'viewer'}
        },
      );
      expect(diff.changedFields, hasLength(1));
      final field = diff.changedFields.single;
      // Keys sorted regardless of insertion order; only the changed value
      // (b: editor -> viewer) distinguishes the two sides.
      expect(field.localText, 'a: owner\nb: editor');
      expect(field.remoteText, 'a: owner\nb: viewer');
    });
  });
}
