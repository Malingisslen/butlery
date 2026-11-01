/// The mirror of `rules_allowlist_drift_test.dart`: every key a rule REQUIRES
/// is still one its writer sends.
///
/// `firestore.rules` also guards creates with `hasRequiredFields([...])` and
/// `keys().hasAll([...])`. A model that STOPS emitting one of those keys is
/// denied exactly as silently as one that adds an unknown key — it fails closed
/// on the write, with no compiler, no analyzer and no error a user reports. The
/// allowlist guard cannot see it, because it only asks whether every key sent
/// is allowed.
///
/// The two directions live in separate files because they are different
/// claims. `sent` not in `allowed` means the feature is denied now; `required`
/// not in `sent` means the same from the other side, and one red should keep
/// meaning one thing. They also differ in what a missing key means: an
/// allowlist wider than its writer is routinely legitimate (an Admin SDK
/// writer, several client writers), while a REQUIRED key the writer does not
/// send is never legitimate.
///
/// The key sets are the ones `rules_writer_keys.dart` derives for the
/// allowlist guard, so there is one copy of each writer's keys. Three sites
/// that guard has no allowlist for (`feedback`, `recipe_cook_events`,
/// `deep_links`) carry their own.
///
/// **Not covered:** the required lists of writes with no entry below. They are
/// counted, so a new one forces a decision rather than passing unseen, but each
/// needs a writer key set before it can be compared.
library;

import 'dart:io';

import 'package:butlery/models/cook_event.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rules_source.dart';
import 'rules_writer_keys.dart';

/// One required-fields list, located by the text that precedes it.
class _Required {
  const _Required({
    required this.label,
    required this.anchor,
    required this.mustContain,
    required this.writer,
    this.sent,
  });

  final String label;

  /// Text in `firestore.rules` shortly BEFORE the list. Scanned forward, so
  /// [mustContain] is what pins which list was found.
  final String anchor;

  /// A key only the intended list contains.
  final String mustContain;

  final String writer;

  /// The writer's keys when [label] has no entry in `writtenKeys()`.
  final Set<String> Function()? sent;
}

final _requiredCall = RegExp(
  r'(?:hasRequiredFields|keys\(\)\s*\.hasAll)\(\s*\[([^\]]*)\]',
);

final _requiredLists = <_Required>[
  const _Required(
    label: 'users/{uid}/overwritten_versions',
    anchor: 'match /users/{userId}/overwritten_versions/{versionId}',
    mustContain: 'resourceType',
    writer: 'OverwrittenVersion.toFirestore',
  ),
  const _Required(
    label: 'users/{uid}/trash',
    anchor: 'match /users/{userId}/trash/{itemId}',
    mustContain: 'sourceId',
    writer: 'TrashItem.toFirestore',
  ),
  const _Required(
    label: 'recipe_suggestions',
    anchor: 'match /recipe_suggestions/{suggestionId}',
    mustContain: 'suggesterId',
    writer: 'RecipeSuggestion.toFirestore',
  ),
  const _Required(
    label: 'conversations/{id}/participants',
    anchor: 'match /participants/{participantId}',
    mustContain: 'participantId',
    writer: 'ConversationParticipant.toFirestore',
  ),
  const _Required(
    label: 'recipe_comments create',
    anchor: 'match /recipe_comments/{commentId}',
    mustContain: 'authorId',
    writer: 'the recipe_comments create payload',
  ),
  const _Required(
    label: 'recipe_ratings create',
    anchor: 'match /recipe_ratings/{ratingId}',
    mustContain: 'rating',
    writer: 'the recipe_ratings create payload',
  ),
  const _Required(
    label: 'household_allergen_shares',
    anchor: 'function allergenShareValid',
    mustContain: 'consentVersion',
    writer: 'HouseholdAllergenShare.toFirestore',
  ),
  const _Required(
    label: 'signup_allowlist create',
    anchor: 'match /signup_allowlist/{email}',
    mustContain: 'invitedBy',
    writer: 'FirebaseSignupAllowlistRepository.toFirestore',
  ),
  _Required(
    label: 'feedback',
    anchor: 'match /feedback/{feedbackId}',
    mustContain: 'description',
    writer: 'FeedbackEntry.toMap, stored by FirebaseFeedbackRepository',
    sent: () => FeedbackEntry(
      id: 'f',
      userId: 'u',
      category: FeedbackCategory.bug,
      description: 'd',
      recentInteractions: const [],
      createdAt: DateTime(2026),
    ).toMap().keys.toSet(),
  ),
  _Required(
    label: 'recipe_cook_events',
    anchor: 'match /recipe_cook_events/{userId}/events/{eventId}',
    mustContain: 'cookedAt',
    writer: 'CookEvent.toFirestore, stored by FirebaseCookEventRepository',
    // The narrowest payload: no attendees. The required keys must be there
    // even then.
    sent: () => CookEvent(
      id: 'e',
      userId: 'u',
      recipeId: 'r',
      cookedAt: DateTime(2026),
    ).toFirestore().keys.toSet(),
  ),
  _Required(
    label: 'deep_links create',
    anchor: 'match /deep_links/{linkId}',
    mustContain: 'longUrl',
    // Hand-assembled: the writer builds the map inline with no model, so this
    // set is a retyped copy of `linkData` in `createShortUrl`, not derived.
    // Named by method, not line number.
    writer: 'FirebaseDeepLinkRepository.createShortUrl — the linkData map',
    sent: () => {
      'id',
      'longUrl',
      'metadata',
      'createdAt',
      'createdBy',
      'clickCount',
    },
  ),
];

