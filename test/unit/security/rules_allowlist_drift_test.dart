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
/// The review of that fix then found four more live drifts and one latent.
///
/// So this test compares an allowlist against the keys the writer ACTUALLY
/// SENDS, and it derives those keys by calling the model rather than retyping
/// them — retyping is the mechanism that let all five through, including the
/// hand-written fixture in the rules suite that was supposed to catch it.
///
/// **It does not cover every allowlist.** Five of the entries here are the ones
/// an actual drift was found in:
/// `isValidTagResult`, `counters`, `conversation_memberships`,
/// `notification_history` and the deep-link `clicks`. The remaining two,
/// `participants` and the poll vote, never drifted and could not have — each
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
/// **Scope, stated honestly: FOUR of the seven key sets are hand-assembled**,
/// not derived, because their writer builds its map inline in a repository with
/// no model to call — the notification-history row, the deep-link click, the
/// poll vote, and the share counters. The counters entry looks derived and is
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
/// **NOT COVERED, and the omission is not implied by the name:** the MIRROR
/// family. `firestore.rules` also guards writes with `keys().hasAll([...])` and
/// `hasRequiredFields([...])`, and a model that STOPS emitting a required key is
/// denied exactly as silently as one that adds an unknown key. This guard's
/// `sent` ⊆ `allowed` direction structurally cannot see that. It wants its own
/// test with the comparison the other way round — recorded in `tasks/todo.md`
/// and filed as BUT-1823, not built here, because one red must keep meaning one
/// thing.
///
/// **ALSO NOT COVERED, a different question entirely:** this guard proves an
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

import 'package:butlery/models/messaging/conversation_membership.dart';
import 'package:butlery/models/messaging/conversation_participant.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/user_counters.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// One `hasOnly([...])` list, located by the text that uniquely precedes it.
class _Allowlist {
  const _Allowlist({
    required this.label,
    required this.anchor,
    required this.mustContain,
    required this.writer,
  });

  /// What a failure should say out loud.
  final String label;

  /// A snippet appearing in `firestore.rules` shortly BEFORE the `hasOnly(`
  /// that belongs to this write. Anchoring on the enclosing `match` path is not
  /// enough — several blocks carry more than one allowlist.
  final String anchor;

  /// A key that pins WHICH list was extracted. Not necessarily globally unique
  /// — `timestamp` also appears in `notification_engagement`'s list and
  /// `notificationId` in three — so this catches a rebind to a NEARBY list,
  /// which is the failure mode that exists (the extractor scans forward from
  /// the anchor), not any conceivable mix-up. A future entry must not pick a
  /// sentinel shared with the list its anchor would scan into.
  final String mustContain;

  /// Where the payload is built, so a reader can check the other side.
  final String writer;
}

const _allowlists = <_Allowlist>[
  _Allowlist(
    label: 'recipes: core.tagResult',
    mustContain: 'generatorVersion',
    anchor: 'function isValidTagResult',
    writer: 'lib/models/tagging/tag_result.dart TagResult.toFirestore',
  ),
  _Allowlist(
    label: 'users/{uid}/counters',
    mustContain: 'totalSharedContent',
    anchor: 'match /counters/{counterId}',
    writer:
        'lib/repositories/firebase/base_shared_content_repository.dart — '
        'incrementUnreadCounter, decrementUnreadCounter, and the recalculate '
        'path (named, not line-numbered: the line numbers were already off by '
        'one, and a method name survives the edits a number does not)',
  ),
  _Allowlist(
    label: 'users/{uid}/conversation_memberships',
    mustContain: 'conversationTitle',
    anchor: 'match /conversation_memberships/{conversationId}',
    writer: 'lib/models/messaging/conversation_membership.dart toFirestore',
  ),
  _Allowlist(
    label: 'conversations/{id}/participants',
    mustContain: 'displayName',
    anchor: 'match /participants/{participantId}',
    writer: 'lib/models/messaging/conversation_participant.dart toFirestore',
  ),
  _Allowlist(
    label: 'notification_history',
    mustContain: 'notificationId',
    anchor: 'match /notification_history/{notificationId}',
    writer:
        'lib/repositories/firebase/firebase_notification_history_repository.dart '
        'recordNotification (create), plus the markNotificationDelivered and '
        'markNotificationOpened updates',
  ),
  _Allowlist(
    label: 'deep_links/{linkId}/clicks',
    mustContain: 'timestamp',
    anchor: 'match /clicks/{clickId}',
    writer:
        'lib/repositories/firebase/firebase_deeplink_repository.dart '
        'trackUrlClick — the clicks .add after the counter update',
  ),
  // Anchored on the FUNCTION, not the `match /poll_votes/{voterId}` block: the
  // block declares `pollMessage()`, `inPollConversation()` and `pollIsOpen()`
  // above `isValidVote()`, and a forward-scanning extractor anchored on the
  // match line would bind to whichever of them acquires a `hasOnly` first.
  //
  // Both probes measured, because a guard nobody reddened is a hypothesis:
  // dropping `votedAt` from the rules list reddens the comparison naming the
  // missing key, and dropping `optionIds` reddens the sentinel instead, whose
  // message says "pointing at the WRONG list". That second message is the
  // wrong diagnosis for a real deletion — true of every sentinel in this file,
  // not of this entry alone. It still prints the extracted list, so a reader
  // sees what happened; a better instrument would be a separate assertion, not
  // a sentinel chosen to dodge the overlap.
  _Allowlist(
    label: 'messages/{messageId}/poll_votes',
    mustContain: 'optionIds',
    anchor: 'function isValidVote',
    writer:
        'lib/repositories/firebase/modules/message_mutation_module.dart '
        'votePoll — the transaction.set at the end of the method (named, not '
        'line-numbered: a method name survives the edits a line number does '
        'not)',
  ),
];

