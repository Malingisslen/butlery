/// The guard that exists because five of these drifted at once.
///
/// `firestore.rules` gates several writes with
/// `request.resource.data.keys().hasOnly([...])`. That list is a SECOND COPY of
/// a model's field list, and it has no compiler, no analyzer and no error the
/// user would report: `hasOnly` fails CLOSED, silently, on the write. The
/// feature simply stops working.
///
/// It cost three weeks of production once already — `configRevision` was added
/// to `TagResult` on 2026-07-23 and every recipe create and update was denied
/// until 2026-08-12, unnoticed because nobody saved a recipe in the window.
/// The review of that fix then found more live drifts and one latent.
///
/// So this test compares an allowlist against the keys the writer ACTUALLY
/// SENDS, and it derives those keys by calling the model rather than retyping
/// them — retyping is the mechanism that let all five through, including the
/// hand-written fixture in the rules suite that was supposed to catch it.
///
/// **It does not cover every allowlist.** An actual drift was found in:
/// `isValidTagResult`, `counters`,
/// `notification_history` and the deep-link `clicks`.
/// `participants` and the poll vote never drifted and could not have — each
/// `match` block was new when it was added here, so those writes were failing on
/// default-deny, not on a stale allowlist. Both are guarded because a brand-new
/// allowlist is the likeliest of all to drift next.
///
/// The poll vote is also the census earning its keep: it shipped UNGUARDED on
/// 2026-08-17 and nothing said so, because this test was already red over an
/// unrelated count and a red test cannot demand a decision. Chronic red disarms
/// the guard, which is the lesson, not a footnote.
///
/// The rest were each checked against their writer once and none had drifted —
/// but "checked once" is not "guarded", which is why the census
/// test below fails the moment a new one appears, forcing a decision instead
/// of a silent omission.
///
/// **Scope, stated honestly: some key sets are hand-assembled**,
/// not derived, because their writer builds its map inline in a repository with
/// no model to call. The counters entry looks derived and is
/// only half so: the field NAMES come from `UserCounterIncrements`, but WHICH
/// keys the writer sends is read off `base_shared_content_repository.dart` and
/// retyped, so adding a key to that `set({...})` leaves this guard green. Every
/// hand-assembled set names its writer's file AND the method that builds the
/// payload, never a line number — a method name survives the edits a line
/// number does not. Genuinely deriving the counters set means driving
/// `incrementUnreadCounter` against a fake Firestore and reading the written
/// document back; worth doing, not done here.
///
/// **This guard checks ONE DIRECTION on purpose: every key the writer sends is
/// allowed.** It does not assert the reverse. `sent` not in `allowed` is a fact
/// about production — the feature is denied right now, and a red is never a
/// judgement call. An allowlist WIDER than the writer is routinely legitimate:
/// a Cloud Function writing the same document under the Admin SDK, one of
/// several client writers the fixture does not model, or a rule deliberately
/// written ahead of its writer. The `notification_history` set below is itself
/// a hand-made UNION of a create and two update payloads. An equality assertion
/// would redden on every future widening until somebody invented a payload
/// nothing sends, which is how a guard teaches people to ignore it. If it is
/// ever added it goes in a SEPARATE test with its own name — never a second
/// `expect` in here, so that a red keeps meaning exactly one thing.
///
/// The mirror direction — every key a `hasRequiredFields` / `hasAll` list
/// requires is still sent — is `rules_required_fields_drift_test.dart`, over
/// the same writer key sets (`rules_writer_keys.dart`).
///
/// **NOT COVERED, a different question entirely:** this guard proves an
/// allowlist's CONTENT matches its writer. It cannot prove the allowlist is
/// EVALUATED. Four edits leave every assertion here green while the constraint
/// stops binding: dropping `request.` so the check reads the STORED document
/// (fail-closed on create, fail-OPEN on update, and plausible as a typo);
/// flipping the `&&` in front of it to `||`; replacing the CALL
/// `isValidTagResult(...)` with `true` while the function stays intact — which
/// this guard's own anchor is the definition of, so it structurally cannot see
/// it; and adding a second permissive `allow` beside the constrained one, since
/// `allow` statements OR together. Presence-versus-enforcement needs a different
/// instrument — the emulator rules suite, which evaluates the rule instead of
/// reading it. Named here so nobody reads a green run as more than it is.
library;

