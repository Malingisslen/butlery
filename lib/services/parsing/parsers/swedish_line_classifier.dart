import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/constants/preparation_words.dart';
import 'package:butlery/services/parsing/swedish_units.dart';
import 'package:butlery/services/parsing/parsers/viterbi_context_processor.dart';
import 'package:butlery/services/import/parsers/recipe_section_detector.dart';

/// Classification result for a single line of text.
enum LineType {
  /// Ingredient line (e.g., "2 dl mjölk").
  ingredient,

  /// Instruction/step (e.g., "Vispa ihop mjölk och ägg").
  instruction,

  /// Recipe title.
  title,

  /// Metadata like time or portions (e.g., "4 portioner", "30 min").
  metadata,

  /// Section header (e.g., "Ingredienser:", "Gör så här:").
  sectionHeader,

  /// Empty or whitespace-only line.
  empty,

  /// Noise or irrelevant content.
  noise,
}

/// Classification of a single line with confidence.
class ClassifiedLine {
  /// The original line text.
  final String text;

  /// The classified type.
  final LineType type;

  /// Confidence in the classification (0.0-1.0).
  final double confidence;

  /// Secondary type if ambiguous.
  final LineType? secondaryType;

  const ClassifiedLine({
    required this.text,
    required this.type,
    required this.confidence,
    this.secondaryType,
  });

  @override
  String toString() =>
      'ClassifiedLine(${type.name}, conf: ${(confidence * 100).toInt()}%): "$text"';
}

/// A section of recipe content (ingredients or instructions).
class RecipeSection {
  /// The section type.
  final LineSectionType type;

  /// Lines in this section.
  final List<ClassifiedLine> lines;

  const RecipeSection({
    required this.type,
    required this.lines,
  });

  @override
  String toString() => 'RecipeSection(${type.name}, ${lines.length} lines)';
}

/// Types of recipe sections.
enum LineSectionType {
  /// Title/intro section.
  title,

  /// Ingredients section.
  ingredients,

  /// Instructions section.
  instructions,

  /// Mixed/unknown content.
  mixed,
}

/// Swedish line classifier for unstructured recipe text.
///
/// Handles text from Instagram, TikTok, YouTube descriptions, and other
/// unstructured sources. Classifies each line and groups them into sections.
class SwedishLineClassifier {
  /// Singleton instance.
  static final SwedishLineClassifier instance = SwedishLineClassifier._();

  SwedishLineClassifier._();

  final _viterbi = const ViterbiContextProcessor();

  /// Patterns for ingredient section headers.
  static final _ingredientHeaders = [
    RegExp(r'^ingrediens(er)?:?\s*$', caseSensitive: false),
    RegExp(r'^du behöver:?\s*$', caseSensitive: false),
    RegExp(r'^detta behövs:?\s*$', caseSensitive: false),
    RegExp(r'^det här behöver du:?\s*$', caseSensitive: false),
  ];

  /// Patterns for instruction section headers.
  static final _instructionHeaders = [
    RegExp(r'^(gör\s+så\s+här|så\s+gör\s+du):?\s*$', caseSensitive: false),
    RegExp(r'^instruktion(er)?:?\s*$', caseSensitive: false),
    RegExp(r'^tillagnin(g|gssätt):?\s*$', caseSensitive: false),
    RegExp(r'^framställning:?\s*$', caseSensitive: false),
    RegExp(r'^steg:?\s*$', caseSensitive: false),
    RegExp(r'^metod:?\s*$', caseSensitive: false),
  ];

  /// Swedish measurement units for ingredient detection — shared with the
  /// parsing pipeline (see `swedish_units.dart`).
  static const _swedishUnits = kSwedishUnits;

  /// Food words for ingredient detection — unified from KnownIngredients (~329 entries).
  // ignore: prefer_const_declarations
  static final _swedishFoodWords = KnownIngredients.all;

  /// Swedish cooking verbs — delegates to shared PreparationWords constant.
  static const _swedishCookingVerbs = PreparationWords.cookingVerbs;

  /// Whitespace split pattern (shared across scoring methods).
  static final _whitespaceSplit = RegExp(r'\s+');

  /// Pattern for quantity at line start (ingredient indicator).
  static final _quantityPattern = RegExp(
    r'^(\d+[\.,]?\d*|½|¼|¾|\d+\s*½|\d+\s*¼|\d+\s*¾|\d+/\d+)\s*',
    caseSensitive: false,
  );

