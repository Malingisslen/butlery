/// Emulator-lane test: pantry, personal shopping-list, week menu, recipe
/// comment, profile and chat saves made without a connection (BUT-2287,
/// BUT-2288, BUT-2289, BUT-2363, BUT-2290, BUT-2291).
///
/// Firestore keeps an offline write in its own queue and sends it on
/// reconnect, but the write's future only settles when the server answers.
/// The fake settles every write at once, so only a real Firestore with its
/// network switched off can show whether a save returns while offline.
///
/// Mock tier skips the group; the emulator tier runs it on an Android
/// emulator through `integration_test/emulator_lane_test.dart`.
@Tags(['integration', 'firebase'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';
import 'package:butlery/repositories/firebase/modules/message_mutation_module.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/messaging/message_reactions_service.dart';
import 'package:butlery/repositories/firebase/firebase_pantry_repository.dart';
import 'package:butlery/repositories/firebase/firebase_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/firebase/modules/shopping_item_operations_module.dart';
import 'package:butlery/services/attribution_source.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_support/emulator_lane.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

const _uid = 'alice';
const _listId = 'veckohandling';

/// Long enough for every save below to wait out its patience, short enough
/// that a save waiting for the server fails the test instead of the lane.
const _offlineBudget = Duration(seconds: 15);

FakeAuthRepository _signedIn() => FakeAuthRepository()
  ..setAuthState(
    user: FakeUser(uid: _uid, displayName: _uid),
    userId: _uid,
    isAuthenticated: true,
  );

UnifiedShoppingItem _row(String id, {bool bought = false}) =>
    UnifiedShoppingItem(
      id: id,
      name: id,
      amount: 1,
      unit: 'st',
      category: ShoppingCategory.other,
      bought: bought,
    );

ShoppingItemOperationsModule _shopping(
  FirebaseFirestore firestore,
  UnifiedShoppingList list,
) {
  final auth = FakeAuthRepository()
    ..setAuthState(
      user: FakeUser(uid: _uid, displayName: _uid),
      userId: _uid,
      isAuthenticated: true,
    );
  return ShoppingItemOperationsModule(
    firestore: firestore,
    authRepository: auth,
    requireCurrentUserId: () => _uid,
    readList: (_) async => list,
    mutateCollaborativeList: (_, _) =>
        throw StateError('a personal list never takes the shared path'),
    getUserCollection: (userId) => firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.unifiedShoppingLists),
    validateOwnership:
        ({
          required String currentUserId,
          required String resourceOwnerId,
          required String resourceType,
          required String resourceId,
        }) async {},
    validateRequiredFields:
        ({
          required Map<String, dynamic> data,
          required List<String> requiredFields,
          required String resourceType,
        }) {},
    logPermissionCheck:
        ({
          required String userId,
          required String resource,
          required String operation,
          required bool granted,
          String? details,
        }) async {},
    resolveDisplayName: () => _uid,
  );
}

void main() {
  group('saves made without a connection (emulator)', () {
    late FirebaseFirestore firestore;

    setUp(() async {
      firestore = await firestoreForLane();
      await clearLane();
    });

    // The lane shares one Firestore instance across suites.
    tearDown(() => firestore.enableNetwork());

    test(
      'pantry: add, change amount, edit and remove return offline and reach the '
      'server on reconnect',
      () async {
        final repo = FirebasePantryRepository(firestore: firestore);
        final pantry = firestore
            .collection(FirestoreCollections.users)
            .doc(_uid)
            .collection(FirestoreCollections.pantry);
        await repo.add(
          _uid,
          PantryItem(
            id: 'gone',
            ingredientName: 'Gammal mjölk',
            quantity: 1,
            unit: 'l',
            location: PantryLocation.fridge,
            addedAt: DateTime.utc(2026, 10, 10),
          ),
        );

        await firestore.disableNetwork();
        await repo
            .add(
              _uid,
              PantryItem(
                id: 'ris',
                ingredientName: 'Ris',
                quantity: 2,
                unit: 'kg',
                location: PantryLocation.pantry,
                addedAt: DateTime.utc(2026, 10, 10),
              ),
            )
            .timeout(_offlineBudget);
        await repo.adjustQuantity(_uid, 'ris', 1).timeout(_offlineBudget);
        await repo
            .updateFields(_uid, 'ris', {
              'note': 'Jasmin',
            })
            .timeout(_offlineBudget);
        await repo.remove(_uid, 'gone').timeout(_offlineBudget);

        final cached = await pantry
            .doc('ris')
            .get(const GetOptions(source: Source.cache));
        expect(cached.data()?['quantity'], 3);
        expect(cached.data()?['note'], 'Jasmin');

        await firestore.enableNetwork();
        await firestore.waitForPendingWrites();
        final server = await pantry.get(
          const GetOptions(source: Source.server),
        );
        expect(
          {
            for (final d in server.docs)
              d.id: (d.data()['quantity'], d.data()['note']),
          },
          {'ris': (3, 'Jasmin')},
        );
      },
    );

    test(
      'personal list: add, add several, tick and remove return offline and reach the '
      'server on reconnect',
      () async {
        final list = UnifiedShoppingList(
          id: _listId,
          name: 'Veckohandling',
          ownerId: _uid,
          ownerDisplayName: _uid,
          // An earlier day, so each write also stamps the list's day.
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        final parent = firestore
            .collection(FirestoreCollections.users)
            .doc(_uid)
            .collection(FirestoreCollections.unifiedShoppingLists)
            .doc(_listId);
        await parent.set(list.toFirestore());
        final shopping = _shopping(firestore, list);
        await shopping.addItem(_listId, _row('bröd'));

        await firestore.disableNetwork();
        await shopping.addItem(_listId, _row('mjölk')).timeout(_offlineBudget);
        await shopping
            .addItemsBatch(_listId, [_row('ägg'), _row('smör')])
            .timeout(_offlineBudget);
        await shopping
            .updateItem(
              _listId,
              _row('mjölk', bought: true),
              before: _row('mjölk'),
            )
            .timeout(_offlineBudget);
        await shopping
            .removeItem(_listId, 'bröd', removed: _row('bröd'))
            .timeout(_offlineBudget);

        await firestore.enableNetwork();
        await firestore.waitForPendingWrites();
        final rows = await parent
            .collection(FirestoreCollections.items)
            .get(const GetOptions(source: Source.server));
        expect(
          {for (final d in rows.docs) d.id: d.data()['bought']},
          {'mjölk': true, 'ägg': false, 'smör': false},
        );
      },
    );

    test(
      'week menu: a save from outside the calendar returns offline and reaches '
      'the server on reconnect',
      () async {
        final repo = FirebaseWeeklyMenuPlanRepository(
          firestore: firestore,
          authRepository: _signedIn(),
        );
        final service = WeeklyMenuPlanService(
          repository: repo,
          userService: MockUserService(),
        );
        final week = WeeklyMenuPlan.empty(
          userId: _uid,
          date: DateTime.utc(2026, 10, 12),
        );

        await firestore.disableNetwork();
        await service
            .save(
              week.copyWith(
                entries: [
                  WeeklyMenuPlanEntry.create(
                    day: DayOfWeek.mon,
                    slot: MealSlot.middag,
                    recipeId: 'r1',
                    recipeTitle: 'Pannkakor',
                  ),
                ],
              ),
            )
            .timeout(_offlineBudget);

        await firestore.enableNetwork();
        await firestore.waitForPendingWrites();
        final server = await firestore
            .collection(FirestoreCollections.weeklyMenuPlans)
            .doc(week.id)
            .get(const GetOptions(source: Source.server));
        expect(
          WeeklyMenuPlan.fromMap(
            server.id,
            server.data()!,
          ).entries.map((e) => e.recipeId),
          ['r1'],
        );
      },
    );

    test(
      'recipe comment: posting returns offline and reaches the server on '
      'reconnect',
      () async {
        final users = MockUserService();
        when(() => users.attributionDisplayName).thenReturn(_uid);
        final repo = FirebaseCommentsRepository(
          firestore: firestore,
          authRepository: _signedIn(),
          attribution: AttributionSource(userService: () => users),
        );

        await firestore.disableNetwork();
        final posted = await repo
            .addComment(recipeId: 'r1', userId: _uid, content: 'Gott!')
            .timeout(_offlineBudget);
        expect(posted.text, 'Gott!');
        // The 5 s burst guard would refuse a second queued comment on
        // reconnect, so it is held before anything is written.
        await expectLater(
          repo.addComment(recipeId: 'r1', userId: _uid, content: 'Igen!'),
          throwsA(isA<CommentAwaitingSendException>()),
        );

        await firestore.enableNetwork();
        await firestore.waitForPendingWrites();
        final again = await repo
            .addComment(recipeId: 'r1', userId: _uid, content: 'Igen!')
            .timeout(_offlineBudget);
        expect(again.text, 'Igen!');
        final server = await firestore
            .collection(FirestoreCollections.recipeComments)
            .doc(posted.id)
            .get(const GetOptions(source: Source.server));
        expect(server.data()?['text'], 'Gott!');
        final all = await firestore
            .collection(FirestoreCollections.recipeComments)
            .get(const GetOptions(source: Source.server));
        expect(
          all.docs.map((d) => d.data()['text']),
          unorderedEquals(['Gott!', 'Igen!']),
        );
      },
    );

    test(
      'profile: saving the profile and a setting return offline and reach the '
      'server on reconnect',
      () async {
        final repo = FirebaseUserRepository(
          firestore: firestore,
          authRepository: _signedIn(),
        );

        await firestore.disableNetwork();
        await repo
            .saveProfile(
              UserProfile(
                uid: _uid,
                displayName: 'Alice',
                email: 'alice@example.com',
                joinedAt: DateTime.utc(2026, 1, 1),
                lastActiveAt: DateTime.utc(2026, 1, 1),
              ),
            )
            .timeout(_offlineBudget);
        await repo.setShowNutritionStrip(_uid, true).timeout(_offlineBudget);

        await firestore.enableNetwork();
        await firestore.waitForPendingWrites();
        final profile = await firestore
            .collection(FirestoreCollections.publicProfiles)
            .doc(_uid)
            .get(const GetOptions(source: Source.server));
        expect(profile.data()?['displayName'], 'Alice');
        final settings = await firestore
            .collection(FirestoreCollections.users)
            .doc(_uid)
            .collection(FirestoreCollections.userSettings)
            .doc('preferences')
            .get(const GetOptions(source: Source.server));
        expect(settings.data()?['showNutritionStrip'], true);
      },
    );

    test(
      'chat: sending a message and reacting to it return offline and reach the '
      'server on reconnect',
      () async {
        final conversations = firestore.collection('conversations');
        final messages = firestore.collection(FirestoreCollections.messages);
        await conversations.doc('conv-1').set({
          'participantIds': [_uid, 'bob'],
        });
        final message = Message.text(
          conversationId: 'conv-1',
          senderId: _uid,
          senderDisplayName: _uid,
          content: 'Hej!',
        );
        final module = MessageMutationModule(
          firestore: firestore,
          collectionName: 'conversations',
          messagesRef: messages,
          readConversation: (id) async => Conversation(
            id: id,
            participantIds: const [_uid, 'bob'],
            participantDisplayNames: const {_uid: 'Alice', 'bob': 'Bob'},
            participantAvatarUrls: const {},
            lastReadTimestamps: const {},
            isGroup: false,
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        final reactions = MessageReactionsService(
          firestoreRepository: FirestoreRepository(firestore: firestore),
          authRepository: _signedIn(),
        );

        await firestore.disableNetwork();
        await module.sendMessage(message).timeout(_offlineBudget);
        await reactions
            .toggleReaction(
              messageId: message.id,
              conversationId: 'conv-1',
              userId: _uid,
              emoji: '👍',
            )
            .timeout(_offlineBudget);

        await firestore.enableNetwork();
        await firestore.waitForPendingWrites();
        final server = await messages
            .doc(message.id)
            .get(const GetOptions(source: Source.server));
        expect(server.data()?['content'], 'Hej!');
        expect(server.data()?['reactions'], {
          '👍': [_uid],
        });
      },
    );
  }, skip: emulatorOnlySkip);
}
