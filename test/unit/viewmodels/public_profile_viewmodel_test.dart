import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/viewmodels/public_profile_viewmodel.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('PublicProfileViewModel', () {
    late MockUserRepository mockUserRepo;
    late MockRecipeRepository mockRecipeRepo;

    const testUserId = 'user-public-456';

    final testProfile = MockFactory.createUserProfile(
      userId: testUserId,
      displayName: 'Chef Anna',
      publicRecipeCount: 3,
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      production.ServiceLocator.initialize(DIContainer());

      mockUserRepo = MockUserRepository();
      mockRecipeRepo = MockRecipeRepository();

      TestServiceLocator.registerMock<UserRepository>(mockUserRepo);
      TestServiceLocator.registerMock<RecipeRepository>(mockRecipeRepo);
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // Helper to create the VM. The constructor calls loadProfile() immediately,
    // so we must set up stubs before creating the VM.
    PublicProfileViewModel createViewModel() {
      return PublicProfileViewModel(userId: testUserId);
    }

    // -- loadProfile success --

    group('loadProfile', () {
      test('should load profile and public recipes on construction', () async {
        // Behavior: constructing the VM triggers loadProfile which fetches
        // both user profile and public recipes
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Pasta Carbonara'),
          RecipeFactory.build(id: 'r2', title: 'Pizza Margherita'),
        ];

        when(
          () => mockUserRepo.fetchProfile(testUserId),
        ).thenAnswer((_) async => testProfile);
        when(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: any(named: 'limit'),
            after: any(named: 'after'),
          ),
        ).thenAnswer((_) async => recipes);

        final viewModel = createViewModel();

        // Wait for the async constructor call to complete
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        expect(viewModel.profile, isNotNull);
        expect(viewModel.profile!.displayName, 'Chef Anna');
        expect(viewModel.publicRecipes, hasLength(2));
        expect(viewModel.hasPublicRecipes, true);
        expect(viewModel.isLoading, false);
        expect(viewModel.hasError, false);

        viewModel.dispose();
      });

      test('should set error when profile is not found (null)', () async {
        // Behavior: null profile from repo triggers an error with
        // publicProfileError message
        when(
          () => mockUserRepo.fetchProfile(testUserId),
        ).thenAnswer((_) async => null);

        final viewModel = createViewModel();

        // Wait for the async constructor call to complete
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        expect(viewModel.hasError, true);
        expect(viewModel.profile, isNull);
        expect(viewModel.publicRecipes, isEmpty);
        expect(viewModel.isLoading, false);

        viewModel.dispose();
      });

      test('should set error when user repository throws', () async {
        // Behavior: repository exception is caught and surfaced as error state
        when(
          () => mockUserRepo.fetchProfile(testUserId),
        ).thenThrow(Exception('Network error'));

        final viewModel = createViewModel();

        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        expect(viewModel.hasError, true);
        expect(viewModel.isLoading, false);
        expect(viewModel.profile, isNull);

        viewModel.dispose();
      });

      test('should set error when recipe repository throws', () async {
        // Behavior: profile loads but recipe fetch fails — error state set
        when(
          () => mockUserRepo.fetchProfile(testUserId),
        ).thenAnswer((_) async => testProfile);
        when(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: any(named: 'limit'),
            after: any(named: 'after'),
          ),
        ).thenThrow(Exception('Firestore unavailable'));

        final viewModel = createViewModel();

        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        expect(viewModel.hasError, true);
        expect(viewModel.isLoading, false);

        viewModel.dispose();
      });

      test('should handle user with no public recipes', () async {
        // Behavior: valid profile but empty recipe list is a normal state,
        // not an error
        when(
          () => mockUserRepo.fetchProfile(testUserId),
        ).thenAnswer((_) async => testProfile);
        when(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: any(named: 'limit'),
            after: any(named: 'after'),
          ),
        ).thenAnswer((_) async => <Recipe>[]);

        final viewModel = createViewModel();

        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        expect(viewModel.profile, isNotNull);
        expect(viewModel.publicRecipes, isEmpty);
        expect(viewModel.hasPublicRecipes, false);
        expect(viewModel.hasError, false);

        viewModel.dispose();
      });
    });

    // -- Loading state management --

    group('loading state', () {
      test('should be loading while profile is being fetched', () async {
        // Behavior: isLoading is true during the async operation
        final completer = Completer<UserProfile?>();

        when(
          () => mockUserRepo.fetchProfile(testUserId),
        ).thenAnswer((_) => completer.future);

        final viewModel = createViewModel();

        // The async operation is in progress
        await Future.delayed(Duration.zero);
        expect(viewModel.isLoading, true);

        // Complete the future
        completer.complete(testProfile);

        // Need recipe stub too for the second part
        when(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: any(named: 'limit'),
            after: any(named: 'after'),
          ),
        ).thenAnswer((_) async => <Recipe>[]);

        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        expect(viewModel.isLoading, false);

        viewModel.dispose();
      });
    });

    // -- R8-7: findable in search, read strictly --

    group('isSearchable', () {
      Future<PublicProfileViewModel> loadWith(
        Future<bool> Function() searchable,
      ) async {
        when(
          () => mockUserRepo.fetchProfile(testUserId),
        ).thenAnswer((_) async => testProfile);
        when(
          () => mockUserRepo.fetchPersistedSearchable(testUserId),
        ).thenAnswer((_) => searchable());
        when(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: any(named: 'limit'),
            after: any(named: 'after'),
          ),
        ).thenAnswer((_) async => <Recipe>[]);
        final viewModel = createViewModel();
        for (var i = 0; i < 5; i++) {
          await Future.delayed(Duration.zero);
        }
        return viewModel;
      }

      test('is the stored value when it reads true', () async {
        final viewModel = await loadWith(() async => true);

        expect(viewModel.isSearchable, isTrue);
        viewModel.dispose();
      });

      test('is false when the stored value is not true', () async {
        final viewModel = await loadWith(() async => false);

        expect(viewModel.isSearchable, isFalse);
        viewModel.dispose();
      });

      test('a profile hidden by moderation is not searchable, as in '
          'search', () async {
        when(() => mockUserRepo.fetchProfile(testUserId)).thenAnswer(
          (_) async => testProfile.copyWith(isHidden: true),
        );
        when(
          () => mockUserRepo.fetchPersistedSearchable(testUserId),
        ).thenAnswer((_) async => true);
        when(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: any(named: 'limit'),
            after: any(named: 'after'),
          ),
        ).thenAnswer((_) async => <Recipe>[]);
        final viewModel = createViewModel();
        for (var i = 0; i < 5; i++) {
          await Future.delayed(Duration.zero);
        }

        expect(viewModel.profile, isNotNull);
        expect(viewModel.isSearchable, isFalse);
        viewModel.dispose();
      });

      test('a failed read counts as not searchable and still shows the '
          'profile', () async {
        final viewModel = await loadWith(() async => throw Exception('down'));

        expect(viewModel.isSearchable, isFalse);
        expect(viewModel.profile, isNotNull);
        expect(viewModel.hasError, isFalse);
        viewModel.dispose();
      });
    });

    // -- Verify delegation --

    group('repository delegation', () {
      test('should call fetchProfile with the correct userId', () async {
        // Behavior: the VM passes its userId to the user repository
        when(
          () => mockUserRepo.fetchProfile(testUserId),
        ).thenAnswer((_) async => testProfile);
        when(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: any(named: 'limit'),
            after: any(named: 'after'),
          ),
        ).thenAnswer((_) async => <Recipe>[]);

        final viewModel = createViewModel();
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        verify(() => mockUserRepo.fetchProfile(testUserId)).called(1);

        viewModel.dispose();
      });

      test(
        'should call fetchPublicUserRecipes with the correct userId',
        () async {
          // Behavior: the VM passes its userId to the recipe repository
          when(
            () => mockUserRepo.fetchProfile(testUserId),
          ).thenAnswer((_) async => testProfile);
          when(
            () => mockRecipeRepo.fetchPublicUserRecipes(
              testUserId,
              limit: any(named: 'limit'),
              after: any(named: 'after'),
            ),
          ).thenAnswer((_) async => <Recipe>[]);

          final viewModel = createViewModel();
          await Future.delayed(Duration.zero);
          await Future.delayed(Duration.zero);

          verify(
            () => mockRecipeRepo.fetchPublicUserRecipes(
              testUserId,
              limit: any(named: 'limit'),
              after: any(named: 'after'),
            ),
          ).called(1);

          viewModel.dispose();
        },
      );
    });

    group('paging', () {
      List<Recipe> page(String prefix, int n) => [
        for (var i = 0; i < n; i++)
          RecipeFactory.build(id: '$prefix$i', title: 'Recept $prefix$i'),
      ];

      Future<PublicProfileViewModel> loadFirst(List<Recipe> first) async {
        when(
          () => mockUserRepo.fetchProfile(testUserId),
        ).thenAnswer((_) async => testProfile);
        when(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: any(named: 'limit'),
            after: null,
          ),
        ).thenAnswer((_) async => first);
        final viewModel = createViewModel();
        for (var i = 0; i < 5; i++) {
          await Future.delayed(Duration.zero);
        }
        return viewModel;
      }

      test('a full first page of 20 has more', () async {
        final viewModel = await loadFirst(page('a', 20));

        expect(PublicProfileViewModel.recipePageSize, 20);
        expect(viewModel.hasMoreRecipes, isTrue);
        verify(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: 20,
            after: null,
          ),
        ).called(1);
        viewModel.dispose();
      });

      test('a short first page has no more', () async {
        final viewModel = await loadFirst(page('a', 19));

        expect(viewModel.hasMoreRecipes, isFalse);
        viewModel.dispose();
      });

      test('loadMoreRecipes appends and asks after the last recipe', () async {
        final first = page('a', 20);
        final viewModel = await loadFirst(first);
        final second = page('b', 5);
        when(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: any(named: 'limit'),
            after: first.last,
          ),
        ).thenAnswer((_) async => second);

        await viewModel.loadMoreRecipes();

        expect(viewModel.publicRecipes, [...first, ...second]);
        expect(viewModel.hasMoreRecipes, isFalse);
        expect(viewModel.isLoadingMore, isFalse);
        verify(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: 20,
            after: first.last,
          ),
        ).called(1);
        viewModel.dispose();
      });

      test('a full second page keeps hasMoreRecipes true', () async {
        final first = page('a', 20);
        final viewModel = await loadFirst(first);
        when(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: any(named: 'limit'),
            after: first.last,
          ),
        ).thenAnswer((_) async => page('b', 20));

        await viewModel.loadMoreRecipes();

        expect(viewModel.publicRecipes, hasLength(40));
        expect(viewModel.hasMoreRecipes, isTrue);
        viewModel.dispose();
      });

      test(
        'a failing loadMoreRecipes keeps the list, no error, can retry',
        () async {
          final first = page('a', 20);
          final viewModel = await loadFirst(first);
          when(
            () => mockRecipeRepo.fetchPublicUserRecipes(
              testUserId,
              limit: any(named: 'limit'),
              after: first.last,
            ),
          ).thenThrow(Exception('offline'));

          await viewModel.loadMoreRecipes();

          expect(viewModel.publicRecipes, first);
          expect(viewModel.hasError, isFalse);
          expect(viewModel.hasMoreRecipes, isTrue);
          expect(viewModel.isLoadingMore, isFalse);
          viewModel.dispose();
        },
      );

      test('loadMoreRecipes does nothing without more', () async {
        final viewModel = await loadFirst(page('a', 3));

        await viewModel.loadMoreRecipes();

        verifyNever(
          () => mockRecipeRepo.fetchPublicUserRecipes(
            testUserId,
            limit: any(named: 'limit'),
            after: any(named: 'after', that: isNotNull),
          ),
        );
        viewModel.dispose();
      });
    });
  });
}
