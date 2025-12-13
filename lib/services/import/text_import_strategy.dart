/// Text Import Strategy - Parses structured/unstructured text into recipes (social media, manual input).

import 'package:uuid/uuid.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/utils/text/ingredient_processor.dart';

/// Strategy for importing recipes from text (social media, manual input, structured/unstructured text).
class TextImportStrategy extends ImportStrategy with ImportValidationMixin {
  static const _uuid = Uuid();

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
        (_hasIngredientKeywords(normalized) ||
            _hasInstructionKeywords(normalized) ||
            _hasRecipeStructure(normalized));
  }

  @override
  bool validateInput(String input) {
    if (input.trim().isEmpty || input.trim().length < 10) return false;
    return canHandle(input);
  }

  @override
  Future<ImportResult> import(String input,
      {Map<String, dynamic>? options}) async {
    try {
      final normalized = normalizeText(input);
      final preprocessed = _preprocessText(normalized);

      final recipe = _parseTextToRecipe(preprocessed);

      if (recipe == null) {
        return ImportResult.failure(
          'Could not parse recipe from text. Please check the format.',
        );
      }

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

  bool _hasIngredientKeywords(String text) {
    final keywords = [
      'ingrediens',
      'råvaror',
      'behöver',
      'du behöver är',
      'ingredients',
      'what you need',
    ];
    return keywords
        .any((keyword) => text.toLowerCase().contains(keyword.toLowerCase()));
  }

  bool _hasInstructionKeywords(String text) {
    final keywords = [
      'gör så här',
      'instruktion',
      'tillredning',
      'steg',
      'börja med',
      'sätt ugnen',
      'instructions',
      'method',
      'koka',
      'stek',
      'blanda',
      'rör'
    ];
    return keywords
        .any((keyword) => text.toLowerCase().contains(keyword.toLowerCase()));
  }

  bool _hasRecipeStructure(String text) {
    // Check for numbered lists (1., 2., etc.)
    if (RegExp(r'\d+\.\s+').hasMatch(text)) return true;

    // Check for bullet points
    if (RegExp(r'[•-]\s+').hasMatch(text)) return true;

    // Check for measurement patterns
    if (RegExp(r'\d+\s*(dl|cl|ml|kg|g|msk|tsk|st)').hasMatch(text)) return true;

    return false;
  }

  // Temporary marker for protected decimals (Unicode BLACK CIRCLE)
  static const _decimalMarker = '⬤';

  /// Protect decimal numbers from being corrupted by sentence splitting.
  /// Example: "0.75 dl" → "0⬤75 dl" (protected)
  String _protectDecimals(String text) {
    return text.replaceAllMapped(
      RegExp(r'(\d)\.(\d)'),
      (m) => '${m.group(1)}$_decimalMarker${m.group(2)}',
    );
  }

  /// Restore protected decimals back to normal.
  /// Example: "0⬤75 dl" → "0.75 dl"
  String _restoreDecimals(String text) {
    return text.replaceAll(_decimalMarker, '.');
  }

  /// Smart sentence splitting that respects decimals and Swedish patterns.
  /// Splits at periods ONLY when followed by sentence boundaries.
  String _smartSentenceSplit(String text) {
    // Step 1: Protect decimals FIRST
    String result = _protectDecimals(text);

    // Step 2: Also protect common abbreviations
    result = result.replaceAll('ca.', 'ca⬛');
    result = result.replaceAll('ev.', 'ev⬛');
    result = result.replaceAll('st.', 'st⬛');
    result = result.replaceAll('t.ex.', 't⬛ex⬛');

    // Step 3: Split at period + space + capital letter (new sentence)
    result = result.replaceAllMapped(
      RegExp(r'\.(\s*)([A-ZÅÄÖ])'),
      (m) => '.\n${m.group(2)}',
    );

    // Step 4: Split at period followed immediately by Swedish action verbs
    // These indicate a new instruction is starting
    const actionWords =
        'stek|koka|blanda|rör|häll|lägg|skär|servera|värm|vispa|grädda|fräs|'
        'sjud|tillsätt|smaksätt|strö|vänd|ta|låt|förvärm|sätt|börja|gör|ställ|'
        'skala|hacka|riv|strimla|marinera|krydda|toppa|garnera';
    result = result.replaceAllMapped(
      RegExp('\\.($actionWords)', caseSensitive: false),
      (m) => '.\n${m.group(1)}',
    );

    // Step 5: Restore protected abbreviations
    result = result.replaceAll('ca⬛', 'ca.');
    result = result.replaceAll('ev⬛', 'ev.');
    result = result.replaceAll('st⬛', 'st.');
    result = result.replaceAll('t⬛ex⬛', 't.ex.');

    // Step 6: Restore decimals
    result = _restoreDecimals(result);

    return result;
  }

  /// Split concatenated ingredient text that lacks line breaks.
  /// Common in Instagram captions where ingredients run together.
  /// Example: "oystersås2 msk japansk soya1 msk" → "oystersås\n2 msk japansk soya\n1 msk"
  String _splitConcatenatedIngredients(String text) {
    // CRITICAL: Protect decimals before ANY regex processing
    String result = _protectDecimals(text);

    // Pattern 1: Split before measurements when preceded by word characters
    // Match: letters followed directly by digit + measurement unit
    // Example: "oystersås2 msk" → "oystersås\n2 msk"
    // Example: "strösocker500 g" → "strösocker\n500 g"
    result = result.replaceAllMapped(
      RegExp(
        '([a-zåäöA-ZÅÄÖ]{2,})(\\d+(?:[⬤,]\\d+)?\\s*(?:dl|cl|ml|msk|tsk|krm|g|kg|hg|st|burk|pkt|påse|bit|skiva|klyfta|klyft)\\b)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}\n${m.group(2)}',
    );

    // Pattern 2: Split before Swedish recipe section headers
    // Example: "...pepparbiffen500 g" → "...peppar\nbiffen\n500 g"
    // Example: "...sockersås0.75 dl" → "...socker\nsås\n0.75 dl"
    result = result.replaceAllMapped(
      RegExp(
        r'([a-zåäö])(sås|såsen|biffen|övrigt|marinaden|gräddsåsen|till servering|kycklingen|fisken|köttet|grönsakerna|woka ihop|servera)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}\n${m.group(2)}\n',
    );

    // Pattern 3: Split before "X portioner" patterns mid-text
    // Example: "recept4 portioner" → "recept\n4 portioner"
    result = result.replaceAllMapped(
      RegExp(r'([a-zåäö]{2,})\s*(\d+\s*portioner?\b)', caseSensitive: false),
      (m) => '${m.group(1)}\n${m.group(2)}',
    );

    // Pattern 3b: Split AFTER "X portioner" when followed by uppercase (section header)
    // Example: "4 portionerSÅS" → "4 portioner\nSÅS"
    result = result.replaceAllMapped(
      RegExp(r'(\d+\s*portioner?)\s*([A-ZÅÄÖ])', caseSensitive: false),
      (m) => '${m.group(1)}\n${m.group(2)}',
    );

    // Pattern 4: Split when a digit+unit is immediately followed by another digit
    // Example: "2 msk soya1 tsk" → "2 msk soya\n1 tsk"
    result = result.replaceAllMapped(
      RegExp(
        r'(\d+\s*(?:dl|cl|ml|msk|tsk|krm|g|kg|hg|st|burk|pkt)\s+[a-zåäöA-ZÅÄÖ]+)(\d+\s*(?:dl|cl|ml|msk|tsk|krm|g|kg|hg|st|burk|pkt)\b)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}\n${m.group(2)}',
    );

    // Pattern 5: Split ALL CAPS section header from following content
    // Example: "BIFFENStrimla biffen" → "BIFFEN\nStrimla biffen"
    // Example: "WOKA IHOPStek biffen" → "WOKA IHOP\nStek biffen"
    // Note: Following word often starts with uppercase (sentence case), so we match
    // uppercase letter followed by lowercase letter to detect word boundary
    result = result.replaceAllMapped(
      RegExp(r'([A-ZÅÄÖ]{2,15}(?:\s+[A-ZÅÄÖ]+)?)([A-ZÅÄÖ])([a-zåäö])'),
      (m) => '${m.group(1)}\n${m.group(2)}${m.group(3)}',
    );

    // Restore decimals at the end
    result = _restoreDecimals(result);

    return result;
  }

  String _preprocessText(String input) {
    String processed = input;

    // Stage 1: Smart sentence splitting with decimal protection
    processed = _smartSentenceSplit(processed);

    // Stage 2: Split concatenated ingredients (handles Instagram text without line breaks)
    processed = _splitConcatenatedIngredients(processed);

    // Clean up social media formatting
    processed = _cleanSocialMediaFormatting(processed);

    // Add line breaks after common ingredient headers
    processed = processed.replaceAllMapped(
      RegExp(
        r'(behöver är|ingredienser|du behöver|ingredients|what you need|shopping list)',
        caseSensitive: false,
      ),
      (match) => '${match.group(0)}\n',
    );

    // Normalize instruction header variants before adding line breaks
    processed = processed.replaceAll(
      RegExp(r'gör\s*så\s*här', caseSensitive: false),
      'gör så här',
    );

    // Add line breaks after instruction headers
    processed = processed.replaceAllMapped(
      RegExp(
        r'(gör så här|gör såhär|instruktion|tillredning|tillagning|steg|instructions|method|directions|preparation)',
        caseSensitive: false,
      ),
      (match) => '${match.group(0)}\n',
    );

    // Add line breaks before common instruction words
    processed = processed.replaceAllMapped(
      RegExp(
        r'(Börja med|Sätt ugnen|Koka|Stek|Blanda|Häll|Lägg|Skär|Servera|Värm|Rör|Start by|Preheat|Cook|Fry|Mix|Pour|Add|Cut|Serve|Heat|Stir)',
        caseSensitive: false,
      ),
      (match) => '\n${match.group(0)}',
    );

    // Fix measurement formatting (e.g., "2dl" -> "2 dl")
    processed = processed.replaceAllMapped(
      RegExp(r'(\d+(?:[,\.]\d+)?)(dl|cl|ml|kg|g|msk|tsk|st|krm)'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    // Normalize line breaks
    processed = processed.replaceAll(RegExp(r'\n+'), '\n');

    return processed.trim();
  }

  /// Clean up common social media formatting issues
  String _cleanSocialMediaFormatting(String text) {
    String processed = text;

    // Remove emoji separators but keep recipe emojis
    processed = processed.replaceAll(RegExp(r'[🔥💥✨🌟⭐]+'), '');

    // Clean up excessive punctuation
    processed = processed.replaceAll(RegExp(r'[!]{2,}'), '!');
    processed = processed.replaceAll(RegExp(r'[.]{3,}'), '...');

    // Remove hashtags but keep the content
    processed = processed.replaceAll(RegExp(r'#\w+'), '');

    // Clean up multiple spaces
    processed = processed.replaceAll(RegExp(r' {2,}'), ' ');

    // Remove Instagram/Facebook line separators
    processed =
        processed.replaceAll(RegExp(r'^[-_=]{3,}$', multiLine: true), '');

    return processed;
  }

  /// Known recipe section headers in Swedish
  static const _sectionHeaders = {
    // Ingredient sections
    'såsen',
    'sås',
    'biffen',
    'marinaden',
    'kycklingen',
    'grönsakerna',
    'övrigt',
    'fisken',
    'köttet',
    'gräddsåsen',
    'till servering',
    // Instruction sections
    'gör så här',
    'tillagning',
    'instruktioner',
    'woka ihop',
    'servera',
  };

  /// Section headers that indicate INSTRUCTIONS (not ingredients)
  static const _instructionSectionHeaders = {
    'woka ihop',
    'servera',
    'gör så här',
    'gör såhär', // variant without space
    'gör så',
    'tillagning',
    'tillaga',
    'förbered',
    'instruktioner',
    'steg',
    'övrigt', // often contains final instructions
  };

  /// Check if text is a section header (like "biffen", "såsen")
  bool _isSectionHeader(String text) {
    final clean = text.toLowerCase().trim();
    // Check known headers
    if (_sectionHeaders.contains(clean)) return true;
    // Single word < 15 chars that could be a component name
    if (clean.length < 15 &&
        !clean.contains(' ') &&
        RegExp(r'^[a-zåäö]+$').hasMatch(clean)) {
      return true;
    }
    return false;
  }

  /// Detect garbage/invalid text fragments
  bool _isGarbage(String text) {
    final clean = text.trim();

    // Too short
    if (clean.length < 3) return true;

    // Just "na" or punctuation fragments (common Instagram artifact)
    if (RegExp(r'^[na\.\s,]+$', caseSensitive: false).hasMatch(clean)) {
      return true;
    }

    // Malformed metadata like "Ingrediens 32"
    if (RegExp(r'^ingrediens\s*\d+$', caseSensitive: false).hasMatch(clean)) {
      return true;
    }

    // "Instruktion" alone or with just numbers
    if (RegExp(r'^instruktion\s*\d*$', caseSensitive: false).hasMatch(clean)) {
      return true;
    }

    // Section headers that are too short (orphaned)
    if (_isSectionHeader(clean) && clean.length < 20) return true;

    // "X portioner" should not be an ingredient
    if (RegExp(r'^\d+\s*portioner?$', caseSensitive: false).hasMatch(clean)) {
      return true;
    }

    return false;
  }

  /// Extract just the ingredient name without measurement for deduplication
  /// E.g., "1 påse vörtmix" → "vörtmix", "6 dl mjölk" → "mjölk"
  String _extractIngredientNameOnly(String ingredient) {
    // Remove leading measurement pattern
    final withoutMeasure = ingredient.replaceFirst(
      RegExp(
        r'^\d+(?:[,\.]\d+)?\s*(dl|cl|ml|msk|tsk|krm|g|kg|hg|st|burk|pkt|påse|bit|skiva|klyfta|nypa)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    return withoutMeasure.trim();
  }

  /// Extract title from Instagram-style text
  /// Handles format: "username Recipe title here - description..."
  String _extractTitleFromText(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';

    String firstLine = lines.first.trim();

    // Remove common Instagram username patterns at start (lowercase word followed by space)
    firstLine = firstLine.replaceFirst(
      RegExp(r'^[a-z_][a-z0-9_\.]*\s+', caseSensitive: true),
      '',
    );

    // Remove emojis (common Unicode emoji ranges)
    firstLine = firstLine
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2600}-\u{26FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2700}-\u{27BF}]', unicode: true), '')
        .trim();

    // Take text before first hyphen if it exists (often intro text follows)
    final dashIndex = firstLine.indexOf('-');
    if (dashIndex > 5 && dashIndex < 80) {
      firstLine = firstLine.substring(0, dashIndex).trim();
    }

    // Or take text before "Om du" / "Spara" which are common Instagram intros
    final introPatterns = ['om du', 'spara och', 'prova detta', 'testa detta'];
    for (final pattern in introPatterns) {
      final idx = firstLine.toLowerCase().indexOf(pattern);
      if (idx > 5) {
        firstLine = firstLine.substring(0, idx).trim();
        break;
      }
    }

    // Validate: reasonable length, not a section header, not garbage
    if (firstLine.length >= 5 &&
        firstLine.length <= 100 &&
        !_isIngredientHeader(firstLine.toLowerCase()) &&
        !_isInstructionHeader(firstLine.toLowerCase()) &&
        !_isSectionHeader(firstLine)) {
      return firstLine;
    }

    return '';
  }

  /// Check if a section header indicates instruction content
  bool _isInstructionSectionHeader(String header) {
    final clean = header.toLowerCase().trim();
    return _instructionSectionHeaders.contains(clean);
  }

  /// Check if following text looks like instructions (for section header detection)
  bool _followingTextIsInstruction(List<String> lines, int currentIndex) {
    // Look at next 1-3 non-empty, non-header lines
    for (int j = currentIndex + 1; j < lines.length && j < currentIndex + 4; j++) {
      final nextLine = lines[j].trim();
      if (nextLine.isEmpty) continue;
      if (_isSectionHeader(nextLine)) continue;

      // Check if this looks like instruction text
      final score = _instructionScore(nextLine);
      if (score >= 2) return true;
      if (nextLine.length > 50) return true; // Long text = likely instruction

      break; // Only check first substantive line
    }
    return false;
  }

  /// Validate if text is a valid ingredient
  bool _isValidIngredient(String text) {
    // Must have reasonable length
    if (text.length < 3 || text.length > 100) return false;

    // Reject if it contains instruction phrases
    if (RegExp(
      r'(gör\s+så|att\s+pensla|att\s+strö|att\s+servera|'
      r'lös\s+upp|degen|smeten|blandningen|efter\s+gräddning)',
      caseSensitive: false,
    ).hasMatch(text)) {
      return false;
    }

    // Reject orphan fragments (single short words without measurements)
    if (text.length < 6 &&
        !text.contains(RegExp(r'\d')) &&
        text.split(' ').length == 1) {
      return false;
    }

    // Should contain a measurement OR be a simple ingredient like "salt, peppar"
    final hasMeasurement = RegExp(
      r'\d+(?:[,\.]\d+)?\s*(dl|cl|ml|msk|tsk|krm|g|kg|hg|st|burk|pkt|påse|bit|skiva|klyfta)',
      caseSensitive: false,
    ).hasMatch(text);

    // Simple ingredients: short, no periods suggesting sentences
    final isSimpleIngredient =
        text.length < 30 && !text.contains('. ') && !_isSectionHeader(text);

    return hasMeasurement || isSimpleIngredient;
  }

  /// Calculate instruction likelihood score
  int _instructionScore(String text) {
    int score = 0;
    final lower = text.toLowerCase();

    // +3: Starts with Swedish action verb
    final actionVerbs = [
      'stek',
      'koka',
      'blanda',
      'rör',
      'häll',
      'lägg',
      'skär',
      'servera',
      'värm',
      'vispa',
      'grädda',
      'fräs',
      'sjud',
      'tillsätt',
      'smaksätt',
      'strö',
      'vänd',
      'ta',
      'låt',
      'förvärm',
      'sätt',
      'börja',
      'gör',
      'ställ',
      'skala',
      'hacka',
      'riv',
      'strimla',
      'marinera',
      'toppa',
    ];
    if (actionVerbs.any((verb) => lower.startsWith(verb))) score += 3;

    // +2: Contains time indicator
    if (RegExp(r'\d+\s*(min|minut|tim|sek)', caseSensitive: false)
        .hasMatch(lower)) {
      score += 2;
    }

    // +2: Contains temperature
    if (RegExp(r'\d+\s*(°|grad)', caseSensitive: false).hasMatch(lower)) {
      score += 2;
    }

    // +1: Contains sequencing words
    if (RegExp(r'\b(sedan|därefter|tills|medan|när|sen)\b',
            caseSensitive: false)
        .hasMatch(lower)) {
      score += 1;
    }

    // +1: Longer text (>40 chars suggests instruction)
    if (text.length > 40) score += 1;

    // -2: Contains measurement (likely ingredient)
    if (RegExp(r'\d+\s*(dl|msk|tsk|g|kg|cl|ml)', caseSensitive: false)
        .hasMatch(lower)) {
      score -= 2;
    }

    return score;
  }

  /// Extract ingredients using measurement-first approach.
  /// Finds all quantity + unit + name patterns in the text.
  List<String> _extractIngredientsByMeasurement(String text) {
    final ingredients = <String>[];

    // Pattern: quantity + optional space + unit + ingredient name
    // Captures: "0.75 dl oystersås", "2 msk japansk soya", "500 g lövbiff"
    final measurementPattern = RegExp(
      r'(\d+(?:[,\.]\d+)?)\s*'
      r'(dl|cl|ml|msk|tsk|krm|g|kg|hg|st|burk|pkt|påse|bit|skiva|klyfta)\s+'
      r'([a-zåäöA-ZÅÄÖ][a-zåäöA-ZÅÄÖ\s\-]{1,40})',
      caseSensitive: false,
    );

    for (final match in measurementPattern.allMatches(text)) {
      final quantity = match.group(1);
      final unit = match.group(2);
      var name = match.group(3)!.trim();

      // Clean up: remove trailing action words
      name = _cleanIngredientName(name);

      if (name.isNotEmpty) {
        ingredients.add('$quantity $unit $name');
      }
    }

    return ingredients;
  }

  /// Clean ingredient name by removing trailing instruction fragments
  String _cleanIngredientName(String name) {
    // Remove trailing digits (often from adjacent measurements)
    name = name.replaceAll(RegExp(r'\d+$'), '').trim();

    // CUT OFF at instruction phrases - these indicate we've captured too much
    // Pattern matches start of instruction text
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

    // Remove trailing action verbs that got captured
    final trailingActions = RegExp(
      r'\s+(stek|koka|blanda|och\s+\w+|i\s+\w+|på\s+\w+|med\s+\w+)$',
      caseSensitive: false,
    );
    name = name.replaceAll(trailingActions, '').trim();

    // Remove trailing punctuation
    name = name.replaceAll(RegExp(r'[,\.]+$'), '').trim();

    // Limit ingredient name length (most ingredients are short)
    if (name.length > 25) {
      // Find last space before 25 chars
      final spaceIdx = name.lastIndexOf(' ', 25);
      if (spaceIdx > 5) {
        name = name.substring(0, spaceIdx).trim();
      }
    }

    return name;
  }

  Recipe? _parseTextToRecipe(String text) {
    final lines =
        text.split('\n').where((line) => line.trim().isNotEmpty).toList();

    if (lines.isEmpty) return null;

    // Extract recipe name from first lines before processing sections
    String recipeName = '';
    String description = '';
    final List<String> ingredients = [];
    final List<String> instructions = [];

    // ===== STAGE 1: MEASUREMENT-FIRST INGREDIENT EXTRACTION =====
    // This is the most reliable method for Instagram text
    final measurementIngredients = _extractIngredientsByMeasurement(text);
    ingredients.addAll(measurementIngredients);

    // Create a set to track text already captured as ingredients
    final capturedAsIngredient = <String>{};
    for (final ing in measurementIngredients) {
      capturedAsIngredient.add(ing.toLowerCase());
    }

    // ===== STAGE 2: EXTRACT TITLE =====
    // First try the Instagram-aware extraction from raw text
    recipeName = _extractTitleFromText(text);

    // Fallback: try line-by-line if Instagram extraction failed
    if (recipeName.isEmpty) {
      for (int i = 0; i < lines.length && i < 3; i++) {
        final line = lines[i].trim();
        final lowerLine = line.toLowerCase();

        // Skip empty lines and garbage
        if (line.isEmpty || _isGarbage(line)) continue;

        // If this line looks like a section header, stop looking for title
        if (_isIngredientHeader(lowerLine) || _isInstructionHeader(lowerLine)) {
          break;
        }

        // If this line looks like an ingredient (has measurements), skip it
        if (_looksLikeIngredient(line)) {
          break;
        }

        // If this looks like a good title (not too long, not too short, no measurements)
        if (line.length > 2 &&
            line.length < 100 &&
            !_isSectionHeader(line) &&
            !line.contains(
                RegExp(r'\d+\s+(dl|cl|ml|kg|g(?!\w)|msk|tsk|st|krm)\b'))) {
          recipeName = line;
          break;
        }
      }
    }

    // ===== STAGE 3: LINE-BY-LINE CLASSIFICATION WITH SCORING =====
    bool inIngredients = false;
    bool inInstructions = false;
    final seenIngredientSections = <String>{}; // Track seen section headers

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lowerLine = line.toLowerCase();

      // Skip empty lines and garbage
      if (line.isEmpty || _isGarbage(line)) continue;

      // Skip the line if it's already been used as the title
      if (line == recipeName) continue;

      // Check for explicit section headers first
      if (_isIngredientHeader(lowerLine)) {
        inIngredients = true;
        inInstructions = false;
        continue;
      }

      if (_isInstructionHeader(lowerLine)) {
        inIngredients = false;
        inInstructions = true;
        continue;
      }

      // Handle section headers (like "biffen", "såsen", "woka ihop")
      if (_isSectionHeader(line)) {
        final headerKey = lowerLine.trim();

        // Check if this is a known instruction section header
        if (_isInstructionSectionHeader(lowerLine)) {
          inIngredients = false;
          inInstructions = true;
          continue;
        }

        // If we've seen this header before as ingredient section,
        // it's now an instruction section (Swedish recipes repeat headers)
        if (seenIngredientSections.contains(headerKey)) {
          inIngredients = false;
          inInstructions = true;
          continue;
        }

        // Look ahead: if following text looks like instructions, switch to instruction mode
        if (_followingTextIsInstruction(lines, i)) {
          inIngredients = false;
          inInstructions = true;
          continue;
        }

        // Mark this as a seen ingredient section header
        if (inIngredients) {
          seenIngredientSections.add(headerKey);
        }

        // Otherwise, assume it's an ingredient sub-section (like "BIFFEN" for beef ingredients)
        // Don't change mode, just skip the header
        continue;
      }

      // Use instruction scoring for classification
      final score = _instructionScore(line);

      // In explicit ingredient section
      if (inIngredients) {
        // Only add if it's valid and not already captured
        if (_isValidIngredient(line) &&
            !capturedAsIngredient.contains(lowerLine)) {
          final ingredient = _parseIngredientLine(line);
          if (ingredient != null) {
            ingredients.add(ingredient);
            capturedAsIngredient.add(ingredient.toLowerCase());
          }
        }
        continue;
      }

      // In explicit instruction section
      if (inInstructions) {
        final instruction = _parseInstructionLine(line);
        if (instruction != null && instruction.length > 10) {
          instructions.add(instruction);
        }
        continue;
      }

      // Auto-detect based on scoring: score >= 2 → likely instruction
      if (score >= 2) {
        final instruction = _parseInstructionLine(line);
        if (instruction != null && instruction.length > 10) {
          instructions.add(instruction);
        }
      } else if (_looksLikeIngredient(line)) {
        // Only add if not already captured by measurement extraction
        if (!capturedAsIngredient.contains(lowerLine)) {
          final ingredient = _parseIngredientLine(line);
          if (ingredient != null && _isValidIngredient(ingredient)) {
            ingredients.add(ingredient);
            capturedAsIngredient.add(ingredient.toLowerCase());
          }
        }
      } else if (description.isEmpty && line.length > 10 && score < 1) {
        description = line;
      }
    }

    // ===== STAGE 4: FINAL CLEANUP - Remove duplicates and garbage =====
    // Smart deduplication - handles partial matches and keeps best version
    final cleanedIngredients = <String>[];
    final seenNames = <String>[]; // Track ingredient names for partial matching

    for (final ing in ingredients) {
      if (_isGarbage(ing) || !_isValidIngredient(ing)) continue;

      final normalized = ing.toLowerCase().trim();
      final ingName = _extractIngredientNameOnly(normalized);

      // Check if this ingredient name is a duplicate or partial match
      var isDuplicate = false;
      var replaceIndex = -1;

      for (var i = 0; i < seenNames.length; i++) {
        final existingName = seenNames[i];

        // Exact match
        if (existingName == ingName) {
          isDuplicate = true;
          break;
        }

        // One contains the other (partial match)
        if (existingName.contains(ingName) || ingName.contains(existingName)) {
          // Keep the longer one (more complete)
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
          // Replace shorter with longer
          cleanedIngredients[replaceIndex] = ing;
          seenNames[replaceIndex] = ingName;
        } else {
          cleanedIngredients.add(ing);
          seenNames.add(ingName);
        }
      }
    }

    final cleanedInstructions = instructions
        .where((i) => !_isGarbage(i) && i.length > 10)
        .toList();

    // Extract additional metadata
    final portions = _extractPortions(text);
    final timeMinutes = _extractTime(text);
    final rating = extractRating(text);
    final mealType =
        _guessMealType(text); // Use full text to detect label format

    return Recipe(
      core: RecipeCore(
        id: _uuid.v4(),
        title: recipeName,
        description: description,
        ingredients: cleanedIngredients.isNotEmpty
            ? cleanedIngredients
            : ['Ingen ingrediensinformation'],
        instructions: cleanedInstructions.isNotEmpty
            ? cleanedInstructions
            : ['Ingen instruktionsinformation'],
        imageUrls: [],
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        tags: _extractTags(text),
        sourceUrl: 'Importerat från text',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: '',
      ),
      type: RecipeType.personal,
    );
  }

  bool _isIngredientHeader(String line) {
    final clean = line.toLowerCase().trim();
    final headers = [
      'ingrediens',
      'ingredienser',
      'ingredienserna',
      'råvaror',
      'du behöver',
      'behöver är',
      'ingredients',
      'what you need'
    ];
    // Only match if line STARTS with header and is short (actual header)
    // This prevents matching "häll i resten av ingredienser" as a header
    return headers.any((header) =>
        clean.startsWith(header) && clean.length < header.length + 30);
  }

  bool _isInstructionHeader(String line) {
    final headers = [
      'gör så här',
      'instruktion',
      'tillredning',
      'steg',
      'instructions',
      'method',
      'directions'
    ];
    return headers.any((header) => line.contains(header));
  }

  bool _looksLikeIngredient(String line) {
    // Has common Swedish measurements
    if (RegExp(
            r'\d+(?:[,\.]\d+)?\s*(dl|cl|ml|kg|g|hg|msk|tsk|st|krm|bit|skiva|klyfta|burk|pkt|påse)')
        .hasMatch(line)) {
      return true;
    }

    // Has common English measurements
    if (RegExp(
            r'\d+(?:[,\.]\d+)?\s*(cup|cups|oz|tbsp|tsp|lb|lbs|pound|pounds|ounce|ounces)')
        .hasMatch(line)) {
      return true;
    }

    // Has fractions (½, ¼, ¾)
    if (RegExp(r'[½¼¾]').hasMatch(line)) return true;

    // Common ingredient words (with word boundaries to avoid false matches)
    final ingredientWords = [
      'mjöl',
      'socker',
      'smör',
      'ägg',
      'mjölk',
      'grädde',
      'olja',
      'salt',
      'peppar',
      'lök',
      'vitlök',
      'tomat',
      'potatis',
      'kött',
      'kyckling',
      'fisk',
      'ris',
      'pasta',
      'flour',
      'sugar',
      'butter',
      'eggs',
      'milk',
      'cream',
      'oil',
      'salt',
      'pepper'
    ];
    // Use word boundaries to match complete words only (prevents "gräddsås" from matching "grädde")
    final lineLower = line.toLowerCase();
    if (ingredientWords
        .any((word) => RegExp('\\b$word\\b').hasMatch(lineLower))) {
      return true;
    }

    // Short line with comma separators (common in ingredient lists like "Salt, peppar")
    if (line.contains(',') && line.length > 3 && line.length < 80) return true;

    // Starts with bullet point or dash
    if (RegExp(r'^[•\-\*]\s+').hasMatch(line)) return true;

    return false;
  }

  String? _parseIngredientLine(String line) {
    // Step 1: Basic cleanup - remove list markers (bullets, numbered lists like "1. ", "2. ")
    // Note: Use alternation to match digit sequences followed by period (numbered lists)
    // Character class would match single digits and break ingredient quantities
    String cleaned =
        line.replaceAll(RegExp(r'^[•\-\*]+\s*|^\d+\.\s*'), '').trim();

    if (cleaned.isEmpty) return null;

    // Step 2: Further cleanup of common prefixes
    cleaned =
        cleaned.replaceAll(RegExp(r'^-\s*'), ''); // Additional dash cleanup
    cleaned = cleaned.replaceAll(RegExp(r'^\*\s*'), ''); // Asterisk cleanup

    // Step 3: MODUL1 Integration - Full preprocessing pipeline
    // This handles:
    // - Approximations ("ca", "cirka" → removed)
    // - Ranges ("3-5" → "5" max value)
    // - Optional markers ("ev" → removed)
    // - Parentheses ("(kall)" → removed)
    // - Instructions ("till gröten" → removed)
    // - Preserves diet descriptors ("glutenfri" → kept!)
    // - Preserves "med [flavor]" products
    cleaned = IngredientProcessor.preprocessOnly(cleaned);

    // Step 4: Normalize fractions (ASCII → Unicode for readability)
    cleaned = cleaned.replaceAll('1/2', '½');
    cleaned = cleaned.replaceAll('1/4', '¼');
    cleaned = cleaned.replaceAll('3/4', '¾');

    // Step 5: Fix common spacing issues with measurements
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\d+)([a-zA-ZåäöÅÄÖ]+)'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    return cleaned;
  }

  String? _parseInstructionLine(String line) {
    // Remove numbering and bullets
    String cleaned = line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[•\-\*]\s*'), '').trim();

    if (cleaned.isEmpty) return null;

    // Capitalize first letter if it's not already
    if (cleaned.isNotEmpty && cleaned[0] == cleaned[0].toLowerCase()) {
      cleaned = '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
    }

    // Ensure instruction ends with proper punctuation
    if (!cleaned.endsWith('.') &&
        !cleaned.endsWith('!') &&
        !cleaned.endsWith('?')) {
      cleaned += '.';
    }

    return cleaned;
  }

  int? _extractPortions(String text) {
    final patterns = [
      // Label-colon format (more specific, check first)
      RegExp(r'portioner?\s*:\s*(\d+)', caseSensitive: false),
      RegExp(r'servings?\s*:\s*(\d+)', caseSensitive: false),
      // Inline format
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
      // Label-colon format (more specific, check first)
      RegExp(r'tid\s*:\s*(\d+)\s*min', caseSensitive: false),
      RegExp(r'tid\s*:\s*(\d+)\s*timm?', caseSensitive: false),
      RegExp(r'time\s*:\s*(\d+)\s*min', caseSensitive: false),
      // Inline format
      RegExp(r'(\d+)\s*min'),
      RegExp(r'(\d+)\s*timm'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text.toLowerCase());
      if (match != null) {
        final time = int.tryParse(match.group(1)!);
        // Convert hours to minutes if pattern suggests hours
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

    // Check label format first (more specific) - preserve exact category names
    if (RegExp(r'typ\s*:\s*frukost', caseSensitive: false)
        .hasMatch(lowerText)) {
      return 'Frukost';
    }
    if (RegExp(r'typ\s*:\s*huvudrätt', caseSensitive: false)
        .hasMatch(lowerText)) {
      return 'Huvudrätt'; // Preserve main course category
    }
    if (RegExp(r'typ\s*:\s*lunch', caseSensitive: false).hasMatch(lowerText)) {
      return 'Lunch';
    }
    if (RegExp(r'typ\s*:\s*middag', caseSensitive: false).hasMatch(lowerText)) {
      return 'Middag';
    }
    if (RegExp(r'typ\s*:\s*(dessert|efterrätt)', caseSensitive: false)
        .hasMatch(lowerText)) {
      return 'Dessert';
    }
    if (RegExp(r'typ\s*:\s*fika', caseSensitive: false).hasMatch(lowerText)) {
      return 'Fika';
    }

    // Then check inline text for meal times
    if (lowerText.contains('frukost') || lowerText.contains('fralla')) {
      return 'Frukost';
    }
    if (lowerText.contains('lunch')) {
      return 'Lunch';
    }
    if (lowerText.contains('middag')) {
      return 'Middag';
    }
    if (lowerText.contains('huvudrätt')) {
      return 'Huvudrätt'; // Preserve as meal category
    }
    if (lowerText.contains('dessert') || lowerText.contains('efterrätt')) {
      return 'Dessert';
    }
    if (lowerText.contains('fika') || lowerText.contains('kaka')) {
      return 'Fika';
    }

    return 'Lunch'; // Default
  }

  List<String> _extractTags(String text) {
    final tags = <String>[];
    final lowerText = text.toLowerCase();

    // Common recipe tags
    if (lowerText.contains('vegetarisk')) tags.add('Vegetarisk');
    if (lowerText.contains('vegan')) tags.add('Vegan');
    if (lowerText.contains('glutenfri')) tags.add('Glutenfri');
    if (lowerText.contains('snabb')) tags.add('Snabb');
    if (lowerText.contains('lätt')) tags.add('Lätt');
    if (lowerText.contains('barn')) tags.add('Barnvänlig');

    return tags;
  }
}
