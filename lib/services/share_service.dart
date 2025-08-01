/// Comprehensive content sharing service providing multi-format recipe and meal planning sharing capabilities.
///
/// This service implements sophisticated content formatting and sharing functionality for recipes, shopping lists,
/// and meal planning data. It provides multiple output formats optimized for different sharing contexts including
/// social media, messaging, email, and clipboard operations with Swedish language localization and emoji integration
/// for enhanced visual appeal and user engagement.
///
/// **Architecture Integration:**
/// - Extends [BaseService] for consistent service patterns and comprehensive error handling
/// - Integrates with [Share] plugin for native platform sharing capabilities
/// - Uses [Clipboard] services for direct content copying functionality
/// - Supports [Recipe] unified model for comprehensive recipe data formatting
/// - Implements [UnifiedShoppingItem] integration for shopping list sharing
///
/// **Sharing Capabilities:**
/// - **Recipe Sharing**: Multiple format options for different sharing contexts and platforms
/// - **Shopping List Sharing**: Organized shopping lists with category grouping and completion status
/// - **Menu Planning**: Weekly menu sharing with comprehensive meal organization and metadata
/// - **Clipboard Integration**: Direct content copying for paste operations in external applications
/// - **Smart Formatting**: Context-aware format selection for optimal sharing experience
///
/// **Format Support:**
/// - **Complete Format**: Full recipe details with comprehensive metadata and structured presentation
/// - **Compact Format**: Optimized for messaging and social media with emoji enhancement
/// - **Markdown Format**: Structured format for documentation and export with technical formatting
/// - **Shopping Lists**: Category-organized lists with completion status and visual indicators
/// - **Weekly Menus**: Comprehensive meal planning with metadata and summary statistics
///
/// **Localization Features:**
/// - Swedish language labels and terminology throughout all formats
/// - Cultural cooking terminology and measurement units
/// - Emoji integration for visual appeal and cross-platform compatibility
/// - Category naming conventions aligned with Swedish meal planning patterns
///
/// **Usage Examples:**
/// ```dart
/// final shareService = ShareService();
/// 
/// // Share recipe with smart format selection
/// await shareService.shareRecipe(recipe);
/// 
/// // Share with specific format
/// await shareService.shareRecipeWithFormat(recipe, RecipeShareFormat.compact);
/// 
/// // Copy to clipboard
/// await shareService.copyRecipe(recipe, format: RecipeShareFormat.markdown);
/// 
/// // Share shopping list
/// await shareService.shareShoppingList(shoppingItems);
/// 
/// // Get formatted text for custom usage
/// final formattedText = shareService.getFormattedRecipe(recipe);
/// ```

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/base/base_service.dart';

/// Enumeration defining available recipe sharing formats for different contexts and platforms.
///
/// This enum provides comprehensive format options for recipe sharing enabling optimal presentation
/// across different sharing contexts from social media and messaging to documentation and export.
/// Each format is optimized for specific use cases with appropriate detail levels and formatting.
///
/// **Format Options:**
/// - [complete] Full recipe details with comprehensive metadata and structured presentation
/// - [compact] Optimized for messaging and social media with emoji enhancement and concise layout
/// - [markdown] Technical format for documentation and export with structured markup
///
/// **Usage Context Guidelines:**
/// - Complete format: Email sharing, recipe collections, detailed documentation
/// - Compact format: SMS, instant messaging, social media posts, quick sharing
/// - Markdown format: Recipe blogs, documentation systems, structured export
enum RecipeShareFormat {
  /// Full recipe details with comprehensive metadata and structured presentation.
  complete,
  
  /// Optimized for messaging and social media with emoji enhancement and concise layout.
  compact,
  
  /// Technical format for documentation and export with structured markup.
  markdown,
}

/// Comprehensive content sharing service providing multi-format recipe and meal planning sharing.
///
/// This service implements sophisticated content formatting and sharing with multiple output formats,
/// Swedish localization, and platform-native sharing capabilities. It provides a complete sharing
/// solution for recipes, shopping lists, and meal planning with intelligent format selection and
/// comprehensive error handling through the BaseService architecture.
class ShareService extends BaseService {
  
  @override
  String get serviceName => 'ShareService';
  // ===== FORMATERINGS-KONSTANTER =====
  // Använder nu AppTheme för formaterings-symboler

