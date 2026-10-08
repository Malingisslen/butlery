/// BUT-1300: unit tests for [RecipeDetailViewModel.reextractFromSource].
///
/// BUT-2279: the re-extract goes through [ImportManager.reimportFromArtefact],
/// which picks the strategy (tested beside the manager), so these drive a
/// mocked manager to prove the view model's own contract:
///   * the ORIGINAL artefact is what the manager is asked to re-read,
///   * identity preservation on success (id/createdAt unchanged, original
///     sourceArtefact re-attached),
///   * parsed-field overwrite from the re-extraction,
///   * every failure path leaves the in-memory recipe untouched.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/services/import/import_manager_result.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';

/// Pure mocktail mock so `updateRecipe` / `getRecipeById` / `stateStream` are
/// all stubbable. The shared [MockUnifiedRecipeService] hardcodes
/// `updateRecipe → true` (a concrete override mocktail can't intercept), so the
/// persistence branches — and capturing the persisted recipe — need this.
class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

void main() {
  group('RecipeDetailViewModel.reextractFromSource (BUT-1300)', () {
    late _MockUnifiedRecipeService recipeService;
    late MockImportManager importManager;
    late MockAnalyticsService analyticsService;
    late MockRecipeCookingService cookingService;
    late Recipe original;

    // The re-extraction output — deliberately different in every parsed field
    // so "overwrite" is observable, but with a DIFFERENT id/createdAt and a
    // DIFFERENT sourceArtefact to prove those are NOT what gets persisted.
    late Recipe extracted;

    const originalId = 'recipe-original';
    final originalCreatedAt = DateTime(2024, 1, 1, 8, 0);

    final originalArtefact = SourceArtefact(
      type: SourceArtefactType.url,
      payload: 'https://example.com/original',
      fetchedAt: DateTime(2024, 1, 1, 7, 0),
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(originalArtefact);
    });

    setUp(() async {
      await TestServiceLocator.reset();
      await TestServiceLocator.initialize();

      recipeService = _MockUnifiedRecipeService();
      importManager = MockImportManager();
      analyticsService = MockFactory.createAnalyticsService();
      cookingService = MockFactory.createRecipeCookingService();

      // The VM constructor subscribes to stateStream and (on update) calls
      // getRecipeById — keep both inert so only reextract behaviour is tested.
      when(
        () => recipeService.stateStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => recipeService.getRecipeById(any())).thenReturn(null);

      original = RecipeBuilder()
          .withId(originalId)
          .withTitle('Original Title')
          .withDescription('Original description')
          .withIngredients(['1 dl original'])
          .withInstructions(['Do the original thing'])
          .withPortions(2)
          .withTimeMinutes(15)
          .withImageUrls(['original.jpg'])
          .withCreatedAt(originalCreatedAt)
          .build()
          .copyWith(sourceArtefact: originalArtefact);

      extracted = RecipeBuilder()
          .withId('recipe-DIFFERENT-from-extraction')
          .withTitle('Re-extracted Title')
          .withDescription('Re-extracted description')
          .withIngredients(['500 g extracted'])
          .withInstructions(['Do the re-extracted thing'])
          .withPortions(6)
          .withTimeMinutes(99)
          .withImageUrls(['extracted-1.jpg', 'extracted-2.jpg'])
          .withCreatedAt(DateTime(2099, 12, 31))
          .build()
          .copyWith(
            structuredIngredients: [
              RecipeIngredient.rawOnly('500 g extracted'),
            ],
            // A different artefact on the extraction result — must be ignored;
            // the ORIGINAL artefact is the one that survives.
            sourceArtefact: SourceArtefact(
              type: SourceArtefactType.textPaste,
              payload: 'WRONG payload',
              fetchedAt: DateTime(2099, 1, 1),
            ),
          );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    void reimportAnswers(Future<ImportManagerResult> Function() answer) => when(
      () => importManager.reimportFromArtefact(any()),
    ).thenAnswer((_) => answer());

    RecipeDetailViewModel buildViewModel() {
      return RecipeDetailViewModel(
        recipe: original,
        recipeService: recipeService,
        analyticsService: analyticsService,
        cookingService: cookingService,
        importManager: importManager,
      );
    }

    test('asks the import manager to re-read the original artefact', () async {
      when(
        () => recipeService.updateRecipe(any()),
      ).thenAnswer((_) async => true);
      reimportAnswers(() async => ImportManagerResult.success(extracted));
      final vm = buildViewModel();
      addTearDown(vm.dispose);

      final outcome = await vm.reextractFromSource(originalArtefact);

      expect(outcome, ReextractOutcome.success);
      verify(
        () => importManager.reimportFromArtefact(originalArtefact),
      ).called(1);
    });

    group('success path', () {
      test(
        'preserves id + createdAt and re-attaches the ORIGINAL artefact',
        () async {
          Recipe? persisted;
          when(() => recipeService.updateRecipe(any())).thenAnswer((inv) async {
            persisted = inv.positionalArguments.first as Recipe;
            return true;
          });

          reimportAnswers(() async => ImportManagerResult.success(extracted));
          final vm = buildViewModel();
          addTearDown(vm.dispose);

          final outcome = await vm.reextractFromSource(originalArtefact);

          expect(outcome, ReextractOutcome.success);
          // copyWith never overwrites id/createdAt — identity survives a re-extract.
          expect(persisted, isNotNull);
          expect(persisted!.id, originalId);
          expect(persisted!.createdAt, originalCreatedAt);
          // The ORIGINAL artefact is re-passed (not the extraction's artefact),
          // so capture metadata / comments / history stay attached.
          expect(persisted!.core.sourceArtefact, originalArtefact);
          // The VM's in-memory recipe is updated to the persisted version.
          expect(vm.recipe.id, originalId);
          expect(vm.recipe.title, 'Re-extracted Title');
        },
      );

      test('overwrites all parsed fields from the re-extraction', () async {
        Recipe? persisted;
        when(() => recipeService.updateRecipe(any())).thenAnswer((inv) async {
          persisted = inv.positionalArguments.first as Recipe;
          return true;
        });

        reimportAnswers(() async => ImportManagerResult.success(extracted));
        final vm = buildViewModel();
        addTearDown(vm.dispose);

        await vm.reextractFromSource(originalArtefact);

        expect(persisted, isNotNull);
        expect(persisted!.title, 'Re-extracted Title');
        expect(persisted!.description, 'Re-extracted description');
        expect(persisted!.ingredients, ['500 g extracted']);
        expect(persisted!.core.structuredIngredients, isNotNull);
        expect(
          persisted!.core.structuredIngredients!.single.raw,
          '500 g extracted',
        );
        expect(persisted!.instructions, ['Do the re-extracted thing']);
        expect(persisted!.portions, 6);
        expect(persisted!.timeMinutes, 99);
        expect(persisted!.imageUrls, ['extracted-1.jpg', 'extracted-2.jpg']);
      });
    });

    group('failure paths leave the recipe untouched', () {
      test('import throwing → failure, in-memory recipe unchanged', () async {
        reimportAnswers(() async => throw Exception('import blew up'));
        final vm = buildViewModel();
        addTearDown(vm.dispose);

        final outcome = await vm.reextractFromSource(originalArtefact);

        expect(outcome, ReextractOutcome.failure);
        expect(vm.recipe, original);
        // Never reached persistence.
        verifyNever(() => recipeService.updateRecipe(any()));
      });

      test(
        'import returning failure/null recipe → failure, recipe unchanged',
        () async {
          for (final result in [
            ImportManagerResult.failure('nope'),
            // A "success" flag with a null recipe — the second failure branch
            // the method guards.
            ImportManagerResult.success(null),
          ]) {
            reimportAnswers(() async => result);
            final vm = buildViewModel();

            final outcome = await vm.reextractFromSource(originalArtefact);

            expect(outcome, ReextractOutcome.failure);
            expect(vm.recipe, original);
            vm.dispose();
          }
          verifyNever(() => recipeService.updateRecipe(any()));
        },
      );

      test('updateRecipe returning false → failure, recipe unchanged', () async {
        when(
          () => recipeService.updateRecipe(any()),
        ).thenAnswer((_) async => false);

        reimportAnswers(() async => ImportManagerResult.success(extracted));
        final vm = buildViewModel();
        addTearDown(vm.dispose);

        final outcome = await vm.reextractFromSource(originalArtefact);

        expect(outcome, ReextractOutcome.failure);
        // The optimistic in-memory update only runs AFTER a successful persist.
        expect(vm.recipe, original);
      });

      test('updateRecipe throwing → failure, recipe unchanged', () async {
        when(
          () => recipeService.updateRecipe(any()),
        ).thenThrow(Exception('write rejected'));

        reimportAnswers(() async => ImportManagerResult.success(extracted));
        final vm = buildViewModel();
        addTearDown(vm.dispose);

        final outcome = await vm.reextractFromSource(originalArtefact);

        expect(outcome, ReextractOutcome.failure);
        expect(vm.recipe, original);
      });
    });
  });
}
