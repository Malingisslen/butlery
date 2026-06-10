/// First view-level scaffolding for [RecipeDetailView] (BUT-1225) + the
/// favorite-toggle announce coverage that closes BUT-1212 site 3/3 (BUT-905)
/// + the cook-snap visibility dialog wiring (BUT-1214/BUT-1231): the "Bara
/// jag" choice must reach `CookSnapService.addCookSnap` as
/// `CookSnapVisibility.onlyMe` — every layer in that chain defaults to
/// `sameAsRecipe`, so a dropped forward compiles clean and silently shares
/// author-only photos.
///
/// The view is the 1100-line self-providing shell: its State resolves
/// SocialRecipeViewModel/UserService from the production ServiceLocator in
/// initState/build, and its `build()` creates the RecipeDetailViewModel inside
/// a `ChangeNotifierProvider(create:)` — exactly the wiring class that hid the
/// CollaborativeShoppingView ProviderNotFoundException until the first
/// full-shell tap (BUT-1212). These tests pump the REAL view over the
/// prod↔test locator bridge; the favorite announce is asserted on the REAL
/// `flutter/accessibility` channel against live l10n.
///
/// Mocked at the locator (the view's seams, not its subject):
///   UnifiedRecipeService, RecipeCookingService, AnalyticsService (default),
///   PermissionService (default, user `test-user-123`), UserService,
///   SocialRecipeViewModel, OfflineService, CookSnapService,
///   UnifiedFriendsService (default).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail_view.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../infrastructure/di/test_service_locator.dart';
import '../infrastructure/factories/mock_factory.dart';
import '../infrastructure/factories/recipe_factory.dart';
import '../infrastructure/helpers/announce_channel.dart';
import '../infrastructure/mocks/production_mocks.dart';
import '../infrastructure/mocks/widget_mocks.dart';
import 'helpers/view_test_helpers.dart';

/// CookSnapService is a concrete class with repository deps; the gallery only
/// needs its stream, so a Fake emitting an empty list keeps the cook-snap
/// section in its (settled, snapless) state without Firebase.
///
/// `addCookSnap` is a recording override (BUT-1231): the view creates its
/// CookSnapViewModel internally via `ChangeNotifierProvider(create:)`, so the
/// service is the practical capture seam for "which visibility did the dialog
/// choice actually produce" — consistent with the BUT-1214 service-level pin.
class _FakeCookSnapService extends Fake implements CookSnapService {
  int addCalls = 0;
  String? lastRecipeId;
  ImageSource? lastSource;
  CookSnapVisibility? lastVisibility;

  @override
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) =>
      Stream.value(const <CookSnap>[]);

  @override
  Future<CookSnap?> addCookSnap({
    required String recipeId,
    required String recipeAuthorId,
    required String recipeName,
    required ImageSource source,
    String? caption,
    CookSnapVisibility visibility = CookSnapVisibility.sameAsRecipe,
  }) async {
    addCalls++;
    lastRecipeId = recipeId;
    lastSource = source;
    lastVisibility = visibility;
    return CookSnap.create(
      recipeId: recipeId,
      userId: _testUserId,
      userDisplayName: 'Test User',
      photoUrl: 'https://example.com/snap.jpg',
    );
  }
}

const _testUserId = 'test-user-123';

