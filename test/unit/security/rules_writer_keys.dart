/// The writer side of the rules drift guards: each `hasOnly` allowlist in
/// `firestore.rules` paired with the keys its writer really sends.
///
/// Shared by `rules_allowlist_drift_test.dart` (every key sent is allowed) and
/// `rules_required_fields_drift_test.dart` (every key the rules require is
/// sent), so the two directions read ONE copy of the writer's key set instead
/// of two that can drift apart.
library;

import 'package:butlery/models/acquisition_attribution.dart';
import 'package:butlery/models/admin/signup_invite.dart';
import 'package:butlery/models/messaging/conversation_participant.dart';
import 'package:butlery/models/realtime/menu_ballot.dart';
import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/models/trash_item.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/user_counters.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/repositories/firebase/firebase_signup_allowlist_repository.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import '../../infrastructure/mocks/production_mocks.dart';

/// One `hasOnly([...])` list, located by the text that uniquely precedes it.
class Allowlist {
  const Allowlist({
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

const allowlists = <Allowlist>[
  Allowlist(
    label: 'recipes: core.tagResult',
    mustContain: 'generatorVersion',
    anchor: 'function isValidTagResult',
    writer: 'lib/models/tagging/tag_result.dart TagResult.toFirestore',
  ),
  Allowlist(
    label: 'users/{uid}/overwritten_versions',
    mustContain: 'overwrittenByName',
    anchor: 'match /users/{userId}/overwritten_versions/{versionId}',
    writer:
        'lib/models/realtime/overwritten_version.dart OverwrittenVersion.toFirestore, '
        'stored by FirebaseOverwrittenVersionRepository (P5-U26b)',
  ),
  Allowlist(
    label: 'users/{uid}/trash',
    mustContain: 'sourceId',
    anchor: 'match /users/{userId}/trash/{itemId}',
    writer:
        'lib/models/trash_item.dart TrashItem.toFirestore, stored by '
        'FirebaseTrashRepository in the batch that deletes the recipe (BUT-907)',
  ),
  Allowlist(
    label: 'recipe_suggestions',
    mustContain: 'suggesterId',
    anchor: 'match /recipe_suggestions/{suggestionId}',
    writer:
        'lib/models/recipe_suggestion.dart RecipeSuggestion.toFirestore, '
        'stored by FirebaseRecipeSuggestionRepository.suggest (P5-U27b)',
  ),
  Allowlist(
    label: 'users/{uid}/counters',
    mustContain: 'totalSharedContent',
    anchor: 'match /counters/{counterId}',
    writer:
        'lib/repositories/firebase/base_shared_content_repository.dart — '
        'incrementUnreadCounter, decrementUnreadCounter, and the recalculate '
        'path (named, not line-numbered: the line numbers were already off by '
        'one, and a method name survives the edits a number does not)',
  ),
  Allowlist(
    label: 'conversations/{id}/participants',
    mustContain: 'displayName',
    anchor: 'match /participants/{participantId}',
    writer: 'lib/models/messaging/conversation_participant.dart toFirestore',
  ),
  Allowlist(
    label: 'notification_history',
    mustContain: 'notificationId',
    anchor: 'match /notification_history/{notificationId}',
    writer:
        'lib/repositories/firebase/firebase_notification_history_repository.dart '
        'recordNotification (create), plus the markNotificationDelivered and '
        'markNotificationOpened updates',
  ),
  Allowlist(
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
  Allowlist(
    label: 'messages/{messageId}/poll_votes',
    mustContain: 'optionIds',
    anchor: 'function isValidVote',
    writer:
        'lib/repositories/firebase/modules/message_mutation_module.dart '
        'votePoll — the transaction.set at the end of the method (named, not '
        'line-numbered: a method name survives the edits a line number does '
        'not)',
  ),
  // BUT-2079. Anchored on the block: the create limb's list is the first
  // `hasOnly(` in each, and the sentinel is a key the update limbs' lists
  // below it do not carry.
  Allowlist(
    label: 'recipe_comments create',
    mustContain: 'authorDisplayName',
    anchor: 'match /recipe_comments/{commentId}',
    writer:
        'lib/repositories/firebase/comments/comment_creation.dart '
        '_commentData — the map and its two conditional keys',
  ),
  Allowlist(
    label: 'recipe_ratings create',
    mustContain: 'createdAt',
    anchor: 'match /recipe_ratings/{ratingId}',
    writer:
        'lib/repositories/firebase/firebase_ratings_repository.dart '
        'rateRecipe — the map batched onto docRef',
  ),
  // Anchored on the helper, which holds the block's only `keys().hasOnly`; the
  // create and update limbs both call it.
  Allowlist(
    label: 'household_allergen_shares',
    mustContain: 'includeUnknownInMenu',
    anchor: 'function allergenShareValid',
    writer: 'lib/models/household_allergen_share.dart toFirestore',
  ),
  // Anchored on the helper, which holds the block's only `keys().hasOnly`; the
  // create and update limbs both call it.
  Allowlist(
    label: 'realtime_resources (menu)',
    mustContain: 'menuSnapshot',
    anchor: 'function realtimeResourceShapeOk',
    writer:
        'lib/models/realtime/realtime_menu.dart RealtimeMenu.toFirestore, '
        'written whole by ConflictResolutionModule.performUpdate (BUT-2151)',
  ),
  // Anchored on the helper, which holds the block's only `keys().hasOnly`; the
  // create and update limbs both call it.
  Allowlist(
    label: 'realtime_resources/{menuId}/votes',
    mustContain: 'proposals',
    anchor: 'function voteShapeOk',
    writer:
        'lib/repositories/firebase/firebase_menu_voting_repository.dart '
        'toFirestore — MenuBallot.toFirestore plus the retention stamp '
        '(BUT-2118)',
  ),
  // BUT-2243: the block now holds two lists, the `imports` one first.
  Allowlist(
    label: 'users/{uid}/rate_limits stamp',
    mustContain: 'lastDocId',
    anchor: "type != 'llm_cost'",
    writer: 'lib/repositories/firebase/rate_limit_stamp.dart stampRateLimit',
  ),
  Allowlist(
    label: 'users/{uid}/rate_limits/imports',
    mustContain: 'importsThisMinute',
    anchor: 'match /rate_limits/{type}',
    writer:
        'lib/services/import/models/rate_limit_models.dart '
        'UsageLimits.toFirestore, written whole by ImportRateLimiter.recordUsage',
  ),
  // BUT-1997. The block's only `keys().hasOnly`, on the create limb.
  Allowlist(
    label: 'users/{uid}/acquisition create',
    mustContain: 'firstSeenAt',
    anchor: 'match /users/{userId}/acquisition/{acquisitionDoc}',
    writer:
        'lib/models/acquisition_attribution.dart AcquisitionAttribution.toFirestore',
  ),
  // BUT-2452. The block's only `keys().hasOnly`, on the create limb.
  Allowlist(
    label: 'signup_allowlist create',
    mustContain: 'invitedBy',
    anchor: 'match /signup_allowlist/{email}',
    writer:
        'lib/repositories/firebase/firebase_signup_allowlist_repository.dart '
        'FirebaseSignupAllowlistRepository.toFirestore',
  ),
];

/// The keys each writer really sends.
///
/// Derived by calling the model where one exists. The hand-assembled sets carry
/// their writer's file and method in [allowlists] instead.
Map<String, Set<String>> writtenKeys() => {
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
  // Derived from the model, so a new field in toFirestore reddens here.
  'users/{uid}/overwritten_versions': OverwrittenVersion(
    id: 'v',
    ownerId: 'u',
    entity: ConflictEntity.values.first,
    resourceType: RealtimeResourceType.values.first,
    resourceId: 'r',
    version: const <String, dynamic>{},
    overwrittenBy: 'o',
    overwrittenByName: 'O',
    overwrittenAt: DateTime.utc(2026),
    expiresAt: DateTime.utc(2026, 1, 31),
  ).toFirestore().keys.toSet(),
  // BUT-907. Derived from the model, so a new field in toFirestore reddens
  // here. `thumbnailUrl` is set so a writer that drops a null key still
  // sends it.
  'users/{uid}/trash': TrashItem(
    id: 'r',
    kind: TrashItemKind.recipe,
    ownerId: 'u',
    sourceId: 'r',
    title: 'T',
    thumbnailUrl: 't',
    payload: const <String, dynamic>{},
    deletedAt: DateTime.utc(2026),
    expireAt: DateTime.utc(2026, 1, 31),
  ).toFirestore().keys.toSet(),
  // P5-U27b. Derived from the model, so a new field in toFirestore reddens
  // here. The owner's decision is an `affectedKeys().hasOnly` diff
  // (status, decidedAt), not a payload, so it is counted in the census below
  // and not compared here.
  'recipe_suggestions': RecipeSuggestion.create(
    recipeId: 'r',
    ownerId: 'o',
    suggesterId: 's',
    suggestion: const <String, dynamic>{},
    at: DateTime.utc(2026),
  ).toFirestore().keys.toSet(),
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
  // Hand-built maps — no model to derive from. See the writer in allowlists.
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
  // Hand-built maps, the widest each writer can send: `recipeOwnerId` and
  // `imageUrls` are emitted only when populated, `createdAt` only on a new row.
  'recipe_comments create': {
    'recipeId',
    'authorId',
    'authorDisplayName',
    'text',
    'parentCommentId',
    'createdAt',
    'updatedAt',
    'isDeleted',
    'likesCount',
    'replyCount',
    'sharedWithUserIds',
    'recipeOwnerId',
    'imageUrls',
  },
  'recipe_ratings create': {
    'recipeId',
    'userId',
    'rating',
    'review',
    'recipeOwnerId',
    'createdAt',
    'updatedAt',
  },
  // Both dates set: `toFirestore` omits each when null, and the guard needs
  // the widest set the writer can send.
  'household_allergen_shares': HouseholdAllergenShare(
    householdId: 'h',
    userId: 'u',
    trackedAllergens: const {'gluten'},
    trackedDietary: const {},
    includeUnknownInMenu: false,
    consentGranted: true,
    consentVersion: 'v1',
    consentGrantedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ).toFirestore().keys.toSet(),
  // Hand-built map; `stampRateLimit` is its only writer.
  'users/{uid}/rate_limits stamp': {'lastWrite', 'expireAt', 'lastDocId'},
  // Every key is emitted unconditionally, so the default instance is already
  // the widest set.
  'users/{uid}/rate_limits/imports': const UsageLimits()
      .toFirestore()
      .keys
      .toSet(),
  // Every key is emitted unconditionally.
  'users/{uid}/acquisition create': const AcquisitionAttribution(
    source: 's',
    medium: 'm',
    campaign: 'c',
  ).toFirestore().keys.toSet(),
  // Every optional argument set, so the set is the widest the writer sends.
  'realtime_resources (menu)': RealtimeMenu.fromMenuCategories(
    menuTitle: 'm',
    menuSnapshot: const {},
    ownerId: 'o',
    ownerDisplayName: 'O',
    editorUserIds: const ['e'],
    viewerUserIds: const ['v'],
    menuNotes: 'n',
    favoriteRecipeIds: const ['f'],
    originalPrompt: 'p',
    createdForDate: DateTime(2026),
  ).toFirestore().keys.toSet(),
  // The model's keys are derived; the two stamp keys are added in the
  // repository's toFirestore and retyped here.
  'realtime_resources/{menuId}/votes': {
    ...const MenuBallot(userId: 'u').toFirestore().keys,
    'updatedAt',
    'expireAt',
  },
  // The repository builds the payload and stamps the caller's uid, so it needs
  // a signed-in fake behind it.
  'signup_allowlist create': () {
    final auth = FakeAuthRepository()
      ..setAuthState(
        user: FakeUser(uid: 'a', displayName: 'A'),
        userId: 'a',
        isAuthenticated: true,
      );
    return FirebaseSignupAllowlistRepository(
      firestore: FakeFirebaseFirestore(),
      authRepository: auth,
    ).toFirestore(const SignupInvite(email: 'x@example.com')).keys.toSet();
  }(),
};
