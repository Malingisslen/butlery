/// 🔍 AI INFO BLOCK:
/// Component: Text Import Strategy - Strategy for importing recipes from text
/// File: lib/services/import/text_import_strategy.dart
/// Quick Guide: Handles text-based recipe imports (social media, manual text)
/// Dependencies IN: ImportStrategy interface, Recipe model
/// Dependencies OUT: Used by import ViewModels and import manager
/// Data flow: Text input -> Parsing logic -> Recipe model
/// State management: Stateless parsing strategy
/// Purpose: Parse structured and unstructured text into recipe format
/// Common issues: Text format variations, ingredient extraction, instruction parsing
/// Test coverage: Unit tests for different text formats
/// Performance: Efficient regex-based parsing
/// Analytics: Text import success rates, format detection
/// Code smells: None - follows strategy pattern
/// Connected to: TextImportViewModel, PersonalRecipeOperations
/// Used in phases: Phase 5 - Service Consolidation (import strategy pattern)

import 'package:uuid/uuid.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_strategy.dart';

/// Strategy for importing recipes from text content
/// 
/// Handles various text formats:
/// - Social media posts (Instagram, Facebook, etc.)
/// - Manual text input
/// - Structured recipe text
/// - Copy-pasted recipes from websites
class TextImportStrategy extends ImportStrategy with ImportValidationMixin {
  static const _uuid = Uuid();

  @override
  String get strategyName => 'Text Import';

  @override
  String get description => 
      'Import recipes from text content (social media posts, manual input)';

  @override
  String get inputExample => '''
Pannkakor
Ingredienser:
3 ägg
5 dl mjölk
3 dl vetemjöl
1 tsk salt

Gör så här:
1. Vispa ihop allt till en slät smet
2. Stek pannkakor i smörad panna
3. Servera med sylt och grädde
''';

  @override
  bool canHandle(String input) {
    final normalized = normalizeText(input);
    
    // Check for recipe-like content
    return normalized.length > 20 && (
        _hasIngredientKeywords(normalized) ||
        _hasInstructionKeywords(normalized) ||
        _hasRecipeStructure(normalized)
    );
  }

  @override
  bool validateInput(String input) {
    if (input.trim().isEmpty || input.trim().length < 10) return false;
    return canHandle(input);
  }

