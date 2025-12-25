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

  /// Swedish measurement units for ingredient detection.
  static const _swedishUnits = {
    // Volume
    'dl', 'l', 'ml', 'cl', 'liter',
    // Weight
    'g', 'kg', 'hg', 'gram', 'kilo',
    // Cooking measures
    'msk', 'tsk', 'krm', 'matsked', 'tesked', 'kryddmått',
    // Packaging
    'st', 'bit', 'burk', 'pkt', 'paket', 'förp', 'påse',
    'skiva', 'klyfta', 'knippe', 'nypa', 'skvätt',
    // American (often used)
    'cup', 'cups', 'tbsp', 'tsp', 'oz',
  };

  /// Common Swedish food words for ingredient detection.
  static const _swedishFoodWords = {
    // Proteins
    'kyckling', 'fläsk', 'nötkött', 'fisk', 'lax', 'torsk', 'räkor',
    'ägg', 'ost', 'grädde', 'mjölk', 'smör', 'bacon', 'korv',
    'köttfärs', 'skinka', 'kalkon', 'ankbröst', 'kycklingfilé',
    // Vegetables
    'lök', 'vitlök', 'morot', 'potatis', 'tomat', 'paprika', 'gurka',
    'sallad', 'spenat', 'broccoli', 'blomkål', 'zucchini', 'aubergine',
    'champinjoner', 'svamp', 'majs', 'ärtor', 'bönor', 'selleri',
    // Fruits
    'äpple', 'banan', 'citron', 'lime', 'apelsin', 'bär', 'jordgubbar',
    // Grains & Carbs
    'mjöl', 'ris', 'pasta', 'nudlar', 'bröd', 'havregryn', 'couscous',
    // Dairy
    'yoghurt', 'kvarg', 'crème fraiche', 'fetaost', 'mozzarella',
    // Spices & Condiments
    'salt', 'peppar', 'socker', 'honung', 'olja', 'olivolja', 'vinäger',
    'soja', 'senap', 'ketchup', 'majonnäs', 'curry', 'paprikapulver',
    'basilika', 'oregano', 'timjan', 'rosmarin', 'persilja', 'dill',
    'ingefära', 'kanel', 'vanilj', 'kardemumma',
    // Liquids
    'vatten', 'buljong', 'vin', 'öl', 'juice', 'fond',
  };

  /// Swedish cooking verbs for instruction detection (imperative form).
  static const _swedishCookingVerbs = {
    // Preparation
    'skär', 'hacka', 'skala', 'riv', 'mosa', 'blanda', 'vispa', 'rör',
    'mixa', 'knåda', 'forma', 'kavla', 'fyll', 'garnera',
    // Cooking
    'koka', 'stek', 'fräs', 'grilla', 'grädda', 'baka', 'ugnssteka',
    'bryn', 'sjud', 'puttra', 'reducera', 'smält', 'värm',
    // Timing/Process
    'låt', 'vila', 'ställ', 'sätt', 'ta', 'häll', 'tillsätt', 'strö',
    'servera', 'toppa', 'lägg', 'placera', 'vänd', 'rosta',
    // Common starts
    'börja', 'förvärm', 'förbered',
  };

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
    r'(\d+)\s*(port(ion(er)?)?|pers(on(er)?)?|st)',
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

    // Calculate scores for ingredient vs instruction
    final ingredientScore = _scoreAsIngredient(trimmed);
    final instructionScore = _scoreAsInstruction(trimmed);

    // Determine classification
    if (ingredientScore > 0.6 && ingredientScore > instructionScore) {
      return ClassifiedLine(
        text: line,
        type: LineType.ingredient,
        confidence: ingredientScore,
        secondaryType: instructionScore > 0.3 ? LineType.instruction : null,
      );
    }

    if (instructionScore > 0.5 && instructionScore > ingredientScore) {
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
  List<RecipeSection> classifyAndGroup(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final classified = lines.map(classifyLine).toList();
    return _groupIntoSections(classified);
  }

  /// Extract classified lines by type.
  List<ClassifiedLine> extractByType(String text, LineType type) {
    final lines = text.split(RegExp(r'\r?\n'));
    return lines.map(classifyLine).where((c) => c.type == type).toList();
  }

  /// Get confidence-weighted recipe structure from text.
  ParsedRecipeStructure parseStructure(String text) {
    final sections = classifyAndGroup(text);

    String? title;
    final ingredients = <String>[];
    final instructions = <String>[];
    int? portions;
    Duration? totalTime;

    for (final section in sections) {
      for (final line in section.lines) {
        switch (line.type) {
          case LineType.title:
            title ??= line.text.trim();
            break;
          case LineType.ingredient:
            ingredients.add(line.text.trim());
            break;
          case LineType.instruction:
            instructions.add(line.text.trim());
            break;
          case LineType.metadata:
            final portionMatch = _portionsPattern.firstMatch(line.text);
            if (portionMatch != null) {
              portions = int.tryParse(portionMatch.group(1) ?? '');
            }
            final timeMatch = _timePattern.firstMatch(line.text);
            if (timeMatch != null) {
              final value = int.tryParse(timeMatch.group(1) ?? '') ?? 0;
              final unit = timeMatch.group(2)?.toLowerCase() ?? '';
              if (unit.startsWith('tim') || unit == 'h') {
                totalTime = Duration(hours: value);
              } else {
                totalTime = Duration(minutes: value);
              }
            }
            break;
          case LineType.sectionHeader:
          case LineType.empty:
          case LineType.noise:
            break;
        }
      }
    }

    return ParsedRecipeStructure(
      title: title,
      ingredients: ingredients,
      instructions: instructions,
      portions: portions,
      totalTime: totalTime,
    );
  }

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

  double _scoreAsIngredient(String text) {
    var score = 0.0;
    final lower = text.toLowerCase();
    final words = lower.split(RegExp(r'\s+'));

    // Quantity at start is strong indicator
    if (_quantityPattern.hasMatch(text)) {
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

    // Food words
    var foodWordCount = 0;
    for (final food in _swedishFoodWords) {
      if (lower.contains(food)) {
        foodWordCount++;
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

  double _scoreAsInstruction(String text) {
    var score = 0.0;
    final lower = text.toLowerCase();
    final words = lower.split(RegExp(r'\s+'));

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
      if (words.contains(verb)) {
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

    // Check if it looks like a food name
    final lower = text.toLowerCase();
    for (final food in _swedishFoodWords) {
      if (lower.contains(food)) return true;
    }

    // First letter capitalized
    if (text[0] == text[0].toUpperCase()) {
      return true;
    }

    return false;
  }

  List<RecipeSection> _groupIntoSections(List<ClassifiedLine> lines) {
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

/// Parsed recipe structure from line classification.
class ParsedRecipeStructure {
  final String? title;
  final List<String> ingredients;
  final List<String> instructions;
  final int? portions;
  final Duration? totalTime;

  const ParsedRecipeStructure({
    this.title,
    required this.ingredients,
    required this.instructions,
    this.portions,
    this.totalTime,
  });

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
  String toString() => 'ParsedRecipeStructure(title: $title, '
      '${ingredients.length} ingredients, '
      '${instructions.length} instructions, '
      'portions: $portions, time: $totalTime)';
}