/// The keys each writer really sends.
///
/// Derived by calling the model where one exists. The hand-assembled sets carry
/// their writer's file and method in [_allowlists] instead.
Map<String, Set<String>> _writtenKeys() => {
  // WIDEST set, not a convenient one. `TagResult.empty()` leaves
  // `configRevision` and `errorReason` null, and `toFirestore` emits both only
  // when non-null — so a fixture built from `empty()` derives a 10-key set with
  // no `configRevision` in it, and this guard would stay GREEN while the exact
  // three-week outage it exists to prevent was live again. Caught in review,
  // then mutation-tested: remove `configRevision` from the allowlist and this
  // entry reddens.
  'recipes: core.tagResult': TagResult(
    tags: const <String>{},
    allergenStatus: const <String, TriState>{},
    dietaryStatus: const <String, TriState>{},
    coverage: 1,
    generatedAt: DateTime(2026),
    generatorVersion: 'test',
    errorReason: 'x',
    configRevision: 1,
    // NON-EMPTY on purpose. An empty list would be the NARROWEST non-null value,
    // and the emission shape this is meant to see is
    // `decisions != null && decisions!.isNotEmpty` — which an empty list fails,
    // so the guard would derive a key set without `decisions` and stay green.
    // `toJson` still uses that exact shape, and it is what anyone re-adding the
    // Firestore emission would copy.
    //
    // What this does NOT reach, stated so nobody assumes otherwise: the removed
    // `includeDecisions` parameter defaulted to FALSE and this guard calls
    // `toFirestore()` bare, so no fixture here can catch that parameter coming
    // back — `tag_result_test.dart` calls `toFirestore()` bare too, so nothing
    // guards that shape either. What the two DO split is the allowlist: this
    // entry catches a re-added emission only while `decisions` is absent from
    // `isValidTagResult`; widen the allowlist and this goes green while
    // `tag_result_test.dart` stays red.
    //
    // The first version of this fixture was an empty list under a comment
    // claiming it caught exactly the edit it cannot — the same "convenient set,
    // not the widest set" mistake this file already records making twice.
    decisions: const [
      TagDecision(
        type: 'allergen',
        key: 'gluten',
        result: TriState.free,
        reason: 'fixture',
      ),
    ],
  ).toFirestore().keys.toSet(),
  'users/{uid}/conversation_memberships': ConversationMembership(
    conversationId: 'c',
    conversationTitle: 't',
    isGroup: false,
    lastActivityAt: DateTime(2026),
    joinedAt: DateTime(2026),
  ).toFirestore().keys.toSet(),
  // avatarUrl is emitted only when non-null, so the fixture carries one: the
  // guard has to compare against the WIDEST set the writer can send, not the
  // narrowest.
  'conversations/{id}/participants': ConversationParticipant(
    conversationId: 'c',
    participantId: 'u',
    displayName: 'n',
    avatarUrl: 'https://example.com/a.png',
    joinedAt: DateTime(2026),
    lastReadAt: DateTime(2026),
  ).toFirestore().keys.toSet(),
  // Field names derived, key SET retyped — see the scope note in the header.
  // `incrementUnreadCounter` sends
  // `fieldForType(counterTypeKey)`, and THREE subclasses supply a different
  // key, so naming only `unreadSharedRecipes` left the menu and shopping fields
  // unguarded — remove either from the rules and this stayed green while that
  // badge silently stopped moving. Which is D1 verbatim, in the collection D1
  // was found in. Caught in review; the same "convenient set, not the widest
  // set" mistake as the first tagResult fixture.
  // RESIDUAL, stated because the same mistake was already made twice above: the
  // three type STRINGS are still typed by hand, so a FOURTH
  // `BaseSharedContentRepository` subclass produces a field this guard never
  // asks about. There are exactly three today, re-verified 2026-08-12.
  //
  // A typo in an existing `counterTypeKey` is NOT that residual, though an
  // earlier version of this comment said it was: `fieldForType` ends in
  // `throw ArgumentError`, and `incrementUnreadCounter` wraps the call in a
  // best-effort try/catch — so a typo throws before any write and sends no
  // field at all. Different failure (the badge silently stops moving, nothing
  // is denied), and not one this guard is the instrument for.
  'users/{uid}/counters': {
    for (final type in const [
      'shared_recipes',
      'shared_menus',
      'shared_shopping_lists',
    ])
      UserCounterIncrements.fieldForType(type),
    UserCounterIncrements.totalSharedContent,
    'lastUpdated',
  },
  // Hand-built maps — no model to derive from. See the writer in _allowlists.
  'notification_history': {
    'userId',
    'notificationId',
    'category',
    'type',
    'data',
    'sentAt',
    'delivered',
    'opened',
    'deliveredAt',
    'openedAt',
    'expireAt',
  },
  'deep_links/{linkId}/clicks': {'userId', 'timestamp'},
  // `votePoll` writes the row with a bare `set` — no merge — so the keys the
  // rule sees are exactly these three and nothing widens them elsewhere. The
  // other branch of the method DELETES the row when the last option is
  // deselected, and a delete carries no `request.resource.data`, so it cannot
  // contribute a key. `voterId` duplicates the document id deliberately: the
  // Art. 17 sweep queries by field, and `hasOnly` cannot see a document id.
  'messages/{messageId}/poll_votes': {
    'voterId',
    'optionIds',
    'votedAt',
  },
};

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
];

