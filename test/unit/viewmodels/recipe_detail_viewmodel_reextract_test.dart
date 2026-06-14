/// BUT-1300: unit tests for [RecipeDetailViewModel.reextractFromSource].
///
/// The production method constructed `UrlImportStrategy()` / `TextImportStrategy()`
/// inline, so it could not be exercised without hitting real network/parsing and
/// had zero coverage. BUT-1300 added a [ReextractStrategyFactory] seam; these
/// tests drive a fake strategy through it to prove the documented contract:
///   * strategy selection (url → url strategy; everything else → text strategy),
///   * identity preservation on success (id/createdAt unchanged, original
///     sourceArtefact re-attached),
///   * parsed-field overwrite from the re-extraction,
///   * all three failure paths leave the in-memory recipe untouched.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';

/// A scripted [ImportStrategy]: records the input it was asked to import and
/// returns a canned [ImportResult]. Either succeeds with [_result]'s recipe,
/// fails, returns a null recipe, or throws — covering every branch the
/// re-extract method inspects. Only [import] is meaningful; the other
/// interface members are unused by the VM.
class _ScriptedStrategy implements ImportStrategy {
  _ScriptedStrategy.success(Recipe recipe)
      : _result = ImportResult.success(recipe),
        _throws = false;
  _ScriptedStrategy.failure()
      : _result = ImportResult.failure('nope'),
        _throws = false;
  _ScriptedStrategy.nullRecipe()
      // A "success" flag with a null recipe — the second failure branch the
      // method guards (`!result.isSuccess || extracted == null`).
      : _result = ImportResult.success(null),
        _throws = false;
  _ScriptedStrategy.throwing()
      : _result = ImportResult.failure('unused'),
        _throws = true;

  final ImportResult _result;
  final bool _throws;
  String? capturedInput;

  @override
  Future<ImportResult> import(String input,
      {Map<String, dynamic>? options}) async {
    capturedInput = input;
    if (_throws) throw Exception('import blew up');
    return _result;
  }

  @override
  bool canHandle(String input) => true;
  @override
  bool validateInput(String input) => true;
  @override
  String get strategyName => 'scripted';
  @override
  String get inputExample => '';
  @override
  String get description => '';
}

/// Pure mocktail mock so `updateRecipe` / `getRecipeById` / `stateStream` are
/// all stubbable. The shared [MockUnifiedRecipeService] hardcodes
/// `updateRecipe → true` (a concrete override mocktail can't intercept), so the
/// persistence branches — and capturing the persisted recipe — need this.
class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

