/// The recipes that carry a tag, under its rules on the tag page.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/list/recipe_thumb_row.dart';

class TagDetailRecipesSection extends StatefulWidget {
  const TagDetailRecipesSection({
    required this.tagId,
    required this.recipeCount,
    super.key,
  });

  final String tagId;

  /// The tag's total, which can be more than the list shows.
  final int recipeCount;

  @override
  State<TagDetailRecipesSection> createState() =>
      _TagDetailRecipesSectionState();
}

class _TagDetailRecipesSectionState extends State<TagDetailRecipesSection> {
  late Future<List<Recipe>> _recipes = _load();

  Future<List<Recipe>> _load() async {
    try {
      return await ServiceLocator.get<RecipeRepository>().fetchRecipesByTagId(
        widget.tagId,
      );
    } catch (e) {
      AppLogger.warning('Tag page: recipes with the tag not loaded: $e');
      return const [];
    }
  }

  @override
  void didUpdateWidget(TagDetailRecipesSection old) {
    super.didUpdateWidget(old);
    if (old.tagId != widget.tagId || old.recipeCount != widget.recipeCount) {
      _recipes = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: context.modeColors.textAccent,
                width: AppDimensions.borderWidthThick,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
            child: Text(
              context.l10n.tagDetailRecipesHeading(widget.recipeCount),
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
        FutureBuilder<List<Recipe>>(
          future: _recipes,
          builder: (context, snapshot) => Column(
            children: [
              for (final recipe in snapshot.data ?? const <Recipe>[])
                RecipeThumbRow(
                  key: ValueKey('tag-recipe-${recipe.id}'),
                  recipe: recipe,
                  onTap: () => Navigator.of(context).pushNamed(
                    Routes.recipeDetail,
                    arguments: <String, dynamic>{'recipe': recipe},
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