  // Lokaliseringar - kommer flyttas till l10n när flerspråksstöd implementeras
  static const String _ingredientsTitle = 'Ingredienser:';
  static const String _instructionsTitle = 'Gör så här:';
  static const String _sourceLabel = 'Källa:';
  static const String _portionsLabel = 'portioner';
  static const String _minutesLabel = 'minuter';

  // Emojis - kan göras konfigurerbar senare
  static const String _recipeEmoji = '🍽';
  static const String _timeEmoji = '⏱';
  static const String _servingsEmoji = '🍴';
  static const String _starEmoji = '⭐';

  // ===== RECIPE FORMATTING =====

  /// Formats recipe as complete text with comprehensive details and structured presentation.
  ///
  /// This method generates a full-featured text representation of a recipe including all available
  /// metadata, ingredients, instructions, and source information. It provides structured formatting
  /// with visual separators and organized sections for optimal readability in email sharing and
  /// detailed documentation contexts.
  ///
  /// [recipe] Complete recipe object to format with all available data
  /// Returns formatted string with comprehensive recipe information and structured layout
  ///
  /// **Formatting Features:**
  /// - **Structured Header**: Recipe title with visual separator for clear identification
  /// - **Metadata Section**: Portions, cooking time, and rating with organized presentation
  /// - **Content Sections**: Description, ingredients, and instructions with clear labeling
  /// - **Additional Information**: Tags and source URL with appropriate formatting
  /// - **Swedish Localization**: All labels and terminology in Swedish for cultural alignment
  ///
  /// **Section Organization:**
  /// 1. Title with equal-sign separator for visual emphasis
  /// 2. Metadata row with portions, time, and star rating
  /// 3. Recipe description if available
  /// 4. Bulleted ingredient list with clear organization
  /// 5. Numbered instruction steps for easy following
  /// 6. Tag list for categorization and discovery
  /// 7. Source URL for attribution and reference
  String formatRecipeComplete(Recipe recipe) {
    final buffer = StringBuffer();

    // Rubrik
    buffer.writeln(recipe.title);
    buffer.writeln('=' * recipe.title.length);

    // Metadata
    final metadata = <String>[];
    if (recipe.portions != null) {
      metadata.add('${recipe.portions} $_portionsLabel');
    }
    if (recipe.timeMinutes != null) {
      metadata.add('${recipe.timeMinutes} $_minutesLabel');
    }
    if (recipe.rating != null && recipe.rating! > 0) {
      metadata.add(_starEmoji * recipe.rating!.round());
    }

    if (metadata.isNotEmpty) {
      buffer.writeln(metadata.join(' | '));
      buffer.writeln();
    }

    // Beskrivning
    if (recipe.description.isNotEmpty) {
      buffer.writeln(recipe.description);
      buffer.writeln();
    }

    // Ingredienser
    if (recipe.ingredients.isNotEmpty) {
      buffer.writeln(_ingredientsTitle);
      for (final ingredient in recipe.ingredients) {
        buffer.writeln('• $ingredient');
      }
      buffer.writeln();
    }

    // Instruktioner
    if (recipe.instructions.isNotEmpty) {
      buffer.writeln(_instructionsTitle);
      for (int i = 0; i < recipe.instructions.length; i++) {
        buffer.writeln(
          '${i + 1}. ${recipe.instructions[i]}',
        );
      }
      buffer.writeln();
    }

    // Tags istället för tips
    if (recipe.tags != null && recipe.tags!.isNotEmpty) {
      buffer.writeln('Tags: ${recipe.tags!.join(", ")}');
      buffer.writeln();
    }

    // Källa
    if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      buffer.writeln('$_sourceLabel ${recipe.sourceUrl}');
    }

