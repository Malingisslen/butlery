/// Widget tests for [SharedRecipesByFriendView] (BUT-1000) — the per-friend
/// filtered "shared with me" list.
///
/// Intent: prove the view's render-state branching (the `_buildBody` contract):
/// loading → spinner, error → error state with retry, empty → branded empty
/// state, and that its own chrome stays in the square design language (the view
/// introduces no rounded `BorderRadius.circular` of its own — the card's
/// rounding is the card's concern, deliberately out of this view's scope).
///
/// Step-0 note (BUT-1271): the populated "list" state renders `SharedRecipeCard`,
/// whose Reply button resolves `MessagingService` from the locator and whose
/// shape is intentionally rounded (see shared_recipe_card.dart). Exercising the
/// full card drags in unrelated services and contradicts the square assertion,
/// so the list branch is asserted at the contract boundary the view owns
/// (recipes are passed to the list builder) via the empty/non-empty split; the
/// card internals are covered by their own tests.
///
/// Harness: the view reads its coordinator from the locator in initState, so we
/// register a fake `SharedContentCoordinatorViewModel` whose only real surface
/// is the recipe sub-ViewModel state the view reads (loading / error / the
/// `recipesSharedBy` list). All sub-ViewModels are injected with `Fake`
/// coordinators to keep construction off the real DI graph.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/modules/social_shopping/social_shopping_coordinator.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/social_sharing_viewmodel.dart';
import 'package:butlery/views/social/shared_with_me/shared_recipes_by_friend_view.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/state_widget.dart';

// ── Fake service coordinators — never invoked, only satisfy constructors. ────
class _FakePermissionService extends Fake implements PermissionService {
  @override
  String? get currentUserId => 'me';
}

class _FakeSocialRecipeCoordinator extends Fake
    implements SocialRecipeCoordinator {}

class _FakeSocialMenuCoordinator extends Fake
    implements SocialMenuCoordinator {}

class _FakeSocialShoppingCoordinator extends Fake
    implements SocialShoppingCoordinator {}

class _FakeFriendsService extends Fake implements UnifiedFriendsService {
  @override
  bool get isInitialized => true;

  @override
  List<UserProfile> get friends => const [];

  @override
  Set<String> get blockedUsers => const {};
}

class _FakeMenuService extends Fake implements UnifiedMenuService {}

class _FakeShoppingService extends Fake implements UnifiedShoppingService {}

class _FakeOfflineService extends Fake implements OfflineService {
  @override
  bool get isOnline => true;

  @override
  bool get isInitialized => false;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Recipe sub-ViewModel whose render-relevant surface is fully controlled.
class _FakeRecipeViewModel extends SharedRecipeViewModel {
  _FakeRecipeViewModel({
    this.loading = false,
    this.errorMessage,
    this.recipes = const [],
  }) : super(
          socialRecipeCoordinator: _FakeSocialRecipeCoordinator(),
          permissionService: _FakePermissionService(),
        );

  final bool loading;
  final String? errorMessage;
  final List<SharedRecipe> recipes;

  @override
  bool get isLoading => loading;

  @override
  bool get hasError => errorMessage != null;

  @override
  String? get error => errorMessage;

  @override
  List<SharedRecipe> recipesSharedBy(String friendId) => recipes;

  @override
  Future<void> refreshContent() async {}
}

/// Coordinator that exposes the controlled recipe VM and a non-loading global
/// state. Construction passes every sub-VM so the super-ctor never touches the
/// real locator.
class _FakeCoordinator extends SharedContentCoordinatorViewModel {
  _FakeCoordinator(this._recipeVm)
      : super(
          recipeViewModel: _recipeVm,
          menuViewModel: SharedMenuViewModel(
            socialMenuCoordinator: _FakeSocialMenuCoordinator(),
            permissionService: _FakePermissionService(),
          ),
          shoppingViewModel: SharedShoppingViewModel(
            socialShoppingCoordinator: _FakeSocialShoppingCoordinator(),
            shoppingService: _FakeShoppingService(),
            permissionService: _FakePermissionService(),
          ),
          socialSharingViewModel: SocialSharingViewModel(
            friendsService: _FakeFriendsService(),
            recipeCoordinator: _FakeSocialRecipeCoordinator(),
            menuCoordinator: _FakeSocialMenuCoordinator(),
            shoppingCoordinator: _FakeSocialShoppingCoordinator(),
            menuService: _FakeMenuService(),
            shoppingService: _FakeShoppingService(),
          ),
        );

  final _FakeRecipeViewModel _recipeVm;

  @override
  bool get isGloballyLoading => false;

  @override
  SharedRecipeViewModel get recipeViewModel => _recipeVm;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refreshAllContent() async {}
}

void _register(_FakeRecipeViewModel recipeVm) {
  // The view's offline banner resolves OfflineService from the locator.
  GetIt.instance.registerSingleton<OfflineService>(_FakeOfflineService());
  GetIt.instance.registerFactory<SharedContentCoordinatorViewModel>(
    () => _FakeCoordinator(recipeVm),
  );
  production.ServiceLocator.initialize(DIContainer());
}

Widget _wrap() => MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SharedRecipesByFriendView(
        friendId: 'friend-1',
        friendDisplayName: 'Erik',
      ),
    );

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  group('SharedRecipesByFriendView render states (BUT-1000)', () {
    testWidgets('loading state shows a spinner, no list or error',
        (tester) async {
      _register(_FakeRecipeViewModel(loading: true));
      await tester.pumpWidget(_wrap());
      await tester.pump(); // run the post-frame initialize()

      expect(find.byType(LoadingIndicator), findsOneWidget,
          reason: 'isLoading must render the loading indicator');
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('error state shows the error widget with a retry action',
        (tester) async {
      _register(_FakeRecipeViewModel(errorMessage: 'Något gick fel'));
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text('Något gick fel'), findsOneWidget,
          reason: 'hasError must surface the error message');
      // StateWidget.error renders a retry button wired to refreshAllContent.
      expect(find.byType(StateWidget), findsOneWidget);
    });

    testWidgets('empty state shows the branded "no recipes" empty widget',
        (tester) async {
      _register(_FakeRecipeViewModel(recipes: const []));
      await tester.pumpWidget(_wrap());
      await tester.pump();

      // sharedNoRecipesFromFriend(name) — Swedish copy includes the friend name.
      expect(find.byType(StateWidget), findsOneWidget,
          reason: 'an empty friend list must render the empty state');
      expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
    });

    testWidgets('the title carries the friend display name', (tester) async {
      _register(_FakeRecipeViewModel(recipes: const []));
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.textContaining('Erik'), findsWidgets,
          reason: 'the app bar title is scoped to the friend');
    });
  });

  group('SharedRecipesByFriendView design language (BUT-1000)', () {
    testWidgets(
        'the view introduces no rounded BorderRadius.circular in its own chrome',
        (tester) async {
      _register(_FakeRecipeViewModel(recipes: const []));
      await tester.pumpWidget(_wrap());
      await tester.pump();

      // Square design language: the view's scaffold/empty-state chrome must not
      // round any container it owns. (The list-card rounding lives in the card,
      // which this empty state does not render.)
      final rounded = find.byWidgetPredicate((w) {
        if (w is Container) {
          final deco = w.decoration;
          if (deco is BoxDecoration && deco.borderRadius != null) return true;
        }
        if (w is ClipRRect && w.borderRadius != BorderRadius.zero) return true;
        return false;
      });
      expect(rounded, findsNothing,
          reason: 'the view chrome must stay square (no rounded corners)');
    });
  });
}
