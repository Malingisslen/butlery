// test/widget/views/recipe_detail_read_only_test.dart
//
// Task 4 (2026-06-21): readOnly mode on RecipeDetailView.
// When readOnly:true, owner actions (favorite toggle, Edit, Edit-tags, Delete)
// are hidden; the Save-a-copy (fork) action and comments/ratings remain.
//
// Harness mirrors test/views/recipe_detail_view_test.dart:
//   production.ServiceLocator.initialize(DIContainer()) + ViewTestHelpers
//   bridge + MockUnifiedRecipeService/MockUserService/MockSocialRecipeViewModel/
//   MockOfflineService/FakeCookSnapService registered in the shared GetIt.
//
// Scope note: the overflow menu is not opened — tapping PopupMenuButton in
// widget tests requires the route/overlay infrastructure present in
// recipe_detail_view_test.dart. The favorite-toggle key assertion is the
// highest-value behavioral check: it is visible without scrolling and directly
// verifies the readOnly contract. The save-copy check verifies the retained
// action. Both are in the hero button column, no overlay interaction needed.

library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail_view.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../views/helpers/view_test_helpers.dart';

// Minimal CookSnapService fake — gallery only needs its stream.
class _FakeCookSnapService extends Fake implements CookSnapService {
  @override
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) =>
      Stream.value(const <CookSnap>[]);
}

const _testUserId = 'test-user-123';
const _friendUserId = 'friend-user-456';

// Minimal mock for SocialRecipeService: only acceptRecipeShareRequest needed.
class _MockSocialRecipeService extends Mock implements SocialRecipeService {}

