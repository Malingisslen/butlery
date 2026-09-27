/// P8-U01 hosts: start, friends/group (three rows) and the ingredient
/// search (two rows).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/app/auth/auth_wrapper.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/ingredient_match_service.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/viewmodels/ingredient_search_viewmodel.dart';
import 'package:butlery/views/ingredient_search/ingredient_search_view.dart';
import 'package:butlery/views/social/add_members_to_group_view.dart';

import '../../../helpers/user_profile_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../state_host.dart';

class _MockFriends extends Mock implements UnifiedFriendsService {}

class _MockCategories extends Mock implements FriendsCategoriesOperations {}

class _MockManagement extends Mock implements FriendsManagementOperations {}

class _MockInvitations extends Mock implements FriendsInvitationsOperations {}

class _MockMatch extends Mock implements IngredientMatchService {}

class _MockIngredients extends Mock implements IngredientRepository {}

class _MockRecipes extends Mock implements UnifiedRecipeService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

const _me = 'test-user-123';

/// The group "Middagsgänget" and the friends who could join it. With
/// [coldStart] the friends service has not loaded yet: it says it is
/// loading and its in-memory list is still empty.
Widget _addMembers({required bool friends, bool coldStart = false}) {
  final service = _MockFriends();
  final categories = _MockCategories();
  final management = _MockManagement();
  final invitations = _MockInvitations();
  when(() => service.categories).thenReturn(categories);
  when(() => service.management).thenReturn(management);
  when(() => service.invitations).thenReturn(invitations);
  when(() => service.currentUserId).thenReturn(_me);
  when(() => service.hasError).thenReturn(false);
  when(() => service.isLoading).thenReturn(coldStart);
  when(() => service.isInitialized).thenReturn(!coldStart);
  when(() => categories.getCategoryById(any())).thenReturn(
    FriendCategory(
      id: 'g1',
      ownerId: _me,
      name: 'Middagsgänget',
      friendUserIds: const ['u-per'],
    ),
  );
  when(management.getAllFriends).thenReturn([
    if (friends && !coldStart) ...[
      testUserProfile(uid: 'u-anna', displayName: 'Anna Lindqvist'),
      testUserProfile(uid: 'u-cecilia', displayName: 'Cecilia Berg'),
      testUserProfile(uid: 'u-david', displayName: 'David Öberg'),
    ],
    if (!coldStart) testUserProfile(uid: 'u-per', displayName: 'Per Nilsson'),
  ]);
  when(invitations.getSentInvitations).thenReturn(const []);
  TestServiceLocator.registerMock<UnifiedFriendsService>(service);
  return const AddMembersToGroupView(groupId: 'g1');
}

/// The ingredient search over two recipes of the user's own.
IngredientSearchViewModel _search(
  HostContext ctx, {
  required List<IngredientMatchResult> results,
}) {
  final match = _MockMatch();
  final recipes = _MockRecipes();
  final auth = _MockAuthRepository();
  when(() => auth.currentUserId).thenReturn(_me);
  final library = <Recipe>[
    RecipeFactory.build(
      id: 'r1',
      title: 'Kycklinggryta med citron',
      ingredients: ['kyckling', 'citron', 'grädde'],
    ),
    RecipeFactory.build(
      id: 'r2',
      title: 'Ugnsbakad kyckling med rotfrukter',
      ingredients: ['kyckling', 'morot', 'palsternacka'],
    ),
  ];
  when(() => recipes.recipes).thenReturn(library);
  when(
    () => match.matchRecipesWithNormalization(
      selectedIngredientIds: any(named: 'selectedIngredientIds'),
      recipes: any(named: 'recipes'),
    ),
  ).thenAnswer(
    (_) async => [
      for (final r in results)
        IngredientMatchResult(
          recipe: library.firstWhere((l) => l.id == r.recipe.id),
          matchPercent: r.matchPercent,
          matchedCount: r.matchedCount,
          totalCount: r.totalCount,
          missingIngredientIds: r.missingIngredientIds,
        ),
    ],
  );
  TestServiceLocator.registerMock<AuthRepository>(auth);
  final vm = IngredientSearchViewModel(
    matchService: match,
    ingredientRepository: _MockIngredients(),
    recipeService: recipes,
  );
  TestServiceLocator.registerMock<IngredientSearchViewModel>(vm);
  return vm;
}

