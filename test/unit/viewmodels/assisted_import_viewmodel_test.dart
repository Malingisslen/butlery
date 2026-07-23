/// IMP-10: Unit tests for AssistedImportViewModel.
///
/// What this file proves (one bullet per group):
///
/// 1) **Step gating** — `nextStep` does NOT advance when `canProceed` is
///    false; it DOES advance when the gate condition is met. The three-step
///    sequence is enforced end-to-end.
///
/// 2) **previousStep navigation** — rewinds to the correct prior step at each
///    position; is a no-op at step 1 (already at the start).
///
/// 3) **Selection management** — `setIngredientSelection` / `setInstructionSelection`
///    update the respective sets and notify listeners. `selectAllHighlightedIngredients`
///    copies the pre-detected set into the user selection.
///
/// 4) **buildRecipe** — assembles a Recipe from the selections made during the
///    wizard; numbering prefixes on instructions are stripped; empty strings
///    are excluded from both lists.
///
/// 5) **validateCurrentStep** — returns a non-null string for each violation
///    (no ingredient selected, no instruction selected, no title on review step)
///    and null when the step's gate condition is met.
///
/// 6) **Editable list mutations** — add / update / remove work in bounds and
///    are silently ignored out of bounds.
///
/// The VM is pure synchronous logic with no Firebase or service dependencies.
/// No locator setup, no async test infrastructure.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/services/parsing/feedback/import_correction_snapshot.dart';
import 'package:butlery/viewmodels/assisted_import_viewmodel.dart';

