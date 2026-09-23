// A conflict on your own recipe, in recipe detail (P5-U27).
//
// Sources: produktregler.md:102 (own recipe: both versions are shown and the
// user chooses; the choice is the decision), flows-roles-budget.md:18 (the
// user always learns that a conflict happened), Komponentark v1:755-758 (the
// banner). Mounted as edit_recipe_view.dart does: ConflictBanner scoped by
// the recipe's id. PQ-02 = A: a shared recipe gets the same view.
//
// Harness copied from test/widget/views/recipe_detail_read_only_test.dart.

library;

import 'dart:async';

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
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail_view.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/widgets/realtime/conflict_banner.dart';
import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/services/realtime/overwritten_version_service.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../../../views/helpers/view_test_helpers.dart';

// Minimal CookSnapService fake — gallery only needs its stream.
class _FakeCookSnapService extends Fake implements CookSnapService {
  @override
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) =>
      Stream.value(const <CookSnap>[]);
}

class _MockRealtimeSyncService extends Mock implements RealtimeSyncService {}

class _MockOverwrittenVersionService extends Mock
    implements OverwrittenVersionService {}

OverwrittenVersion _kept(String recipeId) => OverwrittenVersion(
  id: 'kept-$recipeId',
  ownerId: _testUserId,
  entity: ConflictEntity.recipeOwn,
  resourceType: RealtimeResourceType.recipe,
  resourceId: recipeId,
  version: const {},
  overwrittenBy: _friendUserId,
  overwrittenByName: 'Per',
  overwrittenAt: DateTime.now().toUtc(),
  expiresAt: DateTime.now().toUtc().add(OverwrittenVersion.keptFor),
);

class _FakeResource extends Fake implements RealtimeResource {
  _FakeResource([this.lastEditedByDisplayName = 'Per']);

  @override
  final String lastEditedByDisplayName;
}

ConflictEvent _event(String docId) => ConflictEvent(
  collectionPath: 'recipes',
  docId: docId,
  localValue: _FakeResource(),
  remoteValue: _FakeResource('Per'),
  chosenStrategy: ConflictResolutionStrategy.remoteWon,
  entity: ConflictEntity.recipeOwn,
  occurredAt: DateTime(2026, 9, 23),
);

const _testUserId = 'test-user-123';
const _friendUserId = 'friend-user-456';

void main() {
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;
  late MockSocialRecipeViewModel socialVm;
  late Recipe ownedRecipe;
  late Recipe friendRecipe;
  late StreamController<ConflictEvent> conflicts;
  late _MockOverwrittenVersionService overwritten;
  late List<OverwrittenVersion> keptVersions;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
    registerFallbackValue(ConflictEntity.recipeOwn);
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

    final realtime = _MockRealtimeSyncService();
    when(() => realtime.conflictStream).thenAnswer((_) => conflicts.stream);
    TestServiceLocator.registerMock<RealtimeSyncService>(realtime);

    keptVersions = const [];
    overwritten = _MockOverwrittenVersionService();
    when(
      () => overwritten.watch(
        entity: any(named: 'entity'),
        resourceId: any(named: 'resourceId'),
      ),
    ).thenAnswer((inv) {
      final id = inv.namedArguments[#resourceId] as String?;
      return Stream.value([
        for (final v in keptVersions)
          if (v.resourceId == id) v,
      ]);
    });
    TestServiceLocator.registerMock<OverwrittenVersionService>(overwritten);
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

  // P5-U26b: Återställ in the owner's overflow menu, only while a version of
  // this recipe is kept (produktregler.md:109; PQ-01 = A).
  group('RecipeDetailView — Återställ (P5-U26b)', () {
    const restoreRow = ValueKey('test-recipe-detail-restore-version');

    Future<void> openMore(WidgetTester tester) async {
      // The menu's existing rows (edit, add to menu, ...) are plain Rows and
      // overflow under the test font's wide glyphs; that is not this unit's
      // row, which is Flexible. Only that layout report is set aside here.
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('RenderFlex overflowed')) {
          return;
        }
        previous?.call(details);
      };
      addTearDown(() => FlutterError.onError = previous);
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
    }

    testWidgets('a kept version of this recipe adds the row', (tester) async {
      conflicts = StreamController<ConflictEvent>.broadcast();
      addTearDown(conflicts.close);
      keptVersions = [_kept(ownedRecipe.id)];
      await pumpView(tester, RecipeDetailView(recipe: ownedRecipe));
      await openMore(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RecipeDetailView)),
      );
      expect(find.byKey(restoreRow), findsOneWidget);
      expect(find.text(l10n.overwrittenRestoreAction), findsOneWidget);
    });

    testWidgets('nothing kept, no row', (tester) async {
      conflicts = StreamController<ConflictEvent>.broadcast();
      addTearDown(conflicts.close);
      keptVersions = [_kept(friendRecipe.id)];
      await pumpView(tester, RecipeDetailView(recipe: ownedRecipe));
      await openMore(tester);

      expect(find.byKey(restoreRow), findsNothing);
    });

    testWidgets("someone else's recipe never gets the row", (tester) async {
      conflicts = StreamController<ConflictEvent>.broadcast();
      addTearDown(conflicts.close);
      keptVersions = [_kept(friendRecipe.id)];
      await pumpView(
        tester,
        RecipeDetailView(recipe: friendRecipe, readOnly: true),
      );
      await openMore(tester);

      expect(find.byKey(restoreRow), findsNothing);
    });
  });

  group('RecipeDetailView — conflict (P5-U27)', () {
    testWidgets('a conflict on this recipe shows the conflict banner', (
      tester,
    ) async {
      // Created on the test's clock so its events are delivered by pump.
      conflicts = StreamController<ConflictEvent>.broadcast();
      addTearDown(conflicts.close);
      await pumpView(tester, RecipeDetailView(recipe: ownedRecipe));
      expect(tester.takeException(), isNull);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(RecipeDetailView)),
      );
      // Idle, the banner is mounted but takes no space.
      expect(
        find.byType(ConflictBanner, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text(l10n.conflictBannerTitleRecipe), findsNothing);

      conflicts.add(_event(ownedRecipe.id));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.conflictBannerTitleRecipe), findsOneWidget);
      expect(find.text(l10n.conflictBannerBody('Per')), findsOneWidget);
      expect(find.text(l10n.commonView), findsOneWidget);
    });

    testWidgets('a conflict on another recipe leaves this page alone', (
      tester,
    ) async {
      // Created on the test's clock so its events are delivered by pump.
      conflicts = StreamController<ConflictEvent>.broadcast();
      addTearDown(conflicts.close);
      await pumpView(tester, RecipeDetailView(recipe: ownedRecipe));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(RecipeDetailView)),
      );

      conflicts.add(_event(friendRecipe.id));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.conflictBannerTitleRecipe), findsNothing);
    });

    testWidgets('a shared recipe of someone else gets the same banner '
        '(PQ-02 = A)', (tester) async {
      conflicts = StreamController<ConflictEvent>.broadcast();
      addTearDown(conflicts.close);
      await pumpView(
        tester,
        RecipeDetailView(recipe: friendRecipe, readOnly: true),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(RecipeDetailView)),
      );

      conflicts.add(_event(friendRecipe.id));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.conflictBannerTitleRecipe), findsOneWidget);
    });
  });
}
