/// Text Import Strategy - Parses structured/unstructured text into recipes (social media, manual input).

import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/parsing/feedback/import_correction_snapshot.dart';
import 'package:butlery/services/import/parsers/heading_word_lists.dart';
import 'package:butlery/services/import/parsers/text_import_normalizer.dart';
import 'package:butlery/services/import/parsers/recipe_section_detector.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/utils/text/ingredient_processor.dart';
import 'package:butlery/utils/text/ocr_error_corrector.dart';
import 'package:butlery/utils/text/structured_ingredient_deriver.dart';

/// Strategy for importing recipes from text (social media, manual input, structured/unstructured text).
/// Uses TextImportNormalizer for text preprocessing and RecipeSectionDetector for section classification.
class TextImportStrategy extends ImportStrategy with ImportValidationMixin {
  static const _uuid = Uuid();

  // BUT-1501: the shared CRF → BERT NER ingredient cascade (the same one URL
  // imports get via RecipeParserService). Resolved lazily and best-effort:
  // absent (tests / early boot) → fall back to the deterministic regex deriver.
  bool _strategyResolved = false;
  IngredientParsingStrategy? _cachedStrategy;
  IngredientParsingStrategy? get _ingredientStrategy {
    if (_strategyResolved) return _cachedStrategy;
    _strategyResolved = true;
    _cachedStrategy = ServiceLocator.tryGet<IngredientParsingStrategy>();
    return _cachedStrategy;
  }

  @override
  String get strategyName => 'Text Import';

  @override
  String get description =>
      'Import recipes from text content (social media posts, manual input)';

  @override
  String get inputExample =>
      'Pannkakor\nIngredienser: 3 ägg, 5 dl mjölk...\nGör så här: 1. Vispa ihop...';

  @override
  bool canHandle(String input) {
    final normalized = normalizeText(input);

    // Check for recipe-like content
    return normalized.length > 20 &&
        (RecipeSectionDetector.hasIngredientKeywords(normalized) ||
            RecipeSectionDetector.hasInstructionKeywords(normalized) ||
            RecipeSectionDetector.hasRecipeStructure(normalized));
  }

