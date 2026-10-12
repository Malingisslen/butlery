/// Hosts for the chat, menu, family and conflict views the register had not
/// compared.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/family_rating.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/messaging/chat_group.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/repositories/firebase/firebase_diner_profile_repository.dart';
import 'package:butlery/repositories/firebase/firebase_family_rating_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/chat_group_repository.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/family_rating_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/family_rating_service.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/recipe_suggestion_service.dart';
import 'package:butlery/services/unified/operations/realtime_group_menu/realtime_group_menu_module.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/family/family_rating_entry_view.dart';
import 'package:butlery/views/group_weekly_menu_view.dart';
import 'package:butlery/views/menu_placement_view.dart';
import 'package:butlery/views/messaging/conversation_group_detail_view.dart';
import 'package:butlery/views/messaging/create_group_conversation_view.dart';
import 'package:butlery/views/realtime/conflict_diff_view.dart';
import 'package:butlery/views/realtime/recipe_suggestion_view.dart';

import '../../../helpers/user_profile_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart'
    show MockChatGroupRepository;
import '../state_host.dart';

class _MockMessaging extends Mock implements MessagingService {}

class _MockFriends extends Mock implements UnifiedFriendsService {}

class _MockGroupPlans extends Mock implements GroupWeeklyMenuPlanService {}

class _MockGroupRealtime extends Mock implements RealtimeGroupMenuModule {}

class _MockUsers extends Mock implements UserService {}

class _MockPlans extends Mock implements WeeklyMenuPlanService {
  @override
  Stream<String?> get weekWrites => const Stream.empty();

  @override
  Stream<LateWeekConflict> get lateConflicts => const Stream.empty();
}

class _MockRealtimeSync extends Mock implements RealtimeSyncService {}

class _MockSuggestions extends Mock implements RecipeSuggestionService {}

class _Resource extends Fake implements RealtimeResource {
  _Resource(this._map, this.lastEditedByDisplayName);

  final Map<String, dynamic> _map;

  @override
  final String lastEditedByDisplayName;

  @override
  Map<String, dynamic> toFirestore() => _map;