void main() {
  // Shared fixture text. Indices (0-based after trim+split):
  //   0: "200 g kycklingfilé"   → ingredient (measurement keyword)
  //   1: "2 msk olivolja"       → ingredient
  //   2: ""                     → blank (skipped)
  //   3: "Steg 1. Stekpanna het" → instruction candidate
  //   4: "Steg 2. Tillsätt kyckling och stek" → instruction candidate
  const extractedText = '''200 g kycklingfilé
2 msk olivolja

Steg 1. Stekpanna het
Steg 2. Tillsätt kyckling och stek''';

  // ---------------------------------------------------------------------------
  // Step gating
  // ---------------------------------------------------------------------------
  group('Step gating', () {
    test('starts at step 1 (selectIngredients)', () {
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);

      expect(vm.currentStep, equals(AssistedImportStep.selectIngredients));
      expect(vm.stepNumber, equals(1));
      expect(vm.totalSteps, equals(3));
    });

    test('nextStep does not advance when no ingredients are selected', () {
      // Proves the gate: an empty selection must block progression to step 2.
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);

      expect(vm.canProceed, isFalse);
      vm.nextStep();

      expect(vm.currentStep, equals(AssistedImportStep.selectIngredients));
    });

    test('nextStep advances to step 2 once ingredients are selected', () {
      // Proves the gate opens when the user picks at least one ingredient line.
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);

      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setIngredientSelection({0});
      expect(vm.canProceed, isTrue);

      vm.nextStep();

      expect(vm.currentStep, equals(AssistedImportStep.selectInstructions));
      expect(vm.stepNumber, equals(2));
      expect(notifications, greaterThanOrEqualTo(1));
    });

    test(
      'nextStep does not advance from step 2 when no instructions selected',
      () {
        // Proves the second gate mirrors the first.
        final vm = AssistedImportViewModel(extractedText: extractedText);
        addTearDown(vm.dispose);
        vm.setIngredientSelection({0});
        vm.nextStep(); // → step 2

        expect(vm.canProceed, isFalse);
        vm.nextStep();

        expect(vm.currentStep, equals(AssistedImportStep.selectInstructions));
      },
    );

    test('nextStep advances to step 3 once instructions are selected', () {
      // Proves the full 3-step advancement sequence.
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);
      vm.setIngredientSelection({0});
      vm.nextStep(); // → step 2
      vm.setInstructionSelection({3, 4});

      vm.nextStep(); // → step 3

      expect(vm.currentStep, equals(AssistedImportStep.reviewEdit));
      expect(vm.stepNumber, equals(3));
    });

    test('nextStep on step 3 (reviewEdit) is a no-op', () {
      // Proves step 3 has no "step 4" — the caller must submit via buildRecipe.
      final vm = AssistedImportViewModel(
        extractedText: extractedText,
        suggestedTitle: 'Kycklingrätt',
      );
      addTearDown(vm.dispose);
      vm.setIngredientSelection({0});
      vm.nextStep();
      vm.setInstructionSelection({3});
      vm.nextStep(); // → step 3 (title pre-filled from suggestedTitle)

      vm.nextStep(); // should be no-op

      expect(vm.currentStep, equals(AssistedImportStep.reviewEdit));
    });
  });

  // ---------------------------------------------------------------------------
  // previousStep navigation
  // ---------------------------------------------------------------------------
  group('previousStep navigation', () {
    test('previousStep from step 2 goes back to step 1', () {
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);
      vm.setIngredientSelection({0});
      vm.nextStep(); // → step 2

      var notifications = 0;
      vm.addListener(() => notifications++);
      vm.previousStep();

      expect(vm.currentStep, equals(AssistedImportStep.selectIngredients));
      expect(notifications, greaterThanOrEqualTo(1));
    });

    test('previousStep from step 3 goes back to step 2', () {
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);
      vm.setIngredientSelection({0});
      vm.nextStep();
      vm.setInstructionSelection({3});
      vm.nextStep(); // → step 3

      vm.previousStep();

      expect(vm.currentStep, equals(AssistedImportStep.selectInstructions));
    });

    test('previousStep on step 1 is a no-op', () {
      // Proves the back-navigation guard at the wizard boundary.
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);

      expect(vm.canGoBack, isFalse);
      vm.previousStep();

      expect(vm.currentStep, equals(AssistedImportStep.selectIngredients));
    });
  });

  // ---------------------------------------------------------------------------
  // Selection management
  // ---------------------------------------------------------------------------
  group('Selection management', () {
    test('setIngredientSelection updates indices and notifies', () {
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);

      var notifications = 0;
      vm.addListener(() => notifications++);
      vm.setIngredientSelection({0, 1});

      expect(vm.selectedIngredientIndices, equals({0, 1}));
      expect(notifications, greaterThanOrEqualTo(1));
    });

    test('setInstructionSelection updates indices and notifies', () {
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);

      vm.setInstructionSelection({3, 4});

      expect(vm.selectedInstructionIndices, equals({3, 4}));
    });

    test('selectAllHighlightedIngredients copies the pre-detected set', () {
      // Proves the "select all suggested" shortcut works.
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);

      // Pre-detection ran in constructor; likelyIngredientIndices is non-empty
      // for lines that match Swedish measurement patterns ("g", "msk").
      expect(vm.likelyIngredientIndices, isNotEmpty);

      vm.selectAllHighlightedIngredients();

      expect(
        vm.selectedIngredientIndices,
        equals(vm.likelyIngredientIndices),
      );
    });

    test('hasSelections is true once any index is chosen', () {
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);

      expect(vm.hasSelections, isFalse);
      vm.setIngredientSelection({0});
      expect(vm.hasSelections, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // buildRecipe
  // ---------------------------------------------------------------------------
  group('buildRecipe', () {
    AssistedImportViewModel advanceToReview({
      String title = 'Kycklingrätt',
      Set<int> ingredients = const {0, 1},
      Set<int> instructions = const {3, 4},
    }) {
      final vm = AssistedImportViewModel(
        extractedText: extractedText,
        suggestedTitle: title,
        sourceUrl: 'https://example.se/recept',
        thumbnailUrl: 'https://example.se/thumb.jpg',
      );
      vm.setIngredientSelection(ingredients);
      vm.nextStep();
      vm.setInstructionSelection(instructions);
      vm.nextStep(); // → reviewEdit, _buildEditableLists called here
      return vm;
    }

    test(
      'assembles recipe title, ingredients and instructions from selections',
      () {
        // Proves the core output of the wizard: the built recipe must carry the
        // lines the user selected.
        final vm = advanceToReview();
        addTearDown(vm.dispose);

        final recipe = vm.buildRecipe();

        expect(recipe.title, equals('Kycklingrätt'));
        expect(recipe.ingredients, hasLength(2));
        expect(recipe.ingredients.first, equals('200 g kycklingfilé'));
        expect(recipe.instructions, isNotEmpty);
      },
    );

    test('strips leading "Steg N." prefix from instruction lines', () {
      // Proves the _cleanInstructionLine normalization step. "Steg 1. Stekpanna het"
      // must become "Stekpanna het" so the recipe shows clean steps.
      final vm = advanceToReview(instructions: {3});
      addTearDown(vm.dispose);

      final recipe = vm.buildRecipe();

      expect(recipe.instructions.first, equals('Stekpanna het'));
    });

    test('includes sourceUrl and thumbnailUrl in the built recipe', () {
      // Proves provenance fields are wired through (not accidentally dropped).
      final vm = advanceToReview();
      addTearDown(vm.dispose);

      final recipe = vm.buildRecipe();

      expect(recipe.sourceUrl, equals('https://example.se/recept'));
      expect(recipe.imageUrls, contains('https://example.se/thumb.jpg'));
    });

    test('excludes empty strings from ingredients and instructions', () {
      // Proves the empty-filter guard: a user who deletes all text in a line
      // must not produce a recipe with blank ingredients.
      final vm = advanceToReview(ingredients: {0, 1}, instructions: {3});
      addTearDown(vm.dispose);
      vm.updateIngredient(0, '   '); // blank out line 0
      vm.updateIngredient(1, 'olivolja'); // keep line 1

      final recipe = vm.buildRecipe();

      expect(recipe.ingredients, equals(['olivolja']));
    });

    test('respects setPortions and setTimeMinutes clamping', () {
      // Proves the boundary clamps so UI sliders can never persist illegal values.
      final vm = advanceToReview();
      addTearDown(vm.dispose);

      vm.setPortions(0); // below min → clamped to 1
      vm.setTimeMinutes(-5); // below 0 → clamped to 0

      expect(vm.portions, equals(1));
      expect(vm.timeMinutes, equals(0));

      vm.setPortions(200); // above max 100
      vm.setTimeMinutes(9999); // above max 1440 (24h)

      expect(vm.portions, equals(100));
      expect(vm.timeMinutes, equals(1440));
    });
  });

  // ---------------------------------------------------------------------------
  // validateCurrentStep
  // ---------------------------------------------------------------------------
  group('validateCurrentStep', () {
    test('returns non-null on step 1 when no ingredients are selected', () {
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);

      expect(vm.validateCurrentStep(), isNotNull);
    });

    test('returns null on step 1 when at least one ingredient is selected', () {
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);
      vm.setIngredientSelection({0});

      expect(vm.validateCurrentStep(), isNull);
    });

    test('returns non-null on step 2 when no instructions are selected', () {
      final vm = AssistedImportViewModel(extractedText: extractedText);
      addTearDown(vm.dispose);
      vm.setIngredientSelection({0});
      vm.nextStep(); // → step 2

      expect(vm.validateCurrentStep(), isNotNull);
    });

    test('returns non-null on step 3 when title is empty', () {
      // Proves the review-step title gate.
      final vm = AssistedImportViewModel(
        extractedText: extractedText,
        suggestedTitle: null, // no pre-fill
      );
      addTearDown(vm.dispose);
      vm.setIngredientSelection({0});
      vm.nextStep();
      vm.setInstructionSelection({3});
      vm.nextStep(); // → reviewEdit

      // Title is empty — isValidForSave must be false.
      expect(vm.isValidForSave, isFalse);
      expect(vm.validateCurrentStep(), isNotNull);
    });

    test(
      'returns null on step 3 when title, ingredients and instructions all present',
      () {
        final vm = AssistedImportViewModel(
          extractedText: extractedText,
          suggestedTitle: 'Kycklingrätt',
        );
        addTearDown(vm.dispose);
        vm.setIngredientSelection({0});
        vm.nextStep();
        vm.setInstructionSelection({3});
        vm.nextStep(); // → reviewEdit — editable lists built

        expect(vm.isValidForSave, isTrue);
        expect(vm.validateCurrentStep(), isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Editable list mutations
  // ---------------------------------------------------------------------------
  group('Editable list mutations', () {
    late AssistedImportViewModel vm;

    setUp(() {
      vm = AssistedImportViewModel(
        extractedText: extractedText,
        suggestedTitle: 'Kycklingrätt',
      );
      vm.setIngredientSelection({0, 1});
      vm.nextStep();
      vm.setInstructionSelection({3});
      vm.nextStep(); // → reviewEdit — editable lists built
    });

    tearDown(() => vm.dispose());

    test('addIngredient appends a non-empty trimmed value and notifies', () {
      final before = vm.editedIngredients.length;
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.addIngredient('  salt  ');

      expect(vm.editedIngredients.length, equals(before + 1));
      expect(vm.editedIngredients.last, equals('salt'));
      expect(notifications, greaterThanOrEqualTo(1));
    });

    test('addIngredient ignores a blank string', () {
      final before = vm.editedIngredients.length;
      vm.addIngredient('   ');
      expect(vm.editedIngredients.length, equals(before));
    });

    test('removeIngredient removes the item at valid index', () {
      vm.addIngredient('extra');
      final before = vm.editedIngredients.length;

      vm.removeIngredient(0);

      expect(vm.editedIngredients.length, equals(before - 1));
    });

    test('removeIngredient is a no-op for an out-of-bounds index', () {
      final before = vm.editedIngredients.length;
      vm.removeIngredient(999);
      expect(vm.editedIngredients.length, equals(before));
    });

    test('updateInstruction replaces the text at a valid index', () {
      vm.updateInstruction(0, 'Hetta upp pannan ordentligt');
      expect(vm.editedInstructions[0], equals('Hetta upp pannan ordentligt'));
    });

    test(
      'review-step edits survive a Back→Forward round-trip with unchanged '
      'selections',
      () {
        // Regression (High): nextStep() used to rebuild the editable lists
        // unconditionally on the step 2→3 transition, silently reverting every
        // manual correction the moment the user stepped Back to step 2 and
        // Forward again. The whole purpose of the wizard is manual correction,
        // so those edits must be preserved when the selection did not change.
        vm.addIngredient('salt');
        vm.updateInstruction(0, 'Egen instruktion');

        vm.previousStep(); // → step 2 (no selection change)
        vm.nextStep(); // → step 3

        expect(vm.editedIngredients, contains('salt'));
        expect(vm.editedInstructions, contains('Egen instruktion'));
      },
    );

    test(
      'changing the selection on Back DOES re-derive the editable lists',
      () {
        // The guard must not over-freeze: if the user actually changes which
        // lines are selected, the lists should be rebuilt from the new choice.
        vm.addIngredient('salt');

        vm.previousStep(); // → step 2
        vm.setInstructionSelection({3, 4}); // was {3} — genuine change
        vm.nextStep(); // → step 3 rebuilds

        expect(vm.editedIngredients, isNot(contains('salt')));
        expect(vm.editedInstructions, hasLength(2));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // BUT-1501 correction-snapshot capture on wizard completion
  //
  // `buildRecipe()` must anchor the parser feedback loop the same way every
  // other import path does (BUT-1469): it stores an ImportCorrectionSnapshot in
  // the shared ParsedRecipeCache, keyed by the produced recipe id, tagged with
  // the ORIGIN strategy's ImportSource (BUT-1656 — no longer hardcoded url) and
  // the source domain. These wire a real cache into the production
  // ServiceLocator and read the snapshot back.
  // ---------------------------------------------------------------------------
  group('BUT-1501 correction-snapshot capture on completion', () {
    late ParsedRecipeCache cache;

    setUp(() {
      cache = ParsedRecipeCache();
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(DIContainer());
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ParsedRecipeCache>()) {
        getIt.unregister<ParsedRecipeCache>();
      }
      getIt.registerSingleton<ParsedRecipeCache>(cache);
    });

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ParsedRecipeCache>()) {
        getIt.unregister<ParsedRecipeCache>();
      }
      app_provider.ServiceLocator.reset();
    });

    AssistedImportViewModel advanceToReview({
      String title = 'Kycklingrätt',
      String? sourceUrl = 'https://www.example.se/recept/kyckling',
      ImportSource source = ImportSource.url,
    }) {
      final vm = AssistedImportViewModel(
        extractedText: extractedText,
        suggestedTitle: title,
        sourceUrl: sourceUrl,
        source: source,
      );
      vm.setIngredientSelection({0, 1});
      vm.nextStep();
      vm.setInstructionSelection({3, 4});
      vm.nextStep(); // → reviewEdit
      return vm;
    }

    test(
      'buildRecipe stores a snapshot keyed by recipe id, tagged url + domain '
      'with the snapshot sentinel version',
      () {
        final vm = advanceToReview();
        addTearDown(vm.dispose);

        final recipe = vm.buildRecipe();

        final snapshot = cache.retrieve(recipe.id);
        expect(
          snapshot,
          isNotNull,
          reason: 'assisted-import completion must anchor the feedback loop',
        );
        expect(
          snapshot!.metadata.source,
          ImportSource.url,
          reason: 'a URL-origin assisted import stays tagged url',
        );
        expect(
          snapshot.metadata.domain,
          'example.se',
          reason: 'the www. prefix is stripped to the bare domain',
        );
        expect(
          snapshot.metadata.parserVersion,
          ImportCorrectionSnapshot.snapshotParserVersion,
          reason:
              'the anchor is built from a produced recipe, not a real parse',
        );
      },
    );

    test(
      'BUT-1656: a voice-origin assisted import tags the snapshot voice, not url',
      () {
        // Proves buildRecipe no longer hardcodes ImportSource.url: a voice
        // dictation reaching the wizard must be attributed to voice so the
        // feedback analytics don't miscount it as a URL import. Voice has no
        // source URL, hence no domain.
        final vm = advanceToReview(
          sourceUrl: null,
          source: ImportSource.voice,
        );
        addTearDown(vm.dispose);

        final recipe = vm.buildRecipe();
        final snapshot = cache.retrieve(recipe.id);

        expect(snapshot, isNotNull);
        expect(
          snapshot!.metadata.source,
          ImportSource.voice,
          reason: 'the origin strategy drives the snapshot source tag',
        );
        expect(snapshot.metadata.domain, isNull);
      },
    );

    test(
      'BUT-1656: a text-origin assisted import tags the snapshot text',
      () {
        // Proves the pasted-text (manual) path is attributed to text.
        final vm = advanceToReview(
          sourceUrl: null,
          source: ImportSource.text,
        );
        addTearDown(vm.dispose);

        final recipe = vm.buildRecipe();
        final snapshot = cache.retrieve(recipe.id);

        expect(snapshot!.metadata.source, ImportSource.text);
      },
    );

    test(
      'the stored snapshot mirrors the wizard selections (title + chosen lines)',
      () {
        final vm = advanceToReview();
        addTearDown(vm.dispose);

        final recipe = vm.buildRecipe();
        final snapshot = cache.retrieve(recipe.id)!;

        expect(snapshot.title.value, 'Kycklingrätt');
        // Snapshot ingredients are built from the produced recipe's flat lines
        // (blank lines skipped) — the two ingredient lines the user picked.
        expect(
          snapshot.ingredients.value,
          hasLength(recipe.ingredients.length),
        );
      },
    );

    test(
      'no sourceUrl → snapshot captured with a null domain (still anchored)',
      () {
        final vm = advanceToReview(sourceUrl: null);
        addTearDown(vm.dispose);

        final recipe = vm.buildRecipe();
        final snapshot = cache.retrieve(recipe.id);

        expect(snapshot, isNotNull);
        expect(
          snapshot!.metadata.domain,
          isNull,
          reason: 'no source URL means no domain attribution',
        );
      },
    );

    test('capture is best-effort: with no cache registered, buildRecipe still '
        'returns a recipe', () {
      app_provider.ServiceLocator.reset(); // drop the container entirely

      final vm = advanceToReview();
      addTearDown(vm.dispose);

      final recipe = vm.buildRecipe();
      expect(recipe.title, 'Kycklingrätt');
      expect(recipe.ingredients, hasLength(2));
    });
  });
}