  @override
  bool validateInput(String input) {
    if (input.trim().isEmpty || input.trim().length < 10) return false;
    return canHandle(input);
  }

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    try {
      final normalized = normalizeText(input);
      final preprocessed = TextImportNormalizer.preprocessText(normalized);

      // Title from `normalized` (pre-preprocess), NOT `preprocessed`: the
      // ingredient/instruction splitters in preprocessText mangle a compound
      // title — "Köttbullar med gräddsås" is torn into "grädd"/"sås" (the
      // section-header suffix split) and "graddsas" into "gr"/"addsas" (the
      // English "Add" instruction cue matched inside the word). The original
      // first line is the real title; the body still parses from `preprocessed`.
      final parsed = await _parseTextToRecipe(preprocessed, normalized);

      if (parsed == null) {
        return ImportResult.failure(
          'Could not parse recipe from text. Please check the format.',
        );
      }

      // BUT-922: persist the original pasted text as the source artefact
      // so re-extract can reparse without asking the user to repaste.
      final recipe = parsed.copyWith(
        sourceArtefact: SourceArtefact(
          type: SourceArtefactType.textPaste,
          payload: input,
          fetchedAt: clock.now(),
        ),
      );

      final warnings = <String>[];
      if (!isValidRecipeName(recipe.title)) {
        warnings.add('Recipe name seems too short or empty');
      }
      if (!isValidIngredients(recipe.ingredients)) {
        warnings.add('No valid ingredients found');
      }
      if (!isValidInstructions(recipe.instructions)) {
        warnings.add('No valid instructions found');
      }

      // BUT-1469: capture a pre-edit snapshot so text-import corrections feed
      // the parser feedback loop. Photo/voice delegate here and then re-tag the
      // snapshot with their own source (same recipe id, last write wins).
      ImportCorrectionSnapshot.capture(recipe, source: ImportSource.text);

      return ImportResult.success(
        recipe,
        warnings: warnings.isNotEmpty ? warnings : null,
        metadata: {
          'strategy': strategyName,
          'textLength': input.length,
          'preprocessedLength': preprocessed.length,
        },
      );
    } catch (e) {
      return ImportResult.failure(
        'Error parsing text: $e',
        metadata: {'strategy': strategyName},
      );
    }
  }

  /// Extract just the ingredient name without measurement for deduplication
  String _extractIngredientNameOnly(String ingredient) {
    final withoutMeasure = ingredient.replaceFirst(
      RegExp(
        r'^\d+(?:[,\.]\d+)?\s*(dl|cl|ml|msk|tsk|krm|g|kg|hg|st|burk|pkt|påse|bit|skiva|klyfta|nypa)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    return withoutMeasure.trim();
  }

  // A yield/portioning label ("2 PORTIONER", "12 STYCKEN") — never a title.
  static final _yieldLabel = RegExp(
    r'^\s*\d*\s*(portion\w*|stycken\w*|pers\w*|bitar|skivor)\b',
    caseSensitive: false,
  );

  // A measurement line ("100 g grönkål", "4 dl mjölk") — an ingredient, not a
  // title. Cookbook OCR routinely surfaces these as the first line.
  static final _measurementLine = RegExp(
    r'\d+\s*(dl|cl|ml|l|kg|hg|g|msk|tsk|krm|st)\b',
    caseSensitive: false,
  );

  // A line that OPENS with a quantity ("1 medelstor morot", "2 boveteflingor",
  // "ca 8 tilapiafiléer") is an ingredient/count line even when the unit is
  // missing or OCR-mangled — the leading "[ca] <number><space>" is the tell,
  // not the unit. Compound numeric titles keep the digit attached
  // ("5-minuters bröd") and so survive.
  static final _leadingQuantity = RegExp(
    r'^\s*(?:ca|cirka|c:a)?\s*\d+(?:[.,/]\d+)?\s+\S',
    caseSensitive: false,
  );

  /// True when a candidate line cannot be a recipe title: a yield label, a
  /// measurement, a quantity-leading line, or an ALL-CAPS label. Surfaced by
  /// the cookbook gold-corpus (the detector kept grabbing "2 PORTIONE",
  /// "100 g grönkål", "1 medelstor morot", "SOM TILLBEHÖR", "CA 12 BITAR").
  /// OCR-corrected first so a misread unit ("2 di" → "2 dl") is still caught.
  bool _looksLikeYieldOrMeasurement(String line) {
    final t = OcrErrorCorrector.correctLine(line.trim());
    // ALL-CAPS lines in cookbooks are labels/sub-headers ("SOM TILLBEHÖR",
    // "TILL FÖRRÄTT", "CA 12 BITAR"), never titles — real titles are Title-Case.
    if (_isAllCapsLabel(t)) return true;
    return _leadingQuantity.hasMatch(t) ||
        _yieldLabel.hasMatch(t) ||
        _measurementLine.hasMatch(t);
  }

  /// A line that is all-uppercase letters (≥2 letters, no lowercase). Cookbook
  /// section labels are set in caps; recipe titles are not.
  bool _isAllCapsLabel(String s) {
    final letters = s.replaceAll(RegExp(r'[^a-zåäöA-ZÅÄÖ]'), '');
    return letters.length >= 2 && s == s.toUpperCase() && s != s.toLowerCase();
  }

  /// Comparison key for the leading-title-fragment skip: letters/digits only,
  /// lower-cased, so "Köttbullar med grädd" + "sås" re-joins to the same key as
  /// "Köttbullar med gräddsås" regardless of the spaces/colons preprocessing
  /// left behind.
  String _titleKey(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9åäö]'), '');

  /// Extract title from Instagram-style text
  String _extractTitleFromText(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';

    String firstLine = lines.first.trim();

    // Skip standalone Instagram username lines (username alone on first line)
    if (_looksLikeInstagramUsername(firstLine) && lines.length > 1) {
      firstLine = lines[1].trim();
    }

    // Remove common Instagram username patterns at start of line
    firstLine = firstLine.replaceFirst(
      RegExp(r'^[a-z_][a-z0-9_\.]*\s+', caseSensitive: true),
      '',
    );

    // Remove emojis
    firstLine = firstLine
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2600}-\u{26FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2700}-\u{27BF}]', unicode: true), '')
        .trim();

    // Take text before first dash (hyphen, en-dash, or em-dash)
    final dashPattern = RegExp(r'[-\u2013\u2014]');
    final dashMatch = dashPattern.firstMatch(firstLine);
    if (dashMatch != null && dashMatch.start > 5 && dashMatch.start < 80) {
      firstLine = firstLine.substring(0, dashMatch.start).trim();
    }

    // Cut at common Instagram intros
    final introPatterns = ['om du', 'spara och', 'prova detta', 'testa detta'];
    for (final pattern in introPatterns) {
      final idx = firstLine.toLowerCase().indexOf(pattern);
      if (idx > 5) {
        firstLine = firstLine.substring(0, idx).trim();
        break;
      }
    }

    // BUT-1727: a RESCUED GLUTEN ROW is never the recipe title. The headerless
    // fallback loop below already skips these, but THIS path runs first and
    // every heuristic here misses them: isSectionHeader's word regex breaks on
    // the trailing colon, and the gluten carve-out deliberately stops "Mjöl:"
    // being a sub-heading. Any such word of 5+ characters ("Mjöl:",
    // "Havregryn:", every *mjöl: compound) would otherwise be consumed as the
    // title AND skipped in STAGE 3, so the gluten row never reaches the flat
    // list the allergen tagging reads.
    //
    // Deliberately NOT also skipping `_ingredientSubHeading` here, even though
    // the fallback loop does. That predicate matches any colon-terminated
    // label of ≤4 digit-free words, which most Swedish dish names satisfy —
    // "Kladdkaka:" as a caption's first line would lose its title entirely and
    // then be promoted to a component section instead. Whether a lone "Deg:"
    // may be a title is a separate, pre-existing question (BUT-1754); it is
    // not an allergen-safety one, so it is not settled at ship time.
    if (_bareGlutenIngredient(firstLine) != null) {
      return '';
    }

    // Validate: reasonable length, not a section header
    if (firstLine.length >= 5 &&
        firstLine.length <= 100 &&
        !_looksLikeYieldOrMeasurement(firstLine) &&
        !RecipeSectionDetector.isIngredientHeader(firstLine.toLowerCase()) &&
        !RecipeSectionDetector.isInstructionHeader(firstLine.toLowerCase()) &&
        !RecipeSectionDetector.isSectionHeader(firstLine)) {
      return firstLine;
    }

    return '';
  }

  /// Check if a line looks like a standalone Instagram username
  bool _looksLikeInstagramUsername(String line) {
    // Instagram usernames: lowercase letters, numbers, underscores, dots
    // Max 30 chars, no spaces
    return line.length <= 30 &&
        !line.contains(' ') &&
        RegExp(r'^[a-z_][a-z0-9_\.]*$', caseSensitive: true).hasMatch(line);
  }

  /// Extract ingredients using measurement-first approach.
  List<String> _extractIngredientsByMeasurement(String text) {
    final ingredients = <String>[];

    final measurementPattern = RegExp(
      r'(\d+(?:[,\.]\d+)?)\s*'
      r'(dl|cl|ml|msk|tsk|krm|g|kg|hg|st|burk|pkt|påse|bit|skiva|klyfta)\s+'
      r'([a-zåäöA-ZÅÄÖ][a-zåäöA-ZÅÄÖ\s\-]{1,40})',
      caseSensitive: false,
    );

    // Process LINE BY LINE (not over the whole blob) so we can:
    //   1. OCR-correct each line — this stage matches a UNIT ALLOWLIST, so a
    //      misread unit ("8 di" → "8 dl") would make the ingredient invisible
    //      (corpus: Grötbas lost "8 di dinkelflingor"/"8 di rågflingor").
    //   2. SKIP instruction lines — their embedded measurement ("Blanda 1 dl
    //      grötbas per portion med 2 1/2 dl vatten") is not an ingredient.
    //      Correcting the unit un-blocks those too, so without this skip the
    //      fix above would just trade missed ingredients for hallucinated ones.
    for (final raw in text.split('\n')) {
      final line = OcrErrorCorrector.correctLine(raw.trim());
      if (line.isEmpty) continue;
      if (RecipeSectionDetector.instructionScore(line) >= 2) continue;

      for (final match in measurementPattern.allMatches(line)) {
        final quantity = match.group(1);
        final unit = match.group(2);
        final name = _cleanIngredientName(match.group(3)!.trim());
        if (name.isNotEmpty) {
          ingredients.add('$quantity $unit $name');
        }
      }
    }

    return ingredients;
  }

  /// Clean ingredient name by removing trailing instruction fragments
  String _cleanIngredientName(String name) {
    name = name.replaceAll(RegExp(r'\d+$'), '').trim();

    final instructionCutoff = RegExp(
      r'\s*(att\s+|gör\s+så|för\s+att|till\s+att|sedan\s+|sen\s+|'
      r'stek|koka|blanda|rör|häll|lägg|skär|servera|värm|vispa|grädda|fräs|'
      r'pensla|strö|toppa|garnera|tillsätt|smält|lös\s+upp|'
      r'degen|smeten|såsen|blandningen)',
      caseSensitive: false,
    );

    final cutoffMatch = instructionCutoff.firstMatch(name);
    if (cutoffMatch != null && cutoffMatch.start > 2) {
      name = name.substring(0, cutoffMatch.start).trim();
    }

    final trailingActions = RegExp(
      r'\s+(stek|koka|blanda|och\s+\w+|i\s+\w+|på\s+\w+|med\s+\w+)$',
      caseSensitive: false,
    );
    name = name.replaceAll(trailingActions, '').trim();
    name = name.replaceAll(RegExp(r'[,\.]+$'), '').trim();

    if (name.length > 25) {
      final spaceIdx = name.lastIndexOf(' ', 25);
      if (spaceIdx > 5) {
        name = name.substring(0, spaceIdx).trim();
      }
    }

    return name;
  }

  /// [text] is the preprocessed body used for ingredient/instruction parsing.
  /// [titleSource] is the pre-preprocess text used ONLY for the title, so the
  /// ingredient/instruction splitters can't truncate a compound title.
  Future<Recipe?> _parseTextToRecipe(String text, String titleSource) async {
    final lines = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;

    final titleLines = titleSource
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    String recipeName = '';
    String description = '';
    final List<String> ingredients = [];
    final List<String> instructions = [];

    // STAGE 1: MEASUREMENT-FIRST INGREDIENT EXTRACTION
    final measurementIngredients = _extractIngredientsByMeasurement(text);
    ingredients.addAll(measurementIngredients);

    final capturedAsIngredient = <String>{};
    for (final ing in measurementIngredients) {
      capturedAsIngredient.add(ing.toLowerCase());
    }

    // STAGE 2: EXTRACT TITLE (from titleSource — the un-mangled original)
    recipeName = _extractTitleFromText(titleSource);

    if (recipeName.isEmpty) {
      for (int i = 0; i < titleLines.length && i < 3; i++) {
        final line = titleLines[i].trim();
        final lowerLine = line.toLowerCase();

        if (line.isEmpty || RecipeSectionDetector.isGarbage(line)) continue;
        if (_looksLikeInstagramUsername(line)) continue;
        if (RecipeSectionDetector.isIngredientHeader(lowerLine) ||
            RecipeSectionDetector.isInstructionHeader(lowerLine)) {
          break;
        }
        if (RecipeSectionDetector.looksLikeIngredient(line)) break;
        // A sub-group heading ("Deg:") is never the recipe title — skip it so
        // it flows to STAGE 3 and is captured as a section. Needed because
        // isSectionHeader ignores it (the trailing colon breaks its word
        // regex), so without this skip a headerless caption whose real title
        // was rejected above would accept "Deg:" as the title at the guard below.
        if (_ingredientSubHeading(line) != null) continue;
        // BUT-1727: the gluten carve-out makes "Råg:" stop being a sub-heading,
        // but it is an INGREDIENT row — never the recipe title. Skip it here
        // too, so refusing the heading can't promote it to a title.
        if (_bareGlutenIngredient(line) != null) continue;

        if (line.length > 2 &&
            line.length < 100 &&
            !RecipeSectionDetector.isSectionHeader(line) &&
            !_looksLikeYieldOrMeasurement(line)) {
          recipeName = line;
          break;
        }
      }
    }

    // STAGE 3: LINE-BY-LINE CLASSIFICATION WITH SCORING
    bool inIngredients = false;
    bool inInstructions = false;
    final seenIngredientSections = <String>{};

    // Current ingredient sub-group heading ("Deg", "Fyllning") and the section
    // each captured ingredient sits under, joined back by ingredient string in
    // STAGE 4. Heading text lives ONLY here / on the structured entry, never in
    // the flat `ingredients` list that allergen tagging reads (safety invariant).
    String? currentSection;
    final sectionByKey = <String, String>{};
    // BUT-1727: lowercased rows kept by the bare-gluten carve-out, so STAGE 4's
    // orphan-fragment filter doesn't discard what STAGE 3 deliberately rescued.
    final rescuedGluten = <String>{};

    // The title now comes from the un-mangled `titleSource`, but the body still
    // carries the preprocessed title — possibly split into fragments
    // ("Köttbullar med grädd" + "sås"). Consume those leading fragments so they
    // don't leak into the description/ingredients: while no real content has
    // been seen, skip lines that keep spelling out the title (letters/digits
    // only, case- and whitespace-insensitive). Bounded to the top, so it can
    // never eat a mid-recipe ingredient that merely echoes a title word.
    final titleKey = _titleKey(recipeName);
    final titleBuffer = StringBuffer();
    bool titleConsumed = titleKey.isEmpty;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lowerLine = line.toLowerCase();

      if (line.isEmpty) continue;
      if (line == recipeName) continue;

      if (!titleConsumed) {
        final lineKey = _titleKey(line);
        if (lineKey.isEmpty) continue; // punctuation-only leftover (":", ".")
        final candidate = titleBuffer.toString() + lineKey;
        if (titleKey == candidate || titleKey.startsWith(candidate)) {
          titleBuffer.write(lineKey);
          if (titleBuffer.toString() == titleKey) titleConsumed = true;
          continue;
        }
        titleConsumed = true; // first non-title line — fall through to parse it
      }

      // Check section headers BEFORE isGarbage. The garbage detector
      // filters short section-header-like strings ("Steg", "Instruktion")
      // as orphan fragments, but that also catches legitimate
      // "Instructions:" / "Ingredients:" markers. Consuming them as
      // section flips first preserves the inIngredients / inInstructions
      // state machine that the rest of the loop depends on.
      if (RecipeSectionDetector.isIngredientHeader(lowerLine)) {
        inIngredients = true;
        inInstructions = false;
        // A fresh ingredient block ("Ingredienser:") clears any sub-group
        // carried over from an earlier block.
        currentSection = null;
        continue;
      }

      if (RecipeSectionDetector.isInstructionHeader(lowerLine)) {
        inIngredients = false;
        inInstructions = true;
        continue;
      }

      // Capture an ingredient sub-group heading ("Deg:", "Fyllning:") so
      // pasted-caption imports keep the same grouping the LLM/OCR tiers
      // produce. Gated on !inInstructions (not inIngredients) because captions
      // routinely omit the top-level "Ingredienser:" marker and jump straight
      // to "Deg:". Stored only in currentSection (stamped onto the structured
      // entries below) — the heading line is dropped here via `continue`, so it
      // never reaches the flat `ingredients` list that allergen tagging reads.
      if (!inInstructions) {
        final subHeading = _ingredientSubHeading(line);
        if (subHeading != null) {
          currentSection = subHeading;
          continue;
        }

        // BUT-1727: the carve-out's other half — keep the refused gluten line
        // as an ingredient instead of letting the garbage/orphan-fragment
        // filters below swallow it. Guessing "ingredient" only adds a noisy
        // row; guessing "heading" loses the gluten from the tagging input.
        final glutenIngredient = _bareGlutenIngredient(line);
        if (glutenIngredient != null) {
          final key = glutenIngredient.toLowerCase();
          if (!capturedAsIngredient.contains(key)) {
            ingredients.add(glutenIngredient);
            capturedAsIngredient.add(key);
            rescuedGluten.add(key);
          }
          if (currentSection != null) {
            sectionByKey.putIfAbsent(key, () => currentSection!);
          }
          continue;
        }
      }

      if (RecipeSectionDetector.isGarbage(line)) continue;

      if (RecipeSectionDetector.isSectionHeader(line)) {
        final headerKey = lowerLine.trim();

        if (RecipeSectionDetector.isInstructionSectionHeader(lowerLine)) {
          inIngredients = false;
          inInstructions = true;
          continue;
        }

        if (seenIngredientSections.contains(headerKey)) {
          inIngredients = false;
          inInstructions = true;
          continue;
        }

        if (RecipeSectionDetector.followingTextIsInstruction(lines, i)) {
          inIngredients = false;
          inInstructions = true;
          continue;
        }

        if (inIngredients) {
          seenIngredientSections.add(headerKey);
        }
        continue;
      }

      final score = RecipeSectionDetector.instructionScore(line);

      if (inIngredients) {
        if (RecipeSectionDetector.isValidIngredient(line)) {
          final ingredient = _parseIngredientLine(line);
          if (ingredient != null) {
            if (!capturedAsIngredient.contains(lowerLine)) {
              ingredients.add(ingredient);
              capturedAsIngredient.add(ingredient.toLowerCase());
            }
            // Record the current sub-group for this line's STRUCTURED entry.
            // Lines already captured measurement-first in STAGE 1 still get
            // their section here; the flat list is left untouched. Two
            // identical lines under different headings take the first
            // (putIfAbsent) — cosmetic only, sections never touch tagging.
            if (currentSection != null) {
              sectionByKey.putIfAbsent(
                ingredient.toLowerCase(),
                () => currentSection!,
              );
            }
          }
        }
        continue;
      }

      if (inInstructions) {
        final instruction = _parseInstructionLine(line);
        if (instruction != null && instruction.length > 10) {
          instructions.add(instruction);
        }
        continue;
      }

      if (score >= 2) {
        final instruction = _parseInstructionLine(line);
        if (instruction != null && instruction.length > 10) {
          instructions.add(instruction);
        }
      } else if (RecipeSectionDetector.looksLikeIngredient(line)) {
        final ingredient = _parseIngredientLine(line);
        if (ingredient != null &&
            RecipeSectionDetector.isValidIngredient(ingredient)) {
          if (!capturedAsIngredient.contains(lowerLine)) {
            ingredients.add(ingredient);
            capturedAsIngredient.add(ingredient.toLowerCase());
          }
          // Stamp the current sub-group even for lines already captured
          // measurement-first in STAGE 1 (the common headerless-caption path).
          if (currentSection != null) {
            sectionByKey.putIfAbsent(
              ingredient.toLowerCase(),
              () => currentSection!,
            );
          }
        }
      } else if (description.isEmpty && line.length > 10 && score < 1) {
        description = line;
      }
    }

    // STAGE 4: FINAL CLEANUP
    final cleanedIngredients = _deduplicateIngredients(
      ingredients,
      exemptFromFilters: rescuedGluten,
    );
    final cleanedInstructions = instructions
        .where((i) => !RecipeSectionDetector.isGarbage(i) && i.length > 10)
        .toList();

    // CRIT-12: Log warning when no ingredients/instructions found instead of
    // inserting placeholder strings that confuse the tagging system
    if (cleanedIngredients.isEmpty) {
      AppLogger.warning(
        'CRIT-12: No ingredients extracted from text import for "$recipeName"',
        'TextImportStrategy',
      );
    }
    if (cleanedInstructions.isEmpty) {
      AppLogger.warning(
        'CRIT-12: No instructions extracted from text import for "$recipeName"',
        'TextImportStrategy',
      );
    }

    final portions = _extractPortions(text);
    final timeMinutes = _extractTime(text);
    final rating = extractRating(text);
    final mealType = _guessMealType(text);

    final structuredIngredients = await _structuredIngredients(
      cleanedIngredients,
      sectionByKey,
    );

    return Recipe(
      core: RecipeCore(
        id: _uuid.v4(),
        title: recipeName,
        description: description,
        // CRIT-12: Use empty list instead of fake placeholder
        // Tagging system will handle empty ingredients correctly via TagResult.empty()
        ingredients: cleanedIngredients,
        structuredIngredients: structuredIngredients,
        instructions: cleanedInstructions,
        imageUrls: [],
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        personalTagIds: _extractTags(text),
        sourceUrl: AppLocale.current.textImportSourceUrl,
        createdAt: clock.now(),
        updatedAt: clock.now(),
        createdBy: '',
      ),
      type: RecipeType.personal,
    );
  }

  /// Deduplicate ingredients, keeping the most complete version.
  /// [exemptFromFilters] holds lowercased entries that skip the garbage /
  /// orphan-fragment filters AND the substring-containment rule below, but are
  /// still deduplicated by exact name.
  List<String> _deduplicateIngredients(
    List<String> ingredients, {
    Set<String> exemptFromFilters = const {},
  }) {
    final cleanedIngredients = <String>[];
    final seenNames = <String>[];
    // Index-aligned with [seenNames]: whether that kept row was rescued.
    final seenRescued = <bool>[];

    for (final ing in ingredients) {
      // BUT-1727: a rescued bare gluten row ("Råg") is a single short word, so
      // both filters below read it as an orphan fragment and would undo the
      // carve-out one stage after it fired. It is exempt from them — but not
      // from exact-name dedup, so a fuller "2 dl råg" row still wins.
      final isRescuedGluten = exemptFromFilters.contains(ing.toLowerCase());
      if (!isRescuedGluten &&
          (RecipeSectionDetector.isGarbage(ing) ||
              !RecipeSectionDetector.isValidIngredient(ing))) {
        continue;
      }

      final normalized = ing.toLowerCase().trim();
      final ingName = _extractIngredientNameOnly(normalized);

      var isDuplicate = false;
      var replaceIndex = -1;

      for (var i = 0; i < seenNames.length; i++) {
        final existingName = seenNames[i];

        if (existingName == ingName) {
          isDuplicate = true;
          break;
        }

        // BUT-1727 review: containment was the second half of the swallow the
        // rescue exists to stop. The rescued row is a bare stem, so ANY longer
        // ingredient name containing it — "potatismjöl" over "Mjöl",
        // "bovetemjöl" over "Vete", "majskorn" over "Korn" — deleted the gluten
        // row while the swallower is itself gluten-FREE, moving the recipe from
        // UNKNOWN to a false-negative FREE. Skipping the branch in BOTH
        // directions (the rescued row can be either side, since STAGE 3 rows
        // interleave with STAGE 1 rows) is the whole fix; exact-name dedup
        // above still collapses "Råg:" into "2 dl råg". Scanning continues
        // rather than breaking, so a later exact match is still found.
        if (isRescuedGluten || seenRescued[i]) continue;

        if (existingName.contains(ingName) || ingName.contains(existingName)) {
          if (ingName.length > existingName.length) {
            replaceIndex = i;
          } else {
            isDuplicate = true;
          }
          break;
        }
      }

      if (!isDuplicate) {
        if (replaceIndex >= 0) {
          cleanedIngredients[replaceIndex] = ing;
          seenNames[replaceIndex] = ingName;
          seenRescued[replaceIndex] = isRescuedGluten;
        } else {
          cleanedIngredients.add(ing);
          seenNames.add(ingName);
          seenRescued.add(isRescuedGluten);
        }
      }
    }

    return cleanedIngredients;
  }

  /// A colon-terminated ingredient sub-group heading ("Deg:", "Fyllning:",
  /// "Glasyr:") — the explicit caption form the LLM/OCR tiers already capture.
  /// Returns the cleaned label, or null when [line] is not such a heading.
  /// Deliberately narrow: requires the trailing colon and rejects anything
  /// numbered, measured, or that reads as an instruction cue, so the ingredient
  /// scoring below is untouched for every other line.
  String? _ingredientSubHeading(String line) {
    final trimmed = line.trim();
    if (!trimmed.endsWith(':')) return null;
    final label = trimmed.substring(0, trimmed.length - 1).trim();
    if (label.isEmpty || label.length > 30) return null;
    if (label.split(RegExp(r'\s+')).length > 4) return null;
    if (RegExp(r'\d').hasMatch(label)) return null;
    // BUT-1727: the SAME carve-out RecipeSectionDetector applies (BUT-1714) —
    // a lone gluten word plus a colon ("Råg:", "Havregryn:") is as likely an
    // OCR'd ingredient row whose quantity landed in another column as it is a
    // component heading, and a heading is pulled OUT of the flat list allergen
    // tagging reads. The shared list is the single source of truth so the
    // pasted/photo/voice path can never drift from the detector's.
    if (HeadingWordLists.isBareGlutenWord(label)) return null;
    final lower = label.toLowerCase();
    // A top-level marker, an instruction cue, or a real ingredient is not a
    // sub-group heading.
    if (RecipeSectionDetector.isIngredientHeader(lower)) return null;
    if (RecipeSectionDetector.isInstructionSectionHeader(lower)) return null;
    if (RecipeSectionDetector.isInstructionHeader(lower)) return null;
    if (RecipeSectionDetector.looksLikeIngredient(label)) return null;
    return label;
  }

  /// BUT-1727: the ingredient text to KEEP for a colon-terminated line the
  /// carve-out in [_ingredientSubHeading] refuses ("Råg:" → "Råg"), or null
  /// when [line] is not one.
  ///
  /// Refusing the heading is not enough on its own: "Råg:" is four characters,
  /// so `isValidIngredient` drops it as an orphan fragment and the gluten is
  /// lost anyway. This re-injects it directly, colon-STRIPPED — lookup folds
  /// diacritics but strips no punctuation, so "Mjöl:" would query `mjol:`,
  /// match no registry document and take every allergen verdict on the recipe
  /// to UNKNOWN. Colon-only by design: the accepted deviation covers the
  /// colon-terminated form, and a colon-less bare word keeps the long-standing
  /// orphan-fragment handling.
  String? _bareGlutenIngredient(String line) {
    final trimmed = line.trim();
    if (!trimmed.endsWith(':')) return null;
    return RecipeSectionDetector.bareGlutenIngredientLabel(trimmed);
  }

  /// Section labels index-aligned with [ingredients] for
  /// `StructuredIngredientDeriver.deriveAll`, or null when no line was grouped
  /// (so the deriver skips the section pass entirely). Joined by the parsed
  /// ingredient string; an unmatched line degrades to no section, never a
  /// wrong one. The join lands only when STAGE 1's measurement-first string and
  /// STAGE 3's `_parseIngredientLine` output render identically for the same
  /// source line (they do for clean caption lines); on divergence the section
  /// is silently dropped for that line — safe, since it can never mislabel.
  List<String?>? _sectionsFor(
    List<String> ingredients,
    Map<String, String> sectionByKey,
  ) {
    if (sectionByKey.isEmpty) return null;
    final sections = [
      for (final ing in ingredients) sectionByKey[ing.toLowerCase()],
    ];
    return sections.any((s) => s != null) ? sections : null;
  }

  /// BUT-1501: structured (amount/unit/name) form for the final cleaned
  /// ingredient strings. Runs the shared CRF → BERT NER cascade — the SAME
  /// parser URL imports get (BUT-1216) — when [IngredientParsingStrategy] is
  /// registered, so pasted / photo / voice imports (which delegate here) reach
  /// model-quality parsing instead of only the regex deriver (BUT-1232).
  ///
  /// SAFETY: this only ever populates the ADDITIVE `structuredIngredients`
  /// field. The flat `ingredients` list that allergen tagging reads is passed
  /// through untouched by the caller — the cascade never sees it. The
  /// `raw == ingredients[i]` alignment invariant is preserved by forcing each
  /// entry's `raw` to the exact cleaned string, and sub-group sections are
  /// stamped identically to the deriver path. Best-effort: any absence or
  /// failure falls back to the deterministic, synchronous regex deriver, so
  /// behaviour is never worse than before.
  Future<List<RecipeIngredient>?> _structuredIngredients(
    List<String> cleaned,
    Map<String, String> sectionByKey,
  ) async {
    if (cleaned.isEmpty) return null;

    final sections = _sectionsFor(cleaned, sectionByKey);

    final strategy = _ingredientStrategy;
    if (strategy != null) {
      try {
        // Lines are already OCR-corrected during extraction — don't re-correct
        // (would drift `raw` off the flat `ingredients[i]` string).
        final field = await strategy.parseLines(cleaned);
        final parsed = field.value;
        if (parsed != null && parsed.length == cleaned.length) {
          // Fold in BERT NER for low-confidence CRF lines (mutates in place).
          final growable = List<ParsedIngredient>.from(parsed);
          await strategy.getUncertainLines(growable, cleaned);
          return [
            for (var i = 0; i < cleaned.length; i++)
              _structuredFrom(growable[i], cleaned[i], sections?[i]),
          ];
        }
      } catch (e) {
        AppLogger.debug('TextImportStrategy: CRF/NER cascade skipped: $e');
      }
    }

    return StructuredIngredientDeriver.deriveAll(cleaned, sections: sections);
  }

  /// Convert one cascade result to a persisted entry, forcing [raw] to the
  /// exact flat-list string (alignment invariant) and stamping the caption
  /// [section] (authoritative over any section the parser inferred).
  RecipeIngredient _structuredFrom(
    ParsedIngredient parsed,
    String raw,
    String? section,
  ) {
    final base = RecipeIngredient.fromParsed(parsed);
    return RecipeIngredient(
      amount: base.amount,
      unit: base.unit,
      name: base.name,
      note: base.note,
      raw: raw,
      section: RecipeIngredient.normalizeSection(section),
    );
  }

  String? _parseIngredientLine(String line) {
    String cleaned = line
        .replaceAll(RegExp(r'^[•\-\*]+\s*|^\d+\.\s*'), '')
        .trim();

    if (cleaned.isEmpty) return null;

    cleaned = cleaned.replaceAll(RegExp(r'^-\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^\*\s*'), '');
    cleaned = IngredientProcessor.preprocessOnly(cleaned);
    // Repair systematic OCR misreads (e.g. "4 di" -> "4 dl"). Gate-safe: only
    // swaps a token when the result is a known unit/ingredient, so clean
    // manual/social input is left untouched.
    cleaned = OcrErrorCorrector.correctLine(cleaned);

    cleaned = cleaned.replaceAll('1/2', '½');
    cleaned = cleaned.replaceAll('1/4', '¼');
    cleaned = cleaned.replaceAll('3/4', '¾');

    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\d+)([a-zA-ZåäöÅÄÖ]+)'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    return cleaned;
  }

  String? _parseInstructionLine(String line) {
    String cleaned = line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[•\-\*]\s*'), '').trim();

    if (cleaned.isEmpty) return null;

    if (cleaned.isNotEmpty && cleaned[0] == cleaned[0].toLowerCase()) {
      cleaned = '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
    }

    if (!cleaned.endsWith('.') &&
        !cleaned.endsWith('!') &&
        !cleaned.endsWith('?')) {
      cleaned += '.';
    }

    return cleaned;
  }

  int? _extractPortions(String text) {
    final patterns = [
      RegExp(r'portioner?\s*:\s*(\d+)', caseSensitive: false),
      RegExp(r'servings?\s*:\s*(\d+)', caseSensitive: false),
      RegExp(r'(\d+)\s*portion'),
      RegExp(r'för\s*(\d+)'),
      RegExp(r'(\d+)\s*pers'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text.toLowerCase());
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }

    return null;
  }

  int? _extractTime(String text) {
    final patterns = [
      RegExp(r'tid\s*:\s*(\d+)\s*min', caseSensitive: false),
      RegExp(r'tid\s*:\s*(\d+)\s*timm?', caseSensitive: false),
      RegExp(r'time\s*:\s*(\d+)\s*min', caseSensitive: false),
      RegExp(r'(\d+)\s*min'),
      RegExp(r'(\d+)\s*timm'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text.toLowerCase());
      if (match != null) {
        final time = int.tryParse(match.group(1)!);
        if (pattern.pattern.contains('timm') && time != null) {
          return time * 60;
        }
        return time;
      }
    }

    return null;
  }

  String _guessMealType(String text) {
    final lowerText = text.toLowerCase();

    // Check label format first
    if (RegExp(
      r'typ\s*:\s*frukost',
      caseSensitive: false,
    ).hasMatch(lowerText)) {
      return 'Frukost';
    }
    if (RegExp(
      r'typ\s*:\s*huvudrätt',
      caseSensitive: false,
    ).hasMatch(lowerText)) {
      return 'Huvudrätt';
    }
    if (RegExp(r'typ\s*:\s*lunch', caseSensitive: false).hasMatch(lowerText)) {
      return 'Lunch';
    }
    if (RegExp(r'typ\s*:\s*middag', caseSensitive: false).hasMatch(lowerText)) {
      return 'Middag';
    }
    if (RegExp(
      r'typ\s*:\s*(dessert|efterrätt)',
      caseSensitive: false,
    ).hasMatch(lowerText)) {
      return 'Dessert';
    }
    if (RegExp(r'typ\s*:\s*fika', caseSensitive: false).hasMatch(lowerText)) {
      return 'Fika';
    }

    // Check inline text
    if (lowerText.contains('frukost') || lowerText.contains('fralla')) {
      return 'Frukost';
    }
    if (lowerText.contains('lunch')) return 'Lunch';
    if (lowerText.contains('middag')) return 'Middag';
    if (lowerText.contains('huvudrätt')) return 'Huvudrätt';
    if (lowerText.contains('dessert') || lowerText.contains('efterrätt')) {
      return 'Dessert';
    }
    if (lowerText.contains('fika') || lowerText.contains('kaka')) {
      return 'Fika';
    }

    return 'Lunch';
  }

  List<String> _extractTags(String text) {
    final tags = <String>[];
    final lowerText = text.toLowerCase();

    if (lowerText.contains('vegetarisk')) tags.add('Vegetarisk');
    if (lowerText.contains('vegan')) tags.add('Vegan');
    if (lowerText.contains('glutenfri')) tags.add('Glutenfri');
    if (lowerText.contains('snabb')) tags.add('Snabb');
    if (lowerText.contains('lätt')) tags.add('Lätt');
    if (lowerText.contains('barn')) tags.add('Barnvänlig');

    return tags;
  }
}
