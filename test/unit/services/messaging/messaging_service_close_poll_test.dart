/// Tests for `MessagingService.closePoll` auto-resolution path.
///
/// History:
/// - BUT-340: initial MVP. Winner appended to the poll creator's personal
///   plan + reshared via `shareMenuWithFriends`. Group or 1:1, both paths
///   landed on the personal plan.
/// - BUT-405: routing split. Group conversations now write to a
///   `GroupWeeklyMenuPlan` (collaborative, per-group). 1:1 conversations
///   retain the BUT-340 personal-plan fallback.
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
import 'package:butlery/services/social/blocking/blocked_user_filter.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/repositories/interfaces/chat_group_repository.dart';

class _MockMessagingRepo extends Mock implements MessagingRepository {}

class _MockChatGroupRepo extends Mock implements ChatGroupRepository {}

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockReactionsService extends Mock implements MessageReactionsService {}

class _MockPlanService extends Mock implements WeeklyMenuPlanService {}

class _MockGroupPlanService extends Mock
    implements GroupWeeklyMenuPlanService {}

class _MockSocialMenuOps extends Mock implements SocialMenuOperations {}

class _MockRecipeService extends Mock implements UnifiedRecipeService {}

class _MockBlockedUserFilter extends Mock implements BlockedUserFilter {}