  /// Pattern for step number at line start (instruction indicator).
  static final _stepPattern = RegExp(
    r'^(\d+[\.\):]|\d+\s*[\.\):]|steg\s*\d+)',
    caseSensitive: false,
  );

  /// Pattern for time metadata.
  static final _timePattern = RegExp(
    r'(\d+)\s*(min(ut(er)?)?|tim(me|mar)?|h|sek(und(er)?)?)',
    caseSensitive: false,
  );

  /// Pattern for portions metadata.
  static final _portionsPattern = RegExp(
    r'(\d+)\s*(port(ion(er)?)?|pers(on(er)?)?)(\s|$)',
    caseSensitive: false,
  );

  /// Classify a single line of text.
  ClassifiedLine classifyLine(String line) {
    final trimmed = line.trim();

    // Empty line
    if (trimmed.isEmpty) {
      return ClassifiedLine(
        text: line,
        type: LineType.empty,
        confidence: 1.0,
      );
    }

    // Check for section headers first
    if (_isSectionHeader(trimmed)) {
      return ClassifiedLine(
        text: line,
        type: LineType.sectionHeader,
        confidence: 0.95,
      );
    }

    // Check for metadata (time, portions)
    if (_isMetadata(trimmed)) {
      return ClassifiedLine(
        text: line,
        type: LineType.metadata,
        confidence: 0.85,
      );
    }

    // Pre-compute shared text analysis for scoring methods
    final lower = trimmed.toLowerCase();
    final words = lower.split(_whitespaceSplit);
    final wordSet = words.toSet();

    // Calculate scores for ingredient vs instruction
    final ingredientScore = _scoreAsIngredient(trimmed, lower, words, wordSet);
    final instructionScore = _scoreAsInstruction(
      trimmed,
      lower,
      words,
      wordSet,
    );

    // Determine classification
    if (ingredientScore > 0.6 && ingredientScore > instructionScore) {
      return ClassifiedLine(
        text: line,
        type: LineType.ingredient,
        confidence: ingredientScore,
        secondaryType: instructionScore > 0.3 ? LineType.instruction : null,
      );
    }

    if (instructionScore >= 0.5 && instructionScore > ingredientScore) {
      return ClassifiedLine(
        text: line,
        type: LineType.instruction,
        confidence: instructionScore,
        secondaryType: ingredientScore > 0.3 ? LineType.ingredient : null,
      );
    }

    // Check if it could be a title (short, no numbers, capitalized)
    if (_couldBeTitle(trimmed)) {
      return ClassifiedLine(
        text: line,
        type: LineType.title,
        confidence: 0.6,
      );
    }

    // Default to noise if no clear classification
    return ClassifiedLine(
      text: line,
      type: LineType.noise,
      confidence: 0.4,
    );
  }

  /// Classify multiple lines and group into sections.
  ///
  /// Applies Viterbi post-processing so that sequential context (e.g. a run
  /// of ingredients) can resolve ambiguous lines that the per-line classifier
  /// cannot decide on its own.
  List<RecipeSection> classifyAndGroup(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final classified = lines.map(classifyLine).toList();
    final contextual = _viterbi.classifyWithContext(classified);
    return groupIntoSections(contextual);
  }

  /// Extract classified lines by type with Viterbi context.
  List<ClassifiedLine> extractByType(String text, LineType type) {
    final lines = text.split(RegExp(r'\r?\n'));
    final classified = lines.map(classifyLine).toList();
    final contextual = _viterbi.classifyWithContext(classified);
    return contextual.where((c) => c.type == type).toList();
  }

  /// Get confidence-weighted recipe structure from text.
  ///
  /// [captureSubHeadings] threads the `ingredient_section_capture` kill switch
  /// down from the tier (ServiceLocator isn't reachable inside a background
  /// isolate, so the flag must arrive as a value). When false, component
  /// sub-heading lines ("Deg:") are RETAINED as ingredients rather than pulled
  /// out, matching the LLM/schema.org tiers. OFF means "no grouping" — it is
  /// NOT a full revert: a bare gluten line ("Mjöl:") is still kept, and kept
  /// colon-stripped, because losing an allergen is the one outcome the switch
  /// must never produce (BUT-1714).
  ParsedRecipeStructure parseStructure(
    String text, {
    bool captureSubHeadings = true,
  }) {
    final sections = classifyAndGroup(text);
    return extractStructureFromSections(
      sections,
      captureSubHeadings: captureSubHeadings,
    );
  }