  @override
  Future<ImportResult> import(String input, {Map<String, dynamic>? options}) async {
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
      
      // Validate parsed recipe
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

  // ===== PRIVATE PARSING METHODS =====

  bool _hasIngredientKeywords(String text) {
    final keywords = [
      'ingrediens', 'råvaror', 'behöver', 'du behöver är',
      'ingredients', 'what you need',
    ];
    return keywords.any((keyword) => 
        text.toLowerCase().contains(keyword.toLowerCase()));
  }

  bool _hasInstructionKeywords(String text) {
    final keywords = [
      'gör så här', 'instruktion', 'tillredning', 'steg',
      'börja med', 'sätt ugnen', 'instructions', 'method',
      'koka', 'stek', 'blanda', 'rör'
    ];
    return keywords.any((keyword) => 
        text.toLowerCase().contains(keyword.toLowerCase()));
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

  String _preprocessText(String input) {
    String processed = input;

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

    // Add line breaks after instruction headers  
    processed = processed.replaceAllMapped(
      RegExp(
        r'(gör så här|instruktion|tillredning|steg|instructions|method|directions|preparation)',
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
    processed = processed.replaceAll(RegExp(r'^[-_=]{3,}$', multiLine: true), '');
    
    return processed;
  }

  Recipe? _parseTextToRecipe(String text) {
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    if (lines.isEmpty) return null;

    // Extract recipe name (usually first meaningful line)
    String recipeName = 'Importerat recept';
    String description = '';
    final List<String> ingredients = [];
    final List<String> instructions = [];
    
    bool inIngredients = false;
    bool inInstructions = false;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lowerLine = line.toLowerCase();
      
      // Skip empty lines
      if (line.isEmpty) continue;
      
      // Check for section headers
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
      
      // Extract recipe name from first non-header line
      if (recipeName == 'Importerat recept' && 
          !_isHeader(lowerLine) && 
          line.length > 2 && 
          line.length < 100) {
        recipeName = line;
        continue;
      }
      
      // Parse ingredients
      if (inIngredients) {
        final ingredient = _parseIngredientLine(line);
        if (ingredient != null) {
          ingredients.add(ingredient);
        }
        continue;
      }
      
      // Parse instructions
      if (inInstructions) {
        final instruction = _parseInstructionLine(line);
        if (instruction != null) {
          instructions.add(instruction);
        }
        continue;
      }
      
      // If not in specific section, try to auto-detect
      if (_looksLikeIngredient(line)) {
        ingredients.add(_parseIngredientLine(line) ?? line);
      } else if (_looksLikeInstruction(line)) {
        instructions.add(_parseInstructionLine(line) ?? line);
      } else if (description.isEmpty && line.length > 10) {
        description = line;
      }
    }

    // Extract additional metadata
    final portions = _extractPortions(text);
    final timeMinutes = _extractTime(text);
    final rating = extractRating(text);

    return Recipe(
      core: RecipeCore(
        id: _uuid.v4(),
        title: recipeName,
        description: description,
        ingredients: ingredients.isNotEmpty ? ingredients : ['Ingen ingrediensinformation'],
        instructions: instructions.isNotEmpty ? instructions : ['Ingen instruktionsinformation'],
        imageUrls: [],
        mealType: _guessMealType('$recipeName $description'),
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
    final headers = [
      'ingrediens', 'råvaror', 'du behöver', 'behöver är',
      'ingredients', 'what you need'
    ];
    return headers.any((header) => line.contains(header));
  }

  bool _isInstructionHeader(String line) {
    final headers = [
      'gör så här', 'instruktion', 'tillredning', 'steg',
      'instructions', 'method', 'directions'
    ];
    return headers.any((header) => line.contains(header));
  }

  bool _isHeader(String line) {
    return _isIngredientHeader(line) || _isInstructionHeader(line);
  }

  bool _looksLikeIngredient(String line) {
    // Has common Swedish measurements
    if (RegExp(r'\d+(?:[,\.]\d+)?\s*(dl|cl|ml|kg|g|hg|msk|tsk|st|krm|bit|skiva|klyfta|burk|pkt|påse)').hasMatch(line)) return true;
    
    // Has common English measurements
    if (RegExp(r'\d+(?:[,\.]\d+)?\s*(cup|cups|oz|tbsp|tsp|lb|lbs|pound|pounds|ounce|ounces)').hasMatch(line)) return true;
    
    // Has fractions (½, ¼, ¾)
    if (RegExp(r'[½¼¾]').hasMatch(line)) return true;
    
    // Common ingredient words
    final ingredientWords = [
      'mjöl', 'socker', 'smör', 'ägg', 'mjölk', 'grädde', 'olja', 'salt', 'peppar',
      'lök', 'vitlök', 'tomat', 'potatis', 'kött', 'kyckling', 'fisk', 'ris', 'pasta',
      'flour', 'sugar', 'butter', 'eggs', 'milk', 'cream', 'oil', 'salt', 'pepper'
    ];
    if (ingredientWords.any((word) => line.toLowerCase().contains(word))) return true;
    
    // Short line that could be an ingredient (but not too short)
    if (line.length > 3 && line.length < 80 && line.split(' ').length <= 8) return true;
    
    // Starts with bullet point or dash
    if (RegExp(r'^[•\-\*]\s+').hasMatch(line)) return true;
    
    return false;
  }

  bool _looksLikeInstruction(String line) {
    // Numbered instruction
    if (RegExp(r'^\d+\.').hasMatch(line)) return true;
    
    // Starts with bullet point or dash (but longer than typical ingredient)
    if (RegExp(r'^[•\-\*]\s+').hasMatch(line) && line.length > 15) return true;
    
    // Starts with Swedish action words
    final swedishActionWords = [
      'koka', 'stek', 'blanda', 'rör', 'häll', 'lägg', 'skär', 'servera',
      'värm', 'vispa', 'knåda', 'grädda', 'sjud', 'fräs', 'koka upp',
      'sätt ugnen', 'förvärm', 'tillsätt', 'smaksätt', 'strö över'
    ];
    if (swedishActionWords.any((word) => line.toLowerCase().startsWith(word))) return true;
    
    // Starts with English action words
    final englishActionWords = [
      'cook', 'fry', 'mix', 'stir', 'pour', 'add', 'cut', 'serve',
      'heat', 'whisk', 'knead', 'bake', 'boil', 'sauté', 'preheat',
      'season', 'sprinkle', 'chop', 'slice', 'dice', 'mince'
    ];
    if (englishActionWords.any((word) => line.toLowerCase().startsWith(word))) return true;
    
    // Contains time indicators
    if (RegExp(r'\d+\s*(min|minut|tim|hour|sec)', caseSensitive: false).hasMatch(line)) return true;
    
    // Contains temperature indicators
    if (RegExp(r'\d+\s*(°|grad|degree)', caseSensitive: false).hasMatch(line)) return true;
    
    // Longer descriptive line (likely an instruction)
    if (line.length > 30 && line.split(' ').length > 4) return true;
    
    return false;
  }

  String? _parseIngredientLine(String line) {
    // Remove bullet points, numbers, and asterisks
    String cleaned = line.replaceAll(RegExp(r'^[•\-\*\d+\.]\s*'), '').trim();
    
    if (cleaned.isEmpty) return null;
    
    // Further clean up common prefixes
    cleaned = cleaned.replaceAll(RegExp(r'^-\s*'), ''); // Additional dash cleanup
    cleaned = cleaned.replaceAll(RegExp(r'^\*\s*'), ''); // Asterisk cleanup
    
    // Normalize fractions to make them more readable
    cleaned = cleaned.replaceAll('1/2', '½');
    cleaned = cleaned.replaceAll('1/4', '¼');
    cleaned = cleaned.replaceAll('3/4', '¾');
    
    // Fix common spacing issues with measurements
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
    if (!cleaned.endsWith('.') && !cleaned.endsWith('!') && !cleaned.endsWith('?')) {
      cleaned += '.';
    }
    
    return cleaned;
  }

  int? _extractPortions(String text) {
    final patterns = [
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
    
    if (lowerText.contains('frukost') || lowerText.contains('fralla')) {
      return 'Frukost';
    }
    if (lowerText.contains('lunch')) {
      return 'Lunch';
    }
    if (lowerText.contains('middag')) {
      return 'Middag';
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