/// BUT-1203 behavior gate for the group-creation draft persistence contract.
///
/// The draft was migrated from a hand-rolled `_loadDraft/_saveDraft/_clearDraft`
/// SharedPreferences triad onto the shared `AutoSaveManager<Map<String,dynamic>>`.
/// The novel, must-preserve logic is the encode contract:
///
///   * an initial-empty form encodes to null → the manager REMOVES the key, so
///     opening then abandoning the dialog leaves no useless empty blob behind;
///   * any non-empty field encodes to the SAME JSON shape the old triad wrote
///     (keys: name / description / emoji / friendIds), so drafts persisted by
///     the pre-migration code still decode after the refactor.
///
/// The dialog's load→setState + friend-resolution glue is widget scaffolding,
/// identical in shape to the three already-shipped string-draft migrations
/// (comment / URL / text), and is not re-proven here.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/social/groups/group_draft_codec.dart';

void main() {
  group('encodeGroupDraft — empty form removes the key', () {
    test('a fully initial-empty draft encodes to null', () {
      final draft = buildGroupDraft(
        name: '',
        description: '',
        emoji: kGroupDraftDefaultEmoji,
        friendIds: const [],
      );
      expect(encodeGroupDraft(draft), isNull);
    });

    test('null/absent fields are treated as empty (still null)', () {
      // Defensive: a partially-shaped map must not throw and must read empty.
      expect(encodeGroupDraft(const <String, dynamic>{}), isNull);
    });
  });

  group('encodeGroupDraft — any populated field persists', () {
    test('a name alone makes the draft worth keeping', () {
      final encoded = encodeGroupDraft(buildGroupDraft(
        name: 'Middagsklubben',
        description: '',
        emoji: kGroupDraftDefaultEmoji,
        friendIds: const [],
      ));
      expect(encoded, isNotNull);
      expect(jsonDecode(encoded!), {
        'name': 'Middagsklubben',
        'description': '',
        'emoji': kGroupDraftDefaultEmoji,
        'friendIds': <String>[],
      });
    });

    test('a non-default emoji alone is enough to persist', () {
      expect(
        encodeGroupDraft(buildGroupDraft(
          name: '',
          description: '',
          emoji: '🍝',
          friendIds: const [],
        )),
        isNotNull,
      );
    });

    test('selected friends alone are enough to persist', () {
      final encoded = encodeGroupDraft(buildGroupDraft(
        name: '',
        description: '',
        emoji: kGroupDraftDefaultEmoji,
        friendIds: const ['friend_a', 'friend_b'],
      ));
      expect(encoded, isNotNull);
      expect(
          (jsonDecode(encoded!) as Map)['friendIds'], ['friend_a', 'friend_b']);
    });
  });

  group('encode → decode round-trip preserves every field', () {
    test('a fully-populated draft survives a persist/restore cycle', () {
      final original = buildGroupDraft(
        name: 'Fredagsmys',
        description: 'Tacos varje fredag',
        emoji: '🌮',
        friendIds: const ['u1', 'u2', 'u3'],
      );
      final restored = decodeGroupDraft(encodeGroupDraft(original)!);
      expect(restored, original);
    });

    test('decode reads the exact JSON the old inline triad wrote', () {
      // Byte-for-byte the shape the pre-BUT-1203 _saveDraft produced.
      const legacyBlob =
          '{"name":"Bokklubben","description":"","emoji":"📚","friendIds":["x"]}';
      final restored = decodeGroupDraft(legacyBlob);
      expect(restored['name'], 'Bokklubben');
      expect(restored['emoji'], '📚');
      expect(restored['friendIds'], ['x']);
    });
  });
}
