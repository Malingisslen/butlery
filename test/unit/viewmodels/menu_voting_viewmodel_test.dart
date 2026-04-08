import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/viewmodels/menu_voting_viewmodel.dart';
import 'package:butlery/services/menu_voting_service.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Mock for MenuVotingService (not in production_mocks)
class MockMenuVotingService extends Mock implements MenuVotingService {}

// Fake for VoteOption (needed for any() matchers)
class FakeVoteOption extends Fake implements VoteOption {}

void main() {
  group('MenuVotingViewModel', () {
    late MenuVotingViewModel viewModel;
    late MockMenuVotingService mockVotingService;
    late StreamController<List<MenuSlotVote>> votesStreamController;

    const testMenuId = 'menu-123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(FakeVoteOption());
      registerFallbackValue(const Duration(hours: 24));
      registerFallbackValue(<VoteOption>[]);
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      production.ServiceLocator.initialize(DIContainer());

      mockVotingService = MockMenuVotingService();
      votesStreamController = StreamController<List<MenuSlotVote>>.broadcast();

      TestServiceLocator.registerMock<MenuVotingService>(mockVotingService);

      viewModel = MenuVotingViewModel(menuId: testMenuId);
    });

    tearDown(() async {
      if (!viewModel.isDisposed) viewModel.dispose();
      await votesStreamController.close();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // -- Initial state --

    test('should start with empty votes and no loading', () {
      // Behavior: a freshly created VM has no votes and is not loading
      expect(viewModel.allVotes, isEmpty);
      expect(viewModel.activeVotes, isEmpty);
      expect(viewModel.resolvedVotes, isEmpty);
      expect(viewModel.isLoading, false);
    });

    // -- subscribe() --

    group('subscribe', () {
      test('should receive votes from service stream', () async {
        // Behavior: subscribing connects the VM to the service stream
        when(() => mockVotingService.watchVotesForMenu(testMenuId))
            .thenAnswer((_) => votesStreamController.stream);

        final vote = _createActiveVote();

        viewModel.subscribe();
        votesStreamController.add([vote]);

        // Let the stream event propagate
        await Future.delayed(Duration.zero);

        expect(viewModel.allVotes, hasLength(1));
        expect(viewModel.allVotes.first.id, vote.id);
      });

      test('should update activeVotes when stream emits active votes',
          () async {
        // Behavior: activeVotes filters to only non-resolved, non-expired votes
        when(() => mockVotingService.watchVotesForMenu(testMenuId))
            .thenAnswer((_) => votesStreamController.stream);

        final activeVote = _createActiveVote();
        final resolvedVote = _createResolvedVote();

        viewModel.subscribe();
        votesStreamController.add([activeVote, resolvedVote]);
        await Future.delayed(Duration.zero);

        expect(viewModel.activeVotes, hasLength(1));
        expect(viewModel.activeVotes.first.id, activeVote.id);
      });

      test('should update resolvedVotes when stream emits resolved votes',
          () async {
        // Behavior: resolvedVotes filters to only resolved votes
        when(() => mockVotingService.watchVotesForMenu(testMenuId))
            .thenAnswer((_) => votesStreamController.stream);

        final resolvedVote = _createResolvedVote();

        viewModel.subscribe();
        votesStreamController.add([resolvedVote]);
        await Future.delayed(Duration.zero);

        expect(viewModel.resolvedVotes, hasLength(1));
        expect(viewModel.resolvedVotes.first.id, resolvedVote.id);
      });

      test('should cancel previous subscription on re-subscribe', () async {
        // Behavior: calling subscribe() twice cancels the first stream
        final controller1 = StreamController<List<MenuSlotVote>>.broadcast();
        final controller2 = StreamController<List<MenuSlotVote>>.broadcast();

        when(() => mockVotingService.watchVotesForMenu(testMenuId))
            .thenAnswer((_) => controller1.stream);
        viewModel.subscribe();

        when(() => mockVotingService.watchVotesForMenu(testMenuId))
            .thenAnswer((_) => controller2.stream);
        viewModel.subscribe();

        // Emit on the old controller - should not update
        controller1.add([_createActiveVote()]);
        await Future.delayed(Duration.zero);
        expect(viewModel.allVotes, isEmpty);

        // Emit on the new controller - should update
        final vote = _createActiveVote(id: 'new-vote');
        controller2.add([vote]);
        await Future.delayed(Duration.zero);
        expect(viewModel.allVotes, hasLength(1));
        expect(viewModel.allVotes.first.id, 'new-vote');

        await controller1.close();
        await controller2.close();
      });

      test('should not update state after dispose', () async {
        // Behavior: isDisposed guard prevents state mutation after dispose
        when(() => mockVotingService.watchVotesForMenu(testMenuId))
            .thenAnswer((_) => votesStreamController.stream);

        viewModel.subscribe();
        viewModel.dispose();

        // Emit after dispose - should not crash or update state
        votesStreamController.add([_createActiveVote()]);
        await Future.delayed(Duration.zero);

        expect(viewModel.allVotes, isEmpty);
      });
    });

    // -- createVote() --

    group('createVote', () {
      test('should delegate to service and return true on success', () async {
        // Behavior: createVote passes all parameters to the service
        final alternatives = [
          _createVoteOption(id: 'opt-1', recipeName: 'Pasta'),
          _createVoteOption(id: 'opt-2', recipeName: 'Pizza'),
        ];

        when(() => mockVotingService.createVote(
              menuId: testMenuId,
              category: 'dinner',
              slotIndex: 0,
              alternatives: alternatives,
              votingWindow: const Duration(hours: 12),
            )).thenAnswer((_) async => _createActiveVote());

        final result = await viewModel.createVote(
          category: 'dinner',
          slotIndex: 0,
          alternatives: alternatives,
          votingWindow: const Duration(hours: 12),
        );

        expect(result, true);
        verify(() => mockVotingService.createVote(
              menuId: testMenuId,
              category: 'dinner',
              slotIndex: 0,
              alternatives: alternatives,
              votingWindow: const Duration(hours: 12),
            )).called(1);
      });

      test('should return false when service returns null', () async {
        // Behavior: null from service means vote creation failed
        when(() => mockVotingService.createVote(
              menuId: any(named: 'menuId'),
              category: any(named: 'category'),
              slotIndex: any(named: 'slotIndex'),
              alternatives: any(named: 'alternatives'),
              votingWindow: any(named: 'votingWindow'),
            )).thenAnswer((_) async => null);

        final result = await viewModel.createVote(
          category: 'lunch',
          slotIndex: 1,
          alternatives: [],
        );

        expect(result, false);
      });
    });

    // -- castVote() --

    group('castVote', () {
      test('should delegate to service with correct parameters', () async {
        // Behavior: castVote forwards menuId, voteId, optionId to service
        when(() => mockVotingService.castVote(testMenuId, 'vote-1', 'option-1'))
            .thenAnswer((_) async => true);

        final result = await viewModel.castVote('vote-1', 'option-1');

        expect(result, true);
        verify(() =>
                mockVotingService.castVote(testMenuId, 'vote-1', 'option-1'))
            .called(1);
      });

      test('should return false when service returns false', () async {
        // Behavior: failed vote cast propagates false
        when(() => mockVotingService.castVote(testMenuId, 'vote-1', 'option-1'))
            .thenAnswer((_) async => false);

        final result = await viewModel.castVote('vote-1', 'option-1');
        expect(result, false);
      });
    });

    // -- resolveVote() --

    group('resolveVote', () {
      test('should delegate to service with correct parameters', () async {
        // Behavior: resolveVote forwards menuId and voteId to service
        when(() => mockVotingService.resolveVote(testMenuId, 'vote-1'))
            .thenAnswer((_) async => true);

        final result = await viewModel.resolveVote('vote-1');

        expect(result, true);
        verify(() => mockVotingService.resolveVote(testMenuId, 'vote-1'))
            .called(1);
      });

      test('should return false when service returns false', () async {
        // Behavior: failed resolution propagates false
        when(() => mockVotingService.resolveVote(testMenuId, 'vote-1'))
            .thenAnswer((_) async => false);

        final result = await viewModel.resolveVote('vote-1');
        expect(result, false);
      });
    });

    // -- addAlternative() --

    group('addAlternative', () {
      test('should delegate to service with correct parameters', () async {
        // Behavior: addAlternative forwards menuId, voteId, and option to service
        final option = _createVoteOption(id: 'opt-new', recipeName: 'Sushi');

        when(() =>
                mockVotingService.addAlternative(testMenuId, 'vote-1', option))
            .thenAnswer((_) async => true);

        final result = await viewModel.addAlternative('vote-1', option);

        expect(result, true);
        verify(() =>
                mockVotingService.addAlternative(testMenuId, 'vote-1', option))
            .called(1);
      });
    });

    // -- getVoteForSlot() --

    group('getVoteForSlot', () {
      test('should return matching active vote for category and slot',
          () async {
        // Behavior: finds the active vote matching category + slotIndex
        when(() => mockVotingService.watchVotesForMenu(testMenuId))
            .thenAnswer((_) => votesStreamController.stream);

        final vote = _createActiveVote(category: 'dinner', slotIndex: 2);

        viewModel.subscribe();
        votesStreamController.add([vote]);
        await Future.delayed(Duration.zero);

        final found = viewModel.getVoteForSlot('dinner', 2);
        expect(found, isNotNull);
        expect(found!.id, vote.id);
      });

      test('should return null when no matching vote exists', () async {
        // Behavior: returns null for non-matching slot
        when(() => mockVotingService.watchVotesForMenu(testMenuId))
            .thenAnswer((_) => votesStreamController.stream);

        viewModel.subscribe();
        votesStreamController.add([_createActiveVote()]);
        await Future.delayed(Duration.zero);

        final found = viewModel.getVoteForSlot('breakfast', 99);
        expect(found, isNull);
      });

      test('should return null when no votes loaded', () {
        // Behavior: empty state returns null
        final found = viewModel.getVoteForSlot('dinner', 0);
        expect(found, isNull);
      });

      test('should not return resolved votes', () async {
        // Behavior: getVoteForSlot only returns active (not resolved) votes
        when(() => mockVotingService.watchVotesForMenu(testMenuId))
            .thenAnswer((_) => votesStreamController.stream);

        final resolved = _createResolvedVote(category: 'dinner', slotIndex: 0);

        viewModel.subscribe();
        votesStreamController.add([resolved]);
        await Future.delayed(Duration.zero);

        final found = viewModel.getVoteForSlot('dinner', 0);
        expect(found, isNull);
      });
    });

    // -- dispose() --

    group('dispose', () {
      test('should cancel stream subscription on dispose', () async {
        // Behavior: disposing the VM cancels the stream to prevent leaks
        when(() => mockVotingService.watchVotesForMenu(testMenuId))
            .thenAnswer((_) => votesStreamController.stream);

        viewModel.subscribe();
        viewModel.dispose();

        // After dispose, emitting should not cause issues
        votesStreamController.add([_createActiveVote()]);
        await Future.delayed(Duration.zero);

        expect(viewModel.isDisposed, true);
        expect(viewModel.allVotes, isEmpty);
      });
    });
  });
}

