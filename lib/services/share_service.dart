// lib/services/share_service.dart

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe_unified.dart';
import '../models/unified/unified_shopping_item.dart';
import '../core/base/base_service.dart';

/// Format-alternativ för receptdelning
enum RecipeShareFormat {
  complete, // Fullständigt format med alla detaljer
  compact, // Kompakt format för SMS/chat
  markdown, // Markdown-format för export
}

/// Service som hanterar all delningsfunktionalitet i appen
/// Modulär design för enkel utbyggnad och testning
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

  /// Formattera recept som komplett text med alla detaljer
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

  /// Formattera recept i kompakt format för chat/SMS
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

  /// Dela recept via native share sheet
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