    return buffer.toString();
  }

  /// Formats recipe in compact format optimized for messaging and social media sharing.
  ///
  /// This method generates a concise yet comprehensive recipe representation with emoji enhancement
  /// and condensed formatting suitable for SMS, instant messaging, and social media platforms.
  /// It maintains all essential recipe information while optimizing for character limits and
  /// visual appeal through strategic emoji usage and compact layout.
  ///
  /// [recipe] Recipe object to format in compact, messaging-friendly format
  /// Returns condensed recipe string with emoji enhancement and optimized layout
  ///
  /// **Compact Formatting Features:**
  /// - **Emoji Integration**: Visual recipe emoji and metadata icons for enhanced appeal
  /// - **Condensed Metadata**: Time, portions, and rating with abbreviated labels and icons
  /// - **Complete Content**: All ingredients and instructions despite compact format
  /// - **Mobile Optimization**: Format suitable for mobile messaging and social platforms
  /// - **Character Efficiency**: Optimized for character-limited sharing contexts
  ///
  /// **Visual Enhancement:**
  /// - Recipe emoji (🍽) for immediate identification
  /// - Time emoji (⏱) for cooking time indication
  /// - Serving emoji (🍴) for portion information
  /// - Star emojis (⭐) for rating visualization
  /// - Bulleted lists and numbered steps for clear organization
  String formatRecipeCompact(Recipe recipe) {
    final buffer = StringBuffer();

    // Emoji och titel
    buffer.writeln('$_recipeEmoji ${recipe.title}');

    // Metadata med emojis
    final metadata = <String>[];
    if (recipe.timeMinutes != null) {
      metadata.add('$_timeEmoji ${recipe.timeMinutes} min');
    }
    if (recipe.portions != null) {
      metadata.add('$_servingsEmoji ${recipe.portions} port');
    }
    if (recipe.rating != null && recipe.rating! > 0) {
      metadata.add(_starEmoji * recipe.rating!.round());
    }

    if (metadata.isNotEmpty) {
      buffer.writeln(metadata.join(' | '));
      buffer.writeln();
    }

    // Beskrivning
    if (recipe.description.isNotEmpty) {
      buffer.writeln(recipe.description);
      buffer.writeln();
    }

    // Ingredienser - visa alla för kompakt format också
    if (recipe.ingredients.isNotEmpty) {
      buffer.writeln('Ingredienser:');
      for (final ingredient in recipe.ingredients) {
        buffer.writeln('• $ingredient');
      }
      buffer.writeln();
    }

    // Snabbinstruktioner
    if (recipe.instructions.isNotEmpty) {
      buffer.writeln('Instruktioner:');
      for (int i = 0; i < recipe.instructions.length; i++) {
        buffer.writeln('${i + 1}. ${recipe.instructions[i]}');
      }
    }

    // Källa om den finns
    if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Källa: ${recipe.sourceUrl}');
    }

    return buffer.toString();
  }

  /// Formattera recept som Markdown
  String formatRecipeMarkdown(Recipe recipe) {
    final buffer = StringBuffer();

    // Huvudrubrik
    buffer.writeln('# ${recipe.title}');
    buffer.writeln();

    // Metadata
    if (recipe.timeMinutes != null) {
      buffer.writeln('**Tid:** ${recipe.timeMinutes} $_minutesLabel');
    }
    if (recipe.portions != null) {
      buffer.writeln('**Portioner:** ${recipe.portions}');
    }
    if (recipe.rating != null && recipe.rating! > 0) {
      buffer.writeln('**Betyg:** ${_starEmoji * recipe.rating!.round()}');
    }
    if (recipe.mealType.isNotEmpty) {
      buffer.writeln('**Typ:** ${recipe.mealType}');
    }
    buffer.writeln();

    // Beskrivning
    if (recipe.description.isNotEmpty) {
      buffer.writeln('> ${recipe.description}');
      buffer.writeln();
    }

    // Ingredienser
    if (recipe.ingredients.isNotEmpty) {
      buffer.writeln('## $_ingredientsTitle');
      for (final ingredient in recipe.ingredients) {
        buffer.writeln('- $ingredient');
      }
      buffer.writeln();
    }

    // Instruktioner
    if (recipe.instructions.isNotEmpty) {
      buffer.writeln('## $_instructionsTitle');
      for (int i = 0; i < recipe.instructions.length; i++) {
        buffer.writeln('${i + 1}. ${recipe.instructions[i]}');
      }
      buffer.writeln();
    }

    // Tags
    if (recipe.tags != null && recipe.tags!.isNotEmpty) {
      buffer.writeln('## Tags');
      buffer.writeln(recipe.tags!.map((tag) => '`$tag`').join(' '));
      buffer.writeln();
    }

    // Källa
    if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      buffer.writeln('---');
      buffer.writeln(
        '*$_sourceLabel [${recipe.sourceUrl}](${recipe.sourceUrl})*',
      );
    }

    return buffer.toString();
  }

  // ===== SHOPPING LIST FORMATTING =====

  /// Formattera inköpslista som text
  String formatShoppingList(List<UnifiedShoppingItem> items) {
    final buffer = StringBuffer();

    buffer.writeln('🛒 INKÖPSLISTA');
    buffer.writeln('===========');
    buffer.writeln();

    // Gruppera efter kategori om det finns kategorier
    final groupedItems = <String, List<UnifiedShoppingItem>>{};
    for (final item in items) {
      final category = item.category.isEmpty ? 'Övrigt' : item.category;
      groupedItems.putIfAbsent(category, () => []).add(item);
    }

    // Om bara en kategori, visa som enkel lista
    if (groupedItems.length == 1) {
      for (final item in items) {
        final checkbox = item.bought ? '☑' : '☐';
        buffer.writeln('$checkbox ${item.toString()}');
      }
    } else {
      // Visa grupperat
      for (final entry in groupedItems.entries) {
        buffer.writeln('【${entry.key.toUpperCase()}】');
        for (final item in entry.value) {
          final checkbox = item.bought ? '☑' : '☐';
          buffer.writeln('$checkbox ${item.toString()}');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Formattera inköpslista grupperad efter kategori
  String formatShoppingListGrouped(
    Map<String, List<UnifiedShoppingItem>> groupedItems,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('Inköpslista');
    buffer.writeln(
      '===========',
    ); // Använder = direkt istället för multiplicering
    buffer.writeln();

    groupedItems.forEach((category, items) {
      buffer.writeln(category.toUpperCase());
      for (final item in items) {
        final checkbox = item.bought ? '☑' : '☐';
        buffer.writeln('  $checkbox ${item.toString()}');
      }
      buffer.writeln();
    });

    return buffer.toString();
  }

  // ===== WEEK MENU FORMATTING =====

  /// Formattera veckomeny som text
  String formatWeekMenu(Map<String, Recipe?> weekMenu) {
    final buffer = StringBuffer();

    buffer.writeln('Veckomeny');
    buffer.writeln(
      '=========',
    ); // Använder = direkt istället för multiplicering
    buffer.writeln();

    final weekdays = [
      'Måndag',
      'Tisdag',
      'Onsdag',
      'Torsdag',
      'Fredag',
      'Lördag',
      'Söndag',
    ];

    for (final day in weekdays) {
      final recipe = weekMenu[day];
      if (recipe != null) {
        buffer.writeln('$day: ${recipe.title}');
      } else {
        buffer.writeln('$day: -');
      }
    }

    return buffer.toString();
  }

  // ===== SMART FORMATTING =====

  /// Välj bästa format baserat på innehåll
  String getSmartFormat(Recipe recipe) {
    // Använd alltid det kompletta formatet som inkluderar allt innehåll
    // Detta ger mottagaren all information direkt utan att behöva klicka på länkar
    return formatRecipeComplete(recipe);
  }

  // ===== SHARING METHODS - FIXED =====

  /// Shares recipe using platform-native share sheet with intelligent format selection.
  ///
  /// This method provides seamless recipe sharing through the platform's native sharing interface
  /// with automatic format selection based on recipe content and optimal user experience. It uses
  /// the comprehensive error handling provided by BaseService and supports offline operation for
  /// maximum reliability across different network conditions.
  ///
  /// [recipe] Complete recipe object to share through native platform interface
  /// Throws [ServiceException] if sharing operation fails or platform sharing is unavailable
  ///
  /// **Sharing Process:**
  /// 1. **Smart Formatting**: Automatically selects optimal format based on recipe content
  /// 2. **Native Integration**: Uses platform share sheet for seamless user experience
  /// 3. **Error Handling**: Comprehensive error management through BaseService architecture
  /// 4. **Offline Support**: No network requirements for sharing operation
  /// 5. **Subject Setting**: Recipe title used as sharing subject for email and messaging
  ///
  /// **Platform Compatibility:**
  /// - iOS: Integrates with iOS share sheet and activity view controller
  /// - Android: Uses Android intent system for comprehensive app integration
  /// - Cross-platform: Consistent API across all Flutter-supported platforms
  Future<void> shareRecipe(Recipe recipe) async {
    await executeServiceOperation(
      () async {
        final text = getSmartFormat(recipe);
        await Share.share(text, subject: recipe.title);
      },
      operationName: 'Share recipe',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Dela recept med formatval
  Future<void> shareRecipeWithFormat(
    Recipe recipe,
    RecipeShareFormat format,
  ) async {
    await executeServiceOperation(
      () async {
        final text = switch (format) {
          RecipeShareFormat.complete => formatRecipeComplete(recipe),
          RecipeShareFormat.compact => formatRecipeCompact(recipe),
          RecipeShareFormat.markdown => formatRecipeMarkdown(recipe),
        };

        await Share.share(text, subject: recipe.title);
      },
      operationName: 'Share recipe with format',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Dela inköpslista
  Future<void> shareShoppingList(List<UnifiedShoppingItem> items) async {
    await executeServiceOperation(
      () async {
        final text = formatShoppingList(items);
        await Share.share(text, subject: 'Inköpslista');
      },
      operationName: 'Share shopping list',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Dela veckomeny från kategorier (den faktiska strukturen från MenuViewModel)
  Future<void> shareWeekMenuFromCategories(
    Map<String, List<Recipe>> menu,
  ) async {
    final text = formatWeekMenuFromCategories(menu);
    await Share.share(text, subject: 'Veckomeny');
  }

  /// GET formatted text methods (för views som behöver text)
  String getFormattedRecipe(Recipe recipe, {RecipeShareFormat? format}) {
    return format != null
        ? switch (format) {
            RecipeShareFormat.complete => formatRecipeComplete(recipe),
            RecipeShareFormat.compact => formatRecipeCompact(recipe),
            RecipeShareFormat.markdown => formatRecipeMarkdown(recipe),
          }
        : getSmartFormat(recipe);
  }

  String getFormattedShoppingList(List<UnifiedShoppingItem> items) {
    return formatShoppingList(items);
  }

  String getFormattedWeekMenuFromCategories(Map<String, List<Recipe>> menu) {
    return formatWeekMenuFromCategories(menu);
  }

  /// Formattera veckomeny från kategorier
  String formatWeekMenuFromCategories(Map<String, List<Recipe>> menu) {
    final buffer = StringBuffer();

    buffer.writeln('🍽 VECKOMENY');
    buffer.writeln('===========');
    buffer.writeln();

    // Gå igenom varje kategori
    for (final entry in menu.entries) {
      if (entry.value.isNotEmpty) {
        buffer.writeln('【${entry.key.toUpperCase()}】');

        for (final recipe in entry.value) {
          buffer.writeln('• ${recipe.title}');

          // Lägg till metadata
          final meta = <String>[];
          if (recipe.timeMinutes != null) {
            meta.add('⏱ ${recipe.timeMinutes} min');
          }
          if (recipe.portions != null) {
            meta.add('🍴 ${recipe.portions} port');
          }
          if (recipe.rating != null && recipe.rating! > 0) {
            final stars = List.filled(recipe.rating!.round(), '⭐').join();
            meta.add(stars);
          }

          if (meta.isNotEmpty) {
            buffer.writeln('  ${meta.join(' | ')}');
          }
        }
        buffer.writeln();
      }
    }

    // Sammanfattning
    final totalRecipes = menu.values.fold(0, (sum, list) => sum + list.length);
    final totalCategories =
        menu.keys.where((key) => menu[key]!.isNotEmpty).length;

    buffer.writeln('📊 Sammanfattning:');
    buffer.writeln('$totalRecipes recept i $totalCategories kategorier');

    return buffer.toString();
  }

  // ===== CLIPBOARD METHODS =====

  /// Kopiera text till urklipp
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Kopiera recept till urklipp
  Future<void> copyRecipe(Recipe recipe, {RecipeShareFormat? format}) async {
    final text = format != null
        ? switch (format) {
            RecipeShareFormat.complete => formatRecipeComplete(recipe),
            RecipeShareFormat.compact => formatRecipeCompact(recipe),
            RecipeShareFormat.markdown => formatRecipeMarkdown(recipe),
          }
        : getSmartFormat(recipe);
    await copyToClipboard(text);
  }
}
