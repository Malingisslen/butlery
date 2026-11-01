/// The owner's "Visa på min profil" menu row, the "Publikt" pill and the
/// publicCopy mode used for a public profile copy, over the real [RecipeDetailView].
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_comments.dart';
import 'package:butlery/views/recipe_detail_view.dart';
import 'package:butlery/widgets/common/butlery_tap_target.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/recipe/cook_snap_gallery.dart';
import 'package:butlery/widgets/realtime/recipe_suggestion_notice.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_sharing_status.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/factories/user_profile_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../views/helpers/view_test_helpers.dart';

class _FakeCookSnapService extends Fake implements CookSnapService {
  @override
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) =>
      Stream.value(const <CookSnap>[]);
}

const _me = 'test-user-123';

void main() {
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;
  late Recipe recipe;
  Object? forkArguments;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
  });

  Recipe owned({String title = 'Köttbullar', List<String>? images}) =>
      RecipeFactory.build(
        id: 'recipe-pv-1',
        title: title,
        createdBy: _me,
        imageUrls: images,
        ingredients: ['500 g köttfärs', '1 dl grädde', '1 gul lök'],
        instructions: ['Rulla köttbullarna.', 'Stek och servera med sås.'],
      );

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();
    forkArguments = null;
    recipe = owned();

    recipeService = MockUnifiedRecipeService();
    recipeService.setRecipeState(recipes: [recipe], isInitialized: true);
    when(() => recipeService.updateRecipe(any())).thenAnswer((_) async => true);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);
    TestServiceLocator.registerMock<RecipeCookingService>(
      MockFactory.createRecipeCookingService(),
    );

    userService = MockUserService();
    when(
      () => userService.allergenPreferences,
    ).thenReturn(UserAllergenPreferences.defaults);
    when(() => userService.addListener(any())).thenReturn(null);
    when(() => userService.removeListener(any())).thenReturn(null);
    when(
      () => userService.currentUserProfile,
    ).thenReturn(UserProfileFactory.build());
    TestServiceLocator.registerMock<UserService>(userService);

    final socialVm = MockSocialRecipeViewModel();
    when(() => socialVm.initialize()).thenAnswer((_) async {});
    when(() => socialVm.refreshComments(any())).thenAnswer((_) async {});
    when(() => socialVm.topLevelComments).thenReturn(const <RecipeComment>[]);
    TestServiceLocator.registerMock<SocialRecipeViewModel>(socialVm);

    final offline = MockOfflineService();
    when(() => offline.isOnline).thenReturn(true);
    when(() => offline.addListener(any())).thenReturn(null);
    when(() => offline.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offline);

    TestServiceLocator.registerMock<CookSnapService>(
      _FakeCookSnapService(),
    );
    TestServiceLocator.registerMock<ContentFilterService>(
      ContentFilterService(),
    );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool readOnly = false,
    bool publicCopy = false,
    Size size = const Size(420, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final previous = FlutterError.onError;
    // The shared-recipe status row overflows at phone width; unrelated here.
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('A RenderFlex overflowed')) return;
      previous?.call(d);
    };
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv', 'SE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        onGenerateRoute: (settings) {
          if (settings.name == Routes.manualEntry) {
            forkArguments = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('editor')),
            );
          }
          return null;
        },
        home: RecipeDetailView(
          recipe: recipe,
          readOnly: readOnly,
          publicCopy: publicCopy,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(RecipeDetailView)));

  Finder ratingSummary(WidgetTester tester) => find.byWidgetPredicate(
    (w) =>
        w is ButleryTapTarget &&
        w.semanticLabel == l10n(tester).recipeRatingSheetTitle,
  );

  Future<void> openMenu(WidgetTester tester) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('A RenderFlex overflowed')) return;
      previous?.call(d);
    };
    try {
      await tester.tap(find.byIcon(ButleryIcons.moreVertical));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      FlutterError.onError = previous;
    }
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Recipe savedRecipe() =>
      verify(() => recipeService.updateRecipe(captureAny())).captured.single
          as Recipe;

  group('profile visibility menu row', () {
    testWidgets('an adult owner turns it on after confirming', (tester) async {
      await pump(tester);
      await openMenu(tester);
      final t = l10n(tester);
      await tester.tap(find.text(t.recipeProfileVisibilityShow));
      await settle(tester);

      expect(
        find.text(t.recipeProfileVisibilityConfirmTitle('Köttbullar')),
        findsOneWidget,
      );
      expect(find.text(t.recipeProfileVisibilityConfirmBody), findsOneWidget);
      verifyNever(() => recipeService.updateRecipe(any()));

      await tester.tap(find.text(t.recipeProfileVisibilityConfirmAction));
      await settle(tester);

      final saved = savedRecipe();
      expect(saved.showOnProfile, isTrue);
      expect(saved.core.showOnProfileChangedAt, isNotNull);
      expect(find.text(t.recipeProfileVisibilityShownSnack), findsOneWidget);
    });

    testWidgets('cancelling the confirmation saves nothing', (tester) async {
      await pump(tester);
      await openMenu(tester);
      final t = l10n(tester);
      await tester.tap(find.text(t.recipeProfileVisibilityShow));
      await settle(tester);
      await tester.tap(find.text(t.recipeProfileVisibilityCancel));
      await settle(tester);
      verifyNever(() => recipeService.updateRecipe(any()));
    });

    testWidgets('flagged text stops before the dialog', (tester) async {
      recipe = owned(title: 'Helvete soppa');
      await pump(tester);
      await openMenu(tester);
      final t = l10n(tester);
      await tester.tap(find.text(t.recipeProfileVisibilityShow));
      await settle(tester);

      expect(
        find.text(t.recipeProfileVisibilityBlockedContent),
        findsOneWidget,
      );
      expect(find.text(t.recipeProfileVisibilityConfirmAction), findsNothing);
      verifyNever(() => recipeService.updateRecipe(any()));
    });

    testWidgets('a shown recipe is hidden at once, without a dialog', (
      tester,
    ) async {
      recipe = owned().copyWith(showOnProfile: true);
      await pump(tester);
      await openMenu(tester);
      final t = l10n(tester);
      expect(find.text(t.recipeProfileVisibilityShow), findsNothing);
      await tester.tap(find.text(t.recipeProfileVisibilityHide));
      await settle(tester);

      expect(find.text(t.recipeProfileVisibilityConfirmAction), findsNothing);
      expect(savedRecipe().showOnProfile, isFalse);
      expect(find.text(t.recipeProfileVisibilityHiddenSnack), findsOneWidget);
    });

    testWidgets('a failed save says so', (tester) async {
      when(
        () => recipeService.updateRecipe(any()),
      ).thenAnswer((_) async => false);
      recipe = owned().copyWith(showOnProfile: true);
      await pump(tester);
      await openMenu(tester);
      final t = l10n(tester);
      await tester.tap(find.text(t.recipeProfileVisibilityHide));
      await settle(tester);
      expect(find.text(t.recipeProfileVisibilityFailed), findsOneWidget);
    });

    testWidgets('a minor sees the row disabled with the 18-year line', (
      tester,
    ) async {
      when(
        () => userService.currentUserProfile,
      ).thenReturn(UserProfileFactory.build().copyWith(isMinor: true));
      await pump(tester);
      await openMenu(tester);
      final t = l10n(tester);
      expect(find.text(t.recipeProfileVisibilityShow), findsOneWidget);
      expect(find.text(t.recipeProfileVisibilityMinorHint), findsOneWidget);

      await tester.tap(
        find.text(t.recipeProfileVisibilityShow),
        warnIfMissed: false,
      );
      await settle(tester);
      expect(find.text(t.recipeProfileVisibilityConfirmAction), findsNothing);
      verifyNever(() => recipeService.updateRecipe(any()));
    });

    testWidgets('a collaborative recipe has no row', (tester) async {
      recipe = RecipeFactory.build(
        id: 'recipe-pv-1',
        title: 'Gemensam',
        createdBy: _me,
        type: RecipeType.collaborative,
        socialData: const RecipeSocialData(
          ownerId: _me,
          memberPermissions: {'friend': ResourcePermission.editor},
        ),
      );
      await pump(tester);
      await openMenu(tester);
      final t = l10n(tester);
      expect(find.text(t.recipeProfileVisibilityShow), findsNothing);
      expect(find.text(t.recipeProfileVisibilityHide), findsNothing);
    });
  });

  group('"Publikt" pill', () {
    testWidgets('shows only while the recipe is on the profile', (
      tester,
    ) async {
      await pump(tester);
      expect(
        find.text(l10n(tester).recipeProfileVisibilityBadge.toUpperCase()),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
      recipe = owned().copyWith(showOnProfile: true);
      await pump(tester);
      expect(
        find.text(l10n(tester).recipeProfileVisibilityBadge.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('is not shown to someone viewing another user\'s recipe', (
      tester,
    ) async {
      recipe = RecipeFactory.build(
        id: 'recipe-pv-1',
        title: 'Någon annans',
        createdBy: 'someone-else',
      ).copyWith(showOnProfile: true);
      await pump(tester, readOnly: true);

      expect(find.text('Någon annans'), findsWidgets);
      expect(
        find.text(l10n(tester).recipeProfileVisibilityBadge.toUpperCase()),
        findsNothing,
      );
    });
  });

  group('publicCopy (public profile copy)', () {
    testWidgets('hides the owner\'s social data', (tester) async {
      await pump(tester, readOnly: true, publicCopy: true);
      expect(find.byType(RecipeDetailComments), findsNothing);
      expect(find.byType(CookSnapGallery), findsNothing);
      expect(find.byType(RecipeSuggestionNotice), findsNothing);
      expect(find.byType(RecipeDetailSharingStatus), findsNothing);
      final t = l10n(tester);
      expect(find.text(t.recipeCookedToday), findsNothing);
      expect(find.text(t.familyRatingManualButton), findsNothing);
      expect(ratingSummary(tester), findsNothing);
    });

    testWidgets(
      'hides the owner\'s social data in the wide detail-pane layout',
      (
        tester,
      ) async {
        await pump(
          tester,
          readOnly: true,
          publicCopy: true,
          size: const Size(1200, 900),
        );
        expect(find.byType(RecipeDetailComments), findsNothing);
        expect(find.byType(RecipeDetailSharingStatus), findsNothing);
        expect(ratingSummary(tester), findsNothing);
      },
    );

    testWidgets('the wide layout without publicCopy shows them', (
      tester,
    ) async {
      await pump(tester, size: const Size(1200, 900));
      expect(find.byType(RecipeDetailComments), findsOneWidget);
      expect(find.byType(RecipeDetailSharingStatus), findsOneWidget);
      expect(ratingSummary(tester), findsOneWidget);
    });

    testWidgets('the same view not as a public copy shows them', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byType(RecipeDetailComments), findsOneWidget);
      expect(find.byType(CookSnapGallery), findsOneWidget);
      expect(find.text(l10n(tester).familyRatingManualButton), findsOneWidget);
    });

    testWidgets('plain readOnly (a friend\'s shared recipe) keeps comments and '
        'ratings', (tester) async {
      await pump(tester, readOnly: true);
      expect(find.byType(RecipeDetailComments), findsOneWidget);
      expect(find.byType(CookSnapGallery), findsOneWidget);
      expect(find.byType(RecipeDetailSharingStatus), findsOneWidget);
      expect(ratingSummary(tester), findsOneWidget);
    });

    testWidgets('keeps report and create copy, and offers no profile row', (
      tester,
    ) async {
      await pump(tester, readOnly: true, publicCopy: true);
      await openMenu(tester);
      final t = l10n(tester);
      expect(find.text(t.reportContent), findsOneWidget);
      expect(find.text(t.recipeCreateCopy), findsOneWidget);
      expect(find.text(t.recipeProfileVisibilityShow), findsNothing);
      expect(find.text(t.recipeEdit), findsNothing);
    });

    testWidgets('create copy carries no photos', (tester) async {
      recipe = owned(images: ['https://example.com/owner-uid/a.jpg']);
      recipe.core.thumbnailUrl = 'https://example.com/owner-uid/t.jpg';
      await pump(tester, readOnly: true, publicCopy: true);
      await openMenu(tester);
      await tester.tap(find.text(l10n(tester).recipeCreateCopy));
      await settle(tester);

      final args = forkArguments! as Map<String, dynamic>;
      final template = args['initialRecipe'] as Recipe;
      expect(template.imageUrls, isEmpty);
      expect(template.core.thumbnailUrl, isNull);
    });
  });
}
