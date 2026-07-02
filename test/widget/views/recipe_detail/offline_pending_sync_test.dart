// test/widget/views/recipe_detail/offline_pending_sync_test.dart
//
// BUT-1360 item 2: silent offline writes must surface a "saved locally, will
// sync" hint instead of a plain success (or a swallowed error). The three
// write paths — mark-as-cooked, social rating, comment post — succeed against
// Firestore's local cache while offline; the user needs to know the change is
// queued, not lost, and hasn't reached the server yet.
//
// Each path runs its REAL success-handling branch over a mocked OfflineService
// (isOnline true/false), asserting the pending-sync snackbar replaces the
// normal success when offline and that online behaviour is unchanged.

library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_management_handler.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_social_handler.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_metadata.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/factories/user_profile_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';

class _MockCookEventRepository extends Mock implements CookEventRepository {}

void main() {
  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(RecipeFactory.build());
  });

  /// Registers a MockOfflineService reporting [online] under the shared GetIt,
  /// so the production `SnackBarUtils.showPendingSyncIfOffline` resolves it.
  MockOfflineService registerOffline({required bool online}) {
    final offline = MockOfflineService();
    when(() => offline.isOnline).thenReturn(online);
    TestServiceLocator.registerMock<OfflineService>(offline);
    return offline;
  }

  Widget localize(Widget child) {
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
      home: child,
    );
  }

  AppLocalizations l10nOf(WidgetTester tester, Finder anchor) =>
      AppLocalizations.of(tester.element(anchor));

  // ==================== shared helper ====================

  group('SnackBarUtils.showPendingSyncIfOffline', () {
    setUp(() async {
      await TestServiceLocator.initialize();
    });
    tearDown(() async => TestServiceLocator.reset());

    Future<bool> pumpAndInvoke(WidgetTester tester) async {
      late bool result;
      await tester.pumpWidget(
        localize(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    result = SnackBarUtils.showPendingSyncIfOffline(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      return result;
    }

    testWidgets('offline shows the pending-sync hint and returns true', (
      tester,
    ) async {
      registerOffline(online: false);
      final result = await pumpAndInvoke(tester);

      expect(result, isTrue);
      expect(
        find.text(l10nOf(tester, find.text('go')).pendingSyncOffline),
        findsOneWidget,
      );
    });

    testWidgets('online shows nothing and returns false', (tester) async {
      registerOffline(online: true);
      final result = await pumpAndInvoke(tester);

      expect(result, isFalse);
      expect(
        find.text(l10nOf(tester, find.text('go')).pendingSyncOffline),
        findsNothing,
      );
    });

    testWidgets('no OfflineService registered returns false (no hint)', (
      tester,
    ) async {
      // OfflineService is never registered by TestServiceLocator.initialize().
      final result = await pumpAndInvoke(tester);

      expect(result, isFalse);
      expect(
        find.text(l10nOf(tester, find.text('go')).pendingSyncOffline),
        findsNothing,
      );
    });
  });

  // ==================== comment post path ====================

  group('comment post (RecipeSocialHandler.postComment)', () {
    late MockAuthService authService;
    late MockUserService userService;
    late MockSocialRecipeViewModel socialVm;

    setUp(() async {
      await TestServiceLocator.initialize();

      authService = MockAuthService();
      authService.setAuthState(
        currentUser: FakeUser(uid: 'test-user-123'),
        isAuthenticated: true,
      );
      TestServiceLocator.registerMock<AuthService>(authService);

      userService = MockUserService();
      when(
        () => userService.getUserProfile('test-user-123'),
      ).thenAnswer((_) async => UserProfileFactory.build(uid: 'test-user-123'));
      TestServiceLocator.registerMock<UserService>(userService);

      socialVm = MockSocialRecipeViewModel();
      when(() => socialVm.postComment('recipe-1')).thenAnswer((_) async {});
    });
    tearDown(() async => TestServiceLocator.reset());

    Future<void> pumpHost(WidgetTester tester) {
      return tester.pumpWidget(
        localize(
          ChangeNotifierProvider<SocialRecipeViewModel>.value(
            value: socialVm,
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => RecipeSocialHandler.postComment(
                    context,
                    commentText: 'Riktigt gott',
                    recipeId: 'recipe-1',
                  ),
                  child: const Text('post'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('offline shows pending-sync instead of "posted"', (
      tester,
    ) async {
      registerOffline(online: false);
      await pumpHost(tester);
      await tester.tap(find.text('post'));
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester, find.text('post'));
      expect(find.text(l10n.pendingSyncOffline), findsOneWidget);
      expect(find.text(l10n.socialCommentPosted), findsNothing);
    });

    testWidgets('online shows the normal "posted" success', (tester) async {
      registerOffline(online: true);
      await pumpHost(tester);
      await tester.tap(find.text('post'));
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester, find.text('post'));
      expect(find.text(l10n.socialCommentPosted), findsOneWidget);
      expect(find.text(l10n.pendingSyncOffline), findsNothing);
    });
  });

  // ==================== social rating path ====================

  group('rating (RecipeDetailMetadata → rateRecipe)', () {
    late MockUnifiedRecipeService recipeService;
    late Recipe recipe;

    setUp(() async {
      await TestServiceLocator.initialize();

      // Personal, unrated recipe: _checkUserRating short-circuits (no social
      // record) and rateRecipe persists via updateRecipe.
      recipe = RecipeFactory.build(
        id: 'recipe-rating-1',
        title: 'Köttbullar',
        rating: null,
        type: RecipeType.personal,
      );

      recipeService = MockUnifiedRecipeService();
      recipeService.setRecipeState(recipes: [recipe], isInitialized: true);
      TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);
      TestServiceLocator.registerMock<RecipeCookingService>(
        MockFactory.createRecipeCookingService(),
      );
    });
    tearDown(() async => TestServiceLocator.reset());

    Future<void> pumpRating(WidgetTester tester) async {
      final vm = RecipeDetailViewModel(recipe: recipe);
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        localize(
          Scaffold(
            body: RecipeDetailMetadata(
              viewModel: vm,
              currentPortions: 4,
              isScaled: false,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> tapFourthStar(WidgetTester tester) async {
      final l10n = l10nOf(tester, find.byType(RecipeDetailMetadata));
      await tester.tap(find.bySemanticsLabel(l10n.ratingStarLabel(4)));
      await tester.pumpAndSettle();
    }

    testWidgets('offline success surfaces the pending-sync hint', (
      tester,
    ) async {
      registerOffline(online: false);
      when(
        () => recipeService.updateRecipe(any()),
      ).thenAnswer((_) async => true);

      await pumpRating(tester);
      await tapFourthStar(tester);

      final l10n = l10nOf(tester, find.byType(RecipeDetailMetadata));
      expect(find.text(l10n.pendingSyncOffline), findsOneWidget);
      // The hint replaces feedback, it doesn't co-exist with the generic error.
      expect(find.text(l10n.ratingError), findsNothing);
    });

    testWidgets(
      'offline genuine error shows ratingError, NOT the pending hint',
      (tester) async {
        registerOffline(online: false);
        // A real thrown failure (permission/validation/etc.) while offline must
        // NOT be masked as "queued" — offline state doesn't prove a queued
        // write. The rating would be lost silently; surface the real error.
        when(
          () => recipeService.updateRecipe(any()),
        ).thenThrow(Exception('permission-denied'));

        await pumpRating(tester);
        await tapFourthStar(tester);

        final l10n = l10nOf(tester, find.byType(RecipeDetailMetadata));
        expect(find.text(l10n.ratingError), findsOneWidget);
        expect(find.text(l10n.pendingSyncOffline), findsNothing);
      },
    );

    testWidgets('online success stays silent (no hint, no error)', (
      tester,
    ) async {
      registerOffline(online: true);
      when(
        () => recipeService.updateRecipe(any()),
      ).thenAnswer((_) async => true);

      await pumpRating(tester);
      await tapFourthStar(tester);

      final l10n = l10nOf(tester, find.byType(RecipeDetailMetadata));
      expect(find.text(l10n.pendingSyncOffline), findsNothing);
      expect(find.text(l10n.ratingError), findsNothing);
    });

    testWidgets('online error still shows the generic rating error', (
      tester,
    ) async {
      registerOffline(online: true);
      when(
        () => recipeService.updateRecipe(any()),
      ).thenAnswer((_) async => false);

      await pumpRating(tester);
      await tapFourthStar(tester);

      final l10n = l10nOf(tester, find.byType(RecipeDetailMetadata));
      expect(find.text(l10n.ratingError), findsOneWidget);
      expect(find.text(l10n.pendingSyncOffline), findsNothing);
    });
  });

  // ==================== mark-as-cooked path ====================

  group('mark as cooked (RecipeManagementHandler.markAsCooked)', () {
    late MockUnifiedRecipeService recipeService;
    late MockAnalyticsService analytics;
    late MockRecipeCookingService cooking;
    late Recipe recipe;

    setUp(() async {
      await TestServiceLocator.initialize();

      // A never-cooked recipe so the "already cooked today" short-circuit is
      // skipped and the flow reaches the who-eating sheet + markAsCooked.
      recipe = RecipeFactory.build(
        id: 'recipe-cook-1',
        title: 'Köttbullar',
        type: RecipeType.personal,
      );

      recipeService = MockUnifiedRecipeService();
      recipeService.setRecipeState(recipes: [recipe], isInitialized: true);
      TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);

      analytics = MockAnalyticsService();
      when(
        () => analytics.logRecipeCooked(
          recipeId: any(named: 'recipeId'),
          mealType: any(named: 'mealType'),
          isFirstTime: any(named: 'isFirstTime'),
        ),
      ).thenAnswer((_) async {});
      TestServiceLocator.registerMock<AnalyticsService>(analytics);

      cooking = MockRecipeCookingService();
      when(
        () => cooking.markAsCooked(
          any(),
          attendeeMemberIds: any(named: 'attendeeMemberIds'),
        ),
      ).thenAnswer((_) async => true);
      TestServiceLocator.registerMock<RecipeCookingService>(cooking);

      // The who-eating sheet loads the roster first; a solo/empty roster skips
      // the sheet (WhoAteResult.skipped) so the cook logs with no attendance
      // and no family-rating chain. Stub the one repository the roster VM's
      // load() touches that isn't already provided by TestServiceLocator.
      final cookEvents = _MockCookEventRepository();
      when(
        () => cookEvents.recentAttendeeMemberIds(any()),
      ).thenAnswer((_) async => const <String>[]);
      TestServiceLocator.registerMock<CookEventRepository>(cookEvents);
    });
    tearDown(() async => TestServiceLocator.reset());

    Future<void> pumpCook(WidgetTester tester) async {
      final vm = RecipeDetailViewModel(
        recipe: recipe,
        recipeService: recipeService,
        analyticsService: analytics,
        cookingService: cooking,
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        localize(
          ChangeNotifierProvider<RecipeDetailViewModel>.value(
            value: vm,
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      RecipeManagementHandler.markAsCooked(context),
                  child: const Text('cook'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('offline shows pending-sync instead of "cooked"', (
      tester,
    ) async {
      registerOffline(online: false);
      await pumpCook(tester);
      await tester.tap(find.text('cook'));
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester, find.text('cook'));
      expect(find.text(l10n.pendingSyncOffline), findsOneWidget);
      expect(find.text(l10n.recipeMarkedAsCooked), findsNothing);
    });

    testWidgets('online shows the normal "cooked" success', (tester) async {
      registerOffline(online: true);
      await pumpCook(tester);
      await tester.tap(find.text('cook'));
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester, find.text('cook'));
      expect(find.text(l10n.recipeMarkedAsCooked), findsOneWidget);
      expect(find.text(l10n.pendingSyncOffline), findsNothing);
    });
  });
}
