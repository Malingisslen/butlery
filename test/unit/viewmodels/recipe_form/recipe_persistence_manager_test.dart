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

import 'dart:async';
import 'dart:io';

import 'package:butlery/models/recipe_unified.dart';
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
    when(
      () => mockState.createRecipe(
        recipeId: any(named: 'recipeId'),
        imageUrls: any(named: 'imageUrls'),
        thumbnailUrl: any(named: 'thumbnailUrl'),
      ),
    ).thenAnswer((invocation) {
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
    when(
      () => mockImageManager.commitPendingStorageDeletes(),
    ).thenAnswer((_) async {});

    manager = RecipePersistenceManager(
      recipeService: mockRecipeService,
      state: mockState,
      imageManager: mockImageManager,
      collaborativeManager: mockCollabManager,
      permissionManager: mockPermissionManager,
    );
  });

  group('saveRecipe → commitPendingStorageDeletes (BUT-1033 / BUT-932)', () {
    test(
      'success: commits pending Storage deletes after recipe write',
      () async {
        when(() => mockPersonalOps.addUnifiedRecipe(any())).thenAnswer(
          (_) async => RecipeOperationResult.success('Recipe saved'),
        );

        final result = await manager.saveRecipe(
          isCollaborative: false,
          onNotify: () {},
        );

        expect(
          result,
          isNotNull,
          reason: 'happy-path save should return the saved recipe',
        );
        verify(() => mockImageManager.commitPendingStorageDeletes()).called(1);
      },
    );

    test('failure: does NOT commit deletes when recipe write fails', () async {
      // addUnifiedRecipe returns failure → recipe_persistence_manager
      // throws inside safeExecute, which catches and returns null. Line 229
      // (commit) is *past* the throw site, so it must never run — otherwise
      // the user loses Storage bytes they didn't intend to delete.
      when(() => mockPersonalOps.addUnifiedRecipe(any())).thenAnswer(
        (_) async => RecipeOperationResult.failure('simulated firestore error'),
      );

      final result = await manager.saveRecipe(
        isCollaborative: false,
        onNotify: () {},
      );

      expect(result, isNull, reason: 'failed save returns null');
      verifyNever(() => mockImageManager.commitPendingStorageDeletes());
    });
  });

  // BUT-1667. Intent: a save that is still uploading images when the form is
  // disposed must not write a recipe with the user's ingredients stripped.
  //
  // RecipeFormState.dispose() tears down the three FormFieldsManagers, and
  // FormFieldsManager.dispose() clears the field VALUES, not just the
  // controllers. So a save resuming after its image upload would build a
  // recipe with empty ingredient/instruction lists and overwrite the stored
  // one. The `if (_disposed)` bail-outs in saveRecipe exist for exactly this,
  // but were dead until RecipeFormViewModel.dispose() started disposing the
  // persistence manager.
  group('dispose during an in-flight save (BUT-1667)', () {
    test('a save disposed mid-upload writes nothing', () async {
      final uploadGate = Completer<void>();
      var pending = <File>[File('pending.jpg')];

      when(() => mockImageManager.pendingImages).thenAnswer((_) => pending);
      when(
        () => mockImageManager.uploadPendingImagesInBackground(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async {
        await uploadGate.future;
        pending = <File>[];
        return const <String>[];
      });
      when(() => mockPersonalOps.addUnifiedRecipe(any())).thenAnswer(
        (_) async => RecipeOperationResult.success('Recipe saved'),
      );

      final saving = manager.saveRecipe(
        isCollaborative: false,
        onNotify: () {},
      );
      // Let the save reach the upload await.
      await Future<void>.delayed(Duration.zero);

      // The user pops the edit route while the upload is still running.
      manager.dispose();
      uploadGate.complete();

      expect(await saving, isNull);
      // Control: the save must have got PAST the top-of-method disposal guard
      // and actually reached the upload. Without this the test also passes when
      // the save bails at the first `if (_disposed)` — a different branch than
      // the post-upload one this test exists to pin.
      verify(
        () => mockImageManager.uploadPendingImagesInBackground(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      // Neither the recipe build nor the write may happen — building from a
      // disposed state is what produced the empty recipe.
      verifyNever(
        () => mockState.createRecipe(
          recipeId: any(named: 'recipeId'),
          imageUrls: any(named: 'imageUrls'),
          thumbnailUrl: any(named: 'thumbnailUrl'),
        ),
      );
      verifyNever(() => mockPersonalOps.addUnifiedRecipe(any()));
      verifyNever(() => mockPersonalOps.updateUnifiedRecipe(any()));
    });
  });

  // BUT-1669 AC2. Two saves overlap when the user double-taps "Spara", or taps
  // it while an auto-save-triggered manual save is still writing. The second
  // call parks on its own Completer, which the in-flight save settles.
  //
  // The pre-fix code polled `_isSaveInProgress` every 100 ms, then completed
  // the same completer a SECOND time (StateError out of saveRecipe), and on the
  // disposed exit handed back a `_lastSaveResult` field holding a PREVIOUS
  // save's recipe — so the UI reported success for a save that never ran.
  group('overlapping saves (BUT-1669)', () {
    // Parks the recipe write on [gate] so a second saveRecipe call arrives
    // while the first is still in flight.
    Completer<RecipeOperationResult> gateTheWrite() {
      final gate = Completer<RecipeOperationResult>();
      when(
        () => mockPersonalOps.addUnifiedRecipe(any()),
      ).thenAnswer((_) => gate.future);
      return gate;
    }

    test(
      'the queued save returns the in-flight save result, and neither throws',
      () async {
        // A completed save first, so a stale-result regression has something
        // wrong to hand back instead of the recipe the queued call waited for.
        when(() => mockPersonalOps.addUnifiedRecipe(any())).thenAnswer(
          (_) async => RecipeOperationResult.success('Recipe saved'),
        );
        final previous = await manager.saveRecipe(
          isCollaborative: false,
          onNotify: () {},
        );
        expect(previous, isNotNull);

        final gate = gateTheWrite();

        // saveRecipe runs synchronously up to the gated write, so the flag is
        // already set when the second call lands; the yields only make that
        // explicit.
        final inFlight = manager.saveRecipe(
          isCollaborative: false,
          onNotify: () {},
        );
        await Future<void>.delayed(Duration.zero);
        final queued = manager.saveRecipe(
          isCollaborative: false,
          onNotify: () {},
        );
        await Future<void>.delayed(Duration.zero);

        gate.complete(RecipeOperationResult.success('Recipe saved'));

        // Both must SETTLE. Re-inserting `completer.complete(result)` after the
        // `await completer.future` completes the completer twice, which throws
        // StateError('Future already completed') out of the queued call.
        await expectLater(inFlight, completes);
        await expectLater(queued, completes);

        final inFlightResult = await inFlight;
        final queuedResult = await queued;

        // The queued caller gets the recipe the save it waited on produced…
        expect(queuedResult, same(inFlightResult));
        // …and provably not the earlier cycle's recipe.
        expect(queuedResult!.id, isNot(previous!.id));

        // The domain invariant behind AC2: a double-tap on "Spara" must leave
        // ONE new recipe in the cookbook, and the id both callers hand back to
        // the UI must be the id that was actually persisted — the detail route
        // the form pushes on success is keyed on it.
        final written = verify(
          () => mockPersonalOps.addUnifiedRecipe(captureAny()),
        ).captured.cast<Recipe>();
        expect(
          written.map((r) => r.id),
          [previous.id, queuedResult.id],
          reason: 'the overlapping pair wrote exactly one recipe, not two',
        );
      },
    );

    test(
      'a save queued behind an in-flight one resolves to null on dispose',
      () async {
        // Same stale-result trap: a previous successful save exists, so "null"
        // is provably the dispose answer rather than an empty fixture.
        when(() => mockPersonalOps.addUnifiedRecipe(any())).thenAnswer(
          (_) async => RecipeOperationResult.success('Recipe saved'),
        );
        final previous = await manager.saveRecipe(
          isCollaborative: false,
          onNotify: () {},
        );
        expect(previous, isNotNull);

        final gate = gateTheWrite();

        final inFlight = manager.saveRecipe(
          isCollaborative: false,
          onNotify: () {},
        );
        await Future<void>.delayed(Duration.zero);
        final queued = manager.saveRecipe(
          isCollaborative: false,
          onNotify: () {},
        );
        await Future<void>.delayed(Duration.zero);

        // The user pops the form while the first save is still writing.
        manager.dispose();

        // Must settle rather than hang: dispose() settles every queued waiter.
        // Dropping the map without completing it strands this caller forever and
        // the test times out.
        final queuedResult = await queued;

        // null is the honest answer — this save never ran. Reporting `previous`
        // here is the shipped-success-for-nothing bug the deleted _lastSaveResult
        // field caused.
        expect(queuedResult, isNull);
        expect(queuedResult, isNot(same(previous)));

        gate.complete(RecipeOperationResult.success('Recipe saved'));
        await inFlight;
      },
    );
  });
}
