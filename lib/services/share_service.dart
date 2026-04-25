/// Share service for recipes, shopping lists, and menus with formats (complete/compact/markdown), Swedish.
/// ```dart
/// final ss = ShareService(); await ss.shareRecipe(recipe);

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';

/// Recipe sharing formats: complete (full details), compact (messaging/social), markdown (documentation/export).
enum RecipeShareFormat { complete, compact, markdown }

/// Content sharing service with multi-format output and platform-native sharing.
class ShareService extends BaseService {
  @override
  String get serviceName => 'ShareService';

  static String get _ingredientsTitle =>
      AppLocale.current.shareIngredientsLabel;
  static String get _instructionsTitle =>
      AppLocale.current.shareInstructionsLabel;
  static String get _sourceLabel => AppLocale.current.shareSourceLabel;
  static String get _portionsLabel => AppLocale.current.sharePortionsUnit;
  static String get _minutesLabel => AppLocale.current.shareMinutesUnit;
  static const String _recipeEmoji = '🍽';
  static const String _timeEmoji = '⏱';
  static const String _servingsEmoji = '🍴';
  static const String _starEmoji = '⭐';

  /// Formats recipe as complete text (title, metadata, description, ingredients, instructions, tags, source).
  String formatRecipeComplete(Recipe recipe) {
    final buffer = StringBuffer();

    // Title
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

    // Description
    if (recipe.description.isNotEmpty) {
      buffer.writeln(recipe.description);
      buffer.writeln();
    }

    // Ingredients
    if (recipe.ingredients.isNotEmpty) {
      buffer.writeln(_ingredientsTitle);
      for (final ingredient in recipe.ingredients) {
        buffer.writeln('• $ingredient');
      }
      buffer.writeln();
    }

    // Instructions
    if (recipe.instructions.isNotEmpty) {
      buffer.writeln(_instructionsTitle);
      for (int i = 0; i < recipe.instructions.length; i++) {
        buffer.writeln(
          '${i + 1}. ${recipe.instructions[i]}',
        );
      }
      buffer.writeln();
    }

    // Tags instead of tips
    if (recipe.personalTagIds != null && recipe.personalTagIds!.isNotEmpty) {
      buffer.writeln('Tags: ${recipe.personalTagIds!.join(", ")}');
      buffer.writeln();
    }

    // Source
    if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      buffer.writeln('$_sourceLabel ${recipe.sourceUrl}');
    }

