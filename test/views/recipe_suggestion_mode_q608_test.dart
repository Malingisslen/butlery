// Q6-08 = A and Q6-07 = B (produktbeslut 2026-09-27): the recipe editor on
// someone else's shared recipe.
//
// Sources: produktregler.md:241 (a member cannot edit a recipe someone else
// owns; the change is kept as a suggestion the owner accepts or dismisses),
// :246 (Redigera shows as "Föreslå ändring" for a member); Q6-07 = B (one
// pending suggestion per member and recipe; nothing is discarded silently);
// content-style-guide.md:87-97 (a failure says what happened, what is kept
// and what to do).
//
// Who owns the recipe comes from its owner id, never from the screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/recipe_suggestion_service.dart';
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

class _MockSuggestions extends Mock implements RecipeSuggestionService {}

const _me = 'test-user-123';
const _owner = 'friend-owner-456';

final _waiting = RecipeSuggestion(
  id: 'waiting-1',
  recipeId: 'shared-recipe-1',
  ownerId: _owner,
  suggesterId: _me,
  suggestion: const {},
  status: RecipeSuggestionStatus.pending,
  createdAt: DateTime.utc(2026, 9, 26, 10),
  expiresAt: DateTime.utc(2026, 10, 3, 10),
);

void main() {
  final l10n = AppLocalizationsSv();
  late mocks.MockPersonalRecipeOperations personal;
  late _MockSuggestions suggestions;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
  });

  setUp(() async {
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

    final sync = _MockRealtimeSyncService();
    when(
      () => sync.watchResource<RealtimeRecipe>(any()),
    ).thenAnswer((_) => const Stream<RealtimeRecipe>.empty());
    when(
      () => sync.conflictStream,
    ).thenAnswer((_) => const Stream<ConflictEvent>.empty());
    TestServiceLocator.registerMock<RealtimeSyncService>(sync);

    suggestions = _MockSuggestions();
    when(
      () => suggestions.suggestEdit(
        edited: any(named: 'edited'),
        ownerId: any(named: 'ownerId'),
        suggesterId: any(named: 'suggesterId'),
      ),
    ).thenAnswer((_) async => _waiting);
    TestServiceLocator.registerMock<RecipeSuggestionService>(suggestions);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Recipe recipeOwnedBy(String ownerId) => RecipeFactory.build(
    id: 'shared-recipe-1',
    title: 'Olles pannkakor',
    description: 'Tunna',
    createdBy: ownerId,
    ingredients: const ['Mjöl', 'Mjölk'],
    instructions: const ['Vispa', 'Stek'],
  );

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

  Future<void> retitle(WidgetTester tester, String title) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Olles pannkakor'),
      title,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('edit-recipe-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('someone else\'s recipe: the editor suggests a change, and '
      'Spara sends it to the owner without writing the recipe', (tester) async {
    await openEditor(tester, recipeOwnedBy(_owner));

    expect(find.text(l10n.recipeSuggestChange), findsOneWidget);
    expect(find.text(l10n.recipeEdit), findsNothing);
    expect(find.text(l10n.recipeSuggestionSend), findsOneWidget);

    await retitle(tester, 'Olles pannkakor med sylt');
    await tapSave(tester);

    final captured = verify(
      () => suggestions.suggestEdit(
        edited: captureAny(named: 'edited'),
        ownerId: _owner,
        suggesterId: _me,
      ),
    ).captured;
    final edited = captured.single as Recipe;
    expect(edited.id, 'shared-recipe-1');
    expect(edited.title, 'Olles pannkakor med sylt');
    verifyNever(() => personal.updateUnifiedRecipe(any()));
    verifyNever(() => personal.addUnifiedRecipe(any()));
    expect(find.byType(EditRecipeView), findsNothing);
    expect(find.text(l10n.recipeSuggestionSent), findsOneWidget);
  });

  testWidgets('Q6-07: while my last suggestion waits, no second one is sent; '
      'Stäng keeps the edits, and they can be kept as my own copy', (
    tester,
  ) async {
    when(
      () => suggestions.suggestEdit(
        edited: any(named: 'edited'),
        ownerId: any(named: 'ownerId'),
        suggesterId: any(named: 'suggesterId'),
      ),
    ).thenThrow(RecipeSuggestionAlreadyWaiting(_waiting));
    await openEditor(tester, recipeOwnedBy(_owner));
    await retitle(tester, 'Olles pannkakor med sylt');
    await tapSave(tester);

    expect(find.text(l10n.recipeSuggestionWaitingTitle), findsOneWidget);
    expect(find.text(l10n.recipeSuggestionWaitingBody), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('suggestion-waiting-close')));
    await tester.pumpAndSettle();
    expect(find.byType(EditRecipeView), findsOneWidget);
    expect(find.text('Olles pannkakor med sylt'), findsOneWidget);
    verifyNever(() => personal.updateUnifiedRecipe(any()));
    verifyNever(() => personal.addUnifiedRecipe(any()));

    await tapSave(tester);
    await tester.tap(
      find.byKey(const ValueKey('suggestion-waiting-save-copy')),
    );
    await tester.pumpAndSettle();

    final copy =
        verify(() => personal.addUnifiedRecipe(captureAny())).captured.single
            as Recipe;
    expect(copy.id, isNot('shared-recipe-1'), reason: 'my copy, not theirs');
    expect(copy.title, 'Olles pannkakor med sylt');
    verifyNever(() => personal.updateUnifiedRecipe(any()));
    expect(find.text(l10n.recipeCopySaved), findsOneWidget);
  });

  testWidgets('a suggestion that cannot be sent says so, keeps the edits and '
      'offers Försök igen', (tester) async {
    when(
      () => suggestions.suggestEdit(
        edited: any(named: 'edited'),
        ownerId: any(named: 'ownerId'),
        suggesterId: any(named: 'suggesterId'),
      ),
    ).thenThrow(StateError('offline'));
    await openEditor(tester, recipeOwnedBy(_owner));
    await retitle(tester, 'Olles pannkakor med sylt');
    await tapSave(tester);

    expect(find.byType(EditRecipeView), findsOneWidget);
    expect(
      find.textContaining(l10n.recipeSuggestionSendFailed),
      findsOneWidget,
    );
    expect(find.text(l10n.commonRetry), findsOneWidget);
    verifyNever(() => personal.updateUnifiedRecipe(any()));
  });

  testWidgets('my own recipe still saves as an edit', (tester) async {
    await openEditor(tester, recipeOwnedBy(_me));

    expect(find.text(l10n.recipeEdit), findsOneWidget);
    expect(find.text(l10n.recipeSuggestChange), findsNothing);
    expect(find.text(l10n.commonSaveChanges), findsOneWidget);

    await retitle(tester, 'Mina pannkakor');
    await tapSave(tester);

    verify(() => personal.updateUnifiedRecipe(any())).called(1);
    verifyNever(
      () => suggestions.suggestEdit(
        edited: any(named: 'edited'),
        ownerId: any(named: 'ownerId'),
        suggesterId: any(named: 'suggesterId'),
      ),
    );
  });
}