  @override
  RealtimeResource copyWithMetadata({
    Map<String, ResourcePermission>? participants,
    List<String>? participantIds,
    DateTime? lastEditedAt,
    String? lastEditedBy,
    String? lastEditedByDisplayName,
    int? editCount,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) => _Resource(
    _map,
    lastEditedByDisplayName ?? this.lastEditedByDisplayName,
  );
}

const _me = 'test-user-123';

final reviewMiscHosts = <String, StateHost>{
  'ConversationGroupDetailView': StateHost(
    build: (ctx) async {
      registerFallbackValue(<String>[]);
      final messaging = _MockMessaging();
      final friends = _MockFriends();
      final groups = MockChatGroupRepository();
      final stream = StreamController<List<Conversation>>.broadcast();
      ctx.disposers.add(stream.close);
      final conversation = Conversation(
        id: 'c1',
        participantIds: [_me, 'u-anna', 'u-per'],
        participantDisplayNames: {
          _me: 'Malin',
          'u-anna': 'Anna Lindqvist',
          'u-per': 'Per Nilsson',
        },
        participantAvatarUrls: const {},
        lastReadTimestamps: {
          _me: DateTime(2026, 9, 27),
          'u-anna': DateTime(2026, 9, 27),
          'u-per': DateTime(2026, 9, 27),
        },
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 27),
        title: 'Söndagsmiddag',
        isGroup: true,
        groupId: 'chat-g1',
      );
      when(messaging.getMyConversations).thenAnswer((_) => stream.stream);
      when(
        () => messaging.getConversation('c1'),
      ).thenAnswer((_) async => conversation);
      when(() => friends.friends).thenReturn([
        testUserProfile(uid: 'u-cecilia', displayName: 'Cecilia Berg'),
      ]);
      when(() => groups.watchGroup('chat-g1')).thenAnswer(
        (_) => Stream.value(
          ChatGroup(
            id: 'chat-g1',
            name: 'Söndagsmiddag',
            memberIds: [_me, 'u-anna', 'u-per'],
            adminIds: [_me],
            memberDisplayNames: const {
              _me: 'Malin',
              'u-anna': 'Anna Lindqvist',
              'u-per': 'Per Nilsson',
            },
            memberAvatarUrls: const {},
            conversationId: 'c1',
            createdBy: _me,
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 27),
          ),
        ),
      );
      TestServiceLocator.registerMock<MessagingService>(messaging);
      TestServiceLocator.registerMock<UnifiedFriendsService>(friends);
      TestServiceLocator.registerMock<ChatGroupRepository>(groups);
      return const ConversationGroupDetailView(conversationId: 'c1');
    },
    reach: (tester, ctx) async {
      await tester.pump(const Duration(milliseconds: 100));
    },
  ),
  'CreateGroupConversationView': StateHost(
    build: (ctx) async {
      final friends = _MockFriends();
      when(() => friends.friends).thenReturn([
        testUserProfile(
          uid: 'u-anna',
          displayName: 'Anna Lindqvist',
          email: 'anna@example.se',
        ),
        testUserProfile(uid: 'u-cecilia', displayName: 'Cecilia Berg'),
        testUserProfile(uid: 'u-per', displayName: 'Per Nilsson'),
      ]);
      TestServiceLocator.registerMock<UnifiedFriendsService>(friends);
      TestServiceLocator.registerMock<ChatGroupRepository>(
        MockChatGroupRepository(),
      );
      return const CreateGroupConversationView();
    },
  ),
  'GroupWeeklyMenuView': StateHost(
    build: (ctx) async {
      registerFallbackValue(
        const WeeklyMenuPlanEntry(
          id: 'fallback',
          day: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipeId: 'r',
          recipeTitle: 't',
        ),
      );
      final week = DateTime.utc(2026, 9, 28);
      final plan =
          GroupWeeklyMenuPlan.empty(
            groupId: 'g1',
            creatorId: _me,
            date: week,
            initialParticipants: [
              GroupMenuParticipant(
                userId: _me,
                permission: SharedListPermission.edit,
                addedAt: DateTime.utc(2026, 1, 1),
              ),
            ],
          ).copyWith(
            entries: [
              for (final (day, title) in [
                (DayOfWeek.mon, 'Linsgryta med spetskål'),
                (DayOfWeek.wed, 'Ugnsbakad lax med dill'),
                (DayOfWeek.sun, 'Söndagsstek med potatisgratäng'),
              ])
                WeeklyMenuPlanEntry.create(
                  day: day,
                  slot: MealSlot.middag,
                  recipeId: 'r-$title',
                  recipeTitle: title,
                ),
            ],
          );
      final service = _MockGroupPlans();
      final realtime = _MockGroupRealtime();
      final users = _MockUsers();
      when(
        () => service.readWeek(
          groupId: any(named: 'groupId'),
          date: any(named: 'date'),
        ),
      ).thenAnswer(
        (_) async => GroupWeeklyMenuPlanRead(plan: plan, readFailed: false),
      );
      when(
        () => realtime.subscribe(
          groupId: any(named: 'groupId'),
          date: any(named: 'date'),
          onUpdate: any(named: 'onUpdate'),
          onError: any(named: 'onError'),
        ),
      ).thenAnswer(
        (_) => const Stream<GroupWeeklyMenuPlan?>.empty().listen(null),
      );
      when(() => users.getUserProfiles(any())).thenAnswer(
        (_) async => ProfileBatchLookup(
          profiles: const [],
          missingIds: const {},
          unavailableIds: const {},
        ),
      );
      TestServiceLocator.registerMock<GroupWeeklyMenuPlanService>(service);
      TestServiceLocator.registerMock<RealtimeGroupMenuModule>(realtime);
      TestServiceLocator.registerMock<UserService>(users);
      return GroupWeeklyMenuView(
        groupId: 'g1',
        groupName: 'Torsdagsklubben',
        currentUserId: _me,
        onStartPoll: () {},
      );
    },
  ),
  'MenuPlacementView': StateHost(
    build: (ctx) async {
      final plans = _MockPlans();
      final week = WeeklyMenuPlan.empty(userId: _me, date: clock.now())
          .copyWith(
            entries: [
              WeeklyMenuPlanEntry.create(
                day: DayOfWeek.mon,
                slot: MealSlot.middag,
                recipeId: 'x1',
                recipeTitle: 'Köttbullar med gräddsås',
              ),
            ],
          );
      when(() => plans.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: week, readFailed: false),
      );
      TestServiceLocator.registerMock<WeeklyMenuPlanService>(plans);
      return MenuPlacementView(
        weekStart: clock.now(),
        generated: {
          'middag': [
            RecipeFactory.build(id: 'g1', title: 'Linsgryta med kokos'),
            RecipeFactory.build(id: 'g2', title: 'Ugnsbakad lax med dill'),
            RecipeFactory.build(id: 'g3', title: 'Krämig svamppasta'),
          ],
          'lunch': [
            RecipeFactory.build(id: 'g4', title: 'Quinoasallad'),
          ],
        },
      );
    },
  ),
  'FamilyRatingEntryView': StateHost(
    build: (ctx) async {
      registerFallbackValue(HouseholdMemberType.user);
      (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
          .setAuthState(
            user: FakeUser(uid: _me),
            userId: _me,
            isAuthenticated: true,
          );
      (TestServiceLocator.get<UserService>() as MockUserService).setUserState(
        users: {
          _me: MockFactory.createUserProfile(userId: _me, displayName: 'Malin'),
        },
      );
      TestServiceLocator.registerSingleton<PermissionService>(
        MockFactory.createPermissionService(currentUserId: _me),
      );
      final fs = FakeFirebaseFirestore();
      final auth = TestServiceLocator.get<AuthRepository>();
      final households = FirebaseHouseholdRepository(
        firestore: fs,
        authRepository: auth,
      );
      final diners = FirebaseDinerProfileRepository(
        firestore: fs,
        authRepository: auth,
        householdRepository: households,
      );
      TestServiceLocator.registerSingleton<HouseholdRepository>(households);
      TestServiceLocator.registerSingleton<DinerProfileRepository>(diners);
      TestServiceLocator.registerSingleton<FamilyRatingRepository>(
        FirebaseFamilyRatingRepository(
          firestore: fs,
          authRepository: auth,
          householdRepository: households,
        ),
      );
      TestServiceLocator.registerSingleton<HouseholdRosterService>(
        HouseholdRosterService(),
      );
      TestServiceLocator.registerSingleton<FamilyRatingService>(
        FamilyRatingService(),
      );
      final household = await households.ensureForUser(_me);
      for (final (name, band) in [
        ('Emma', DinerAgeBand.child),
        ('Albin', DinerAgeBand.teen),
      ]) {
        await diners.create(
          DinerProfile.create(
            householdId: household.id,
            name: name,
            ageBand: band,
            createdBy: _me,
            guardianConsent: GuardianConsent(
              byUid: _me,
              at: DateTime.utc(2026, 1, 1),
              consentVersion: DinerProfile.currentConsentVersion,
              includesAllergenConsent: false,
            ),
          ),
        );
      }
      return const FamilyRatingEntryView(
        recipeId: 'recipe-1',
        recipeTitle: 'Pannkakor med lingon',
      );
    },
  ),
  'ConflictDiffView': StateHost(
    build: (ctx) async {
      final sync = _MockRealtimeSync();
      TestServiceLocator.registerMock<RealtimeSyncService>(sync);
      final users = _MockUsers();
      when(() => users.profileDisplayName).thenReturn('Malin');
      TestServiceLocator.registerMock<UserService>(users);
      return ConflictDiffView(
        event: ConflictEvent(
          collectionPath: 'recipes',
          docId: 'doc-1',
          localValue: _Resource(const {
            'title': 'Linsgryta med kokos och koriander',
            'portions': 4,
            'ingredients': ['2 dl röda linser', '1 burk kokosmjölk'],
          }, 'Malin'),
          remoteValue: _Resource(const {
            'title': 'Linsgryta med kokos, lime och koriander',
            'portions': 6,
            'ingredients': ['3 dl röda linser', '1 burk kokosmjölk', '1 lime'],
          }, 'Per'),
          chosenStrategy: ConflictResolutionStrategy.remoteWon,
          entity: ConflictEntity.recipeOwn,
          occurredAt: DateTime(2026, 9, 28),
        ),
      );
    },
  ),
  'RecipeSuggestionView': StateHost(
    build: (ctx) async {
      final service = _MockSuggestions();
      final suggestion = RecipeSuggestion(
        id: 's1',
        recipeId: 'recipe-1',
        ownerId: _me,
        suggesterId: 'u-per',
        suggestion: const {
          'title': 'Linsgryta med kokos och lime',
          'portions': 6,
        },
        status: RecipeSuggestionStatus.pending,
        createdAt: DateTime(2026, 9, 27),
        expiresAt: DateTime(2026, 10, 4),
      );
      registerFallbackValue(suggestion);
      when(() => service.diffAgainstLive(any())).thenAnswer(
        (_) async => ConflictDiff.fromMaps(
          const {
            'title': 'Linsgryta med kokos och lime',
            'portions': 6,
            'ingredients': ['3 dl röda linser', '1 lime'],
          },
          const {
            'title': 'Linsgryta med kokos',
            'portions': 4,
            'ingredients': ['2 dl röda linser'],
          },
        ),
      );
      TestServiceLocator.registerMock<RecipeSuggestionService>(service);
      return RecipeSuggestionView(suggestion: suggestion, asOwner: true);
    },
  ),
};
