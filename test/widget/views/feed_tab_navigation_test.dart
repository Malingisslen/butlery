// test/widget/views/feed_tab_navigation_test.dart
//
// Task 5 (2026-06-21): Wire feed recipe tap to open a friend's shared recipe
// read-only.
// Task 9 (2026-06-21): Replace unavailable-branch with request-recipe dialog.
//
// Behavioral proofs:
// 1. fetchFriendRecipe returns a recipe → navigation pushes Routes.recipeDetail
//    with readOnly:true in the route arguments.
// 2. fetchFriendRecipe returns null → shows request dialog; confirming calls
//    requestRecipeShare and shows feedRecipeRequestSent snackbar.
//
// Harness: NavigatorObserver (mocktail) captures pushed route settings.
// Uses production.ServiceLocator.initialize + TestServiceLocator bridge,
// mirroring recipe_detail_read_only_test.dart.

library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/social/activity_feed_viewmodel.dart';
import 'package:butlery/views/social/friends_list/feed_tab.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../views/helpers/view_test_helpers.dart';

// ---- Mocks ----

class _MockNavigatorObserver extends Mock implements NavigatorObserver {}

class _MockActivityFeedViewModel extends Mock
    implements ActivityFeedViewModel {}

// ---- Constants ----

const _ownerUserId = 'friend-owner-abc';
// The default currentUserId injected by MockFactory.createPermissionService()
// is 'test-user-123' — used to test the own-recipe (readOnly:false) path.
const _currentUserId = 'test-user-123';
const _recipeId = 'recipe-xyz-123';
const _recipeTitle = 'Vännens Pasta';

