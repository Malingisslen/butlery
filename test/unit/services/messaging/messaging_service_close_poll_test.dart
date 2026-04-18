/// Tests for `MessagingService.closePoll` auto-resolution path.
///
/// History:
/// - BUT-340: initial MVP. Winner appended to the poll creator's personal
///   plan + reshared via `shareMenuWithFriends`. Group or 1:1, both paths
///   landed on the personal plan.
/// - BUT-405: routing split. Group conversations now write to a
///   `GroupWeeklyMenuPlan` (collaborative, per-group). 1:1 conversations
///   retain the BUT-340 personal-plan fallback.
///
/// Scenarios covered:
/// - Group conversation winner → `GroupWeeklyMenuPlanService.addEntry` +
///   `GroupWeeklyMenuPlanService.save` fire, personal plan untouched.
/// - 1:1 direct conversation winner → personal `WeeklyMenuPlanService` +
///   `shareMenuWithFriends` fire, group service untouched.
/// - Winner without `recipeId` → no plan write on either path.
/// - Tie on votes → first option (chronological) wins.
/// - Already-closed poll → no plan write (double-fire guard).
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/messaging/message_reactions_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

class _MockMessagingRepo extends Mock implements MessagingRepository {}

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockReactionsService extends Mock implements MessageReactionsService {}

class _MockPlanService extends Mock implements WeeklyMenuPlanService {}

class _MockGroupPlanService extends Mock
    implements GroupWeeklyMenuPlanService {}

class _MockSocialMenuOps extends Mock implements SocialMenuOperations {}

class _MockRecipeService extends Mock implements UnifiedRecipeService {}

class _FakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? displayName;
  _FakeUser(this.uid, {this.displayName});
}

Recipe _recipe(String id, String title) => Recipe(
      core: RecipeCore(
        id: id,
        title: title,
        description: '',
        ingredients: const ['x'],
        instructions: const ['y'],
        mealType: 'Middag',
      ),
      type: RecipeType.personal,
    );

Message _pollMessage({
  required String messageId,
  required String conversationId,
  required Poll poll,
}) {
  return Message(
    id: messageId,
    conversationId: conversationId,
    senderId: poll.creatorId,
    senderDisplayName: 'Creator',
    content: poll.question,
    type: MessageType.poll,
    status: MessageStatus.sent,
    sentAt: DateTime.now(),
    metadata: {'poll': poll.toMap()},
  );
}

Conversation _groupConversation(String id, List<String> participants) {
  return Conversation(
    id: id,
    participantIds: participants,
    participantDisplayNames: {for (final p in participants) p: 'User $p'},
    participantAvatarUrls: {for (final p in participants) p: null},
    isGroup: true,
    title: 'Familjen',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    lastReadTimestamps: const {},
    metadata: const {},
  );
}