  /// Extracts [ParsedRecipeStructure] from grouped sections.
  ///
  /// Shared between rule-based and neural classifiers. See [parseStructure]
  /// for [captureSubHeadings].
  static ParsedRecipeStructure extractStructureFromSections(
    List<RecipeSection> sections, {
    bool captureSubHeadings = true,
  }) {
    String? title;
    final ingredients = <String>[];
    final ingredientSections = <String?>[];
    final instructions = <String>[];
    int? portions;
    Duration? totalTime;

    // Sub-heading tracking: an INGREDIENT-side section header (e.g. "Deg:",
    // "Fyllning:") sets the current group for subsequent ingredient lines.
    // Instruction-side headers ("Gör så här:") clear it — the ingredient
    // list is over. The heading text itself is NEVER added as an ingredient
    // (the flat-list safety invariant lives here at the source).
    String? currentSection;

    for (final section in sections) {
      // A section whose type is instructions means we've left the ingredient
      // block; drop any lingering ingredient sub-heading.
      if (section.type == LineSectionType.instructions) {
        currentSection = null;
      }
      for (final line in section.lines) {
        switch (line.type) {
          case LineType.title:
            title ??= line.text.trim();
            break;
          case LineType.ingredient:
            final text = line.text.trim();
            // The Viterbi context often pulls a component sub-heading
            // ("Deg:", "Fyllning:") into the ingredient run. Detect it
            // conservatively and treat it as a group marker instead of an
            // ingredient — it was never a real ingredient, so dropping it
            // only removes a phantom "deg" row. The detector must err toward
            // "it's an ingredient" so a real allergen-bearing line is never
            // dropped from tagging input.
            final subHeading = captureSubHeadings
                ? _componentSubHeading(text)
                : null;
            if (subHeading != null) {
              currentSection = subHeading;
            } else {
              // Capture off ⇒ the line stays an ingredient (never dropped),
              // so allergen tagging sees exactly the pre-feature input.
              ingredients.add(text);
              ingredientSections.add(currentSection);
            }
            break;
          case LineType.instruction:
            instructions.add(line.text.trim());
            break;
          case LineType.metadata:
            final portionMatch = _portionsPattern.firstMatch(line.text);
            if (portionMatch != null) {
              portions = int.tryParse(portionMatch.group(1).orEmpty());
            }
            final timeMatch = _timePattern.firstMatch(line.text);
            if (timeMatch != null) {
              final value = int.tryParse(timeMatch.group(1).orEmpty()) ?? 0;
              final unit = (timeMatch.group(2)?.toLowerCase()).orEmpty();
              if (unit.startsWith('tim') || unit == 'h') {
                totalTime = Duration(hours: value);
              } else {
                totalTime = Duration(minutes: value);
              }
            }
            break;
          case LineType.sectionHeader:
            // A classified section header: a generic block marker
            // ("Ingredienser:", "Gör så här:") clears the group; a genuine
            // component header ("Deg:") sets it. With capture off, no group
            // is tracked (sections aren't stamped anyway).
            final headerText = line.text.trim();
            final headerLabel = captureSubHeadings
                ? _componentSubHeading(headerText)
                : null;
            final glutenLabel = headerLabel == null
                ? RecipeSectionDetector.bareGlutenIngredientLabel(headerText)
                : null;
            if (glutenLabel != null) {
              // BUT-1714: the detector refused this line as a heading exactly
              // so the gluten row survives in the flat list tagging reads.
              // Unlike the ingredient branch above, a null here would DELETE
              // the line — the ONNX classifier labels a colon-terminated lone
              // word `sectionHeader`, so this is the live path for "Mjöl:".
              //
              // The COLON-STRIPPED label is what goes in, not the raw line:
              // ingredient lookup strips no punctuation, so "Mjöl:" would query
              // `mjol:`, match nothing, and take every allergen verdict on the
              // recipe to UNKNOWN. See [bareGlutenIngredientLabel].
              //
              // Deliberately NOT gated on [captureSubHeadings]: with capture
              // off `headerLabel` is already null, and gating here would make
              // the kill switch drop the gluten line — the one outcome the
              // switch must never produce. Off means "no grouping", never
              // "lose an allergen".
              ingredients.add(glutenLabel);
              ingredientSections.add(currentSection);
            } else {
              currentSection = headerLabel;
            }
            break;
          case LineType.empty:
          case LineType.noise:
            break;
        }
      }
    }

    return ParsedRecipeStructure(
      title: title,
      ingredients: ingredients,
      ingredientSections: ingredientSections,
      instructions: instructions,
      portions: portions,
      totalTime: totalTime,
    );
  }