const _chicken = IngredientData(
  id: 'kyckling',
  swedish: 'kyckling',
  english: 'chicken',
  group: 'other',
  properties: {},
);

const _lemon = IngredientData(
  id: 'citron',
  swedish: 'citron',
  english: 'lemon',
  group: 'other',
  properties: {},
);

Future<void> _searchFor(WidgetTester tester, HostContext ctx) async {
  final vm = TestServiceLocator.get<IngredientSearchViewModel>()
    ..addIngredient(_chicken)
    ..addIngredient(_lemon);
  unawaited(vm.performSearch());
  await tester.pump();
  await tester.pump();
}

final socialHosts = <String, StateHost>{
  // The first screen for someone signed out: AuthWrapper shows the sign-in
  // view (lib/app/auth/auth_wrapper.dart, the signed-out branch).
  'start::DEFAULT': StateHost(
    build: (ctx) async {
      final auth = MockFactory.createAuthService(isAuthenticated: false)
        ..setAuthState(isAuthenticated: false, isLoading: false);
      TestServiceLocator.registerMock<AuthService>(auth);
      TestServiceLocator.registerMock<AuthViewModel>(
        AuthViewModel(authService: auth),
      );
      TestServiceLocator.registerMock<PendingRetentionNoticeStore>(
        PendingRetentionNoticeStore(),
      );
      return const AuthWrapper();
    },
  ),
  'vänner-grupp::DEFAULT': StateHost(
    build: (ctx) async => _addMembers(friends: true),
  ),
  'vänner-grupp::EMPTY': StateHost(
    build: (ctx) async => _addMembers(friends: false),
  ),
  // The view loads from the friends service's in-memory list. The loading
  // state is the one where that service has not loaded yet (a cold start).
  'vänner-grupp::LOADING': StateHost(
    build: (ctx) async => _addMembers(friends: true, coldStart: true),
  ),
  // BEVIS names the chip row; the chips live in IngredientSearchView,
  // which is pumped with two chosen ingredients and their matches.
  'receptlista-sök::DEFAULT': StateHost(
    build: (ctx) async {
      _search(
        ctx,
        results: [
          IngredientMatchResult(
            recipe: RecipeFactory.build(id: 'r1'),
            matchPercent: 0.67,
            matchedCount: 2,
            totalCount: 3,
            missingIngredientIds: const ['grädde'],
          ),
          IngredientMatchResult(
            recipe: RecipeFactory.build(id: 'r2'),
            matchPercent: 0.33,
            matchedCount: 1,
            totalCount: 3,
            missingIngredientIds: const ['morot', 'palsternacka'],
          ),
        ],
      );
      return const IngredientSearchView();
    },
    reach: _searchFor,
  ),
  // BEVIS is Mina recept, whose banner sits over the library
  // (mina_recept_view.dart:433). That view needs about a dozen services and
  // no test in the repo pumps it, so the row is judged on the pumpable view
  // of the same family: the ingredient search, offline, after a search.
  'receptlista-sök::OFFLINE': StateHost(
    online: false,
    build: (ctx) async {
      _search(
        ctx,
        results: [
          IngredientMatchResult(
            recipe: RecipeFactory.build(id: 'r1'),
            matchPercent: 0.67,
            matchedCount: 2,
            totalCount: 3,
            missingIngredientIds: const ['grädde'],
          ),
        ],
      );
      return const IngredientSearchView();
    },
    reach: _searchFor,
  ),
  'receptlista-sök::EMPTY': StateHost(
    build: (ctx) async {
      _search(ctx, results: const []);
      return const IngredientSearchView();
    },
    reach: _searchFor,
  ),
};