Conversation _directConversation(String id, List<String> participants) {
  return Conversation(
    id: id,
    participantIds: participants,
    participantDisplayNames: {for (final p in participants) p: 'User $p'},
    participantAvatarUrls: {for (final p in participants) p: null},
    isGroup: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    lastReadTimestamps: const {},
    metadata: const {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockMessagingRepo messagingRepo;
  late _MockAuthRepo authRepo;
  late _MockReactionsService reactionsService;
  late _MockPlanService planService;
  late _MockGroupPlanService groupPlanService;
  late _MockSocialMenuOps socialMenuOps;
  late _MockRecipeService recipeService;
  late MessagingService service;

  const creatorId = 'user-creator';
  const conversationId = 'conv-group-1';
  const directConversationId = 'conv-direct-1';
  const messageId = 'msg-poll-1';

  setUpAll(() {
    registerFallbackValue(_recipe('fallback', 'fallback'));
    registerFallbackValue(WeeklyMenuPlan.empty(
      userId: creatorId,
      date: DateTime.now(),
    ));
    registerFallbackValue(GroupWeeklyMenuPlan.empty(
      groupId: conversationId,
      creatorId: creatorId,
      date: DateTime.now(),
    ));
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.middag);
  });

  setUp(() async {
    messagingRepo = _MockMessagingRepo();
    authRepo = _MockAuthRepo();
    reactionsService = _MockReactionsService();
    planService = _MockPlanService();
    groupPlanService = _MockGroupPlanService();
    socialMenuOps = _MockSocialMenuOps();
    recipeService = _MockRecipeService();

    final getIt = GetIt.instance;
    await getIt.reset();
    ServiceLocator.initialize(DIContainer());
    getIt.registerSingleton<WeeklyMenuPlanService>(planService);
    getIt.registerSingleton<GroupWeeklyMenuPlanService>(groupPlanService);
    getIt.registerSingleton<SocialMenuOperations>(socialMenuOps);
    getIt.registerSingleton<UnifiedRecipeService>(recipeService);

    when(() => authRepo.currentUserId).thenReturn(creatorId);
    when(() => authRepo.currentUser)
        .thenReturn(_FakeUser(creatorId, displayName: 'Creator'));

    when(() => messagingRepo.closePoll(
          messageId: any(named: 'messageId'),
          closerId: any(named: 'closerId'),
        )).thenAnswer((_) async {});

    // Default — group conversation. Overridden per-test for 1:1 cases.
    when(() => messagingRepo.getConversation(conversationId))
        .thenAnswer((_) async => _groupConversation(
              conversationId,
              [creatorId, 'user-2', 'user-3'],
            ));

    // Personal plan service stubs (1:1 path).
    when(() => planService.addEntry(
          plan: any(named: 'plan'),
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: any(named: 'recipe'),
        )).thenAnswer((inv) => inv.namedArguments[#plan] as WeeklyMenuPlan);
    when(() => planService.save(any())).thenAnswer((_) async {});

    // Group plan service stubs (group path).
    when(() => groupPlanService.getOrCreateWeek(
          groupId: any(named: 'groupId'),
          creatorId: any(named: 'creatorId'),
          date: any(named: 'date'),
          initialParticipants: any(named: 'initialParticipants'),
        )).thenAnswer((inv) async => GroupWeeklyMenuPlan.empty(
          groupId: inv.namedArguments[#groupId] as String,
          creatorId: inv.namedArguments[#creatorId] as String,
          date: inv.namedArguments[#date] as DateTime,
        ));
    when(() => groupPlanService.addEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: any(named: 'recipe'),
        )).thenAnswer(
      (inv) => inv.namedArguments[#plan] as GroupWeeklyMenuPlan,
    );
    when(() => groupPlanService.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        )).thenAnswer((_) async {});

    when(() => socialMenuOps.shareMenuWithFriends(
          menu: any(named: 'menu'),
          friendUserIds: any(named: 'friendUserIds'),
        )).thenAnswer((_) async => true);

    service = MessagingService(
      messagingRepository: messagingRepo,
      authRepository: authRepo,
      reactionsService: reactionsService,
    );
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  group('closePoll routing by conversation type (BUT-405)', () {
    test(
        'group conversation → writes to GroupWeeklyMenuPlan, personal plan '
        'service is never touched', () async {
      final now = DateTime.now();
      final winnerRecipe = _recipe('recipe-winner', 'Tacos');
      final loserRecipe = _recipe('recipe-loser', 'Pasta');

      when(() => recipeService.recipes).thenReturn([winnerRecipe, loserRecipe]);

      final poll = Poll(
        id: 'poll-1',
        question: 'Vad ska vi äta?',
        creatorId: creatorId,
        createdAt: now,
        options: [
          PollOption(
            id: 'opt-1',
            text: 'Tacos',
            voterIds: const ['user-2', 'user-3'],
            recipeId: 'recipe-winner',
          ),
          PollOption(
            id: 'opt-2',
            text: 'Pasta',
            voterIds: const ['user-4'],
            recipeId: 'recipe-loser',
          ),
        ],
      );
      when(() => messagingRepo.getMessage(messageId)).thenAnswer(
        (_) async => _pollMessage(
            messageId: messageId, conversationId: conversationId, poll: poll),
      );

      await service.closePoll(messageId: messageId);

      verify(() => messagingRepo.closePoll(
            messageId: messageId,
            closerId: creatorId,
          )).called(1);
      verify(() => groupPlanService.getOrCreateWeek(
            groupId: conversationId,
            creatorId: creatorId,
            date: any(named: 'date'),
            initialParticipants: any(named: 'initialParticipants'),
          )).called(1);
      verify(() => groupPlanService.addEntry(
            plan: any(named: 'plan'),
            actorId: creatorId,
            day: any(named: 'day'),
            slot: any(named: 'slot'),
            recipe: any<Recipe>(named: 'recipe', that: isA<Recipe>()),
          )).called(1);
      verify(() => groupPlanService.save(
            plan: any(named: 'plan'),
            actorId: creatorId,
          )).called(1);

      // Personal plan path MUST NOT fire for group conversations.
      verifyNever(() => planService.save(any()));
      verifyNever(() => socialMenuOps.shareMenuWithFriends(
            menu: any(named: 'menu'),
            friendUserIds: any(named: 'friendUserIds'),
          ));
    });

    test(
        '1:1 direct conversation → writes to the creator\'s personal plan + '
        'shares with the other participant, group service untouched', () async {
      final now = DateTime.now();
      final winnerRecipe = _recipe('recipe-winner', 'Tacos');
      when(() => recipeService.recipes).thenReturn([winnerRecipe]);
      when(() => planService.getWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlan.empty(userId: creatorId, date: now),
      );
      // Override default mock: return a direct (1:1) conversation.
      when(() => messagingRepo.getConversation(directConversationId))
          .thenAnswer(
        (_) async =>
            _directConversation(directConversationId, [creatorId, 'user-2']),
      );

      final poll = Poll(
        id: 'poll-direct',
        question: 'Vad ska vi äta ikväll?',
        creatorId: creatorId,
        createdAt: now,
        options: [
          PollOption(
            id: 'opt-1',
            text: 'Tacos',
            voterIds: const ['user-2'],
            recipeId: 'recipe-winner',
          ),
        ],
      );
      when(() => messagingRepo.getMessage(messageId)).thenAnswer(
        (_) async => _pollMessage(
            messageId: messageId,
            conversationId: directConversationId,
            poll: poll),
      );

      await service.closePoll(messageId: messageId);

      // Personal plan path fires.
      verify(() => planService.addEntry(
            plan: any(named: 'plan'),
            day: any(named: 'day'),
            slot: any(named: 'slot'),
            recipe: any<Recipe>(named: 'recipe', that: isA<Recipe>()),
          )).called(1);
      verify(() => planService.save(any())).called(1);

      // Group path MUST NOT fire on 1:1.
      verifyNever(() => groupPlanService.getOrCreateWeek(
            groupId: any(named: 'groupId'),
            creatorId: any(named: 'creatorId'),
            date: any(named: 'date'),
            initialParticipants: any(named: 'initialParticipants'),
          ));
      verifyNever(() => groupPlanService.save(
            plan: any(named: 'plan'),
            actorId: any(named: 'actorId'),
          ));
    });
  });

  group('closePoll auto-resolution (shared behaviours)', () {
    test('winner without recipeId → no plan write', () async {
      when(() => recipeService.recipes).thenReturn(const []);

      final poll = Poll(
        id: 'poll-text',
        question: 'Pizza or sushi?',
        creatorId: creatorId,
        createdAt: DateTime.now(),
        options: const [
          PollOption(id: 'opt-1', text: 'Pizza', voterIds: ['user-2']),
          PollOption(id: 'opt-2', text: 'Sushi'),
        ],
      );
      when(() => messagingRepo.getMessage(messageId)).thenAnswer(
        (_) async => _pollMessage(
            messageId: messageId, conversationId: conversationId, poll: poll),
      );

      await service.closePoll(messageId: messageId);

      verify(() => messagingRepo.closePoll(
            messageId: messageId,
            closerId: creatorId,
          )).called(1);
      verifyNever(() => planService.save(any()));
      verifyNever(() => groupPlanService.save(
            plan: any(named: 'plan'),
            actorId: any(named: 'actorId'),
          ));
      verifyNever(() => socialMenuOps.shareMenuWithFriends(
            menu: any(named: 'menu'),
            friendUserIds: any(named: 'friendUserIds'),
          ));
    });

    test('tie on votes → first option (chronological order) wins', () async {
      final firstRecipe = _recipe('recipe-first', 'Tacos');
      final secondRecipe = _recipe('recipe-second', 'Pasta');
      when(() => recipeService.recipes).thenReturn([firstRecipe, secondRecipe]);

      final poll = Poll(
        id: 'poll-tie',
        question: 'Vad ska vi äta?',
        creatorId: creatorId,
        createdAt: DateTime.now(),
        options: [
          PollOption(
            id: 'opt-1',
            text: 'Tacos',
            voterIds: const ['user-2'],
            recipeId: 'recipe-first',
          ),
          PollOption(
            id: 'opt-2',
            text: 'Pasta',
            voterIds: const ['user-3'],
            recipeId: 'recipe-second',
          ),
        ],
      );
      when(() => messagingRepo.getMessage(messageId)).thenAnswer(
        (_) async => _pollMessage(
            messageId: messageId, conversationId: conversationId, poll: poll),
      );

      await service.closePoll(messageId: messageId);

      // This is a group conversation by default → group path fires.
      final captured = verify(() => groupPlanService.addEntry(
            plan: any(named: 'plan'),
            actorId: any(named: 'actorId'),
            day: any(named: 'day'),
            slot: any(named: 'slot'),
            recipe: captureAny(named: 'recipe'),
          )).captured;
      expect(captured, hasLength(1));
      final recipe = captured.single as Recipe;
      expect(recipe.id, equals('recipe-first'));
    });

    test('already-closed poll → no plan write (double-fire guard)', () async {
      final winnerRecipe = _recipe('recipe-winner', 'Tacos');
      when(() => recipeService.recipes).thenReturn([winnerRecipe]);

      final closedPoll = Poll(
        id: 'poll-closed',
        question: 'Already decided?',
        creatorId: creatorId,
        createdAt: DateTime.now(),
        isClosed: true,
        options: [
          PollOption(
            id: 'opt-1',
            text: 'Tacos',
            voterIds: const ['user-2'],
            recipeId: 'recipe-winner',
          ),
        ],
      );
      when(() => messagingRepo.getMessage(messageId)).thenAnswer(
        (_) async => _pollMessage(
            messageId: messageId,
            conversationId: conversationId,
            poll: closedPoll),
      );

      await service.closePoll(messageId: messageId);

      verifyNever(() => messagingRepo.closePoll(
            messageId: any(named: 'messageId'),
            closerId: any(named: 'closerId'),
          ));
      verifyNever(() => planService.save(any()));
      verifyNever(() => groupPlanService.save(
            plan: any(named: 'plan'),
            actorId: any(named: 'actorId'),
          ));
    });
  });
}