  /// Component sub-heading detection is the one audited heuristic in
  /// [RecipeSectionDetector.componentSubHeadingLabel] — shared with the
  /// schema.org import tier so the allergen-safety rule lives in one place.
  static String? _componentSubHeading(String text) =>
      RecipeSectionDetector.componentSubHeadingLabel(text);

  bool _isSectionHeader(String text) {
    for (final pattern in _ingredientHeaders) {
      if (pattern.hasMatch(text)) return true;
    }
    for (final pattern in _instructionHeaders) {
      if (pattern.hasMatch(text)) return true;
    }
    return false;
  }

  bool _isMetadata(String text) {
    // Short line with time or portions info
    if (text.length > 50) return false;
    return _timePattern.hasMatch(text) || _portionsPattern.hasMatch(text);
  }

  double _scoreAsIngredient(
    String text,
    String lower,
    List<String> words,
    Set<String> wordSet,
  ) {
    var score = 0.0;

    // Quantity at start is strong indicator (but not step numbers like "1.")
    if (_quantityPattern.hasMatch(text) && !_stepPattern.hasMatch(text)) {
      score += 0.4;
    }

    // Swedish units are strong indicator
    for (final unit in _swedishUnits) {
      if (words.contains(unit) ||
          lower.contains(' $unit ') ||
          lower.contains(' $unit,') ||
          lower.endsWith(' $unit')) {
        score += 0.3;
        break;
      }
    }

    // Food words — use word-set matching to prevent substring false positives
    // (e.g. "ost" matching inside "rostad")
    var foodWordCount = 0;
    for (final food in _swedishFoodWords) {
      if (food.contains(' ')) {
        if (lower.contains(food)) foodWordCount++;
      } else {
        if (wordSet.contains(food)) foodWordCount++;
      }
    }
    score += (foodWordCount * 0.15).clamp(0.0, 0.3);

    // Short lines more likely ingredients
    if (text.length < 50) {
      score += 0.1;
    }

    // No cooking verbs at start (instructions usually start with verbs)
    final firstWord = words.isNotEmpty ? words.first : '';
    if (!_swedishCookingVerbs.contains(firstWord)) {
      score += 0.05;
    }

    return score.clamp(0.0, 1.0);
  }

  double _scoreAsInstruction(
    String text,
    String lower,
    List<String> words,
    Set<String> wordSet,
  ) {
    var score = 0.0;

    // Step number at start
    if (_stepPattern.hasMatch(text)) {
      score += 0.35;
    }

    // Cooking verb at start
    final firstWord = words.isNotEmpty ? words.first : '';
    if (_swedishCookingVerbs.contains(firstWord)) {
      score += 0.4;
    }

    // Cooking verbs anywhere
    var verbCount = 0;
    for (final verb in _swedishCookingVerbs) {
      if (wordSet.contains(verb)) {
        verbCount++;
      }
    }
    score += (verbCount * 0.1).clamp(0.0, 0.2);

    // Longer lines more likely instructions
    if (text.length > 40) {
      score += 0.1;
    }
    if (text.length > 80) {
      score += 0.1;
    }

    // Sentence structure (ends with period)
    if (text.endsWith('.')) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  bool _couldBeTitle(String text) {
    // Titles are usually short, no quantities, possibly capitalized
    if (text.length > 60 || text.length < 3) return false;
    if (_quantityPattern.hasMatch(text)) return false;
    if (_stepPattern.hasMatch(text)) return false;

    // Check if it looks like a food name — whole-word matching
    final lower = text.toLowerCase();
    final titleWords = lower.split(RegExp(r'\s+')).toSet();
    for (final food in _swedishFoodWords) {
      if (food.contains(' ')) {
        if (lower.contains(food)) return true;
      } else {
        if (titleWords.contains(food)) return true;
      }
    }

    // First letter capitalized
    if (text[0] == text[0].toUpperCase()) {
      return true;
    }

    return false;
  }

  /// Groups classified lines into recipe sections.
  ///
  /// Shared between rule-based and neural classifiers — both produce
  /// [ClassifiedLine] lists that need the same grouping logic.
  static List<RecipeSection> groupIntoSections(List<ClassifiedLine> lines) {
    final sections = <RecipeSection>[];
    var currentType = LineSectionType.mixed;
    var currentLines = <ClassifiedLine>[];

    for (final line in lines) {
      // Section headers change the current section
      if (line.type == LineType.sectionHeader) {
        // Save previous section if not empty
        if (currentLines.isNotEmpty) {
          sections.add(RecipeSection(type: currentType, lines: currentLines));
          currentLines = [];
        }

        // Determine new section type from header
        final headerLower = line.text.toLowerCase();
        if (_ingredientHeaders.any((p) => p.hasMatch(headerLower))) {
          currentType = LineSectionType.ingredients;
        } else if (_instructionHeaders.any((p) => p.hasMatch(headerLower))) {
          currentType = LineSectionType.instructions;
        }

        currentLines.add(line);
        continue;
      }

      // Skip empty lines between sections
      if (line.type == LineType.empty && currentLines.isEmpty) {
        continue;
      }

      // Add line to current section
      currentLines.add(line);

      // Auto-detect section type based on content if still mixed
      if (currentType == LineSectionType.mixed) {
        if (line.type == LineType.ingredient) {
          currentType = LineSectionType.ingredients;
        } else if (line.type == LineType.instruction) {
          currentType = LineSectionType.instructions;
        } else if (line.type == LineType.title) {
          currentType = LineSectionType.title;
        }
      }
    }

    // Add final section
    if (currentLines.isNotEmpty) {
      sections.add(RecipeSection(type: currentType, lines: currentLines));
    }

    return sections;
  }
}

/// Top-level worker for [compute()] — must be top-level so the Dart isolate
/// spawner can reference it without capturing any closure state.
///
/// Input is a primitive [Map] ('text' + 'captureSubHeadings') because
/// `compute` passes a single message and the kill-switch flag can't be read
/// from ServiceLocator inside the isolate — it must ride in. Returns a [Map]
/// of primitives so the result crosses the boundary without custom codecs.
Map<String, dynamic> parseStructureInIsolate(Map<String, dynamic> args) {
  final text = (args['text'] as String?).orEmpty();
  final capture = args['captureSubHeadings'] as bool? ?? true;
  return SwedishLineClassifier.instance
      .parseStructure(text, captureSubHeadings: capture)
      .toIsolateMap();
}

/// Parsed recipe structure from line classification.
class ParsedRecipeStructure {
  final String? title;
  final List<String> ingredients;