import 'dart:io';

import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/services/account/export/activity_export_manager.dart';
import 'package:butlery/services/account/export/family_export_manager.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rules_source.dart';
import 'rules_writer_keys.dart';

/// Pulls the first `hasOnly([...])` list appearing after [anchor].
Set<String> _allowlistAfter(String rules, String anchor, String mustContain) {
  final at = rules.indexOf(anchor);
  expect(
    at,
    isNot(-1),
    reason:
        'anchor "$anchor" no longer appears in firestore.rules — the rule was '
        'renamed or removed, and this guard is now pointing at nothing',
  );
  final call = rules.indexOf('hasOnly(', at);
  expect(call, isNot(-1), reason: 'no hasOnly( after "$anchor"');
  final open = rules.indexOf('[', call);
  final close = rules.indexOf(']', open);
  final found = RegExp(
    "'([^']+)'",
  ).allMatches(rules.substring(open, close)).map((m) => m.group(1)!).toSet();

  // Pin WHICH list was found. Anchoring on the enclosing block is not enough,
  // because this extractor scans FORWARD and does not stop at a closing brace:
  // the participants block contains two `hasOnly` calls, and `isValidTagResult`
  // is immediately followed by a sibling function carrying another. Either way
  // a reordering would silently rebind this comparison to an unrelated list. A
  // sentinel only the intended list contains fails loudly instead.
  expect(
    found,
    contains(mustContain),
    reason:
        'the first hasOnly( after "$anchor" does not contain "$mustContain", '
        'so this guard is pointing at the WRONG list: '
        '${(found.toList()..sort()).join(', ')}',
  );
  return found;
}

/// An allowlist this guard does not compare, plus the text that proves it is
/// still there. The anchor is what turns the census from a count into a check.
class _Uncovered {
  const _Uncovered(this.label, this.anchor);
  final String label;
  final String anchor;
}