// -- Test data helpers --

MenuSlotVote _createActiveVote({
  String id = 'vote-1',
  String category = 'dinner',
  int slotIndex = 0,
}) {
  return MenuSlotVote(
    id: id,
    menuId: 'menu-123',
    category: category,
    slotIndex: slotIndex,
    alternatives: [
      _createVoteOption(id: 'opt-1', recipeName: 'Pasta'),
    ],
    deadline: DateTime.now().add(const Duration(hours: 24)),
    isResolved: false,
    createdByUserId: 'user-1',
    createdAt: DateTime.now(),
  );
}

MenuSlotVote _createResolvedVote({
  String id = 'vote-resolved',
  String category = 'dinner',
  int slotIndex = 0,
}) {
  return MenuSlotVote(
    id: id,
    menuId: 'menu-123',
    category: category,
    slotIndex: slotIndex,
    alternatives: [
      _createVoteOption(id: 'opt-1', recipeName: 'Pasta'),
    ],
    deadline: DateTime.now().add(const Duration(hours: 24)),
    isResolved: true,
    winningOptionId: 'opt-1',
    createdByUserId: 'user-1',
    createdAt: DateTime.now(),
  );
}

VoteOption _createVoteOption({
  required String id,
  required String recipeName,
}) {
  return VoteOption(
    id: id,
    recipeId: 'recipe-$id',
    recipeName: recipeName,
    suggestedByUserId: 'user-1',
  );
}