/// Required lists in `firestore.rules` that no entry above compares, because no
/// writer key set exists for them yet. A new one, or a removed one, moves the
/// total and fails the census below.
const _unguardedRequiredLists = 34;

Set<String> _requiredAfter(String rules, _Required entry) {
  final block = rulesBlock(rules, entry.anchor);
  expect(
    block,
    isNotNull,
    reason:
        'anchor "${entry.anchor}" no longer appears in firestore.rules — the '
        'rule was renamed or removed, and this guard points at nothing',
  );
  // `rulesBlock` stops at the next `match`, which can be a nested one; the
  // list we want comes before any nested block in every entry above.
  final call = _requiredCall.firstMatch(block!);
  expect(
    call,
    isNotNull,
    reason: 'no hasRequiredFields/hasAll list after "${entry.anchor}"',
  );
  final found = RegExp(
    "'([^']+)'",
  ).allMatches(call!.group(1)!).map((m) => m.group(1)!).toSet();
  expect(
    found,
    contains(entry.mustContain),
    reason:
        'the first required list after "${entry.anchor}" does not contain '
        '"${entry.mustContain}", so this guard points at the WRONG list: '
        '${(found.toList()..sort()).join(', ')}',
  );
  return found;
}

void main() {
  late String rules;

  setUpAll(() {
    rules = withoutCStyleComments(File('firestore.rules').readAsStringSync());
  });

  test('every required-fields list is guarded here or counted as unguarded', () {
    final total = _requiredCall.allMatches(rules).length;
    expect(
      total,
      _requiredLists.length + _unguardedRequiredLists,
      reason:
          'firestore.rules now has $total required-fields lists; this guard '
          'compares ${_requiredLists.length} and counts '
          '$_unguardedRequiredLists as unguarded. A new one appeared, or one '
          'was removed. Add a _Required entry with the writer\'s key set, or '
          'adjust _unguardedRequiredLists. Do not just make the number match.',
    );
  });

  for (final entry in _requiredLists) {
    test(
      '${entry.label}: every key the rules require is sent by the writer',
      () {
        final required = _requiredAfter(rules, entry);
        final sent = entry.sent?.call() ?? writtenKeys()[entry.label];
        expect(
          sent,
          isNotNull,
          reason:
              'no writer key set for "${entry.label}" — the label was renamed '
              'on one side only.',
        );
        final missing = required.difference(sent!);

        expect(
          missing,
          isEmpty,
          reason:
              'firestore.rules would DENY this write, silently, on every '
              'attempt.\n'
              '  writer:   ${entry.writer}\n'
              '  sends:    ${(sent.toList()..sort()).join(', ')}\n'
              '  requires: ${(required.toList()..sort()).join(', ')}\n'
              '  NOT SENT: ${(missing.toList()..sort()).join(', ')}\n'
              'Send the field again, or relax the rule on purpose. Do not '
              'delete this expectation.',
        );
      },
    );
  }
}