/// Allowlists this guard does not compare against a writer. Most were read
/// against theirs once and none had drifted; the `user_moderation` entry is a
/// READ gate with no writer, compared instead by its own equality test.
///
/// Each carries an ANCHOR, and the census asserts that the anchor still appears
/// AND that its block still carries a `keys().hasOnly(` — checked up to the next
/// `match `, so a surviving block that quietly lost its key constraint is caught
/// too, whether it was deleted or commented out (the source is comment-stripped
/// before any assertion reads it; see `setUpAll`). Without both halves the census is a bare count: delete one uncovered
/// allowlist and add another in the same commit and the total is unchanged, so
/// the guard stays green over a list nobody has ever compared.
///
/// Three earlier versions of this docstring were wrong about its own strength.
/// The first claimed NAMING them was enough to survive a swap; names never
/// resolved against the file buy diagnosability, not detection. The second added
/// the anchor and claimed that closed it; it caught a block that DISAPPEARS and
/// not an allowlist that disappears from a surviving block — which is the more
/// likely edit, since someone loosening a rule keeps the `match` line. Hence the
/// second half. The third claimed the two halves closed it; they did not, until
/// the source was comment-stripped — every check here matches inside a comment,
/// so commenting a constraint out satisfied all of them at once, including the
/// flagship `isValidTagResult` comparison. A guarded entry is safe from all
/// three: deleting or commenting out its allowlist trips its `mustContain`
/// sentinel, and renaming its block trips the anchor lookup in
/// [_allowlistAfter].
const _knowinglyUncovered = <_Uncovered>[
  // Covered by `the user_moderation read gate and the Art. 15 projection
  // agree` rather than by the writer comparison: it is a READ gate, and its
  // counterpart is a Dart projection, not a `toFirestore`.
  _Uncovered(
    'user_moderation — read gate, compared against the Art. 15 projection',
    'match /user_moderation/{userId}',
  ),
  _Uncovered('recipe_comments/{id}/likes', 'match /likes/{userId}'),
  _Uncovered(
    'recipe_cook_events — CookEvent.toFirestore',
    'match /recipe_cook_events/{userId}/events/{eventId}',
  ),
  _Uncovered('feedback — FeedbackEntry.toMap', 'match /feedback/{feedbackId}'),
  _Uncovered(
    'notification_delivery — NotificationAnalyticsManager',
    'match /notification_delivery/{notificationId}',
  ),
  _Uncovered(
    'notification_engagement — NotificationAnalyticsManager',
    'match /notification_engagement/{engagementId}',
  ),
  _Uncovered(
    'notification_batches — FirebaseNotificationBatchRepository',
    'match /notification_batches/{batchKey}',
  ),
  // BUT-2059: not compared against a WRITER — nothing in `lib/` creates a
  // suggestion, so there is no `toFirestore` to read. Compared instead against
  // the Art. 15 export allowlist by `every client-writable
  // ingredient_suggestions field is exported`, the same way `user_moderation`
  // above is compared against its projection. It stays in this list because
  // the census is a count over every `keys().hasOnly` block plus this list's
  // anchors — removing the line would leave the block counted by nothing and
  // redden the census. The day a Dart writer lands, this entry goes and the
  // writer comparison takes over.
  _Uncovered(
    'ingredient_suggestions — no Dart writer; compared against the Art. 15 '
        'projection',
    'match /ingredient_suggestions/{suggestionId}',
  ),
  // BUT-2115: the allowlist is over the keys of the `reactions` map, not the
  // document's, and the writer is the emoji picker's key list. Those two and
  // COMMENT_REACTION_KEYS are held equal by a functions test instead.
  _Uncovered(
    'recipe_comments reactions — kReactionEmojis keys',
    'function reactionShapeOk(',
  ),
  // BUT-2089: the allowlist is over the keys of the `memberPermissions` map
  // on create, and its one key is the creator's uid, not a writer's field set.
  _Uncovered(
    'unified_shared_shopping_lists create — creator-only memberPermissions',
    'match /unified_shared_shopping_lists/{listId}',
  ),
  // BUT-643 follow-up: the allowlist is over the keys of one amount entry
  // inside the household's `nutritionAmountChoices` map ({a, u}), written by
  // `NutritionAmountChoice.toMap`, not over the household document's keys.
  _Uncovered(
    'households nutritionAmountChoices entry — NutritionAmountChoice.toMap',
    'function nutritionAmountValueValid(',
  ),
];

/// Matches the allowlist form this guard covers, tolerating the line wrap the
/// file already uses elsewhere (`affectedKeys()` then `.hasOnly(` on the next
/// line). A plain substring count would miss a wrapped new list entirely,
/// leaving the census green while the thing it exists to catch walked past.
final _allowlistCall = RegExp(r'\.keys\(\)\s*\.hasOnly\(');

/// The one key set that lives in THREE languages: this READ gate, the Dart
/// export projection, and the Cloud Function that writes the document. The
/// first two are compared mechanically below; the third is named in
/// `ACCEPTED_DEVIATIONS.md` as its own ticket.
///
/// Divergence breaks in BOTH directions, which is why an equality test rather
/// than a subset one: rules wider than the projection means a field nobody
/// decided about becomes readable to the subject; the projection wider than
/// rules means the server denies the whole document and the Art. 15 section
/// fails for every reported user.
const _moderationCounterKeys = {'totalReports', 'lastReportedAt'};

