import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Autocomplete suggestion list for ingredient search.
/// Shared by the pantry add sheet and the ingredient search chip input.
class IngredientSuggestionList extends StatelessWidget {
  const IngredientSuggestionList({
    required this.results,
    required this.onTap,
    super.key,
  });

  final List<IngredientData> results;
  final void Function(IngredientData) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: AppDimensions.spacingXs),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: results.length,
        itemBuilder: (context, index) {
          final ingredient = results[index];
          return Semantics(
            label: context.l10n.a11yAddIngredient(ingredient.swedish),
            button: true,
            child: InkWell(
              key: ValueKey(ingredient.id),
              onTap: () => onTap(ingredient),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                  vertical: AppDimensions.spacingSm,
                ),
                child: Text(
                  ingredient.swedish,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