class _MockBlockRepo extends Mock implements FirebaseBlockRepository {}

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
  late _MockChatGroupRepo chatGroupRepo;
  late _MockAuthRepo authRepo;
  late _MockReactionsService reactionsService;
  late _MockPlanService planService;
  late _MockGroupPlanService groupPlanService;
  late _MockSocialMenuOps socialMenuOps;
  late _MockRecipeService recipeService;
  late _MockBlockedUserFilter defaultBlockFilter;
  late MessagingService service;

  const creatorId = 'user-creator';
  const conversationId = 'conv-group-1';
  const directConversationId = 'conv-direct-1';
  const messageId = 'msg-poll-1';

  setUpAll(() {
    registerFallbackValue(_recipe('fallback', 'fallback'));
    registerFallbackValue(
      WeeklyMenuPlan.empty(
        userId: creatorId,
        date: DateTime.now(),
      ),
    );
    registerFallbackValue(
      GroupWeeklyMenuPlan.empty(
        groupId: conversationId,
        creatorId: creatorId,
        date: DateTime.now(),
      ),
    );
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.middag);
  });

  setUp(() async {
    messagingRepo = _MockMessagingRepo();
    chatGroupRepo = _MockChatGroupRepo();
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
    // BUT-1926: closePoll now REFUSES when no block filter is registered —
    // "not registered" is a build that cannot answer the question, not an
    // empty block list. The BUT-1909 group swaps in its own.
    defaultBlockFilter = _MockBlockedUserFilter();
    when(
      () => defaultBlockFilter.requireBlockedIds(),
    ).thenAnswer((_) async => <String>{});
    getIt.registerSingleton<BlockedUserFilter>(defaultBlockFilter);

    when(() => authRepo.currentUserId).thenReturn(creatorId);
    when(
      () => authRepo.currentUser,
    ).thenReturn(_FakeUser(creatorId, displayName: 'Creator'));

    when(
      () => messagingRepo.closePoll(
        messageId: any(named: 'messageId'),
        closerId: any(named: 'closerId'),
      ),
    ).thenAnswer((_) async {});

    // Default — group conversation. Overridden per-test for 1:1 cases.
    when(() => messagingRepo.getConversation(conversationId)).thenAnswer(
      (_) async => _groupConversation(
        conversationId,
        [creatorId, 'user-2', 'user-3'],
      ),
    );

    // Personal plan service stubs (1:1 path).
    when(
      () => planService.addEntry(
        plan: any(named: 'plan'),
        day: any(named: 'day'),
        slot: any(named: 'slot'),
        recipe: any(named: 'recipe'),
      ),
    ).thenAnswer((inv) => inv.namedArguments[#plan] as WeeklyMenuPlan);
    when(() => planService.save(any())).thenAnswer((_) async {});

    // Group plan service stubs (group path). `readOrBuildWeek`, not
    // `getOrBuildWeek`: BUT-1928 made the read state part of the answer, and
    // the close path refuses on a failed read rather than saving over the week.
    when(
      () => groupPlanService.readOrBuildWeek(
        groupId: any(named: 'groupId'),
        creatorId: any(named: 'creatorId'),
        date: any(named: 'date'),
        initialParticipants: any(named: 'initialParticipants'),
      ),
    ).thenAnswer(
      (inv) async => GroupWeeklyMenuPlanRead(
        plan: GroupWeeklyMenuPlan.empty(
          groupId: inv.namedArguments[#groupId] as String,
          creatorId: inv.namedArguments[#creatorId] as String,
          date: inv.namedArguments[#date] as DateTime,
        ),
        readFailed: false,
      ),
    );
    when(
      () => groupPlanService.addEntry(
        plan: any(named: 'plan'),
        actorId: any(named: 'actorId'),
        day: any(named: 'day'),
        slot: any(named: 'slot'),
        recipe: any(named: 'recipe'),
      ),
    ).thenAnswer(
      (inv) => inv.namedArguments[#plan] as GroupWeeklyMenuPlan,
    );
    when(
      () => groupPlanService.save(
        plan: any(named: 'plan'),
        actorId: any(named: 'actorId'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => socialMenuOps.shareMenuWithFriends(
        menu: any(named: 'menu'),
        friendUserIds: any(named: 'friendUserIds'),
      ),
    ).thenAnswer((_) async => true);

    service = MessagingService(
      messagingRepository: messagingRepo,
      chatGroupRepository: chatGroupRepo,
      authRepository: authRepo,
      reactionsService: reactionsService,
    );
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  group('closePoll routing by conversation type (BUT-405)', () {
    test('group conversation → writes to GroupWeeklyMenuPlan, personal plan '
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
          messageId: messageId,
          conversationId: conversationId,
          poll: poll,
        ),
      );

      await service.closePoll(messageId: messageId);

      verify(
        () => messagingRepo.closePoll(
          messageId: messageId,
          closerId: creatorId,
        ),
      ).called(1);
      verify(
        () => groupPlanService.readOrBuildWeek(
          groupId: conversationId,
          creatorId: creatorId,
          date: any(named: 'date'),
          initialParticipants: any(named: 'initialParticipants'),
        ),
      ).called(1);
      verify(
        () => groupPlanService.addEntry(
          plan: any(named: 'plan'),
          actorId: creatorId,
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: any<Recipe>(named: 'recipe', that: isA<Recipe>()),
        ),
      ).called(1);
      verify(
        () => groupPlanService.save(
          plan: any(named: 'plan'),
          actorId: creatorId,
        ),
      ).called(1);

      // Personal plan path MUST NOT fire for group conversations.
      verifyNever(() => planService.save(any()));
      verifyNever(
        () => socialMenuOps.shareMenuWithFriends(
          menu: any(named: 'menu'),
          friendUserIds: any(named: 'friendUserIds'),
        ),
      );
    });

    test('1:1 direct conversation → writes to the creator\'s personal plan, '
        'group service untouched', () async {
      final now = DateTime.now();
      final winnerRecipe = _recipe('recipe-winner', 'Tacos');
      when(() => recipeService.recipes).thenReturn([winnerRecipe]);
      when(() => planService.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(
          plan: WeeklyMenuPlan.empty(userId: creatorId, date: now),
          readFailed: false,
        ),
      );
      // Override default mock: return a direct (1:1) conversation.
      when(
        () => messagingRepo.getConversation(directConversationId),
      ).thenAnswer(
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
          poll: poll,
        ),
      );

      await service.closePoll(messageId: messageId);

      // Personal plan path fires.
      verify(
        () => planService.addEntry(
          plan: any(named: 'plan'),
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: any<Recipe>(named: 'recipe', that: isA<Recipe>()),
        ),
      ).called(1);
      verify(() => planService.save(any())).called(1);

      // Group path MUST NOT fire on 1:1.
      verifyNever(
        () => groupPlanService.readOrBuildWeek(
          groupId: any(named: 'groupId'),
          creatorId: any(named: 'creatorId'),
          date: any(named: 'date'),
          initialParticipants: any(named: 'initialParticipants'),
        ),
      );
      verifyNever(
        () => groupPlanService.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      );
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
          messageId: messageId,
          conversationId: conversationId,
          poll: poll,
        ),
      );

      await service.closePoll(messageId: messageId);

      verify(
        () => messagingRepo.closePoll(
          messageId: messageId,
          closerId: creatorId,
        ),
      ).called(1);
      verifyNever(() => planService.save(any()));
      verifyNever(
        () => groupPlanService.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      );
      verifyNever(
        () => socialMenuOps.shareMenuWithFriends(
          menu: any(named: 'menu'),
          friendUserIds: any(named: 'friendUserIds'),
        ),
      );
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
          messageId: messageId,
          conversationId: conversationId,
          poll: poll,
        ),
      );

      await service.closePoll(messageId: messageId);

      // This is a group conversation by default → group path fires.
      final captured = verify(
        () => groupPlanService.addEntry(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: captureAny(named: 'recipe'),
        ),
      ).captured;
      expect(captured, hasLength(1));
      final recipe = captured.single as Recipe;
      expect(recipe.id, equals('recipe-first'));
    });

    test('plan append must happen BEFORE the poll is closed — if the plan '
        'save fails, the poll stays open so the user can retry', () async {
      final winnerRecipe = _recipe('recipe-winner', 'Tacos');
      when(() => recipeService.recipes).thenReturn([winnerRecipe]);

      // Make the group-plan save blow up. The repo close must NOT have
      // been called — otherwise the poll would be closed with no plan
      // entry and the idempotency guard would block retry.
      when(
        () => groupPlanService.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).thenThrow(Exception('simulated firestore failure'));

      final poll = Poll(
        id: 'poll-fail',
        question: 'Vad ska vi äta?',
        creatorId: creatorId,
        createdAt: DateTime.now(),
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
          poll: poll,
        ),
      );

      // Expect the error to propagate.
      await expectLater(
        service.closePoll(messageId: messageId),
        throwsException,
      );

      // Poll close must NOT have fired — plan write is the first side-effect.
      verifyNever(
        () => messagingRepo.closePoll(
          messageId: any(named: 'messageId'),
          closerId: any(named: 'closerId'),
        ),
      );
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
          poll: closedPoll,
        ),
      );

      await service.closePoll(messageId: messageId);

      verifyNever(
        () => messagingRepo.closePoll(
          messageId: any(named: 'messageId'),
          closerId: any(named: 'closerId'),
        ),
      );
      verifyNever(() => planService.save(any()));
      verifyNever(
        () => groupPlanService.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      );
    });
  });
  // ══ BUT-1908 / BUT-1909 — closePoll refuses rather than guesses ══════════
  //
  // Closing is a ONE-WAY door: nothing in the repository resets `isClosed`, and
  // a creator close writes the winning recipe into the household's week. So the
  // two ways the tally on screen can be wrong both have to stop it. A REFUSAL
  // case here asserts BOTH omissions — no plan write AND no `isClosed` flip;
  // asserting only one would pass a guard that refused the plan but still
  // burned the poll. The group also holds positive controls, which assert the
  // opposite.
  group('closePoll refuses on a tally it cannot trust', () {
    /// A poll with a real, recipe-backed winner. If the guard fails open, the
    /// plan write is what happens — so the fixture has to be able to produce
    /// one, or every "no plan write" assertion below is satisfied for free.
    Poll winnablePoll() => Poll(
      id: 'poll-guard',
      question: 'Vad ska vi äta?',
      creatorId: creatorId,
      createdAt: DateTime.now(),
      options: [
        PollOption(
          id: 'opt-1',
          text: 'Tacos',
          voterIds: const ['user-2', 'user-3'],
          recipeId: 'recipe-winner',
        ),
        PollOption(id: 'opt-2', text: 'Pasta'),
      ],
    );

    Message pollMessageWith(PollVoteHydration? hydration) {
      final base = _pollMessage(
        messageId: messageId,
        conversationId: conversationId,
        poll: winnablePoll(),
      );
      if (hydration == null) return base;
      return base.copyWith(
        metadata: {
          ...base.metadata!,
          PollVoteHydration.metadataKey: hydration.name,
        },
      );
    }

    void expectNothingHappened() {
      verifyNever(
        () => messagingRepo.closePoll(
          messageId: any(named: 'messageId'),
          closerId: any(named: 'closerId'),
        ),
      );
      verifyNever(() => planService.save(any()));
      verifyNever(
        () => groupPlanService.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      );
    }

    setUp(() {
      when(() => recipeService.recipes).thenReturn([
        _recipe('recipe-winner', 'Tacos'),
      ]);
    });

    test('the CONTROL: a read tally closes and writes the plan', () async {
      // Without this the two refusal cases below are satisfied by a service
      // that refuses everything, and the guard could be an unconditional throw.
      when(
        () => messagingRepo.getMessage(messageId),
      ).thenAnswer((_) async => pollMessageWith(PollVoteHydration.ok));

      await service.closePoll(messageId: messageId);

      verify(
        () => messagingRepo.closePoll(
          messageId: messageId,
          closerId: creatorId,
        ),
      ).called(1);
      verify(
        () => groupPlanService.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      ).called(1);
    });

    // Named for the STATE, not for a scenario: a capped poll cannot actually
    // reach this method (it reads through `getMessage`, a one-element list, so
    // the cap is a no-op there). Kept as a defensive pin on the state machine —
    // `ChatViewModel.closePoll` is where the capped case is really caught.
    test('a poll marked capped → throws, no plan, poll stays open', () async {
      when(
        () => messagingRepo.getMessage(messageId),
      ).thenAnswer((_) async => pollMessageWith(PollVoteHydration.capped));

      await expectLater(
        service.closePoll(messageId: messageId),
        throwsA(
          isA<PollCloseRefusedException>().having(
            (e) => e.reason,
            'reason',
            PollCloseRefusal.votesUnread,
          ),
        ),
      );
      expectNothingHappened();
    });

    test('a failed vote read → throws, no plan, poll stays open', () async {
      // Same refusal, different cause. Both must stop the close identically —
      // the distinction between them exists only for the wording the user sees.
      when(
        () => messagingRepo.getMessage(messageId),
      ).thenAnswer((_) async => pollMessageWith(PollVoteHydration.failed));

      await expectLater(
        service.closePoll(messageId: messageId),
        throwsA(
          isA<PollCloseRefusedException>().having(
            (e) => e.reason,
            'reason',
            PollCloseRefusal.votesUnread,
          ),
        ),
      );
      expectNothingHappened();
    });

    test('a message with no marker at all is treated as read', () async {
      // The default matters as much as the two states: `fromMetadata` returns
      // `ok` when the key is absent, and if it did not, this guard would
      // disable closing for every poll written before the marker existed.
      when(
        () => messagingRepo.getMessage(messageId),
      ).thenAnswer((_) async => pollMessageWith(null));

      await service.closePoll(messageId: messageId);

      verify(
        () => messagingRepo.closePoll(
          messageId: messageId,
          closerId: creatorId,
        ),
      ).called(1);
    });
  });
  // ══ BUT-1909 — a blocked person's vote must not decide the household's week ══
  //
  // Blocking already hides what someone SAYS. It did not touch what their vote
  // DOES, and a poll winner is written into the weekly plan — so a blocked
  // person could steer a recipe into your week from behind a filtered chat.
  //
  // The filter is applied by the SERVICE, through the same helper the display
  // path uses, because filtering the count on screen but not the winner (or the
  // reverse) makes the number and the outcome contradict each other. The
  // repository stays ignorant of blocking on purpose — pinned separately in
  // `message_query_module_test.dart`.
  group('closePoll excludes blocked voters (BUT-1909)', () {
    late _MockBlockedUserFilter blockFilter;

    /// Two options where the BLOCKED voters are the majority. That shape is
    /// load-bearing: with an unfiltered tally `opt-blocked` wins, with a
    /// filtered one `opt-clean` does, so the assertion below can tell the two
    /// apart. A fixture where both tallies agree would pass either way.
    Poll contestedPoll() => Poll(
      id: 'poll-blocked',
      question: 'Vad ska vi äta?',
      creatorId: creatorId,
      createdAt: DateTime.now(),
      options: [
        PollOption(
          id: 'opt-blocked',
          text: 'Tacos',
          voterIds: const ['blocked-1', 'blocked-2'],
          recipeId: 'recipe-blocked',
        ),
        PollOption(
          id: 'opt-clean',
          text: 'Pasta',
          voterIds: const ['user-2'],
          recipeId: 'recipe-clean',
        ),
      ],
    );

    Message contestedMessage() {
      final base = _pollMessage(
        messageId: messageId,
        conversationId: conversationId,
        poll: contestedPoll(),
      );
      return base.copyWith(
        metadata: {
          ...base.metadata!,
          PollVoteHydration.metadataKey: PollVoteHydration.ok.name,
        },
      );
    }

    setUp(() {
      blockFilter = _MockBlockedUserFilter();
      GetIt.instance.unregister<BlockedUserFilter>();
      GetIt.instance.registerSingleton<BlockedUserFilter>(blockFilter);
      when(() => recipeService.recipes).thenReturn([
        _recipe('recipe-blocked', 'Tacos'),
        _recipe('recipe-clean', 'Pasta'),
      ]);
      when(
        () => messagingRepo.getMessage(messageId),
      ).thenAnswer((_) async => contestedMessage());
    });

    test('the CONTROL: with nobody blocked, the majority wins', () async {
      // Establishes that the fixture really does resolve to `recipe-blocked`
      // when nothing is filtered. Without it, the next test's assertion could
      // be satisfied by a winner resolution that never worked at all.
      when(
        () => blockFilter.requireBlockedIds(),
      ).thenAnswer((_) async => <String>{});

      await service.closePoll(messageId: messageId);

      final saved =
          verify(
                () => groupPlanService.addEntry(
                  plan: any(named: 'plan'),
                  actorId: any(named: 'actorId'),
                  day: any(named: 'day'),
                  slot: any(named: 'slot'),
                  recipe: captureAny(named: 'recipe'),
                ),
              ).captured.single
              as Recipe;
      expect(saved.id, 'recipe-blocked');
    });

    test('a blocked majority does not decide the winner', () async {
      when(
        () => blockFilter.requireBlockedIds(),
      ).thenAnswer((_) async => {'blocked-1', 'blocked-2'});

      await service.closePoll(messageId: messageId);

      final saved =
          verify(
                () => groupPlanService.addEntry(
                  plan: any(named: 'plan'),
                  actorId: any(named: 'actorId'),
                  day: any(named: 'day'),
                  slot: any(named: 'slot'),
                  recipe: captureAny(named: 'recipe'),
                ),
              ).captured.single
              as Recipe;
      expect(
        saved.id,
        'recipe-clean',
        reason:
            'the two blocked ballots outnumber the one clean vote — if they '
            'still counted, the blocked option would be in the week plan',
      );
    });

    test('an unreadable block list REFUSES rather than failing open', () async {
      // Deliberately the OPPOSITE of the display path's contract. There, a
      // transient block-list error serves an over-counted poll, which is
      // recoverable. Here it would let a blocked ballot pick the recipe other
      // members then see in their plan, which is not.
      //
      // A REAL `BlockedUserFilter` over a throwing repository, not the mock the
      // other cases use. The first version of this test stubbed
      // `currentBlockedIds()` to throw — and the real method CANNOT throw, it
      // catches internally and returns an empty set. So it measured its own
      // mock while production fell open, which is what the
      // firebase-backend-security gate caught. `requireBlockedIds` is the
      // propagating variant this path now calls, and the only way to prove it
      // is to let the repository underneath do the throwing.
      final throwingRepo = _MockBlockRepo();
      when(() => throwingRepo.getBlockedUserIds()).thenThrow(
        Exception('offline'),
      );
      GetIt.instance.unregister<BlockedUserFilter>();
      GetIt.instance.registerSingleton<BlockedUserFilter>(
        BlockedUserFilter(blockRepository: throwingRepo),
      );

      await expectLater(
        service.closePoll(messageId: messageId),
        throwsA(
          isA<PollCloseRefusedException>().having(
            (e) => e.reason,
            'reason',
            PollCloseRefusal.blockListUnknown,
          ),
        ),
      );

      // Both omissions, not just one: a guard that skipped the plan but still
      // flipped `isClosed` would burn the poll with no way back.
      verifyNever(
        () => messagingRepo.closePoll(
          messageId: any(named: 'messageId'),
          closerId: any(named: 'closerId'),
        ),
      );
      verifyNever(
        () => groupPlanService.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      );
    });

    test('NO block filter registered refuses too (BUT-1926)', () async {
      // The hole this closes: the branch used to be wrapped in
      // `if (blockFilter != null)`, so a build where the filter never got
      // registered skipped the whole guard and resolved on the raw tally —
      // the same fail-open the case above refuses, reached by a different
      // door. Absence is not an empty block list; it is not knowing.
      GetIt.instance.unregister<BlockedUserFilter>();

      await expectLater(
        service.closePoll(messageId: messageId),
        throwsA(
          isA<PollCloseRefusedException>().having(
            (e) => e.reason,
            'reason',
            PollCloseRefusal.blockListUnknown,
          ),
        ),
      );

      verifyNever(
        () => messagingRepo.closePoll(
          messageId: any(named: 'messageId'),
          closerId: any(named: 'closerId'),
        ),
      );
      verifyNever(
        () => groupPlanService.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      );
    });
  });

  // ══ BUT-1928 — a failed week READ must not be saved over ══
  //
  // Both plan services answer a failed fetch with "nothing there": an empty
  // `WeeklyMenuPlan` and a null `GroupWeeklyMenuPlan`. Appending the winner to
  // that and saving is an upsert on a deterministic doc id, so the whole week —
  // every other entry, for every member of a group — is replaced by one recipe.
  //
  // Refusing leaves the poll OPEN (the close is written after the plan), so a
  // retry once the read works is the recovery. The controls beside each case
  // are what stop the guard from being an unconditional throw.
  group('closePoll refuses to write over an unread week (BUT-1928)', () {
    setUp(() {
      when(() => recipeService.recipes).thenReturn([
        _recipe('recipe-winner', 'Tacos'),
      ]);
    });

    Poll winningPoll(String id) => Poll(
      id: id,
      question: 'Vad ska vi äta?',
      creatorId: creatorId,
      createdAt: DateTime.now(),
      options: [
        PollOption(
          id: 'opt-1',
          text: 'Tacos',
          voterIds: const ['user-2'],
          recipeId: 'recipe-winner',
        ),
      ],
    );

    test('group: a failed read → no save, poll stays open', () async {
      when(
        () => groupPlanService.readOrBuildWeek(
          groupId: any(named: 'groupId'),
          creatorId: any(named: 'creatorId'),
          date: any(named: 'date'),
          initialParticipants: any(named: 'initialParticipants'),
        ),
      ).thenAnswer(
        (_) async =>
            const GroupWeeklyMenuPlanRead(plan: null, readFailed: true),
      );
      when(() => messagingRepo.getMessage(messageId)).thenAnswer(
        (_) async => _pollMessage(
          messageId: messageId,
          conversationId: conversationId,
          poll: winningPoll('poll-group-unread'),
        ),
      );

      await expectLater(
        service.closePoll(messageId: messageId),
        throwsA(
          isA<StateError>(),
        ),
      );

      verifyNever(
        () => groupPlanService.save(
          plan: any(named: 'plan'),
          actorId: any(named: 'actorId'),
        ),
      );
      // The poll itself must survive: closing is one-way, and the winner is
      // still unwritten.
      verifyNever(
        () => messagingRepo.closePoll(
          messageId: any(named: 'messageId'),
          closerId: any(named: 'closerId'),
        ),
      );
    });

    test('1:1: a failed read → no save, poll stays open', () async {
      when(() => planService.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(
          plan: WeeklyMenuPlan.empty(
            userId: creatorId,
            date: DateTime.now(),
          ),
          readFailed: true,
        ),
      );
      when(
        () => messagingRepo.getConversation(directConversationId),
      ).thenAnswer(
        (_) async =>
            _directConversation(directConversationId, [creatorId, 'user-2']),
      );
      when(() => messagingRepo.getMessage(messageId)).thenAnswer(
        (_) async => _pollMessage(
          messageId: messageId,
          conversationId: directConversationId,
          poll: winningPoll('poll-personal-unread'),
        ),
      );

      await expectLater(
        service.closePoll(messageId: messageId),
        throwsA(
          isA<StateError>(),
        ),
      );

      verifyNever(() => planService.save(any()));
      verifyNever(
        () => messagingRepo.closePoll(
          messageId: any(named: 'messageId'),
          closerId: any(named: 'closerId'),
        ),
      );
    });

    test('the CONTROL: a read that SUCCEEDS on an empty week still '
        'saves', () async {
      // Without this the two refusals above are satisfied by a service that
      // never writes a plan at all. An empty-but-read week is exactly the
      // shape a failed read produces, so this is the case the guard must let
      // through — it discriminates on `readFailed`, not on emptiness.
      when(() => messagingRepo.getMessage(messageId)).thenAnswer(
        (_) async => _pollMessage(
          messageId: messageId,
          conversationId: conversationId,
          poll: winningPoll('poll-group-empty-week'),
        ),
      );

      await service.closePoll(messageId: messageId);

      verify(
        () => groupPlanService.save(
          plan: any(named: 'plan'),
          actorId: creatorId,
        ),
      ).called(1);
      verify(
        () => messagingRepo.closePoll(
          messageId: messageId,
          closerId: creatorId,
        ),
      ).called(1);
    });
  });
}
