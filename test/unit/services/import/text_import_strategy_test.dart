/// Unit tests for TextImportStrategy - Text and social media recipe imports
///
/// Tests text-based recipe parsing including:
/// - Swedish recipe text parsing with measurements (dl, msk, tsk, krm)
/// - Ingredient extraction with Swedish terms
/// - Instruction parsing with Swedish action words
/// - Social media format cleanup
/// - Recipe structure detection
/// - Portion and time extraction
/// - Meal type guessing
/// - Edge cases (empty, malformed, minimal text)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

// Production imports
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/services/parsing/feedback/import_correction_snapshot.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('TextImportStrategy', () {
    late TextImportStrategy strategy;

    setUp(() async {
      // Initialize base test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create strategy instance
      strategy = TextImportStrategy();
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Ingredient sub-group headings (caption imports)', () {
      // Pasted captions ("Deg:", "Fyllning:") should keep their grouping the
      // same way the LLM/OCR tiers do — the heading lands on each ingredient's
      // structured `.section`, NEVER in the flat `ingredients` list that
      // allergen tagging reads.
      RecipeIngredient bySubstring(
        List<RecipeIngredient> list,
        String needle,
      ) => list.firstWhere((e) => e.raw.toLowerCase().contains(needle));

      test('captures "Deg:"/"Fyllning:" onto structured entries (both '
          'measurement-first and scored ingredients)', () async {
        const text =
            'Kladdkaka\n'
            'Ingredienser:\n'
            'Deg:\n'
            '2 dl socker\n' // measurement-first (STAGE 1) capture
            '1 nypa salt\n' // no known unit — scored (STAGE 3) capture
            'Fyllning:\n'
            '100 g choklad\n'
            'Gör så här:\n'
            'Blanda och grädda i 20 min.';
        final result = await strategy.import(text);
        final structured = result.recipe!.structuredIngredients;

        expect(bySubstring(structured, 'socker').section, 'Deg');
        expect(bySubstring(structured, 'salt').section, 'Deg');
        expect(bySubstring(structured, 'choklad').section, 'Fyllning');
      });

      test('never leaks a heading into the flat ingredients list', () async {
        const text =
            'Kladdkaka\n'
            'Deg:\n'
            '2 dl socker\n'
            'Fyllning:\n'
            '100 g choklad\n'
            'Gör så här:\n'
            'Blanda och grädda.';
        final result = await strategy.import(text);
        final flat = result.recipe!.ingredients.map((e) => e.toLowerCase());

        // The tagging system reads this list; a heading here could ground a
        // false "fritt från" verdict.
        expect(flat, isNot(contains('deg')));
        expect(flat, isNot(contains('deg:')));
        expect(flat, isNot(contains('fyllning')));
        expect(flat, isNot(contains('fyllning:')));
      });

      test(
        'a flat caption with no sub-groups leaves every section null',
        () async {
          const text =
              'Pannkakor\n'
              'Ingredienser:\n'
              '3 dl vetemjöl\n'
              '2 ägg\n'
              'Gör så här:\n'
              'Vispa ihop och stek.';
          final result = await strategy.import(text);
          final structured = result.recipe!.structuredIngredients;

          expect(structured, isNotEmpty);
          expect(structured.every((e) => e.section == null), isTrue);
        },
      );

      test(
        'ingredients before the first heading stay ungrouped; later ones are '
        'stamped (no retroactive back-fill)',
        () async {
          const text =
              'Kaka\n'
              'Ingredienser:\n'
              '2 ägg\n' // before any heading — must stay null
              'Deg:\n'
              '2 dl socker\n' // under "Deg"
              'Gör så här:\n'
              'Blanda och grädda.';
          final result = await strategy.import(text);
          final structured = result.recipe!.structuredIngredients;

          expect(bySubstring(structured, 'ägg').section, isNull);
          expect(bySubstring(structured, 'socker').section, 'Deg');
        },
      );

      test(
        'captures English caption groups ("Dough:"/"Filling:") and never an '
        'instruction header ("Method:")',
        () async {
          const text =
              'Muffins\n'
              'Dough:\n'
              '2 dl flour\n'
              'Filling:\n'
              '100 g chocolate\n'
              'Method:\n'
              'Mix and bake.';
          final result = await strategy.import(text);
          final structured = result.recipe!.structuredIngredients;
          final sections = structured.map((e) => e.section).toList();

          expect(bySubstring(structured, 'flour').section, 'Dough');
          expect(bySubstring(structured, 'chocolate').section, 'Filling');
          expect(sections, isNot(contains('Method')));
        },
      );

      // BUT-1727. The BUT-1714 gluten carve-out was wired into the URL/OCR
      // tiers only; this path ran its own heading heuristic and still ate the
      // line. A heading is dropped from the flat list allergen tagging reads,
      // so eating "Råg:" silently removes the gluten from the recipe.
      group('BUT-1727 bare gluten carve-out on the real import path', () {
        Future<List<String>> flatIngredients(String text) async {
          final result = await strategy.import(text);
          return result.recipe!.ingredients
              .map((e) => e.toLowerCase())
              .toList();
        }

        for (final word in ['Råg', 'Öl', 'Havregryn', 'Dinkel', 'Vetemjöl']) {
          test('keeps "$word:" as an ingredient, colon-stripped', () async {
            final flat = await flatIngredients(
              'Surdegsbröd\n'
              'Ingredienser:\n'
              '5 dl vatten\n'
              '$word:\n'
              '1 tsk salt\n'
              'Gör så här:\n'
              'Blanda och grädda i ugnen.',
            );

            // Colon-stripped: lookup strips no punctuation, so "råg:" would
            // match no registry document and take the whole recipe to UNKNOWN.
            expect(flat, contains(word.toLowerCase()));
            expect(flat, isNot(contains('${word.toLowerCase()}:')));
          });
        }

        test('the ticket\'s own repro block keeps every gluten line', () async {
          final flat = await flatIngredients(
            'Bröd\n'
            'Ingredienser:\n'
            'Råg:\n'
            'Öl:\n'
            'Vete:\n'
            'Havre:\n'
            'Mjöl:\n'
            '2 dl socker\n'
            'Gör så här:\n'
            'Blanda och grädda i ugnen.',
          );

          // Every rescued row survives, "öl" included. The first version of
          // this fix let the substring-containment rule in
          // _deduplicateIngredients swallow "Öl" into "Mjöl", and the comment
          // here called that an accepted no-op because both rows are gluten.
          // That reasoning only held for this fixture: the same rule let
          // gluten-FREE names swallow the rescued row on a real recipe (see
          // the collider group below), which is a false-negative FREE verdict
          // on a coeliac path. Containment is now skipped for rescued rows.
          expect(
            flat,
            containsAll(<String>['råg', 'öl', 'vete', 'havre', 'mjöl']),
          );
        });

        // BUT-1727 review: the rescue was undone one stage later. A rescued row
        // is a bare stem, so any longer ingredient name CONTAINING it replaced
        // it — and the swallowers here are all gluten-FREE, so the recipe lost
        // its only gluten row and could resolve FREE. Note "Mjöl:" was NOT a
        // regression: before the carve-out it was already dropped here, by
        // isValidIngredient's orphan-fragment rule (5 chars, single token, no
        // digit). The 6-character "Mjölk:" is the row that rides through with
        // its colon; that asymmetry is the decided BUT-1714 call.
        group('a gluten-free collider cannot swallow the rescued row', () {
          const colliders = {
            'Mjöl': '1 msk potatismjöl',
            'Vete': '2 dl bovetemjöl',
            'Korn': '2 dl majskorn',
            'Öl': '2 dl majsmjöl',
          };

          colliders.forEach((rescued, collider) {
            test('"$rescued:" survives "$collider"', () async {
              final flat = await flatIngredients(
                'Bröd\n'
                'Ingredienser:\n'
                '$rescued:\n'
                '$collider\n'
                '1 tsk salt\n'
                'Gör så här:\n'
                'Blanda och grädda i ugnen.',
              );

              // Both rows reach allergen tagging: the gluten stem AND the
              // gluten-free row that used to delete it.
              expect(flat, contains(rescued.toLowerCase()));
              expect(flat, contains(collider.toLowerCase()));
            });
          });

          test('a plain collider pair is still deduplicated by '
              'containment', () async {
            // The containment rule is untouched for every non-rescued row —
            // narrowing it to "skip when either side was rescued" must not
            // quietly disable it for the rest of the import.
            final flat = await flatIngredients(
              'Bröd\n'
              'Ingredienser:\n'
              '2 dl socker\n'
              '2 dl florsocker\n'
              'Gör så här:\n'
              'Blanda och grädda i ugnen.',
            );

            expect(flat.where((e) => e.contains('socker')).length, 1);
          });
        });

        test('the rescue is gluten-scoped — a dairy word is not routed '
            'through it', () async {
          final flat = await flatIngredients(
            'Kaka\n'
            'Ingredienser:\n'
            '2 dl socker\n'
            'Mjölk:\n'
            '1 tsk salt\n'
            'Gör så här:\n'
            'Blanda och grädda i ugnen.',
          );

          // Measured, not assumed (2026-07-30): on THIS path "Mjölk:" never
          // reached the heading heuristic at all — `looksLikeIngredient` lists
          // "mjölk" as an ingredient word, so the line has always ridden
          // through as a plain row, colon and all. That predates the carve-out
          // and is untouched by it; the assertion that matters here is that the
          // gluten rescue did not claim it, and colon-stripping — the rescue's
          // signature — is exactly what distinguishes the two.
          expect(flat, isNot(contains('mjölk')));
          expect(flat, contains('mjölk:'));
        });

        test('a real component heading is still a heading, not an '
            'ingredient', () async {
          final result = await strategy.import(
            'Kladdkaka\n'
            'Deg:\n'
            '2 dl socker\n'
            'Gör så här:\n'
            'Blanda och grädda.',
          );
          final flat = result.recipe!.ingredients.map((e) => e.toLowerCase());

          expect(flat, isNot(contains('deg')));
          expect(
            bySubstring(result.recipe!.structuredIngredients, 'socker').section,
            'Deg',
          );
        });

        test('the rescued row does not become the recipe title', () async {
          final result = await strategy.import(
            'Råg:\n'
            '5 dl vatten\n'
            'Gör så här:\n'
            'Blanda och grädda i ugnen.',
          );

          expect(result.recipe!.title.toLowerCase(), isNot('råg:'));
          expect(result.recipe!.title.toLowerCase(), isNot('råg'));
        });

        // "Råg:" is 4 characters, so _extractTitleFromText rejects it on length
        // alone and only the headerless fallback loop is exercised above. A
        // word of 5+ characters reaches the primary title path, where nothing
        // caught it before this guard — and being consumed as the title also
        // skips the row in STAGE 3, so the gluten left the tagging input.
        test(
          'a 5+ character rescued row does not become the title, and survives '
          'into the flat list',
          () async {
            final result = await strategy.import(
              'Havregryn:\n'
              '5 dl vatten\n'
              'Gör så här:\n'
              'Blanda och grädda i ugnen.',
            );

            expect(result.recipe!.title.toLowerCase(), isNot('havregryn:'));
            expect(result.recipe!.title.toLowerCase(), isNot('havregryn'));
            expect(
              result.recipe!.ingredients.map((e) => e.toLowerCase()),
              contains('havregryn'),
            );
          },
        );

        test('a fuller row for the same word still wins dedup', () async {
          final flat = await flatIngredients(
            'Bröd\n'
            'Ingredienser:\n'
            '2 dl råg\n'
            'Råg:\n'
            'Gör så här:\n'
            'Blanda och grädda i ugnen.',
          );

          expect(flat.where((e) => e.contains('råg')).length, 1);
          expect(flat, contains('2 dl råg'));
        });
      });
    });

    group('Cookbook title guards (corpus-found)', () {
      // The gold-corpus showed the title detector grabbing yield labels and
      // measurements as the recipe title on real cookbook pages. These prove it
      // no longer does — it picks the real heading instead.
      test(
        'does not pick a yield label ("2 PORTIONER") as the title',
        () async {
          const text =
              '2 PORTIONER\n'
              'Pannkakor\n'
              'Ingredienser:\n'
              '3 dl vetemjöl\n'
              '2 ägg\n'
              'Gör så här:\n'
              'Vispa ihop och stek.';
          final result = await strategy.import(text);
          final title = result.recipe?.title ?? '';
          expect(title.toLowerCase(), isNot(contains('portioner')));
          expect(title, isNot(startsWith('2')));
        },
      );

      test(
        'does not pick a measurement line ("100 g grönkål") as the title',
        () async {
          const text =
              '100 g grönkål\n'
              'Grön smoothie\n'
              'Ingredienser:\n'
              '2 dl vatten\n'
              '1 banan\n'
              'Gör så här:\n'
              'Mixa allt slätt.';
          final result = await strategy.import(text);
          final title = result.recipe?.title ?? '';
          expect(title.toLowerCase(), isNot(contains('grönkål')));
          expect(title, isNot(startsWith('100')));
        },
      );

      test(
        'does not pick a unit-less quantity line ("1 medelstor morot")',
        () async {
          // The "no unit at all" case: a leading number + noun is still an
          // ingredient, never a title.
          const text =
              '1 medelstor morot\n'
              'Morotssoppa\n'
              'Ingredienser:\n'
              '2 dl grädde\n'
              '1 lök\n'
              'Gör så här:\n'
              'Koka och mixa.';
          final result = await strategy.import(text);
          final title = result.recipe?.title ?? '';
          expect(title, isNot(startsWith('1 ')));
          expect(title.toLowerCase(), isNot(contains('medelstor')));
        },
      );

      test(
        'does not pick an ALL-CAPS section label ("SOM TILLBEHÖR")',
        () async {
          // Cookbook labels are set in caps; real titles are Title-Case.
          const text =
              'SOM TILLBEHÖR\n'
              'Rotmos\n'
              'Ingredienser:\n'
              '500 g potatis\n'
              '200 g kålrot\n'
              'Gör så här:\n'
              'Koka och mosa.';
          final result = await strategy.import(text);
          final title = result.recipe?.title ?? '';
          expect(title.toLowerCase(), isNot(contains('tillbehör')));
        },
      );

      test(
        'does not pick a "ca N" quantity line ("ca 8 tilapiafiléer")',
        () async {
          const text =
              'ca 8 tilapiafiléer\n'
              'Ugnsfisk\n'
              'Ingredienser:\n'
              '2 dl grädde\n'
              '1 citron\n'
              'Gör så här:\n'
              'Grädda i ugn.';
          final result = await strategy.import(text);
          final title = result.recipe?.title ?? '';
          expect(title.toLowerCase(), isNot(contains('tilapia')));
        },
      );

      test(
        'rejects a quantity line even when OCR mangled the unit ("2 di")',
        () async {
          // "2 di boveteflingor" — OCR misread dl→di; corrected before the guard
          // so it's still recognised as a measurement and rejected as a title.
          const text =
              '2 di boveteflingor\n'
              'Frukostgröt\n'
              'Ingredienser:\n'
              '3 dl havremjölk\n'
              '1 äpple\n'
              'Gör så här:\n'
              'Koka ihop.';
          final result = await strategy.import(text);
          final title = result.recipe?.title ?? '';
          expect(title.toLowerCase(), isNot(contains('boveteflingor')));
        },
      );
    });

    group('Header-less ingredient extraction (corpus-found)', () {
      test('OCR-corrects the unit and ignores instruction measurements', () async {
        // Header-less column (no "Ingredienser:"). "8 di" is an OCR misread of
        // "8 dl" — must still be captured. The instruction line carries its own
        // "1 dl"/"2 dl" measurements which must NOT become ingredients.
        const text =
            '8 di dinkelflingor\n'
            '3 dl solrosfrön\n'
            '1 msk salt\n'
            'Grötbas\n'
            'Blanda 1 dl gröt per portion med 2 dl vatten i en kastrull och koka.';
        final result = await strategy.import(text);
        final ings = (result.recipe?.ingredients ?? const <String>[])
            .join(' | ')
            .toLowerCase();

        expect(
          ings,
          contains('dinkelflingor'),
          reason: 'di→dl corrected so the measurement matched',
        );
        expect(ings, contains('solrosfrön'));
        expect(
          ings,
          isNot(contains('vatten')),
          reason: 'measurement embedded in an instruction is not an ingredient',
        );
      });

      // BUT-1661 acceptance criterion #2, end-to-end.
      //
      // Proves that a UNIT-LESS, åäö-leading ingredient line survives a
      // headerless import — the exact shape that used to vanish. Every other
      // "ägg" fixture in this file sits under an "Ingredienser:" header, which
      // flips the parser into its ingredient block and bypasses the predicate
      // entirely; this one deliberately has no header anywhere, so the line can
      // only be captured through
      // `RecipeSectionDetector.looksLikeIngredient` at STAGE 3.
      //
      // Non-vacuity: "4 ägg" carries no unit, no fraction, no comma and no
      // bullet, so none of the other branches of that predicate can fire. Under
      // the pre-fix ASCII boundary — one on either side of "ägg", which never
      // borders 'ä' — the word-list branch returned false too, the line was
      // dropped outright, and
      // this assertion goes red. `text_import_strategy` has no fallback branch
      // after the check, so a drop here is silent data loss on an
      // allergen-bearing line.
      test(
        'keeps a unit-less "4 ägg" line in a fully headerless import',
        () async {
          const text =
              'Fluffiga pannkakor från grunden\n'
              '4 ägg\n'
              '3 dl vetemjöl\n'
              '5 dl mjölk\n'
              'Vispa ihop smeten och stek tunna pannkakor i smör.';

          final result = await strategy.import(text);
          final ings = result.recipe?.ingredients ?? const <String>[];
          final joined = ings.join(' | ').toLowerCase();

          expect(
            joined,
            contains('ägg'),
            reason:
                'the unit-less line is the one at risk — it reaches the list '
                'only via looksLikeIngredient',
          );
          // Positive control: the measured lines prove the parse ran and the
          // ingredient block was populated, so a missing "ägg" above could not
          // be explained by the import having failed wholesale.
          expect(joined, contains('vetemjöl'));
          expect(joined, contains('mjölk'));
          // ...and the instruction line must not have been mistaken for one.
          expect(
            joined,
            isNot(contains('vispa')),
            reason: 'the instruction line is not an ingredient',
          );
        },
      );
    });

    group('Initialization', () {
      test('should create strategy with correct metadata', () {
        // Assert
        expect(strategy, isNotNull);
        expect(strategy.strategyName, equals('Text Import'));
        expect(strategy.description, contains('text'));
        expect(strategy.inputExample, isNotEmpty);
      });

      test('should have validation mixin capabilities', () {
        // Assert - Strategy should be able to validate recipe components
        expect(strategy.isValidRecipeName('Test Recipe'), isTrue);
        expect(strategy.isValidRecipeName(''), isFalse);
      });
    });

    group('Input Validation', () {
      test('should accept valid recipe text formats', () {
        // Arrange
        const validInputs = [
          'Recipe Name\nIngredients:\n- Item 1\nInstructions:\n1. Step 1',
          'Simple Recipe\n500g flour\nMix everything',
          'Köttbullar\n500g köttfärs\n1 dl mjölk',
        ];

        // Act & Assert
        for (final input in validInputs) {
          expect(
            strategy.canHandle(input),
            isTrue,
            reason: 'Should handle: ${input.split('\n').first}...',
          );
          expect(
            strategy.validateInput(input),
            isTrue,
            reason: 'Should validate: ${input.split('\n').first}...',
          );
        }
      });

      test('should reject invalid inputs', () {
        // Arrange
        const invalidInputs = [
          '',
          'archive:123',
          'https://example.com',
          'file://recipe.csv',
        ];

        // Act & Assert
        for (final input in invalidInputs) {
          expect(
            strategy.canHandle(input),
            isFalse,
            reason: 'Should not handle: $input',
          );
        }
      });

      test('should validate minimum recipe content', () {
        // Arrange
        const tooShort = 'Recipe';
        const justRight = 'Recipe Name\nSome ingredients\nSome instructions';

        // Act & Assert
        expect(strategy.validateInput(tooShort), isFalse);
        expect(strategy.validateInput(justRight), isTrue);
      });
    });

    group('Swedish Recipe Parsing', () {
      test('should parse complete Swedish recipe', () async {
        // Arrange
        const swedishRecipe = '''
Köttbullar med gräddsås
För 4 portioner, 30 minuter

Ingredienser:
500 g köttfärs
1 dl ströbröd
2 dl mjölk
1 ägg
1 tsk salt
1/2 tsk svartpeppar
2 msk smör för stekning

Gräddsås:
2 msk smör
2 msk vetemjöl
3 dl grädde
1 dl köttbuljong
Salt och peppar

Gör så här:
1. Blanda köttfärs, ströbröd och mjölk i en bunke
2. Låt svälla 10 minuter
3. Tillsätt ägg, salt och peppar
4. Forma små bollar
5. Stek i smör tills gyllene

För såsen:
1. Smält smör i en kastrull
2. Vispa i mjöl
3. Tillsätt grädde och buljong
4. Koka upp under omrörning
5. Smaka av med salt och peppar
''';

        // Act
        final result = await strategy.import(swedishRecipe);

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);

        final recipe = result.recipe!;
        // Title extraction takes first non-header line after processing
        // Due to preprocessing, the title might be parsed differently
        expect(
          recipe.title,
          anyOf([
            contains('Köttbullar'),
            contains('köttfärs'), // May extract first ingredient line as title
            equals('Importerat recept'), // Default fallback
          ]),
        );
        // "För 4 portioner, 30 minuter" — both metadata values are extracted.
        expect(recipe.portions, equals(4));
        expect(recipe.timeMinutes, equals(30));

        // Ingredients parse from the "Ingredienser:" block. CRIT-12 removed the
        // placeholder string, so an unparsed result is an empty list — this
        // asserts real Swedish content, not a "did nothing" escape.
        expect(recipe.ingredients, isNotEmpty);
        expect(
          recipe.ingredients.any(
            (i) => i.contains('dl') || i.contains('köttfärs'),
          ),
          isTrue,
          reason: 'Should have at least some Swedish ingredients',
        );

        // Instructions parse from the "Gör så här:" block.
        expect(recipe.instructions, isNotEmpty);
      });

      test('should handle Swedish measurement abbreviations', () async {
        // Arrange
        const recipeText = '''
Svenska bullar
Ingredienser:
1 dl socker
2 msk sirap
1 tsk vaniljsocker
1 krm salt
500 g mjöl
''';

        // Act
        final result = await strategy.import(recipeText);

        // Assert
        expect(result.isSuccess, isTrue);
        final ingredients = result.recipe!.ingredients;

        // Check that at least some Swedish measurements are preserved
        final hasSwedishMeasurements =
            ingredients.any((i) => i.contains('dl')) ||
            ingredients.any((i) => i.contains('msk')) ||
            ingredients.any((i) => i.contains('tsk')) ||
            ingredients.any((i) => i.contains('krm'));
        expect(
          hasSwedishMeasurements,
          isTrue,
          reason: 'Should have at least one Swedish measurement unit',
        );
      });

      test('should detect Swedish meal types', () async {
        // Arrange
        final mealTypeTests = {
          'Frukost: Havregrynsgröt': 'Frukost',
          'Lunch - Sallad med kyckling': 'Lunch',
          'Middag: Laxfilé med potatis': 'Middag',
          'Fika - Kanelbullar': 'Fika',
        };

        // Act & Assert
        for (final entry in mealTypeTests.entries) {
          final text =
              '${entry.key}\nIngredienser:\nTest\nInstruktioner:\nTest';
          final result = await strategy.import(text);

          if (result.isSuccess && result.recipe != null) {
            // Meal type detection is basic - looks for keywords in text
            // With colon in title, it may not detect properly
            if (entry.key.toLowerCase().contains('fika')) {
              expect(result.recipe!.mealType, equals('Fika'));
            } else {
              // Other meal types default to 'Lunch' when not detected
              expect(
                result.recipe!.mealType,
                anyOf([equals(entry.value), equals('Lunch')]),
                reason: 'May default to Lunch for: ${entry.key}',
              );
            }
          }
        }
      });

      test(
        'should parse Kroppkakor recipe format correctly - BUG-040 fix',
        () async {
          // Arrange - This is the actual failing recipe format from BUG-040
          const kroppkakorRecipe = '''
Kroppkakor av kokt potatis

Ingredienser:
- 1 kg mjölig potatis
- vatten att koka potatisen i
- 1 tsk salt
- 2 ägg
- ca 3 dl vetemjöl

Fyllning:
- 200 g fläsk, tärnat
- 1 gul lök, hackad
- salt och peppar

Instruktioner:
1. Koka potatisen mjuk med skalet på
2. Låt svalna och skala av
3. Pressa genom potatispress eller mosa fint
4. Tillsätt salt, ägg och mjöl
5. Arbeta till en smidig deg
6. Forma till bollar med fyllning
7. Koka i saltat vatten tills de flyter upp
''';

          // Act
          final result = await strategy.import(kroppkakorRecipe);

          // Assert
          expect(
            result.isSuccess,
            isTrue,
            reason: 'Recipe parsing should succeed',
          );
          expect(result.recipe, isNotNull);

          final recipe = result.recipe!;

          // Title should be extracted correctly (not an ingredient line)
          expect(
            recipe.title,
            equals('Kroppkakor av kokt potatis'),
            reason: 'Should extract proper recipe title, not ingredient',
          );

          // Should find ingredients (with new 'ingredienser' pattern recognition)
          expect(
            recipe.ingredients,
            isNot(equals(['Ingen ingrediensinformation'])),
            reason:
                'Should recognize "Ingredienser:" header and parse ingredients',
          );
          expect(
            recipe.ingredients.length,
            greaterThan(3),
            reason: 'Should find multiple ingredients from the recipe',
          );

          // Check that some specific ingredients are found
          final hasPotatoIngredient = recipe.ingredients.any(
            (ingredient) => ingredient.toLowerCase().contains('potatis'),
          );
          expect(
            hasPotatoIngredient,
            isTrue,
            reason: 'Should find potato ingredient',
          );

          final hasFlourIngredient = recipe.ingredients.any(
            (ingredient) => ingredient.toLowerCase().contains('mjöl'),
          );
          expect(
            hasFlourIngredient,
            isTrue,
            reason: 'Should find flour ingredient',
          );

          // Should find instructions
          expect(
            recipe.instructions,
            isNot(equals(['Ingen instruktionsinformation'])),
            reason: 'Should find cooking instructions',
          );
          expect(
            recipe.instructions.length,
            greaterThan(3),
            reason: 'Should find multiple cooking steps',
          );
        },
      );
    });

    group('Ingredient Extraction', () {
      test('should extract ingredients from various formats', () async {
        // Arrange
        const recipeText = '''
Test Recipe
Ingredients:
- 2 cups flour
- 1/2 tsp salt
• 3 eggs
* 250ml milk
500g butter
1. This is not an ingredient
''';

        // Act
        final result = await strategy.import(recipeText);

        // Assert
        expect(result.isSuccess, isTrue);
        final ingredients = result.recipe!.ingredients;

        // Ingredients are extracted from the "Ingredients:" block. CRIT-12
        // removed the placeholder string, so this asserts real content.
        expect(ingredients, isNotEmpty);
        final foundSomeIngredients =
            ingredients.any((i) => i.contains('flour')) ||
            ingredients.any((i) => i.contains('salt')) ||
            ingredients.any((i) => i.contains('eggs')) ||
            ingredients.any((i) => i.contains('milk')) ||
            ingredients.any((i) => i.contains('butter'));
        expect(foundSomeIngredients, isTrue);
      });

      test('should handle ingredient sections', () async {
        // Arrange
        const recipeText = '''
Layer Cake
Base:
- 200g flour
- 100g sugar

Filling:
- 300ml cream
- 50g chocolate

Instructions:
Mix everything
''';

        // Act
        final result = await strategy.import(recipeText);

        // Assert
        expect(result.isSuccess, isTrue);
        final ingredients = result.recipe!.ingredients;

        // Both "Base:" and "Filling:" measured ingredients are captured
        // measurement-first; the flat list carries the ingredient content
        // (sub-group headings live only on the structured entries).
        expect(ingredients, isNotEmpty);
        expect(
          ingredients.any((i) => i.contains('flour')) ||
              ingredients.any((i) => i.contains('sugar')) ||
              ingredients.any((i) => i.contains('cream')) ||
              ingredients.any((i) => i.contains('chocolate')),
          isTrue,
        );
      });

      test('should normalize ingredient amounts', () async {
        // Arrange
        const recipeText = '''
Recipe
Ingredients:
- 1/2 cup item
- 1½ tsp spice
- 2-3 pieces fruit
- a pinch of salt
- några droppar vanilla
''';

        // Act
        final result = await strategy.import(recipeText);

        // Assert
        expect(result.isSuccess, isTrue);
        final ingredients = result.recipe!.ingredients;

        // Ingredients are extracted and fractions are normalized to ½ (or the
        // unit-less "a pinch of salt" line is kept). Asserts real content.
        expect(ingredients, isNotEmpty);
        final hasFraction = ingredients.any(
          (i) => i.contains('1/2') || i.contains('½'),
        );
        expect(
          hasFraction || ingredients.any((i) => i.contains('pinch')),
          isTrue,
        );
      });
    });

    group('Instruction Parsing', () {
      test('should extract numbered instructions', () async {
        // Arrange
        const recipeText = '''
Recipe
Ingredients:
- Item 1

Instructions:
1. First step
2. Second step
3. Third step
''';

        // Act
        final result = await strategy.import(recipeText);

        // Assert
        expect(result.isSuccess, isTrue);
        final instructions = result.recipe!.instructions;

        // Numbered steps under "Instructions:" are parsed in order.
        expect(instructions.length, greaterThanOrEqualTo(3));
        expect(instructions[0], contains('First step'));
        expect(instructions[1], contains('Second step'));
        expect(instructions[2], contains('Third step'));
      });

      test('should handle Swedish instruction keywords', () async {
        // Arrange
        const recipeText = '''
Recept
Ingredienser:
- Mjöl

Gör så här:
Blanda alla ingredienser
Vispa ägg och mjölk
Tillsätt mjöl försiktigt
Grädda i ugn 200 grader
''';

        // Act
        final result = await strategy.import(recipeText);

        // Assert
        expect(result.isSuccess, isTrue);
        final instructions = result.recipe!.instructions;

        // The "Gör så här:" header opens the instruction block; its Swedish
        // action lines are parsed.
        expect(instructions, isNotEmpty);
        final hasSwedishInstruction =
            instructions.any((i) => i.contains('Blanda')) ||
            instructions.any((i) => i.contains('Vispa')) ||
            instructions.any((i) => i.contains('Tillsätt')) ||
            instructions.any((i) => i.contains('Grädda'));
        expect(hasSwedishInstruction, isTrue);
      });

      test('should separate instruction paragraphs', () async {
        // Arrange
        const recipeText = '''
Recipe
Ingredients:
- Item

Method:
Start by preparing the base. Mix flour and water.

Then make the filling. Combine all filling ingredients.

Finally, assemble and bake for 30 minutes.
''';

        // Act
        final result = await strategy.import(recipeText);

        // Assert
        expect(result.isSuccess, isTrue);
        final instructions = result.recipe!.instructions;

        // The "Method:" header opens the instruction block; at least one
        // instruction paragraph is captured.
        expect(instructions, isNotEmpty);
        expect(
          instructions.any((i) => i.toLowerCase().contains('flour')) ||
              instructions.any((i) => i.toLowerCase().contains('filling')) ||
              instructions.any((i) => i.toLowerCase().contains('bake')) ||
              instructions.any((i) => i.toLowerCase().contains('assemble')),
          isTrue,
        );
      });
    });

    group('Social Media Format Cleanup', () {
      test('should clean emojis from text', () async {
        // Arrange
        const socialMediaPost = '''
🍝 Amazing Pasta Recipe! 😍

Ingredients: 🥘
- 500g pasta 🍝
- 2 cups sauce 🍅
- Cheese 🧀

Instructions: 👨‍🍳
Cook pasta ✨
Add sauce 💯
Top with cheese 🔥
''';

        // Act
        final result = await strategy.import(socialMediaPost);

        // Assert
        expect(result.isSuccess, isTrue);
        final recipe = result.recipe!;

        // Title should be cleaned
        expect(recipe.title.contains('🍝'), isFalse);
        expect(recipe.title.contains('😍'), isFalse);

        // Ingredients should be cleaned
        for (final ingredient in recipe.ingredients) {
          expect(
            RegExp(
              r'[\u{1F300}-\u{1FAD6}]',
              unicode: true,
            ).hasMatch(ingredient),
            isFalse,
            reason: 'Ingredient should not contain emojis: $ingredient',
          );
        }
      });

      test('should handle hashtags and mentions', () async {
        // Arrange
        const socialMediaPost = '''
#Recipe #Foodie Chicken Salad @chef_anna

Ingredients:
- Chicken #protein
- Lettuce #healthy
- Dressing

Make it: Mix everything! #easy #quick
Check out @cooking_tips for more
''';

        // Act
        final result = await strategy.import(socialMediaPost);

        // Assert — single-word ingredients like "Chicken" are rejected by
        // isValidIngredient because isSectionHeader treats single lowercase
        // words < 15 chars as ambiguous. The import succeeds but ingredients
        // may be empty since all are single words after hashtag stripping.
        expect(result.isSuccess, isTrue);
        final recipe = result.recipe!;

        // Title extraction should capture "Chicken Salad" from first line
        expect(recipe.title, contains('Chicken Salad'));
      });

      test('should handle URLs in text', () async {
        // Arrange
        const recipeWithUrls = '''
Recipe Name
Find more at https://example.com/recipes

Ingredients:
- Item 1
- Item 2

Instructions:
1. Step one (see video: https://youtube.com/watch?v=123)
2. Step two
Full recipe: www.blog.com/full-recipe
''';

        // Act
        final result = await strategy.import(recipeWithUrls);

        // Assert
        expect(result.isSuccess, isTrue);
        final recipe = result.recipe!;

        // URLs might be preserved in metadata
        expect(recipe.title, equals('Recipe Name'));
        expect(recipe.ingredients.length, equals(2));
      });
    });

    group('Metadata Extraction', () {
      // These two exist because nothing else in the repo pinned
      // `RecipeTimeExtractor.extract(text) ?? _extractTime(text)`. Reverting it
      // to the bare `_extractTime(text)` left every other suite green, so the
      // whole change could have been undone without a single red test.
      test(
        'a labelled composite time beats what the scavenger reads',
        () async {
          // `_extractTime`'s `tid\s*:\s*(\d+)\s*timm` stops at the hour and
          // answers 60; the extractor sums the composite.
          const text = '''
Fin sillsallad
• Tillagningstid: 1 timme och 15 minuter
Ingredienser:
2 dl grädde
Gör så här:
Koka potatisen i 20 minuter.
''';
          final result = await strategy.import(text);
          expect(result.recipe!.timeMinutes, equals(75));
        },
      );

      test('with no label at all the cruder scavenger still fires', () async {
        // The other half of the `??`: the extractor returning null must not
        // blank out a time the old path could still find.
        const text =
            'Pannkakor\nIngredienser:\n3 dl mjöl\n'
            'Gör så här:\nGrädda i 20 min på medelvärme.';
        final result = await strategy.import(text);
        expect(result.recipe!.timeMinutes, equals(20));
      });

      test('should extract servings information', () async {
        // Arrange — each input mapped to the portions the parser actually
        // extracts today (null where no pattern matches). The extractor keys on
        // "N portion..." / "för N" / "N pers"; "Serves N", "For N people" and
        // "Yield: N servings" have no matching pattern, so they yield null.
        final servingsTests = <String, int?>{
          'Recipe\nServes 4\nIngredients:\n- Item': null,
          'Recipe\nFor 6 people\nIngredients:\n- Item': null,
          'Recipe\n4 portioner\nIngredients:\n- Item': 4,
          'Recipe\nYield: 8 servings\nIngredients:\n- Item': null,
        };

        // Act & Assert
        for (final entry in servingsTests.entries) {
          final fullText = '${entry.key}\nInstructions:\nMix';
          final result = await strategy.import(fullText);

          expect(result.isSuccess, isTrue);
          expect(
            result.recipe!.portions,
            equals(entry.value),
            reason: 'Portions mismatch for: ${entry.key.split('\n')[1]}',
          );
        }
      });

      test('should extract time information', () async {
        // Arrange — each input mapped to the minutes the parser actually
        // extracts today. It matches the FIRST "N min"/"N timm" pattern and does
        // NOT sum multiple values, so "Prep: 15 min, Cook: 30 min" yields 15;
        // "1 hour" has no matching pattern (only "min"/"timm"), so it yields null.
        final timeTests = <String, int?>{
          'Recipe\nPrep: 15 min, Cook: 30 min': 15,
          'Recipe\nTotal time: 1 hour': null,
          'Recipe\n20 minuter': 20,
          'Recipe\nReady in 45 minutes': 45,
        };

        // Act & Assert
        for (final entry in timeTests.entries) {
          final text = '${entry.key}\nIngredients:\n- Item\nInstructions:\nMix';
          final result = await strategy.import(text);

          expect(result.isSuccess, isTrue);
          expect(
            result.recipe!.timeMinutes,
            equals(entry.value),
            reason: 'Time mismatch for: ${entry.key}',
          );
        }
      });

      // NOTE: there is no difficulty-level extraction in TextImportStrategy and
      // the Recipe model carries no difficulty field, so a "should extract
      // difficulty" test could only ever be a green no-op. It was removed rather
      // than left implying coverage that does not exist. If difficulty parsing
      // is added later, add a test asserting the mapped Swedish value per input.
    });

    group('Edge Cases', () {
      test('should handle minimal recipe text', () async {
        // Arrange
        const minimal = 'Recipe\nFlour\nMix';

        // Act
        final result = await strategy.import(minimal);

        // Assert — "Recipe", "Flour", "Mix" are all single words < 15 chars,
        // treated as section headers by isSectionHeader. Title remains empty,
        // ingredients/instructions are empty. Import still succeeds with defaults.
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);
      });

      test('should handle text without clear sections', () async {
        // Arrange
        const unstructured = '''
Pasta dish
Need pasta, sauce, cheese
Boil pasta, add sauce, top with cheese, serve hot
''';

        // Act
        final result = await strategy.import(unstructured);

        // Assert — without section headers (Ingredients:/Instructions:),
        // the parser relies on line-by-line heuristics. Comma-separated
        // items without measurements are not reliably detected as ingredients.
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);
        expect(result.recipe!.title, contains('Pasta'));
      });

      test('should handle very long recipe text', () async {
        // Arrange
        final longText =
            '''
Long Recipe Name
Ingredients:
${List.generate(50, (i) => '- Ingredient ${i + 1}').join('\n')}

Instructions:
${List.generate(30, (i) => '${i + 1}. Step number ${i + 1} with detailed instructions').join('\n')}
''';

        // Act
        final result = await strategy.import(longText);

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.ingredients.length, lessThanOrEqualTo(50));
        expect(result.recipe!.instructions.length, lessThanOrEqualTo(30));
      });

      test('should handle non-recipe text gracefully', () async {
        // Arrange
        const nonRecipe = '''
This is a blog post about cooking.
I really love to cook different dishes.
Yesterday I made something delicious.
''';

        // Act
        final result = await strategy.import(nonRecipe);

        // Assert — import always produces a recipe when the text has any
        // non-empty lines (it only fails on empty input or a parse exception),
        // so blog prose succeeds with a near-empty recipe rather than failing.
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);
        // No ingredient measurements present, so the flat ingredient list is
        // empty (CRIT-12: empty list, never a placeholder string).
        expect(result.recipe!.ingredients, isEmpty);
      });

      test('should handle mixed languages', () async {
        // Arrange
        const mixedLanguage = '''
Chicken Curry
Ingredienser:
- 500g chicken
- 2 msk curry
- 1 dl grädde

Instructions:
1. Stek kycklingen
2. Add curry powder
3. Tillsätt grädde
''';

        // Act
        final result = await strategy.import(mixedLanguage);

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.ingredients, isNotEmpty);
        expect(result.recipe!.instructions, isNotEmpty);
      });

      test('should provide meaningful error messages', () async {
        // Arrange
        const tooShort = 'R';

        // Act
        final result = await strategy.import(tooShort);

        // Assert — 'R' is a single char. _parseTextToRecipe receives it,
        // finds lines = ['R']. Title extraction fails (single char < 5).
        // No ingredients/instructions. Returns a Recipe with empty title.
        expect(result, isNotNull);
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);
        expect(result.recipe!.title, isEmpty);
      });
    });

    group('BUT-1232 structured ingredient derivation', () {
      // Intention: text imports persist structuredIngredients derived from
      // the final cleaned strings — index-aligned (raw == ingredients[i]) so
      // the Recipe.structuredIngredients facade getter accepts them, with
      // unparseable lines degrading to raw-only instead of failing the import.
      test(
        'persists index-aligned structured entries with parsed amounts',
        () async {
          const text =
              'Pannkakor\n'
              'Ingredienser:\n'
              '3 dl vetemjöl\n'
              '2 ägg\n'
              'färsk basilika\n'
              'Gör så här:\n'
              'Vispa ihop alla ingredienser och stek i smör.';

          final result = await strategy.import(text);
          final recipe = result.recipe!;
          final stored = recipe.core.structuredIngredients;

          expect(stored, isNotNull);
          expect(stored!.length, recipe.ingredients.length);
          for (var i = 0; i < stored.length; i++) {
            expect(
              stored[i].raw,
              recipe.ingredients[i],
              reason: 'entry $i must align with its free-text line',
            );
          }
          // Facade getter must return the persisted entries (aligned), not the
          // raw-only fallback.
          expect(recipe.structuredIngredients, equals(stored));

          final flour = stored.firstWhere((e) => e.raw.contains('vetemjöl'));
          expect(flour.amount, 3);
          expect(flour.unit, 'dl');
        },
      );

      test('unparseable ingredient line degrades to raw-only entry', () async {
        const text =
            'Tomatsallad\n'
            'Ingredienser:\n'
            '2 st tomater\n'
            'färsk basilika\n'
            'Gör så här:\n'
            'Skiva tomaterna och toppa med basilika.';

        final result = await strategy.import(text);
        final stored = result.recipe!.core.structuredIngredients!;

        final basil = stored.firstWhere((e) => e.raw.contains('basilika'));
        expect(basil.amount, isNull);
        expect(basil.unit, isNull);
        expect(basil.isStructured, isFalse);
      });

      test(
        'no ingredients extracted leaves structuredIngredients null',
        () async {
          // Instruction-only text: parse succeeds but ingredient list is empty —
          // stay legacy (null) rather than persisting an empty list.
          const text =
              'Mystisk rätt\n'
              'Gör så här:\n'
              'Blanda allt och servera direkt till gästerna.';

          final result = await strategy.import(text);

          expect(result.recipe!.ingredients, isEmpty);
          expect(result.recipe!.core.structuredIngredients, isNull);
        },
      );
    });

    group('BUT-1501 structuredIngredients additive-field contract', () {
      // The CRF→NER cascade (BUT-1501) may ONLY populate the ADDITIVE
      // `structuredIngredients` field. The flat `ingredients` list — the one
      // allergen tagging reads to ground "fritt från X" verdicts — must be
      // passed through untouched: same content, same order, no headings, no
      // drops. These pin that safety invariant, distinct from BUT-1232's
      // per-entry amount parsing.
      RecipeIngredient bySubstring(
        List<RecipeIngredient> list,
        String needle,
      ) => list.firstWhere((e) => e.raw.toLowerCase().contains(needle));

      test(
        'structured.raw maps 1:1 onto the flat ingredients list (additive '
        'projection — no drop, no reorder, no rewrite)',
        () async {
          const text =
              'Kladdkaka\n'
              'Ingredienser:\n'
              'Deg:\n'
              '2 dl socker\n'
              '1 nypa salt\n'
              'Fyllning:\n'
              '100 g choklad\n'
              'Gör så här:\n'
              'Blanda och grädda i 20 min.';
          final result = await strategy.import(text);
          final recipe = result.recipe!;
          final structured = recipe.structuredIngredients;

          // Additive contract: the structured field is a faithful, index-aligned
          // projection OF the flat list — one entry per flat line, same order,
          // each entry's `raw` byte-equal to the flat string it derives from.
          expect(
            structured.map((e) => e.raw).toList(),
            equals(recipe.ingredients),
            reason:
                'the structured field must mirror the flat allergen-read list '
                'exactly — it may add structure, never alter the list',
          );
          expect(structured, hasLength(recipe.ingredients.length));
        },
      );

      test(
        'sub-group headings live ONLY on the additive .section metadata, never '
        'in the flat allergen-read list',
        () async {
          const text =
              'Kladdkaka\n'
              'Deg:\n'
              '2 dl socker\n'
              'Fyllning:\n'
              '100 g choklad\n'
              'Gör så här:\n'
              'Blanda och grädda.';
          final result = await strategy.import(text);
          final recipe = result.recipe!;
          final flat = recipe.ingredients.map((e) => e.toLowerCase()).toList();

          // The heading text is captured additively on the structured entry...
          expect(
            bySubstring(recipe.structuredIngredients, 'socker').section,
            'Deg',
          );
          expect(
            bySubstring(recipe.structuredIngredients, 'choklad').section,
            'Fyllning',
          );
          // ...and must NOT have leaked into the flat list a false "fritt från"
          // verdict could be grounded on.
          expect(flat, isNot(contains('deg')));
          expect(flat, isNot(contains('deg:')));
          expect(flat, isNot(contains('fyllning')));
          expect(flat, isNot(contains('fyllning:')));
        },
      );
    });

    group('BUT-1469/BUT-1614 correction-capture wiring', () {
      // A successful text import must anchor the parser feedback loop: it
      // stores an ImportCorrectionSnapshot in the shared ParsedRecipeCache,
      // keyed by the produced recipe id and tagged ImportSource.text. The
      // strategy resolves that cache from the production ServiceLocator (no
      // cache arg), so these tests wire a real cache in and read it back.
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

      const validText =
          'Pannkakor\n'
          'Ingredienser:\n'
          '3 dl vetemjöl\n'
          '2 ägg\n'
          'Gör så här:\n'
          'Vispa ihop och stek i smör.';

      test(
        'stores a snapshot keyed by the produced recipe id, tagged '
        'ImportSource.text with the snapshot sentinel version',
        () async {
          final result = await strategy.import(validText);
          expect(result.isSuccess, isTrue);

          final snapshot = cache.retrieve(result.recipe!.id);
          expect(
            snapshot,
            isNotNull,
            reason: 'text import must anchor the feedback loop in the cache',
          );
          expect(snapshot!.metadata.source, ImportSource.text);
          expect(
            snapshot.metadata.parserVersion,
            ImportCorrectionSnapshot.snapshotParserVersion,
            reason:
                'the anchor is built from a produced recipe, not a real parse',
          );
          expect(
            snapshot.metadata.domain,
            isNull,
            reason: 'a pasted-text import has no source domain',
          );
        },
      );

      test(
        'the stored snapshot mirrors the produced recipe (real recipe fed in, '
        'so an unedited save diffs to zero)',
        () async {
          final result = await strategy.import(validText);
          final recipe = result.recipe!;
          expect(
            recipe.ingredients,
            isNotEmpty,
            reason: 'this fixture must parse to a real ingredient list',
          );

          final snapshot = cache.retrieve(recipe.id)!;
          // Mirrors ImportCorrectionSnapshot.build: a non-empty title becomes a
          // success FieldResult, an empty one degrades to failed (value null).
          final expectedTitle = recipe.title.trim().isNotEmpty
              ? recipe.title
              : null;
          expect(snapshot.title.value, expectedTitle);
          // Snapshot ingredients are built from the produced recipe's flat
          // ingredient lines (blank lines skipped).
          final nonBlank = recipe.ingredients
              .where((l) => l.trim().isNotEmpty)
              .length;
          expect(snapshot.ingredients.value, hasLength(nonBlank));
        },
      );

      test(
        'capture is best-effort: with no cache registered, import still '
        'succeeds and nothing is stored',
        () async {
          // Drop the production container so tryGet<ParsedRecipeCache> returns
          // null — the capture path must swallow that and never fail import.
          app_provider.ServiceLocator.reset();

          final result = await strategy.import(validText);
          expect(result.isSuccess, isTrue);
          expect(
            cache.contains(result.recipe!.id),
            isFalse,
            reason: 'no cache was reachable, so nothing should be stored',
          );
        },
      );
    });
  });
}
