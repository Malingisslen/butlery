// BUT-1033: RecipePersistenceManager save-flow integration test for
// commitPendingStorageDeletes wiring (BUT-932 follow-up).
//
// The save flow at lib/viewmodels/recipe_form/recipe_persistence_manager.dart:229
// calls `_imageManager.commitPendingStorageDeletes()` *after* the
// addUnifiedRecipe/updateUnifiedRecipe succeeds. Two regression risks:
//
//   1. If the commit fired on save FAILURE, abandoned uploads would get
//      deleted incorrectly (data loss).
//   2. If it didn't fire on save SUCCESS, Storage would accumulate orphan
//      bytes per image-delete-then-save cycle (cost leak).
//
// This file covers both directions through the persistence-manager save
// path; the no-op-on-empty-queue case is already covered at unit level in
// test/unit/viewmodels/recipe_form/recipe_image_deletion_undo_test.dart.

import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_collaborative_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_image_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_permission_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_persistence_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _MockRecipeFormState extends Mock implements RecipeFormState {}

class _MockRecipeImageManager extends Mock implements RecipeImageManager {}

class _MockRecipeCollaborativeManager extends Mock
    implements RecipeCollaborativeManager {}

class _MockRecipePermissionManager extends Mock
    implements RecipePermissionManager {}

class _MockPersonalRecipeOperations extends Mock
    implements PersonalRecipeOperations {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(RecipeFactory.build());
  });

  late _MockRecipeFormState mockState;
  late _MockRecipeImageManager mockImageManager;
  late _MockRecipeCollaborativeManager mockCollabManager;
  late _MockRecipePermissionManager mockPermissionManager;
  late MockUnifiedRecipeService mockRecipeService;
  late _MockPersonalRecipeOperations mockPersonalOps;
  late RecipePersistenceManager manager;

  setUp(() {
    mockState = _MockRecipeFormState();
    mockImageManager = _MockRecipeImageManager();
    mockCollabManager = _MockRecipeCollaborativeManager();
    mockPermissionManager = _MockRecipePermissionManager();
    mockRecipeService = MockUnifiedRecipeService();
    mockPersonalOps = _MockPersonalRecipeOperations();

    mockRecipeService.setRecipeState(
      isInitialized: true,
      personalOperations: mockPersonalOps,
    );

    // Pre-save guards (lines 103-122 in recipe_persistence_manager.dart).
    when(() => mockState.isAutoSaving).thenReturn(false);
    when(() => mockState.isValid).thenReturn(true);
    when(() => mockPermissionManager.canEdit).thenReturn(true);

    // Save-flow state mutators that always fire.
    when(() => mockState.setSaving(any())).thenAnswer((_) {});
    when(() => mockState.setError(any())).thenAnswer((_) {});
    when(() => mockState.clearError()).thenAnswer((_) {});
    when(() => mockState.clearCurrentDraft()).thenAnswer((_) async {});

    // Create-new-recipe branch (isEditing = false → uuid-generated id).
    when(() => mockState.isEditing).thenReturn(false);
    when(() => mockState.createRecipe(
          recipeId: any(named: 'recipeId'),
          imageUrls: any(named: 'imageUrls'),
          thumbnailUrl: any(named: 'thumbnailUrl'),
        )).thenAnswer((invocation) {
      final id = invocation.namedArguments[#recipeId] as String;
      return RecipeFactory.build(id: id, title: 'BUT-1033 fixture');
    });

    // Image manager: nothing pending, no images, no thumbnail. The save
    // path skips the upload block and lands straight on the
    // commitPendingStorageDeletes line.
    when(() => mockImageManager.setActualRecipeId(any())).thenAnswer((_) {});
    when(() => mockImageManager.pendingImages).thenReturn(const []);
    when(() => mockImageManager.validImageUrls).thenReturn(const []);
    when(() => mockImageManager.firstThumbnailUrl).thenReturn(null);
    when(() => mockImageManager.commitPendingStorageDeletes())
        .thenAnswer((_) async {});

    manager = RecipePersistenceManager(
      recipeService: mockRecipeService,
      state: mockState,
      imageManager: mockImageManager,
      collaborativeManager: mockCollabManager,
      permissionManager: mockPermissionManager,
    );
  });

  group('saveRecipe → commitPendingStorageDeletes (BUT-1033 / BUT-932)', () {
    test('success: commits pending Storage deletes after recipe write',
        () async {
      when(() => mockPersonalOps.addUnifiedRecipe(any())).thenAnswer(
          (_) async => RecipeOperationResult.success('Recipe saved'));

      final result = await manager.saveRecipe(
        isCollaborative: false,
        onNotify: () {},
      );

      expect(result, isNotNull,
          reason: 'happy-path save should return the saved recipe');
      verify(() => mockImageManager.commitPendingStorageDeletes()).called(1);
    });

    test('failure: does NOT commit deletes when recipe write fails', () async {
      // addUnifiedRecipe returns failure → recipe_persistence_manager
      // throws inside safeExecute, which catches and returns null. Line 229
      // (commit) is *past* the throw site, so it must never run — otherwise
      // the user loses Storage bytes they didn't intend to delete.
      when(() => mockPersonalOps.addUnifiedRecipe(any())).thenAnswer(
          (_) async =>
              RecipeOperationResult.failure('simulated firestore error'));

      final result = await manager.saveRecipe(
        isCollaborative: false,
        onNotify: () {},
      );

      expect(result, isNull, reason: 'failed save returns null');
      verifyNever(() => mockImageManager.commitPendingStorageDeletes());
    });
  });
}
