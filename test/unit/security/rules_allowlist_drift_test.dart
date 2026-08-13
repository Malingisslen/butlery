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
/// **It does not cover every allowlist.** `firestore.rules` carries twelve. Five
/// of the six here are the ones an actual drift was found in: `isValidTagResult`,
/// `counters`, `conversation_memberships`, `notification_history` and the
/// deep-link `clicks`. The sixth, `participants`, never drifted and could not
/// have — its `match` block is NEW in this same sprint, so those writes were
/// failing on default-deny, not on a stale allowlist. It is guarded here because
/// a brand-new allowlist is the likeliest of all to drift next.
///
/// The other six were each checked against their writer on 2026-08-12 and none
/// had drifted — but "checked once" is not "guarded", which is why the census
/// test below fails the moment a thirteenth appears, forcing a decision instead
/// of a silent omission.
///
/// **Scope, stated honestly: THREE of the six key sets are hand-assembled**, not
/// derived, because their writer builds its map inline in a repository with no
/// model to call — the notification-history row, the deep-link click, and the
/// share counters. The counters entry looks derived and is only half so: the
/// field NAMES come from `UserCounterIncrements`, but WHICH keys the writer
/// sends is read off `base_shared_content_repository.dart` and retyped, so
/// adding a key to that `set({...})` leaves this guard green. Each of the three
/// names its writer's file and line for that reason. Genuinely deriving the
/// counters set means driving `incrementUnreadCounter` against a fake Firestore
/// and reading the written document back; worth doing, not done here.
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
        'lib/repositories/firebase/firebase_notification_history_repository.dart'
        ':92 (create), plus the markNotificationDelivered / '
        'markNotificationOpened updates below it',
  ),
  _Allowlist(
    label: 'deep_links/{linkId}/clicks',
    mustContain: 'timestamp',
    anchor: 'match /clicks/{clickId}',
    writer: 'lib/repositories/firebase/firebase_deeplink_repository.dart:203',
  ),
];

/// The keys each writer really sends.
///
/// Derived by calling the model where one exists. The two hand-built maps carry
/// their writer's line in [_allowlists] instead.
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

/// Allowlists deliberately not compared here. Each was read against its writer
/// on 2026-08-12 and none had drifted.
///
/// Each carries an ANCHOR, and the census asserts that the anchor still appears
/// AND that its block still carries a `keys().hasOnly(` — checked up to the next
/// `match `, so a surviving block that quietly lost its key constraint is caught
/// too, whether it was deleted or commented out (the source is comment-stripped
/// before any assertion reads it; see `setUpAll`). Without both halves the census is a bare count: delete one uncovered
/// allowlist and add another in the same commit and the total is unchanged, so
/// the guard stays green over a list nobody has ever compared.
///
/// Two earlier versions of this docstring were wrong about its own strength.
/// The first claimed NAMING the six was enough to survive a swap; names never
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

  test('every keys().hasOnly allowlist is guarded here or knowingly excluded', () {
    // The census. Without it, a thirteenth allowlist lands unguarded and
    // nothing says so — which is precisely how the five drifts of 2026-08-12
    // happened, one silent omission at a time.
    // Scope: `keys().hasOnly` only. Of the 30 `hasOnly(` calls in the file, 12
    // are this form; 14 are `affectedKeys().hasOnly` update restrictions, one
    // is `values().hasOnly`, two are set differences and one sits in a comment.
    // The update restrictions deny just as silently, but they pin a DIFF, not a
    // payload, so a writer-derived key set is the wrong instrument for them.
    // They want a second guard, not a wider count here.
    // Assert the FULL classification, not just this guard's slice. A rule
    // written as `let k = data.keys(); … k.hasOnly([...])` would slip past
    // `_allowlistCall` with the count still 12; it cannot slip past the total.
    expect(
      'hasOnly('.allMatches(rules).length,
      29,
      reason:
          'the `hasOnly(` population changed. Reclassify before touching the '
          'numbers below: 12 keys().hasOnly + 14 affectedKeys().hasOnly + 1 '
          'values().hasOnly + 2 set differences. (29, not 30: the file also '
          'carries one inside a COMMENT, and this text is comment-stripped — '
          'which is the whole reason a commented-out allowlist cannot satisfy '
          'anything here.) If the new one is a keys() allowlist written in a '
          'form the regex cannot see, this is the only assertion that says so.',
    );
    final total = _allowlistCall.allMatches(rules).length;
    // Resolve every excused allowlist against the file. A swap among the six
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