    return buffer.toString();
  }

  /// Formats recipe in compact format with emoji (🍽⏱🍴⭐) for messaging/social media.
  String formatRecipeCompact(Recipe recipe) {
    final buffer = StringBuffer();

    // Emoji and title
    buffer.writeln('$_recipeEmoji ${recipe.title}');

    // Metadata with emojis
    final metadata = <String>[];
    if (recipe.timeMinutes != null) {
      metadata.add(
          '$_timeEmoji ${recipe.timeMinutes} ${AppLocale.current.shareMinutesAbbrev}');
    }
    if (recipe.portions != null) {
      metadata.add(
          '$_servingsEmoji ${recipe.portions} ${AppLocale.current.sharePortionsAbbrev}');
    }
    if (recipe.rating != null && recipe.rating! > 0) {
      metadata.add(_starEmoji * recipe.rating!.round());
    }

    if (metadata.isNotEmpty) {
      buffer.writeln(metadata.join(' | '));
      buffer.writeln();
    }

    // Description
    if (recipe.description.isNotEmpty) {
      buffer.writeln(recipe.description);
      buffer.writeln();
    }

    // Ingredients - show all for compact format too
    if (recipe.ingredients.isNotEmpty) {
      buffer.writeln(_ingredientsTitle);
      for (final ingredient in recipe.ingredients) {
        buffer.writeln('• $ingredient');
      }
      buffer.writeln();
    }

    // Quick instructions
    if (recipe.instructions.isNotEmpty) {
      buffer.writeln(AppLocale.current.shareInstructionsLabelCompact);
      for (int i = 0; i < recipe.instructions.length; i++) {
        buffer.writeln('${i + 1}. ${recipe.instructions[i]}');
      }
    }

    // Source if available
    if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('$_sourceLabel ${recipe.sourceUrl}');
    }

    return buffer.toString();
  }

  /// Format recipe as Markdown
  String formatRecipeMarkdown(Recipe recipe) {
    final buffer = StringBuffer();

    // Main heading
    buffer.writeln('# ${recipe.title}');
    buffer.writeln();

    // Metadata
    if (recipe.timeMinutes != null) {
      buffer.writeln(
          '${AppLocale.current.shareTimeLabelBold} ${recipe.timeMinutes} $_minutesLabel');
    }
    if (recipe.portions != null) {
      buffer.writeln(
          '${AppLocale.current.sharePortionsLabelBold} ${recipe.portions}');
    }
    if (recipe.rating != null && recipe.rating! > 0) {
      buffer.writeln(
          '${AppLocale.current.shareRatingLabelBold} ${_starEmoji * recipe.rating!.round()}');
    }
    if (recipe.mealType.isNotEmpty) {
      buffer.writeln(
          '${AppLocale.current.shareTypeLabelBold} ${recipe.mealType}');
    }
    buffer.writeln();

    // Description
    if (recipe.description.isNotEmpty) {
      buffer.writeln('> ${recipe.description}');
      buffer.writeln();
    }

    // Ingredients
    if (recipe.ingredients.isNotEmpty) {
      buffer.writeln('## $_ingredientsTitle');
      for (final ingredient in recipe.ingredients) {
        buffer.writeln('- $ingredient');
      }
      buffer.writeln();
    }

    // Instructions
    if (recipe.instructions.isNotEmpty) {
      buffer.writeln('## $_instructionsTitle');
      for (int i = 0; i < recipe.instructions.length; i++) {
        buffer.writeln('${i + 1}. ${recipe.instructions[i]}');
      }
      buffer.writeln();
    }

    // Tags
    if (recipe.personalTagIds != null && recipe.personalTagIds!.isNotEmpty) {
      buffer.writeln('## ${AppLocale.current.shareTagsLabel}');
      buffer.writeln(recipe.personalTagIds!.map((tag) => '`$tag`').join(' '));
      buffer.writeln();
    }

    // Source
    if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      buffer.writeln('---');
      buffer.writeln(
        '*$_sourceLabel [${recipe.sourceUrl}](${recipe.sourceUrl})*',
      );
    }

    return buffer.toString();
  }

  /// Translate language-neutral category constant to localized display name for sharing.
  static String _categoryDisplayName(String category) {
    final l = AppLocale.current;
    switch (category) {
      case ShoppingCategory.fruitVeg:
        return l.categoryFruitVeg;
      case ShoppingCategory.dairy:
        return l.categoryDairy;
      case ShoppingCategory.meatFish:
        return l.categoryMeatFish;
      case ShoppingCategory.breadGrain:
        return l.categoryBread;
      case ShoppingCategory.pantry:
        return l.categoryPantry;
      case ShoppingCategory.frozen:
        return l.categoryFrozen;
      case ShoppingCategory.drinks:
        return l.categoryBeverage;
      case ShoppingCategory.snacks:
        return l.categorySnacks;
      case ShoppingCategory.cleaning:
        return l.categoryHygiene;
      case ShoppingCategory.spices:
        return l.categorySpices;
      case ShoppingCategory.canned:
        return l.categoryCanned;
      case ShoppingCategory.dryGoods:
        return l.categoryDryGoods;
      case ShoppingCategory.other:
        return l.categoryOther;
      default:
        return category;
    }
  }

  String formatShoppingList(List<UnifiedShoppingItem> items) {
    final buffer = StringBuffer();

    buffer.writeln(AppLocale.current.shareShoppingListTitle);
    buffer.writeln('===========');
    buffer.writeln();

    // Group by category if categories exist
    final groupedItems = <String, List<UnifiedShoppingItem>>{};
    for (final item in items) {
      final category =
          item.category.isEmpty ? ShoppingCategory.other : item.category;
      groupedItems.putIfAbsent(category, () => []).add(item);
    }

    // If only one category, show as simple list
    if (groupedItems.length == 1) {
      for (final item in items) {
        final checkbox = item.bought ? '☑' : '☐';
        buffer.writeln('$checkbox ${item.toString()}');
      }
    } else {
      // Show grouped
      for (final entry in groupedItems.entries) {
        buffer.writeln('【${_categoryDisplayName(entry.key).toUpperCase()}】');
        for (final item in entry.value) {
          final checkbox = item.bought ? '☑' : '☐';
          buffer.writeln('$checkbox ${item.toString()}');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  String formatShoppingListGrouped(
    Map<String, List<UnifiedShoppingItem>> groupedItems,
  ) {
    final buffer = StringBuffer();

    buffer.writeln(AppLocale.current.shareShoppingListTitleSimple);
    buffer.writeln(
      '===========',
    ); // Using = directly instead of multiplication
    buffer.writeln();

    groupedItems.forEach((category, items) {
      buffer.writeln(_categoryDisplayName(category).toUpperCase());
      for (final item in items) {
        final checkbox = item.bought ? '☑' : '☐';
        buffer.writeln('  $checkbox ${item.toString()}');
      }
      buffer.writeln();
    });

    return buffer.toString();
  }

  String formatWeekMenu(Map<String, Recipe?> weekMenu) {
    final buffer = StringBuffer();

    buffer.writeln(AppLocale.current.shareWeekMenuTitle);
    buffer.writeln('=========');
    buffer.writeln();

    // Iterate Monday(1) through Sunday(7)
    // Jan 1 2024 is a Monday
    for (int i = 1; i <= 7; i++) {
      final date = DateTime(2024, 1, i);
      final localizedDay =
          DateFormat.EEEE(AppLocale.current.localeName).format(date);
      final displayDay =
          localizedDay[0].toUpperCase() + localizedDay.substring(1);
      // Map keys are Swedish weekday names
      final svDay = DateFormat.EEEE('sv').format(date);
      final svDisplayDay = svDay[0].toUpperCase() + svDay.substring(1);
      final recipe = weekMenu[svDisplayDay];
      if (recipe != null) {
        buffer.writeln('$displayDay: ${recipe.title}');
      } else {
        buffer.writeln('$displayDay: -');
      }
    }

    return buffer.toString();
  }

  String getSmartFormat(Recipe recipe) {
    return formatRecipeComplete(recipe);
  }

  Future<void> shareRecipe(Recipe recipe) async {
    await executeServiceOperation(
      () async {
        final text = getSmartFormat(recipe);
        final textWithLink = await _appendDeepLink(text, recipe.id);
        await SharePlus.instance.share(ShareParams(
          text: textWithLink,
          subject: recipe.title,
        ));
        await _trackShareAnalytics(
          recipeId: recipe.id,
          method: 'system_share_sheet',
        );
      },
      operationName: 'Share recipe',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

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

        final textWithLink = await _appendDeepLink(text, recipe.id);
        await SharePlus.instance.share(ShareParams(
          text: textWithLink,
          subject: recipe.title,
        ));
        await _trackShareAnalytics(
          recipeId: recipe.id,
          method: 'system_share_sheet',
        );
      },
      operationName: 'Share recipe with format',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  /// Emits `recipe_shared` + checks the once-per-user `first_share` milestone.
  /// Recipient count is unknown for external surfaces (system share sheet,
  /// clipboard) — analytics-side bucketed as 0.
  Future<void> _trackShareAnalytics({
    required String recipeId,
    required String method,
  }) async {
    final analytics = ServiceLocator.tryGet<AnalyticsService>();
    if (analytics == null) return;
    await analytics.logRecipeShared(
      method: method,
      recipeId: recipeId,
      recipientCount: 0,
    );
    final userService = ServiceLocator.tryGet<UserService>();
    await analytics.recipe.logFirstShareIfMilestone(
      userId: userService?.currentUserId,
      shareMethod: method,
      joinedAt: userService?.currentUserProfile?.joinedAt,
    );
  }

  Future<String> _appendDeepLink(String text, String recipeId) async {
    try {
      final userId = ServiceLocator.get<PermissionService>().currentUserId;
      if (userId == null) return text;
      final longUrl = DeepLinkService.generateRecipeShareLink(
        recipeId: recipeId,
        fromUserId: userId,
      );
      final url = await DeepLinkService.generateShortUrl(longUrl)
          .timeout(const Duration(seconds: 3), onTimeout: () => longUrl);
      return '$text\n\n$url';
    } catch (e) {
      AppLogger.warning('Failed to append deep link: $e');
      return text;
    }
  }

  Future<void> shareShoppingList(List<UnifiedShoppingItem> items) async {
    await executeServiceOperation(
      () async {
        final text = formatShoppingList(items);
        await SharePlus.instance.share(ShareParams(
          text: text,
          subject: AppLocale.current.shareShoppingListTitleSimple,
        ));
      },
      operationName: 'Share shopping list',
      requiresAuth: false,
      requiresNetwork: false,
    );
  }

  Future<void> shareWeekMenuFromCategories(
    Map<String, List<Recipe>> menu,
  ) async {
    final text = formatWeekMenuFromCategories(menu);
    await SharePlus.instance.share(ShareParams(
      text: text,
      subject: AppLocale.current.shareWeekMenuTitle,
    ));
  }

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

  String formatWeekMenuFromCategories(Map<String, List<Recipe>> menu) {
    final buffer = StringBuffer();

    buffer.writeln(AppLocale.current.shareWeekMenuTitleEmoji);
    buffer.writeln('===========');
    buffer.writeln();

    // Iterate through each category
    for (final entry in menu.entries) {
      if (entry.value.isNotEmpty) {
        buffer.writeln('【${entry.key.toUpperCase()}】');

        for (final recipe in entry.value) {
          buffer.writeln('• ${recipe.title}');

          // Add metadata
          final meta = <String>[];
          if (recipe.timeMinutes != null) {
            meta.add(
                '⏱ ${recipe.timeMinutes} ${AppLocale.current.shareMinutesAbbrev}');
          }
          if (recipe.portions != null) {
            meta.add(
                '🍴 ${recipe.portions} ${AppLocale.current.sharePortionsAbbrev}');
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

    // Summary
    final totalRecipes = menu.values.fold(0, (sum, list) => sum + list.length);
    final totalCategories =
        menu.keys.where((key) => menu[key]!.isNotEmpty).length;

    buffer.writeln(AppLocale.current.shareSummaryLabel);
    buffer.writeln(AppLocale.current
        .shareSummaryRecipesInCategories(totalRecipes, totalCategories));

    return buffer.toString();
  }

  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> copyRecipe(Recipe recipe, {RecipeShareFormat? format}) async {
    final text = format != null
        ? switch (format) {
            RecipeShareFormat.complete => formatRecipeComplete(recipe),
            RecipeShareFormat.compact => formatRecipeCompact(recipe),
            RecipeShareFormat.markdown => formatRecipeMarkdown(recipe),
          }
        : getSmartFormat(recipe);
    await copyToClipboard(text);
    await _trackShareAnalytics(
      recipeId: recipe.id,
      method: 'link_copy',
    );
  }
}