void main() {
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;
  late MockSocialRecipeViewModel socialVm;
  late _FakeCookSnapService cookSnapService;
  late Recipe recipe;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    // Owned by the test user so the app bar shows the owner action set and the
    // sharing-status section short-circuits (personal recipe, no audience).
    // No imageUrls → the hero renders the VegetableIllustration branch instead
    // of CachedNetworkImage (no network in widget tests).
    // ≥3 ingredients + ≥2 instructions keep completenessScore above the
    // incomplete threshold, so the "improve this recipe" banner (whose narrow-
    // width Row overflows at 420px — unrelated to this suite's subject) does
    // not enter the tree.
    recipe = RecipeFactory.build(
      id: 'recipe-fav-1',
      title: 'Köttbullar med Gräddsås',
      createdBy: _testUserId,
      ingredients: ['500 g köttfärs', '1 dl grädde', '1 gul lök'],
      instructions: ['Rulla köttbullarna.', 'Stek och servera med sås.'],
    );

    // RecipeDetailViewModel resolves UnifiedRecipeService from the locator and
    // subscribes to its stateStream in the ctor.
    recipeService = MockUnifiedRecipeService();
    recipeService.setRecipeState(recipes: [recipe], isInitialized: true);
    when(() => recipeService.toggleFavorite(any(), any()))
        .thenAnswer((_) async => true);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);

    // RecipeDetailViewModel's third ctor dep — not in the default registry.
    TestServiceLocator.registerMock<RecipeCookingService>(
        MockFactory.createRecipeCookingService());

    // The view exposes UserService via ChangeNotifierProvider.value and two
    // Selectors read `allergenPreferences` during build.
    userService = MockUserService();
    when(() => userService.allergenPreferences)
        .thenReturn(UserAllergenPreferences.defaults);
    when(() => userService.addListener(any())).thenReturn(null);
    when(() => userService.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<UserService>(userService);

    // The view's State resolves SocialRecipeViewModel in initState (and owns
    // its dispose). RecipeDetailComments drives initialize/refreshComments
    // from a post-frame callback and reads the collapsed-header getters.
    socialVm = MockSocialRecipeViewModel();
    when(() => socialVm.initialize()).thenAnswer((_) async {});
    when(() => socialVm.refreshComments(any())).thenAnswer((_) async {});
    when(() => socialVm.topLevelComments).thenReturn(const <RecipeComment>[]);
    TestServiceLocator.registerMock<SocialRecipeViewModel>(socialVm);

    // Top sliver is LayoutComponents.offlineIndicator() — needs an online
    // OfflineService so it builds collapsed.
    final offlineService = MockOfflineService();
    when(() => offlineService.isOnline).thenReturn(true);
    when(() => offlineService.addListener(any())).thenReturn(null);
    when(() => offlineService.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offlineService);

    // Cook-snap gallery resolves CookSnapService from the locator.
    cookSnapService = _FakeCookSnapService();
    TestServiceLocator.registerMock<CookSnapService>(cookSnapService);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Widget localize(Widget home) {
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
      home: home,
    );
  }

  /// Pumps the WHOLE production view at a mobile width (Breakpoints.isMobile →
  /// single-column path) and drains the post-frame init chain (portion init,
  /// comments initialize/refresh, cook-snap stream settling).
  Future<void> pumpDetailView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(localize(RecipeDetailView(recipe: recipe)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// The favorite hero button's tappable surface inside its keyed wrapper.
  Finder favoriteButton() => find.descendant(
        of: find.byKey(const ValueKey('test-recipe-detail-favorite')),
        matching: find.byType(InkWell),
      );

  /// Tap the favorite toggle and drain its async chain
  /// (toggleFavorite await → service stub → announce).
  Future<void> tapFavorite(WidgetTester tester) async {
    await tester.tap(favoriteButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(RecipeDetailView)));

  group('RecipeDetailView — full shell scaffolding (BUT-1225)', () {
    testWidgets(
        'the real view pumps without exception and shows the recipe title',
        (tester) async {
      // Proves: the self-providing shell (MultiProvider + locator-resolved
      // SocialRecipeViewModel/UserService + internally-created
      // RecipeDetailViewModel) wires up end to end — the class of bug that a
      // sub-widget harness can never see (BUT-1212 ProviderNotFoundException).
      await pumpDetailView(tester);

      expect(tester.takeException(), isNull);
      // Title section renders the title lowercased (design rule).
      expect(find.text('köttbullar med gräddsås'), findsOneWidget);
      expect(favoriteButton(), findsOneWidget);
    });
  });

  group('RecipeDetailView — favorite-toggle announce (BUT-905/BUT-1212)', () {
    testWidgets('favoriting announces a11yRecipeFavorited to screen readers',
        (tester) async {
      // Proves: tapping the heart on an unfavorited recipe announces the new
      // favorited state on the real accessibility channel — the icon swap
      // alone conveys nothing to a screen reader.
      final announces = AnnounceChannel.arm(tester);
      await pumpDetailView(tester);

      await tapFavorite(tester);

      final l10n = l10nOf(tester);
      expect(announces.messages, contains(l10n.a11yRecipeFavorited));
      expect(announces.messages, isNot(contains(l10n.a11yRecipeUnfavorited)));
      verify(() => recipeService.toggleFavorite(recipe.id, true)).called(1);
    });

    testWidgets('unfavoriting announces a11yRecipeUnfavorited', (tester) async {
      // Proves: the announce tracks the toggle both ways — favorited then
      // unfavorited, in order, with no spurious extra announcements.
      final announces = AnnounceChannel.arm(tester);
      await pumpDetailView(tester);

      await tapFavorite(tester);
      await tapFavorite(tester);

      final l10n = l10nOf(tester);
      expect(
        announces.messages,
        [l10n.a11yRecipeFavorited, l10n.a11yRecipeUnfavorited],
        reason: 'each tap must announce exactly the state it produced',
      );
    });

    testWidgets(
        'a failed toggle announces the reverted (true) state, not the '
        'optimistic one', (tester) async {
      // Proves: the announce reads viewModel.recipe.isFavorite AFTER the await
      // — when the service rejects the toggle the VM reverts the optimistic
      // flip, and the screen reader must hear the truth (still unfavorited),
      // matching the heart the sighted user sees revert.
      when(() => recipeService.toggleFavorite(any(), any()))
          .thenAnswer((_) async => false);

      final announces = AnnounceChannel.arm(tester);
      await pumpDetailView(tester);

      await tapFavorite(tester);

      final l10n = l10nOf(tester);
      expect(announces.messages, [l10n.a11yRecipeUnfavorited],
          reason: 'announcement must reflect the reverted state on failure');
    });
  });

  group('RecipeDetailView — cook-snap visibility wiring (BUT-1214/BUT-1231)',
      () {
    /// Scrolls the gallery's add affordance into view, taps it, and resolves
    /// the image-source bottom sheet with the gallery option — landing on
    /// whatever the production flow shows next (visibility dialog for
    /// public/shared recipes, direct upload for private ones).
    Future<void> startAddSnapFlow(WidgetTester tester) async {
      await pumpDetailView(tester);

      final addButton = find.byIcon(Icons.add_a_photo);
      await tester.ensureVisible(addButton);
      await tester.pump();
      await tester.tap(addButton);
      // Modal bottom sheet slide-in.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.commonSelectFromGallery));
      // Sheet pops, then (for non-private recipes) the dialog fades in.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Finder onlyMeRadio() =>
        find.byKey(const ValueKey('cook-snap-visibility-only-me'));

    Finder inDialog(Finder matching) =>
        find.descendant(of: find.byType(AlertDialog), matching: matching);

    group('public recipe (dialog fires)', () {
      setUp(() {
        // The visibility dialog only appears when the snap has an audience
        // beyond the author — a public recipe is the simplest such case.
        // Still owned by the test user; personal type keeps the sharing-
        // status section short-circuited.
        recipe = RecipeFactory.build(
          id: 'recipe-snap-1',
          title: 'Pannkakor',
          createdBy: _testUserId,
          isPublic: true,
          ingredients: ['3 ägg', '6 dl mjölk', '2.5 dl vetemjöl'],
          instructions: ['Vispa smeten.', 'Grädda i stekpanna.'],
        );
        recipeService.setRecipeState(recipes: [recipe], isInitialized: true);
      });

      testWidgets(
          '"Bara jag" choice reaches addCookSnap as '
          'CookSnapVisibility.onlyMe', (tester) async {
        // Proves: the per-snap privacy override survives the whole chain
        // dialog → vm.addSnap → service.addCookSnap. Every link defaults to
        // sameAsRecipe, so dropping any forward compiles clean and silently
        // shares an author-only photo — this is the regression BUT-1214
        // pinned at the service→doc link; this test pins the dialog→service
        // half.
        await startAddSnapFlow(tester);
        expect(onlyMeRadio(), findsOneWidget,
            reason: 'public recipe must show the visibility dialog');

        await tester.tap(onlyMeRadio());
        await tester.pump();
        final l10n = l10nOf(tester);
        await tester.tap(inDialog(find.text(l10n.cookSnapVisibilityConfirm)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(cookSnapService.addCalls, 1);
        expect(cookSnapService.lastVisibility, CookSnapVisibility.onlyMe);
        expect(cookSnapService.lastRecipeId, recipe.id);
        expect(cookSnapService.lastSource, ImageSource.gallery);
      });

      testWidgets('confirming without changing the radio uploads sameAsRecipe',
          (tester) async {
        // Proves: the dialog's default selection is "Samma som receptet" —
        // a regression preselecting onlyMe (or forwarding garbage) would
        // hide every confirmed-by-default snap from the recipe's audience.
        await startAddSnapFlow(tester);

        final l10n = l10nOf(tester);
        await tester.tap(inDialog(find.text(l10n.cookSnapVisibilityConfirm)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(cookSnapService.addCalls, 1);
        expect(cookSnapService.lastVisibility, CookSnapVisibility.sameAsRecipe);
      });

      testWidgets('cancelling the visibility dialog uploads nothing',
          (tester) async {
        // Proves: cancel means cancel — the dialog is a consent gate, so
        // backing out must not fall through to an upload with the default
        // visibility.
        await startAddSnapFlow(tester);

        final l10n = l10nOf(tester);
        await tester.tap(inDialog(find.text(l10n.commonCancel)));
        // Dialog pop transition (~150ms fade) must finish before asserting
        // it left the tree.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(onlyMeRadio(), findsNothing, reason: 'dialog must be dismissed');
        expect(cookSnapService.addCalls, 0,
            reason: 'cancel must not upload anything');
      });
    });

    testWidgets('private recipe skips the dialog and uploads with sameAsRecipe',
        (tester) async {
      // Proves: the BUT-1214 "private recipes add no friction" rule — the
      // audience is already author-only, so no dialog appears AND the upload
      // still happens (a regression gating the upload on the never-shown
      // dialog would silently break adding snaps to personal recipes).
      // Uses the outer setUp's private personal recipe unchanged.
      await startAddSnapFlow(tester);

      expect(onlyMeRadio(), findsNothing,
          reason: 'private recipe must not show the visibility dialog');
      expect(cookSnapService.addCalls, 1,
          reason: 'upload must proceed without the dialog');
      expect(cookSnapService.lastVisibility, CookSnapVisibility.sameAsRecipe);
      expect(cookSnapService.lastRecipeId, recipe.id);
    });
  });
}
