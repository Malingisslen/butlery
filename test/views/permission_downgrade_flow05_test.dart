// P6-U05: flow 05, a role lowered to read-only while an editor is open, and
// the revoked or expired link notice.
//
// Sources: flows-roles-budget.md:83 ("behörighet sänks till endast läsa →
// öppna redigeringsvyer stängs med förklaring, osparat erbjuds som kopia"),
// :132 (the drop takes effect at once in open views), :80 ("Länken gäller
// inte längre"); PQ-13 = A (no request button, BUT-2143); produktregler.md
// :535 (never offer what the app cannot do).
//
// The live role comes from the realtime resource of the shared recipe
// (RecipePermissionManager.watchCanEdit), faked here as a stream.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/edit_recipe_view.dart';

import '../infrastructure/di/test_service_locator.dart';
import '../infrastructure/factories/mock_factory.dart';
import '../infrastructure/factories/recipe_factory.dart';
import '../infrastructure/helpers/widget_test_app.dart';
import '../infrastructure/mocks/production_mocks.dart' as mocks;
import '../test_support/base_unit_test.dart';

class _MockRealtimeSyncService extends Mock implements RealtimeSyncService {}

const _me = 'test-user-123';
const _owner = 'friend-owner-456';

RealtimeRecipe _live(Recipe recipe, ResourcePermission myRole) =>
    RealtimeRecipe(
      id: recipe.id,
      ownerId: _owner,
      ownerDisplayName: 'Olle',
      participants: {_owner: ResourcePermission.owner, _me: myRole},
      createdAt: DateTime(2026, 9, 1),
      lastEditedAt: DateTime(2026, 9, 20),
      lastEditedBy: _owner,
      lastEditedByDisplayName: 'Olle',
      editCount: 1,
      recipe: recipe,
    );

