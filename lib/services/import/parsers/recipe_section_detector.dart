/// Recipe Section Detector - Section detection and scoring for recipe import.
/// Extracted from text_import_strategy.dart for better organization.

/// Provides section header detection, instruction scoring, and content
/// classification for Swedish and English recipe text.
class RecipeSectionDetector {
  /// Known recipe section headers in Swedish
  static const sectionHeaders = {
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
  static const instructionSectionHeaders = {
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
  static bool isSectionHeader(String text) {
    final clean = text.toLowerCase().trim();
    // Check known headers
    if (sectionHeaders.contains(clean)) return true;
    // Single word < 15 chars that could be a component name
    if (clean.length < 15 &&
        !clean.contains(' ') &&
        RegExp(r'^[a-zåäö]+$').hasMatch(clean)) {
      return true;
    }
    return false;
  }

  /// Check if a section header indicates instruction content
  static bool isInstructionSectionHeader(String header) {
    final clean = header.toLowerCase().trim();
    return instructionSectionHeaders.contains(clean);
  }

  /// Detect garbage/invalid text fragments
  static bool isGarbage(String text) {
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
    if (isSectionHeader(clean) && clean.length < 20) return true;

    // "X portioner" should not be an ingredient
    if (RegExp(r'^\d+\s*portioner?$', caseSensitive: false).hasMatch(clean)) {
      return true;
    }

    return false;
  }

  /// Check if following text looks like instructions (for section header detection)
  static bool followingTextIsInstruction(List<String> lines, int currentIndex) {
    // Look at next 1-3 non-empty, non-header lines
    for (int j = currentIndex + 1;
        j < lines.length && j < currentIndex + 4;
        j++) {
      final nextLine = lines[j].trim();
      if (nextLine.isEmpty) continue;
      if (isSectionHeader(nextLine)) continue;

      // Check if this looks like instruction text
      final score = instructionScore(nextLine);
      if (score >= 2) return true;
      if (nextLine.length > 50) return true; // Long text = likely instruction

      break; // Only check first substantive line
    }
    return false;
  }

  /// Calculate instruction likelihood score
  static int instructionScore(String text) {
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

  /// Validate if text is a valid ingredient
  static bool isValidIngredient(String text) {
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
        text.length < 30 && !text.contains('. ') && !isSectionHeader(text);

    return hasMeasurement || isSimpleIngredient;
  }

  /// Check if line looks like an ingredient header
  static bool isIngredientHeader(String line) {
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

  /// Check if line looks like an instruction header
  static bool isInstructionHeader(String line) {
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

  /// Check if line looks like an ingredient (has measurements or common ingredient words)
  static bool looksLikeIngredient(String line) {
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
      'pepper'
    ];
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

  /// Check for ingredient keywords in text
  static bool hasIngredientKeywords(String text) {
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

  /// Check for instruction keywords in text
  static bool hasInstructionKeywords(String text) {
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

  /// Check if text has recipe-like structure (numbered lists, bullets, measurements)
  static bool hasRecipeStructure(String text) {
    // Check for numbered lists (1., 2., etc.)
    if (RegExp(r'\d+\.\s+').hasMatch(text)) return true;

    // Check for bullet points
    if (RegExp(r'[•-]\s+').hasMatch(text)) return true;

    // Check for measurement patterns
    if (RegExp(r'\d+\s*(dl|cl|ml|kg|g|msk|tsk|st)').hasMatch(text)) return true;

    return false;
  }
}
