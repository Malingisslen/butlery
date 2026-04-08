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

        when(() => mockUserRepo.fetchProfile(testUserId))
            .thenAnswer((_) async => testProfile);
        when(() => mockRecipeRepo.fetchPublicUserRecipes(testUserId))
            .thenAnswer((_) async => recipes);

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
        when(() => mockUserRepo.fetchProfile(testUserId))
            .thenAnswer((_) async => null);

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
        when(() => mockUserRepo.fetchProfile(testUserId))
            .thenThrow(Exception('Network error'));

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
        when(() => mockUserRepo.fetchProfile(testUserId))
            .thenAnswer((_) async => testProfile);
        when(() => mockRecipeRepo.fetchPublicUserRecipes(testUserId))
            .thenThrow(Exception('Firestore unavailable'));

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
        when(() => mockUserRepo.fetchProfile(testUserId))
            .thenAnswer((_) async => testProfile);
        when(() => mockRecipeRepo.fetchPublicUserRecipes(testUserId))
            .thenAnswer((_) async => <Recipe>[]);

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

        when(() => mockUserRepo.fetchProfile(testUserId))
            .thenAnswer((_) => completer.future);

        final viewModel = createViewModel();

        // The async operation is in progress
        await Future.delayed(Duration.zero);
        expect(viewModel.isLoading, true);

        // Complete the future
        completer.complete(testProfile);

        // Need recipe stub too for the second part
        when(() => mockRecipeRepo.fetchPublicUserRecipes(testUserId))
            .thenAnswer((_) async => <Recipe>[]);

        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        expect(viewModel.isLoading, false);

        viewModel.dispose();
      });
    });

    // -- Verify delegation --

    group('repository delegation', () {
      test('should call fetchProfile with the correct userId', () async {
        // Behavior: the VM passes its userId to the user repository
        when(() => mockUserRepo.fetchProfile(testUserId))
            .thenAnswer((_) async => testProfile);
        when(() => mockRecipeRepo.fetchPublicUserRecipes(testUserId))
            .thenAnswer((_) async => <Recipe>[]);

        final viewModel = createViewModel();
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        verify(() => mockUserRepo.fetchProfile(testUserId)).called(1);

        viewModel.dispose();
      });

      test('should call fetchPublicUserRecipes with the correct userId',
          () async {
        // Behavior: the VM passes its userId to the recipe repository
        when(() => mockUserRepo.fetchProfile(testUserId))
            .thenAnswer((_) async => testProfile);
        when(() => mockRecipeRepo.fetchPublicUserRecipes(testUserId))
            .thenAnswer((_) async => <Recipe>[]);

        final viewModel = createViewModel();
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);

        verify(() => mockRecipeRepo.fetchPublicUserRecipes(testUserId))
            .called(1);

        viewModel.dispose();
      });
    });
  });
}