void main() {
  final l10n = AppLocalizationsSv();
  late StreamController<RealtimeRecipe> roles;
  late mocks.MockPersonalRecipeOperations personal;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
  });

  setUp(() async {
    // The editor's draft store; the copy clears the draft when it is saved.
    SharedPreferences.setMockInitialValues({});
    await TestServiceLocator.initialize();
    TestServiceLocator.registerMock<AuthService>(
      MockFactory.createAuthService(isAuthenticated: true, userId: _me),
    );
    TestServiceLocator.registerMock<PermissionService>(
      MockFactory.createPermissionService(currentUserId: _me),
    );
    TestServiceLocator.registerMock<SocialRecipeService>(
      MockFactory.createSocialRecipeService(),
    );
    TestServiceLocator.registerFactory<CollaborativeStatusViewModel>(
      () => CollaborativeStatusViewModel(),
    );
    TestServiceLocator.registerMock<ImageUploadService>(ImageUploadService());
    final tags = mocks.MockPersonalTagService();
    TestServiceLocator.registerMock<PersonalTagService>(tags);
    TestServiceLocator.registerMock<OfflineService>(
      OfflineService(
        firestoreRepository: TestServiceLocator.get<FirestoreRepository>(),
        authRepository: TestServiceLocator.get<AuthRepository>(),
      ),
    );
    TestServiceLocator.registerFactory<PersonalTagViewModel>(
      () => PersonalTagViewModel(service: tags),
    );

    personal = mocks.MockPersonalRecipeOperations();
    when(
      () => personal.addUnifiedRecipe(any()),
    ).thenAnswer((_) async => RecipeOperationResult.success());
    when(
      () => personal.updateUnifiedRecipe(any()),
    ).thenAnswer((_) async => RecipeOperationResult.success());
    final recipes = TestServiceLocator.get<UnifiedRecipeService>();
    (recipes as mocks.MockUnifiedRecipeService).setRecipeState(
      isInitialized: true,
      personalOperations: personal,
    );

    roles = StreamController<RealtimeRecipe>.broadcast();
    final sync = _MockRealtimeSyncService();
    when(
      () => sync.watchResource<RealtimeRecipe>(any()),
    ).thenAnswer((_) => roles.stream);
    when(
      () => sync.conflictStream,
    ).thenAnswer((_) => const Stream<ConflictEvent>.empty());
    TestServiceLocator.registerMock<RealtimeSyncService>(sync);
  });

  tearDown(() async {
    await roles.close();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Recipe sharedRecipe() => RecipeFactory.build(
    id: 'shared-recipe-1',
    title: 'Olles pannkakor',
    description: 'Tunna',
    createdBy: _owner,
    ingredients: const ['Mjöl', 'Mjölk'],
    instructions: const ['Vispa', 'Stek'],
  );

  /// A page that opens the editor, so closing it has somewhere to land.
  Future<void> openEditor(WidgetTester tester, Recipe recipe) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditRecipeView(recipe: recipe),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(EditRecipeView), findsOneWidget);
  }

  group('role lowered while the recipe editor is open', () {
    testWidgets('unsaved edits: the editor explains, offers them as a copy, '
        'saves the copy to my own library and writes nothing to the shared '
        'recipe', (tester) async {
      final recipe = sharedRecipe();
      await openEditor(tester, recipe);
      roles.add(_live(recipe, ResourcePermission.editor));
      await tester.pumpAndSettle();
      expect(find.text(l10n.roleLoweredRecipeTitle), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Olles pannkakor'),
        'Olles pannkakor med sylt',
      );
      await tester.pumpAndSettle();

      roles.add(_live(recipe, ResourcePermission.viewer));
      await tester.pumpAndSettle();

      expect(find.text(l10n.roleLoweredRecipeTitle), findsOneWidget);
      expect(find.text(l10n.roleLoweredRecipeBody), findsOneWidget);
      expect(find.text(l10n.roleLoweredSaveCopy), findsOneWidget);
      expect(find.text(l10n.roleLoweredDiscard), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('role-lowered-save-copy')));
      await tester.pumpAndSettle();

      final copy =
          verify(() => personal.addUnifiedRecipe(captureAny())).captured.single
              as Recipe;
      expect(copy.id, isNot(recipe.id), reason: 'a copy, not the shared one');
      expect(copy.title, 'Olles pannkakor med sylt');
      verifyNever(() => personal.updateUnifiedRecipe(any()));
      expect(find.byType(EditRecipeView), findsNothing);
      expect(find.text(l10n.recipeCopySaved), findsOneWidget);
    });

    testWidgets('unsaved edits discarded by name: the editor closes and '
        'nothing is written anywhere', (tester) async {
      final recipe = sharedRecipe();
      await openEditor(tester, recipe);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Olles pannkakor'),
        'Något annat',
      );
      await tester.pumpAndSettle();

      roles.add(_live(recipe, ResourcePermission.viewer));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('role-lowered-discard')));
      await tester.pumpAndSettle();

      expect(find.byType(EditRecipeView), findsNothing);
      verifyNever(() => personal.addUnifiedRecipe(any()));
      verifyNever(() => personal.updateUnifiedRecipe(any()));
    });

    testWidgets('nothing unsaved: the editor closes at once and says why, '
        'with no copy offer', (tester) async {
      final recipe = sharedRecipe();
      await openEditor(tester, recipe);

      roles.add(_live(recipe, ResourcePermission.viewer));
      await tester.pumpAndSettle();

      expect(find.byType(EditRecipeView), findsNothing);
      expect(find.text(l10n.roleLoweredRecipeTitle), findsNothing);
      expect(find.text(l10n.roleLoweredRecipeClosed), findsOneWidget);
      expect(find.text(l10n.commonClose), findsOneWidget);
      verifyNever(() => personal.addUnifiedRecipe(any()));
      verifyNever(() => personal.updateUnifiedRecipe(any()));
    });

    testWidgets('my own recipe is never watched: an owner cannot be lowered', (
      tester,
    ) async {
      final own = RecipeFactory.build(
        id: 'own-recipe-1',
        title: 'Mina pannkakor',
        createdBy: _me,
        ingredients: const ['Mjöl'],
        instructions: const ['Stek'],
      );
      await openEditor(tester, own);
      roles.add(_live(own, ResourcePermission.viewer));
      await tester.pumpAndSettle();

      expect(find.byType(EditRecipeView), findsOneWidget);
      expect(find.text(l10n.roleLoweredRecipeTitle), findsNothing);
    });
  });

  group('revoked or expired link (PQ-13 = A)', () {
    test('the notice says the link no longer holds and who to ask', () {
      expect(
        l10n.deepLinkExpired,
        'Länken gäller inte längre. Be den som delade om en ny.',
      );
      expect(l10n.deepLinkExpired, isNot(contains('!')));
      expect(
        AppLocalizationsEn().deepLinkExpired,
        'This link is no longer valid. Ask the person who shared it for a '
        'new one.',
      );
    });
  });
}