void main() {
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;
  late MockSocialRecipeViewModel socialVm;
  late Recipe ownedRecipe;
  late Recipe friendRecipe;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
    // Mocktail requires a fallback value for any() matchers on SocialRequest.
    registerFallbackValue(
      SocialRequest(
        id: 'fallback',
        type: SocialRequestType.recipeShareRequest,
        fromUserId: 'from',
        toUserId: 'to',
      ),
    );
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    // An owned recipe: favorite toggle is visible (readOnly defaults to false).
    ownedRecipe = RecipeFactory.build(
      id: 'recipe-owned-1',
      title: 'Ägda Pannkakor',
      createdBy: _testUserId,
      ingredients: ['mjöl', 'mjölk', 'ägg'],
      instructions: ['Blanda.', 'Stek.'],
    );

    // A friend's recipe: createdBy differs from test user → showForkInAppBar
    // returns true so test-recipe-detail-save-copy appears; readOnly:true hides
    // the favorite toggle.
    friendRecipe = RecipeFactory.build(
      id: 'recipe-friend-1',
      title: 'Vännens Pasta',
      createdBy: _friendUserId,
      ingredients: ['pasta', 'tomatsås', 'ost'],
      instructions: ['Koka pasta.', 'Häll på sås.'],
    );

    recipeService = MockUnifiedRecipeService();
    recipeService.setRecipeState(
      recipes: [ownedRecipe, friendRecipe],
      isInitialized: true,
    );
    when(
      () => recipeService.toggleFavorite(any(), any()),
    ).thenAnswer((_) async => true);
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
    TestServiceLocator.registerMock<UserService>(userService);

    socialVm = MockSocialRecipeViewModel();
    when(() => socialVm.initialize()).thenAnswer((_) async {});
    when(() => socialVm.refreshComments(any())).thenAnswer((_) async {});
    when(() => socialVm.topLevelComments).thenReturn(const <RecipeComment>[]);
    TestServiceLocator.registerMock<SocialRecipeViewModel>(socialVm);

    final offlineService = MockOfflineService();
    when(() => offlineService.isOnline).thenReturn(true);
    when(() => offlineService.addListener(any())).thenReturn(null);
    when(() => offlineService.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offlineService);

    TestServiceLocator.registerMock<CookSnapService>(_FakeCookSnapService());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Widget localize(Widget home, {ThemeData? theme}) {
    return MaterialApp(
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme ?? AppTheme.lightTheme,
      home: home,
    );
  }

  Future<void> pumpView(
    WidgetTester tester,
    Widget view, {
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(localize(view, theme: theme));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('RecipeDetailView — share-request banner (Task 8)', () {
    testWidgets('banner and share action render when shareRequest is provided', (
      tester,
    ) async {
      // Proves: when the owner opens their own recipe via a share-request
      // notification, a banner with the requester's name is shown together with
      // a one-tap share action button.
      final socialRecipeService = _MockSocialRecipeService();
      when(
        () => socialRecipeService.acceptRecipeShareRequest(any()),
      ).thenAnswer((_) async => true);
      TestServiceLocator.registerMock<SocialRecipeService>(socialRecipeService);

      final shareRequest = SocialRequest(
        id: 'req-001',
        type: SocialRequestType.recipeShareRequest,
        fromUserId: _friendUserId,
        toUserId: _testUserId,
        fromUserName: 'Anna',
        recipeId: 'recipe-owned-1',
      );

      // ownedRecipe.createdBy == _testUserId == PermissionService.currentUserId
      // so the owner-guard passes and the banner renders.
      await pumpView(
        tester,
        RecipeDetailView(recipe: ownedRecipe, shareRequest: shareRequest),
      );

      expect(tester.takeException(), isNull);

      // Banner text: "{name} vill se det här receptet" → "Anna vill se det här receptet"
      expect(
        find.textContaining('Anna'),
        findsWidgets,
        reason: 'Banner must mention the requester name',
      );

      // Share action button renders.
      expect(
        find.textContaining('Dela med Anna'),
        findsOneWidget,
        reason: 'Share-action button must be visible',
      );

      // Tap the share action.
      await tester.tap(find.textContaining('Dela med Anna'));
      await tester.pumpAndSettle();

      verify(
        () => socialRecipeService.acceptRecipeShareRequest(any()),
      ).called(1);
    });

    testWidgets('banner is suppressed when current user is NOT the recipe owner', (
      tester,
    ) async {
      // Proves: removing the `recipe.createdBy == currentUserId` guard in
      // production would cause this test to fail — the banner must only render
      // when the logged-in user owns the recipe.
      final socialRecipeService = _MockSocialRecipeService();
      when(
        () => socialRecipeService.acceptRecipeShareRequest(any()),
      ).thenAnswer((_) async => true);
      TestServiceLocator.registerMock<SocialRecipeService>(socialRecipeService);

      // shareRequest targets the friend's recipe (createdBy == _friendUserId),
      // but the current test user is _testUserId — so the owner guard must fail.
      final shareRequest = SocialRequest(
        id: 'req-002',
        type: SocialRequestType.recipeShareRequest,
        fromUserId: 'another-user-789',
        toUserId: _testUserId,
        fromUserName: 'Björn',
        recipeId: 'recipe-friend-1',
      );

      await pumpView(
        tester,
        RecipeDetailView(recipe: friendRecipe, shareRequest: shareRequest),
      );

      expect(tester.takeException(), isNull);

      // Banner text must not appear when current user doesn't own the recipe.
      expect(
        find.textContaining('Björn vill se'),
        findsNothing,
        reason: 'Banner must be suppressed when current user is not the owner',
      );
      expect(
        find.textContaining('Dela med Björn'),
        findsNothing,
        reason:
            'Share action must be suppressed when current user is not the owner',
      );

      verifyNever(() => socialRecipeService.acceptRecipeShareRequest(any()));
    });
  });

  group('RecipeDetailView — readOnly mode (Task 4)', () {
    testWidgets('readOnly:true hides the favorite toggle and shows save-copy', (
      tester,
    ) async {
      // Proves: when a friend's recipe is shown with readOnly:true, the
      // favorite toggle (owner action) is absent and the save-a-copy fork
      // button (non-owner action) is present.
      await pumpView(
        tester,
        RecipeDetailView(recipe: friendRecipe, readOnly: true),
      );

      expect(tester.takeException(), isNull);
      // Owner action hidden:
      expect(
        find.byKey(const ValueKey('test-recipe-detail-favorite')),
        findsNothing,
        reason: 'Favorite toggle must be hidden when readOnly:true',
      );
      // Non-owner/retained action present:
      expect(
        find.byKey(const ValueKey('test-recipe-detail-save-copy')),
        findsOneWidget,
        reason: 'Save-a-copy must remain visible when readOnly:true',
      );
    });

    testWidgets('readOnly:false (default) keeps the favorite toggle visible', (
      tester,
    ) async {
      // Proves: the default behavior (owned recipe, readOnly omitted) still
      // shows the favorite toggle — the flag does not regress the normal path.
      await pumpView(tester, RecipeDetailView(recipe: ownedRecipe));

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('test-recipe-detail-favorite')),
        findsOneWidget,
        reason: 'Favorite toggle must be visible when readOnly:false',
      );
    });
  });

  // P4-U05: the media hero (Komponentark v1:81-89) and the view's one
  // saffron action (Grafisk manual v6:219; Skarmar v12 del 1 'Receptdetalj',
  // etapp 11 'Receptet brett — någon annans').
  group('RecipeDetailView — media hero and action bar (P4-U05)', () {
    List<String> heroLabels(WidgetTester tester, Brightness b) => tester
        .widgetList<FilledButton>(find.byType(FilledButton))
        .where(
          (button) =>
              button.style?.backgroundColor?.resolve(const {}) ==
              AppModeColors.actionPrimary(b),
        )
        .map((button) => (button.child! as Text).data!)
        .toList();

    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('own recipe: Börja laga is the one saffron action ($mode)', (
        tester,
      ) async {
        await pumpView(
          tester,
          RecipeDetailView(recipe: ownedRecipe),
          theme: theme,
        );

        expect(tester.takeException(), isNull);
        expect(heroLabels(tester, theme.brightness), ['Börja laga']);
        expect(
          find.widgetWithText(FilledButton, 'Lägg i inköpslistan'),
          findsOneWidget,
        );
        expect(find.byType(FloatingActionButton), findsNothing);
        // Icon buttons stand in paper rings on the photo.
        expect(
          find.byKey(const ValueKey('recipe-detail-paper-ring')),
          findsWidgets,
        );
        // No spinner anywhere on the page.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets("a friend's recipe: Spara till mitt kök is the one "
          'saffron action ($mode)', (tester) async {
        await pumpView(
          tester,
          RecipeDetailView(recipe: friendRecipe, readOnly: true),
          theme: theme,
        );

        expect(tester.takeException(), isNull);
        expect(heroLabels(tester, theme.brightness), ['Spara till mitt kök']);
        expect(
          find.widgetWithText(FilledButton, 'Börja laga'),
          findsOneWidget,
        );
      });
    }

    // Skarmar v12 del 1 'Receptdetalj' draws the shopping-list action with
    // an ink fill; 'Receptdetalj — mörkt läge' draws it with no fill, a
    // 1.5 px paper outline and paper text.
    testWidgets('the shopping-list action is ink in light mode', (
      tester,
    ) async {
      await pumpView(tester, RecipeDetailView(recipe: ownedRecipe));
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('test-recipe-detail-add-to-list')),
      );
      expect(button.style, isNull, reason: 'the theme ink fill');
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byKey(const ValueKey('test-recipe-detail-add-to-list')),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, AppTheme.lightTheme.colorScheme.primary);
    });

    testWidgets('the shopping-list action is a paper outline in dark mode', (
      tester,
    ) async {
      await pumpView(
        tester,
        RecipeDetailView(recipe: ownedRecipe),
        theme: AppTheme.darkTheme,
      );
      final paper = AppTheme.darkTheme.colorScheme.onSurface;
      expect(paper, const Color(0xFFF5F4ED));
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byKey(const ValueKey('test-recipe-detail-add-to-list')),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, Colors.transparent);
      final shape = material.shape! as OutlinedBorder;
      expect(shape.side.color, paper);
      expect(shape.side.width, 1.5);
      final label = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Lägg i inköpslistan'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(label.style.color, paper);
    });

    testWidgets('the title stands under the hero, never on the image', (
      tester,
    ) async {
      await pumpView(tester, RecipeDetailView(recipe: ownedRecipe));

      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(bar.title, isA<SizedBox>());
      expect(
        find.descendant(
          of: find.byType(SliverAppBar),
          matching: find.text('Ägda Pannkakor'),
        ),
        findsNothing,
      );
      expect(find.text('Ägda Pannkakor'), findsWidgets);
    });

    testWidgets('the back button is named after where it goes', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpView(
        tester,
        RecipeDetailView(recipe: ownedRecipe, backTo: 'Mina recept'),
      );

      expect(
        find.bySemanticsLabel(RegExp('Tillbaka till Mina recept')),
        findsWidgets,
      );
      handle.dispose();
    });
  });
}