void main() {
  late MockUnifiedRecipeService recipeService;
  late MockSocialRecipeService socialRecipeService;
  late _MockNavigatorObserver navObserver;
  late Recipe friendRecipe;
  late ActivityEvent sharedEvent;
  late _MockActivityFeedViewModel feedVm;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(const RouteSettings());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
    // Route fallback needed for captureAny() inside verify(didPush(...)).
    registerFallbackValue(
      MaterialPageRoute<dynamic>(builder: (_) => const SizedBox()),
    );
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    friendRecipe = RecipeFactory.build(
      id: _recipeId,
      title: _recipeTitle,
      createdBy: _ownerUserId,
      ingredients: ['pasta', 'tomatsås'],
      instructions: ['Koka.', 'Servera.'],
    );

    sharedEvent = ActivityEvent(
      id: 'event-1',
      actorId: _ownerUserId,
      actorDisplayName: 'Anna',
      type: ActivityEventType.shared,
      recipeId: _recipeId,
      recipeTitle: _recipeTitle,
    );

    recipeService = MockUnifiedRecipeService();
    recipeService.setRecipeState(recipes: [], isInitialized: true);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);

    socialRecipeService = MockSocialRecipeService();
    TestServiceLocator.registerMock<SocialRecipeService>(socialRecipeService);

    feedVm = _MockActivityFeedViewModel();
    when(() => feedVm.isLoading).thenReturn(false);
    when(() => feedVm.error).thenReturn(null);
    when(() => feedVm.events).thenReturn([sharedEvent]);
    when(() => feedVm.filteredEvents).thenReturn([sharedEvent]);
    when(() => feedVm.hasMore).thenReturn(false);
    when(() => feedVm.filter).thenReturn(null);
    when(() => feedVm.addListener(any())).thenReturn(null);
    when(() => feedVm.removeListener(any())).thenReturn(null);

    navObserver = _MockNavigatorObserver();
    when(() => navObserver.navigator).thenReturn(null);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Widget buildApp() {
    return MaterialApp(
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      navigatorObservers: [navObserver],
      routes: {
        Routes.recipeDetail: (_) => const Scaffold(body: Text('detail stub')),
      },
      home: Builder(
        builder: (context) => Scaffold(
          body: FeedTab.build(context, feedVm, hasFriends: true),
        ),
      ),
    );
  }

  group('FeedTab recipe tap — Task 5 navigation', () {
    testWidgets(
      'fetchFriendRecipe returns recipe → pushes recipeDetail with readOnly:true',
      (tester) async {
        // Proves: tapping a recipe row in the feed calls fetchFriendRecipe with
        // the event's actorId+recipeId; on success it navigates to recipeDetail
        // with readOnly:true so the friend can view (not edit) the recipe.
        when(
          () => recipeService.fetchFriendRecipe(
            ownerId: _ownerUserId,
            recipeId: _recipeId,
          ),
        ).thenAnswer((_) async => friendRecipe);

        await tester.pumpWidget(buildApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Tap the recipe preview row.
        final recipeTile = find.text(_recipeTitle.toLowerCase());
        expect(
          recipeTile,
          findsOneWidget,
          reason: 'Recipe title must appear in the feed',
        );
        await tester.tap(recipeTile);
        // Wait for the async _navigateToRecipe to complete.
        await tester.pumpAndSettle();

        // Capture the route that was pushed.
        final captured = verify(
          () => navObserver.didPush(captureAny(), any()),
        ).captured;
        expect(
          captured,
          isNotEmpty,
          reason: 'Navigator should have pushed a route',
        );

        final pushedRoute = captured.last as Route<dynamic>;
        final args = pushedRoute.settings.arguments as Map<String, dynamic>?;
        expect(args, isNotNull, reason: 'Route arguments must be a map');
        expect(
          args!['readOnly'],
          isTrue,
          reason: 'readOnly must be true for a friend recipe',
        );
        expect(
          args['recipe'],
          equals(friendRecipe),
          reason: 'The friend recipe must be passed as the route argument',
        );
      },
    );

    testWidgets(
      'own recipe (ownerId == currentUserId) → pushes recipeDetail with readOnly:false',
      (tester) async {
        // Proves: when the current user taps their own activity in the feed,
        // the recipe must open in edit mode (readOnly:false) so their
        // edit/favorite/delete actions remain visible — not locked read-only.
        final ownRecipe = RecipeFactory.build(
          id: _recipeId,
          title: _recipeTitle,
          createdBy: _currentUserId,
        );
        final ownEvent = ActivityEvent(
          id: 'event-own',
          actorId: _currentUserId, // current user's own activity
          actorDisplayName: 'Mig',
          type: ActivityEventType.cooked,
          recipeId: _recipeId,
          recipeTitle: _recipeTitle,
        );

        when(() => feedVm.events).thenReturn([ownEvent]);
        when(() => feedVm.filteredEvents).thenReturn([ownEvent]);

        when(
          () => recipeService.fetchFriendRecipe(
            ownerId: _currentUserId,
            recipeId: _recipeId,
          ),
        ).thenAnswer((_) async => ownRecipe);

        await tester.pumpWidget(buildApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final recipeTile = find.text(_recipeTitle.toLowerCase());
        expect(
          recipeTile,
          findsOneWidget,
          reason: 'Own recipe title must appear in feed',
        );
        await tester.tap(recipeTile);
        await tester.pumpAndSettle();

        final captured = verify(
          () => navObserver.didPush(captureAny(), any()),
        ).captured;
        expect(
          captured,
          isNotEmpty,
          reason: 'Navigator should have pushed a route',
        );

        final pushedRoute = captured.last as Route<dynamic>;
        final args = pushedRoute.settings.arguments as Map<String, dynamic>?;
        expect(args, isNotNull, reason: 'Route arguments must be a map');
        expect(
          args!['readOnly'],
          isFalse,
          reason:
              'readOnly must be false when the recipe belongs to current user',
        );
        expect(args['recipe'], equals(ownRecipe));
      },
    );

    testWidgets(
      'fetchFriendRecipe returns null → shows request dialog; confirm calls requestRecipeShare and shows success snackbar',
      (tester) async {
        // Proves: when the recipe isn't shared yet, tapping it opens a dialog
        // asking the user if they want to request it. Confirming calls
        // requestRecipeShare and shows the feedRecipeRequestSent success snackbar.
        when(
          () => recipeService.fetchFriendRecipe(
            ownerId: _ownerUserId,
            recipeId: _recipeId,
          ),
        ).thenAnswer((_) async => null);

        when(
          () => socialRecipeService.requestRecipeShare(
            ownerId: _ownerUserId,
            recipeId: _recipeId,
            recipeTitle: _recipeTitle,
          ),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(buildApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final recipeTile = find.text(_recipeTitle.toLowerCase());
        expect(recipeTile, findsOneWidget);
        await tester.tap(recipeTile);
        await tester.pumpAndSettle();

        // Dialog should appear with the body text including the actor's name.
        expect(
          find.textContaining('Anna'),
          findsWidgets,
          reason: 'Dialog body must include the actor display name',
        );
        expect(
          find.byType(AlertDialog),
          findsOneWidget,
          reason: 'AlertDialog must be shown when recipe is unavailable',
        );

        // Tap the confirm button.
        final confirmButton = find.text('Be om receptet');
        // The button text appears in both title and action; tap the last one
        // (actions row).
        await tester.tap(confirmButton.last);
        await tester.pumpAndSettle();

        // requestRecipeShare must have been called exactly once.
        verify(
          () => socialRecipeService.requestRecipeShare(
            ownerId: _ownerUserId,
            recipeId: _recipeId,
            recipeTitle: _recipeTitle,
          ),
        ).called(1);

        // Success snackbar must appear.
        expect(
          find.byType(SnackBar),
          findsOneWidget,
          reason: 'Success SnackBar must appear after request is sent',
        );
      },
    );
  });
}