void main() {
  late String rules;

  setUpAll(() {
    // COMMENT-STRIPPED, and that is load-bearing rather than tidy. The file is
    // read as raw text, so every check here — the population count, the census
    // regex, the per-entry extractor and the bounded window — matches happily
    // inside a comment. Commenting a `hasOnly` out is therefore SELF-
    // COMPENSATING: the counts do not move, the window still finds the string,
    // and the extractor pulls the commented list, so all twelve writer keys
    // read as "allowed" while the rule enforces nothing. It is also the likelier
    // loosening edit than a deletion, for the same reason a `match` line
    // survives one. Measured: without this strip, commenting out
    // `isValidTagResult`'s allowlist leaves the suite fully green.
    rules = withoutCStyleComments(File('firestore.rules').readAsStringSync());
  });

  test('the user_moderation read gate and the Art. 15 projection agree', () {
    // The rules side, extracted from the file rather than restated.
    expect(
      _allowlistAfter(rules, 'match /user_moderation/{userId}', 'totalReports'),
      _moderationCounterKeys,
    );

    // The Dart side, read out of the repository source for the same reason:
    // a second hand-kept copy of a key set is the drift this file exists for.
    final dart = File(
      'lib/repositories/firebase/firebase_data_export_repository.dart',
    ).readAsStringSync();
    // Anchored at the method, for the reason `_allowlistAfter`'s own docstring
    // gives about the rules side: an unanchored scan rebinds silently the day a
    // second `for (final key in const [...])` appears above this one.
    final at = dart.indexOf('exportModerationCounters');
    expect(
      at,
      isNot(-1),
      reason: 'exportModerationCounters is gone or renamed',
    );
    final loop = RegExp(
      r'for \(final key in const \[([^\]]*)\]\)',
    ).firstMatch(dart.substring(at));
    expect(
      loop,
      isNotNull,
      reason:
          'the projection allowlist in exportModerationCounters is gone or '
          'rewritten in a form this guard cannot see — if it moved, move this '
          'assertion with it rather than deleting it',
    );
    expect(
      RegExp(
        "'([^']+)'",
      ).allMatches(loop!.group(1)!).map((m) => m.group(1)!).toSet(),
      _moderationCounterKeys,
    );

    // The THIRD reader, added with the pre-deletion warning: the rule fails
    // CLOSED, so a field added to this document by any writer refuses the read
    // for every user rather than narrowing it — and that outage is invisible
    // here unless every reader of the key set is held against the same rule.
    final repo = File(
      'lib/repositories/firebase/firebase_report_repository.dart',
    ).readAsStringSync();
    final fields = RegExp(
      r'static const readableFields = \[([^\]]*)\]',
    ).firstMatch(repo);
    expect(
      fields,
      isNotNull,
      reason:
          'ModerationCounters.readableFields is gone or rewritten in a form '
          'this guard cannot see — if it moved, move this assertion with it '
          'rather than deleting it',
    );
    expect(
      RegExp(
        "'([^']+)'",
      ).allMatches(fields!.group(1)!).map((m) => m.group(1)!).toSet(),
      _moderationCounterKeys,
    );
  });

  // BUT-2059: `ingredient_suggestions` was in `_knowinglyUncovered` because
  // the writer comparison this file performs needs a Dart WRITER and nothing
  // in `lib/` creates a suggestion. That left the collection's rules allowlist
  // and its Art. 15 projection as two hand-kept copies with nothing between
  // them, and the drift direction that matters reddens nothing on its own:
  // somebody widens the rules with a new client-writable content field, the
  // export's fail-closed allowlist does not learn about it, the client stores
  // it, and the user's own content disappears from their own bundle in
  // silence.
  //
  // The relation is SUBSET, not equality, and neither list contains the other.
  // `userId` is in the rules and deliberately not in the export — it is the
  // query's own filter, not a withholding. `reviewedAt`, `notifiedAt` and
  // `sourceApp` are in the export and not in the rules, because the Admin SDK
  // writes them and bypasses rules. An assertion written as export ⊆ rules is
  // wrong in the PERMISSIVE direction.
  test('every client-writable ingredient_suggestions field is exported', () {
    final rulesKeys = _allowlistAfter(
      rules,
      'match /ingredient_suggestions/{suggestionId}',
      'ingredientName',
    );

    final dart = File(
      'lib/services/account/export/content_export_manager.dart',
    ).readAsStringSync();
    // Anchored at the declaration for the reason `_allowlistAfter`'s docstring
    // gives: an unanchored scan rebinds silently the day a second
    // `static const _...Fields = <String>[...]` appears above this one.
    final at = dart.indexOf('_ingredientSuggestionFields');
    expect(
      at,
      isNot(-1),
      reason: '_ingredientSuggestionFields is gone or renamed',
    );
    final list = RegExp(r'<String>\[([^\]]*)\]').firstMatch(dart.substring(at));
    expect(
      list,
      isNotNull,
      reason:
          'the Art. 15 allowlist is gone or rewritten in a form this guard '
          'cannot see — if it moved, move this assertion with it rather than '
          'deleting it',
    );
    final exportKeys = RegExp(
      "'([^']+)'",
    ).allMatches(list!.group(1)!).map((m) => m.group(1)!).toSet();

    expect(
      rulesKeys.difference(exportKeys.union({'userId'})),
      isEmpty,
      reason:
          'a client may write a field the Art. 15 export does not carry. The '
          "export fails closed, so the field is dropped from that person's "
          'own bundle without anything reddening — add it to '
          '_ingredientSuggestionFields, or decide to withhold it and say so in '
          'the data_minimisation line of that section.',
    );
  });

  // Q6-12 = B: the suggester's replacement of a pending suggestion is a diff
  // restriction, `affectedKeys().hasOnly([...])`, not a payload allowlist, so
  // the payload comparison above does not see it. A field the writer adds
  // (RecipeSuggestion.toReplacementFirestore) that the rule does not name
  // would be refused on every replacement, and a field the rule names that
  // the writer never sends widens what a suggester may change.
  test('the recipe_suggestions replacement writes exactly what the rule '
      'admits', () {
    final block = rulesBlock(rules, 'match /recipe_suggestions/{suggestionId}');
    expect(block, isNotNull, reason: 'the recipe_suggestions block is gone');
    final lists = [
      for (final m in RegExp(
        r'hasOnly\(\s*\[([^\]]*)\]',
      ).allMatches(block!))
        RegExp(
          "'([^']+)'",
        ).allMatches(m.group(1)!).map((k) => k.group(1)!).toSet(),
    ].where((keys) => keys.contains('replacedAt')).toList();
    expect(
      lists,
      hasLength(1),
      reason: 'exactly one list in the block names replacedAt',
    );
    final written = RecipeSuggestion.create(
      recipeId: 'r',
      ownerId: 'o',
      suggesterId: 's',
      suggestion: const <String, dynamic>{},
      at: DateTime.utc(2026),
    ).withId('x').replacedWith(const {}, at: DateTime.utc(2026, 1, 2));
    expect(lists.single, written.toReplacementFirestore().keys.toSet());
  });

  // BUT-2079 (R8): a key the create limb admits but the Art. 15 section
  // neither exports nor deliberately withholds would be dropped from the
  // person's own bundle with nothing reddening, because the projection fails
  // closed. Read from the manager's own lists, not retyped.
  for (final (label, anchor, sentinel, exported, withheld) in [
    (
      'recipe_comments',
      'match /recipe_comments/{commentId}',
      'authorDisplayName',
      ActivityExportManager.commentFieldsExported,
      ActivityExportManager.commentFieldsWithheld,
    ),
    (
      'recipe_ratings',
      'match /recipe_ratings/{ratingId}',
      'createdAt',
      ActivityExportManager.ratingFieldsExported,
      ActivityExportManager.ratingFieldsWithheld,
    ),
  ]) {
    test('every $label create key is exported or withheld by Art. 15', () {
      final createKeys = _allowlistAfter(rules, anchor, sentinel);
      expect(
        createKeys.difference({...exported, ...withheld}),
        isEmpty,
        reason:
            'a client may create a $label field the Art. 15 section neither '
            'exports nor lists as withheld in ActivityExportManager — decide '
            'which, in that file.',
      );
    });
  }

  // BUT-1693: the share block's allowlist and the Art. 15 projection are two
  // hand-kept copies of one key set, and the permissive direction reddens
  // nothing on its own — a key added to the rules that the export does not
  // carry is dropped from the person's own bundle in silence, because the
  // projection fails closed.
  //
  // SUBSET, not equality: `userId` is in the rules and deliberately not in the
  // export, where it is the query's own filter rather than a withholding.
  test('every writable household_allergen_shares field is exported', () {
    final rulesKeys = _allowlistAfter(
      rules,
      'function allergenShareValid',
      'includeUnknownInMenu',
    );

    expect(
      rulesKeys.difference({
        ...FamilyExportManager.householdAllergenShareFields,
        'userId',
      }),
      isEmpty,
      reason:
          'a client may write a field the Art. 15 export does not carry. The '
          "export fails closed, so the field is dropped from that person's own "
          'bundle without anything reddening — add it to '
          'FamilyExportManager.householdAllergenShareFields, or decide to '
          'withhold it and say so in the data_minimisation line of that '
          'section.',
    );
  });

  // BUT-2243: the reverse direction, kept out of the per-entry loop for the
  // reason the header gives. This list is the only thing standing between a
  // client and the keys the server's cost ledger used to share the document
  // with, so a key the writer does not send is not a harmless widening here.
  test('the rate_limits/imports allowlist admits exactly what UsageLimits '
      'writes', () {
    final allowed = _allowlistAfter(
      rules,
      'match /rate_limits/{type}',
      'importsThisMinute',
    );
    final sent = const UsageLimits().toFirestore().keys.toSet();

    expect(
      allowed,
      sent,
      reason:
          'rate_limits/imports allowlist and UsageLimits.toFirestore() differ.\n'
          '  allowed only: ${(allowed.difference(sent).toList()..sort())}\n'
          '  sent only:    ${(sent.difference(allowed).toList()..sort())}',
    );
    expect(
      allowed.where((k) => k.toLowerCase().contains('cost')),
      isEmpty,
      reason: 'the AI cost lives in the server-written llm_cost doc only',
    );
  });

  test('every keys().hasOnly allowlist is guarded here or knowingly excluded', () {
    // The census. Without it, a new allowlist lands unguarded and
    // nothing says so — which is precisely how the five drifts of 2026-08-12
    // happened, one silent omission at a time.
    // Scope: `keys().hasOnly` only. The rest are `affectedKeys().hasOnly`
    // update restrictions, one `values().hasOnly`, and set differences.
    //
    // One is a READ gate, not a write allowlist: `user_moderation`
    // permits the subject's read only while the document's key set is exactly
    // the two counters, so an undecided field denies rather than leaks
    // (BUT-2046 follow-up). It is covered by its own equality test below
    // rather than by the writer-side comparison the entries above make.
    // The update restrictions deny just as silently, but they pin a DIFF, not a
    // payload, so a writer-derived key set is the wrong instrument for them.
    // They want a second guard, not a wider count here.
    // The two newest `affectedKeys` restrictions — the admin group rename and
    // the message read/delivery receipts — moved this total without touching
    // anything the per-entry comparisons below can see. That is the census
    // doing its job: a number that only ever moves for a reason.
    // BUT-1718 added two more of the same category, both inside
    // `removesOnlySelfFromMembers()` on `unified_shared_shopping_lists`: one
    // `affectedKeys().hasOnly([request.auth.uid])` over the member MAP's diff,
    // and one `affectedKeys().hasOnly(['memberPermissions', 'updatedAt'])` over
    // the document's. Both restrict a DIFF rather than a payload key set, so
    // neither is comparable against a writer's fields, and the nested one is
    // the first `diff()` in `firestore.rules` whose receiver is a map field
    // rather than the document.
    // BUT-1850 removed the `conversation_memberships` block, and its
    // `keys().hasOnly` went with it. Unlike the movers above, a removal in that
    // category also moves the `_allowlistCall` total asserted below.
    // Assert the FULL classification, not just this guard's slice. A rule
    // written as `let k = data.keys(); … k.hasOnly([...])` would slip past
    // `_allowlistCall` without moving its count; it cannot slip past the total.
    // P5-U26b added users/{uid}/overwritten_versions (keys().hasOnly on create),
    // guarded above in allowlists.
    // P5-U27b added recipe_suggestions: one keys().hasOnly on create (guarded
    // above in allowlists, writer RecipeSuggestion.toFirestore) and one
    // affectedKeys().hasOnly(['status', 'decidedAt']) on the owner's decision,
    // a diff restriction and so outside this guard's payload comparison.
    // Q6-12 = B added one more diff restriction there:
    // affectedKeys().hasOnly(['suggestion', 'replacedAt', 'expiresAt']) on
    // the suggester's replacement (writer
    // RecipeSuggestion.toReplacementFirestore), outside the payload
    // comparison for the same reason.
    // BUT-2151 added realtime_resources: one keys().hasOnly, guarded above in
    // allowlists.
    // BUT-2243 added rate_limits/imports: one keys().hasOnly, guarded above in
    // allowlists.
    // BUT-2115 added the recipe_comments reaction update: one keys().hasOnly
    // over the `reactions` MAP (in _knowinglyUncovered), one
    // affectedKeys().hasOnly(['reactions']) and one set difference.
    // BUT-907 added users/{uid}/trash: one keys().hasOnly on create, guarded
    // above in allowlists.
    // BUT-2321 removed the friend_categories field-only ownership transfer:
    // one affectedKeys().hasOnly(['ownerId', 'updatedAt']), a diff
    // restriction outside the payload comparison.
    // BUT-2118 added realtime_resources/{menuId}/votes: one keys().hasOnly,
    // guarded above in allowlists.
    // BUT-2013 added `adminManagesMembers()` on unified_shared_shopping_lists:
    // one values().hasOnly(['view', 'edit', 'admin']) over the member map's
    // permission levels, a value check rather than a key allowlist.
    // BUT-2339 added the moderator's dish removal on shared_content: one
    // affectedKeys().hasOnly(['menuSnapshot']), a diff restriction outside
    // the payload comparison.
    // BUT-643 added household nutrition choices: one
    // affectedKeys().hasOnly([key]) over the `nutritionFoodChoices` MAP's diff
    // in `nutritionChoiceWriteValid()`, and one
    // affectedKeys().hasOnly(['nutritionFoodChoices', 'nutritionChoiceKey',
    // 'updatedAt']) over the household document's on the member update. Both
    // are diff restrictions outside the payload comparison.
    // BUT-2089 added two on unified_shared_shopping_lists: the create's
    // memberPermissions.keys().hasOnly([request.auth.uid]) over the member
    // MAP (in _knowinglyUncovered), and addedKeys().hasOnly([ownerId]) in
    // `addsNoMember()`, a set difference outside the payload comparison.
    // BUT-643 follow-up added household nutrition amounts: one
    // value.keys().hasOnly(['a', 'u']) over one entry of the
    // `nutritionAmountChoices` map (in _knowinglyUncovered), one
    // affectedKeys().hasOnly([key]) over that map's diff, and one
    // affectedKeys().hasOnly(['nutritionAmountChoices', 'nutritionAmountKey',
    // 'updatedAt']) over the household document's on the member update. The
    // last two are diff restrictions outside the payload comparison.
    expect(
      'hasOnly('.allMatches(rules).length,
      58,
      reason:
          'the `hasOnly(` population changed. Reclassify the new call before '
          'touching this number — it counts `keys().hasOnly`, '
          '`affectedKeys().hasOnly`, `values().hasOnly` and set differences '
          'together, and this text is comment-stripped, which is the whole '
          'reason a commented-out allowlist cannot satisfy anything here. If '
          'the new one is a keys() allowlist written in a form the regex '
          'cannot see, this is the only assertion that says so. (A breakdown '
          'by category stood here and was wrong within a day of the next '
          'allowlist landing: it is the instruction somebody follows when this '
          'reddens, so a stale one sends them to "correct" the number back.)',
    );
    final total = _allowlistCall.allMatches(rules).length;
    // Resolve every excused allowlist against the file. A swap among the
    // uncovered ones leaves the total unchanged and is invisible to a count.
    // Both halves are needed: the block must still be there, AND it must still
    // carry a key constraint. Checking only the first passes over a rule that
    // kept its `match` line and lost its allowlist, which is the likelier edit.
    for (final u in _knowinglyUncovered) {
      final at = rules.indexOf(u.anchor);
      expect(
        at,
        isNot(-1),
        reason:
            'the knowingly-uncovered allowlist "${u.label}" is gone — its '
            'anchor "${u.anchor}" no longer appears in firestore.rules. If it '
            'was removed, drop its entry; if it was renamed, update the anchor. '
            'Do not leave the count matching over a list that is not there.',
      );

      // Bounded at the next `match `, so this cannot borrow a neighbour's
      // allowlist and report health that belongs to a different rule. The `!`
      // is safe: `rulesBlock` returns null on a missing anchor, and the
      // assertion above already refused that.
      final block = rulesBlock(rules, u.anchor)!;
      expect(
        // The same regex the census uses, not a literal — an intact constraint
        // written across two lines would otherwise redden here with a
        // confidently wrong message telling the reader to delete the entry.
        _allowlistCall.hasMatch(block),
        isTrue,
        reason:
            '"${u.label}" still exists but no longer carries a '
            '`keys().hasOnly(` — its writes are now unconstrained in shape, '
            'and the census total can stay put while a NEW allowlist ships '
            'unguarded elsewhere. Decide which happened; do not delete this '
            'entry to make the test pass.',
      );
    }

    expect(
      total,
      allowlists.length + _knowinglyUncovered.length,
      reason:
          'firestore.rules now has $total `keys().hasOnly(` allowlists; this '
          'guard accounts for ${allowlists.length} guarded + '
          '${_knowinglyUncovered.length} knowingly uncovered '
          '(${_knowinglyUncovered.map((u) => u.label).join('; ')}). A new one '
          'appeared, or one was '
          'removed. Decide which: add an Allowlist entry carrying the '
          "writer's key set, or add a line to _knowinglyUncovered naming it "
          'and its writer. Do not just make the number match.',
    );
  });

  for (final entry in allowlists) {
    test('${entry.label}: every key the writer sends is allowed by the rules', () {
      final allowed = _allowlistAfter(rules, entry.anchor, entry.mustContain);
      final sent = writtenKeys()[entry.label];
      expect(
        sent,
        isNotNull,
        reason:
            'no writtenKeys entry for "${entry.label}" — the label was renamed '
            'on one side only. Without this the failure is a bare null crash.',
      );
      final missing = sent!.difference(allowed);

      expect(
        missing,
        isEmpty,
        reason:
            'firestore.rules would DENY this write, silently, on every attempt.\n'
            '  writer:  ${entry.writer}\n'
            '  sends:   ${(sent.toList()..sort()).join(', ')}\n'
            '  allowed: ${(allowed.toList()..sort()).join(', ')}\n'
            '  MISSING: ${(missing.toList()..sort()).join(', ')}\n'
            'Add the field to the allowlist, or stop sending it. Do not delete '
            'this expectation.',
      );
    });
  }
}