/// Matches the allowlist form this guard covers, tolerating the line wrap the
/// file already uses elsewhere (`affectedKeys()` then `.hasOnly(` on the next
/// line). A plain substring count would miss a wrapped new list entirely,
/// leaving the census green while the thing it exists to catch walked past.
final _allowlistCall = RegExp(r'\.keys\(\)\s*\.hasOnly\(');

/// Removes block and line comments so no assertion can be satisfied by prose.
///
/// The `[^:]` guard on the line-comment pattern keeps a `://` inside a URL from
/// being eaten. `firestore.rules` currently contains no URL, so it is belt and
/// braces — and cheaper than discovering the exception later.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAllMapped(
      RegExp(r'(^|[^:])//.*$', multiLine: true),
      (m) => m.group(1)!,
    );

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
    rules = _withoutComments(File('firestore.rules').readAsStringSync());
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
    // Assert the FULL classification, not just this guard's slice. A rule
    // written as `let k = data.keys(); … k.hasOnly([...])` would slip past
    // `_allowlistCall` without moving its count; it cannot slip past the total.
    expect(
      'hasOnly('.allMatches(rules).length,
      34,
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
      // allowlist and report health that belongs to a different rule.
      final nextMatch = rules.indexOf('match ', at + u.anchor.length);
      final block = rules.substring(
        at,
        nextMatch == -1 ? rules.length : nextMatch,
      );
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
      _allowlists.length + _knowinglyUncovered.length,
      reason:
          'firestore.rules now has $total `keys().hasOnly(` allowlists; this '
          'guard accounts for ${_allowlists.length} guarded + '
          '${_knowinglyUncovered.length} knowingly uncovered '
          '(${_knowinglyUncovered.map((u) => u.label).join('; ')}). A new one '
          'appeared, or one was '
          'removed. Decide which: add an _Allowlist entry carrying the '
          "writer's key set, or add a line to _knowinglyUncovered naming it "
          'and its writer. Do not just make the number match.',
    );
  });

  for (final entry in _allowlists) {
    test('${entry.label}: every key the writer sends is allowed by the rules', () {
      final allowed = _allowlistAfter(rules, entry.anchor, entry.mustContain);
      final sent = _writtenKeys()[entry.label];
      expect(
        sent,
        isNotNull,
        reason:
            'no _writtenKeys entry for "${entry.label}" — the label was renamed '
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