void main() {
  group('RecipeDetailViewModel.reextractFromSource (BUT-1300)', () {
    late _MockUnifiedRecipeService recipeService;
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
    });

    setUp(() async {
      await TestServiceLocator.reset();
      await TestServiceLocator.initialize();

      recipeService = _MockUnifiedRecipeService();
      analyticsService = MockFactory.createAnalyticsService();
      cookingService = MockFactory.createRecipeCookingService();

      // The VM constructor subscribes to stateStream and (on update) calls
      // getRecipeById — keep both inert so only reextract behaviour is tested.
      when(() => recipeService.stateStream)
          .thenAnswer((_) => const Stream.empty());
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

    RecipeDetailViewModel buildViewModel(ReextractStrategyFactory factory) {
      return RecipeDetailViewModel(
        recipe: original,
        recipeService: recipeService,
        analyticsService: analyticsService,
        cookingService: cookingService,
        reextractStrategyFactory: factory,
      );
    }

    // BUT-1300 gap: every test below injects a FAKE factory through the seam,
    // so the PRODUCTION default (the real url-vs-text decision the seam wraps)
    // had no coverage — a regression flipping that condition would ship green.
    // These assert the default mapping directly via the @visibleForTesting hook.
    group('production default strategy factory', () {
      test('url-type artefacts route to UrlImportStrategy', () {
        expect(
          defaultReextractStrategyForTest(SourceArtefactType.url),
          isA<UrlImportStrategy>(),
        );
      });

      test('every non-url artefact type routes to TextImportStrategy', () {
        for (final type in SourceArtefactType.values
            .where((t) => t != SourceArtefactType.url)) {
          expect(
            defaultReextractStrategyForTest(type),
            isA<TextImportStrategy>(),
            reason: 'type=$type must use the text strategy',
          );
        }
      });
    });

    group('strategy selection', () {
      test('url artefact selects the url strategy and feeds it the payload',
          () async {
        when(() => recipeService.updateRecipe(any()))
            .thenAnswer((_) async => true);

        SourceArtefactType? selectedType;
        late _ScriptedStrategy strategy;
        final vm = buildViewModel((type) {
          selectedType = type;
          strategy = _ScriptedStrategy.success(extracted);
          return strategy;
        });
        addTearDown(vm.dispose);

        final artefact = SourceArtefact(
          type: SourceArtefactType.url,
          payload: 'https://example.com/re',
          fetchedAt: DateTime(2024, 6, 1),
        );

        final outcome = await vm.reextractFromSource(artefact);

        expect(outcome, ReextractOutcome.success);
        expect(selectedType, SourceArtefactType.url);
        // The artefact payload IS the extraction input — the URL here.
        expect(strategy.capturedInput, 'https://example.com/re');
      });

      test(
          'every non-url artefact type routes through the text strategy '
          'with the raw payload', () async {
        // The default factory sends url→UrlImportStrategy and EVERYTHING else
        // →TextImportStrategy; this asserts the seam preserves that mapping for
        // each non-url type by checking the type the VM hands the factory and
        // that the raw payload (not a URL) is what gets imported.
        when(() => recipeService.updateRecipe(any()))
            .thenAnswer((_) async => true);

        for (final type in SourceArtefactType.values
            .where((t) => t != SourceArtefactType.url)) {
          SourceArtefactType? selectedType;
          late _ScriptedStrategy strategy;
          final vm = buildViewModel((t) {
            selectedType = t;
            strategy = _ScriptedStrategy.success(extracted);
            return strategy;
          });

          final artefact = SourceArtefact(
            type: type,
            payload: 'raw transcript/caption/OCR text for $type',
            fetchedAt: DateTime(2024, 6, 1),
          );

          final outcome = await vm.reextractFromSource(artefact);

          expect(outcome, ReextractOutcome.success, reason: 'type=$type');
          expect(selectedType, type, reason: 'type=$type');
          expect(strategy.capturedInput,
              'raw transcript/caption/OCR text for $type',
              reason: 'type=$type');
          vm.dispose();
        }
      });
    });

    group('success path', () {
      test('preserves id + createdAt and re-attaches the ORIGINAL artefact',
          () async {
        Recipe? persisted;
        when(() => recipeService.updateRecipe(any())).thenAnswer((inv) async {
          persisted = inv.positionalArguments.first as Recipe;
          return true;
        });

        final vm = buildViewModel(
          (_) => _ScriptedStrategy.success(extracted),
        );
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
      });

      test('overwrites all parsed fields from the re-extraction', () async {
        Recipe? persisted;
        when(() => recipeService.updateRecipe(any())).thenAnswer((inv) async {
          persisted = inv.positionalArguments.first as Recipe;
          return true;
        });

        final vm = buildViewModel(
          (_) => _ScriptedStrategy.success(extracted),
        );
        addTearDown(vm.dispose);

        await vm.reextractFromSource(originalArtefact);

        expect(persisted, isNotNull);
        expect(persisted!.title, 'Re-extracted Title');
        expect(persisted!.description, 'Re-extracted description');
        expect(persisted!.ingredients, ['500 g extracted']);
        expect(persisted!.core.structuredIngredients, isNotNull);
        expect(persisted!.core.structuredIngredients!.single.raw,
            '500 g extracted');
        expect(persisted!.instructions, ['Do the re-extracted thing']);
        expect(persisted!.portions, 6);
        expect(persisted!.timeMinutes, 99);
        expect(persisted!.imageUrls, ['extracted-1.jpg', 'extracted-2.jpg']);
      });
    });

    group('failure paths leave the recipe untouched', () {
      test('import throwing → failure, in-memory recipe unchanged', () async {
        final vm = buildViewModel((_) => _ScriptedStrategy.throwing());
        addTearDown(vm.dispose);

        final outcome = await vm.reextractFromSource(originalArtefact);

        expect(outcome, ReextractOutcome.failure);
        expect(vm.recipe, original);
        // Never reached persistence.
        verifyNever(() => recipeService.updateRecipe(any()));
      });

      test('import returning failure/null recipe → failure, recipe unchanged',
          () async {
        for (final strategy in [
          _ScriptedStrategy.failure(),
          _ScriptedStrategy.nullRecipe(),
        ]) {
          final vm = buildViewModel((_) => strategy);

          final outcome = await vm.reextractFromSource(originalArtefact);

          expect(outcome, ReextractOutcome.failure);
          expect(vm.recipe, original);
          vm.dispose();
        }
        verifyNever(() => recipeService.updateRecipe(any()));
      });

      test('updateRecipe returning false → failure, recipe unchanged',
          () async {
        when(() => recipeService.updateRecipe(any()))
            .thenAnswer((_) async => false);

        final vm = buildViewModel(
          (_) => _ScriptedStrategy.success(extracted),
        );
        addTearDown(vm.dispose);

        final outcome = await vm.reextractFromSource(originalArtefact);

        expect(outcome, ReextractOutcome.failure);
        // The optimistic in-memory update only runs AFTER a successful persist.
        expect(vm.recipe, original);
      });

      test('updateRecipe throwing → failure, recipe unchanged', () async {
        when(() => recipeService.updateRecipe(any()))
            .thenThrow(Exception('write rejected'));

        final vm = buildViewModel(
          (_) => _ScriptedStrategy.success(extracted),
        );
        addTearDown(vm.dispose);

        final outcome = await vm.reextractFromSource(originalArtefact);

        expect(outcome, ReextractOutcome.failure);
        expect(vm.recipe, original);
      });
    });
  });
}