  /// Component group per ingredient ("Deg", "Fyllning", ...), index-aligned
  /// with [ingredients]; null entries are ungrouped. Empty when no sections
  /// were detected. NEVER contains heading text as its own ingredient.
  final List<String?> ingredientSections;
  final List<String> instructions;
  final int? portions;
  final Duration? totalTime;

  const ParsedRecipeStructure({
    this.title,
    required this.ingredients,
    this.ingredientSections = const [],
    required this.instructions,
    this.portions,
    this.totalTime,
  });

  /// Encode to a [Map] of primitives that can cross an isolate [SendPort].
  /// [totalTime] is stored as integer minutes (null → absent key).
  Map<String, dynamic> toIsolateMap() => {
    'title': title,
    'ingredients': List<String>.from(ingredients),
    // Encoded as a same-length list; null survives a SendPort so groups round
    // trip when the rule-based tier runs the classifier in an isolate.
    if (ingredientSections.isNotEmpty)
      'ingredientSections': List<String?>.from(ingredientSections),
    'instructions': List<String>.from(instructions),
    'portions': portions,
    if (totalTime != null) 'totalTimeMinutes': totalTime!.inMinutes,
  };

  /// Reconstruct from the map returned by [toIsolateMap].
  factory ParsedRecipeStructure.fromIsolateMap(Map<String, dynamic> map) {
    final rawMinutes = map['totalTimeMinutes'] as int?;
    final rawSections = map['ingredientSections'] as List?;
    return ParsedRecipeStructure(
      title: map['title'] as String?,
      ingredients: List<String>.from(map['ingredients'] as List),
      ingredientSections: rawSections == null
          ? const []
          : rawSections.map((e) => e as String?).toList(),
      instructions: List<String>.from(map['instructions'] as List),
      portions: map['portions'] as int?,
      totalTime: rawMinutes != null ? Duration(minutes: rawMinutes) : null,
    );
  }

  /// Overall confidence based on extracted data.
  double get confidence {
    var score = 0.0;
    if (title != null) score += 0.15;
    if (ingredients.isNotEmpty) score += 0.40;
    if (instructions.isNotEmpty) score += 0.30;
    if (portions != null) score += 0.10;
    if (totalTime != null) score += 0.05;
    return score;
  }

  /// Whether enough data was extracted for a valid recipe.
  bool get isValid => ingredients.isNotEmpty && instructions.isNotEmpty;

  @override
  String toString() =>
      'ParsedRecipeStructure(title: $title, '
      '${ingredients.length} ingredients, '
      '${instructions.length} instructions, '
      'portions: $portions, time: $totalTime)';
}
