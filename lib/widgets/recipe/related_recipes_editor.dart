// lib/widgets/recipe/related_recipes_editor.dart
//
// BUT-1057: "Relaterade recept" section for the recipe edit form.
// Shows existing relatedRecipeIds as removable square chips, with a
// "+ Länka relaterat recept" button that opens the picker dialog.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/recipe/related_recipes_picker_dialog.dart';

/// Edit-form section for managing related-recipe links.
///
/// Renders:
/// - Square chips for each entry in [relatedRecipes] (X removes the link).
/// - A button to open the picker dialog and link more recipes.
///
/// Purely presentational: the caller resolves ids to (id, title) records and
/// owns the async service calls behind [onLink] / [onUnlink]. This widget
/// never touches the ServiceLocator (per lib/widgets/CLAUDE.md).
class RelatedRecipesEditor extends StatelessWidget {
  final String currentRecipeId;

  /// Linked recipes resolved to (id, title) records by the viewmodel.
  final List<({String id, String title})> relatedRecipes;

  /// Callback to add a link. Returns whether the operation succeeded.
  final Future<bool> Function(String targetId) onLink;

  /// Callback to remove a link. Returns whether the operation succeeded.
  final Future<bool> Function(String targetId) onUnlink;

  const RelatedRecipesEditor({
    super.key,
    required this.currentRecipeId,
    required this.relatedRecipes,
    required this.onLink,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading
        Text(
          context.l10n.recipeRelatedSectionTitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXs),

        // Chips for currently linked recipes
        if (relatedRecipes.isNotEmpty) ...[
          Wrap(
            spacing: AppDimensions.spacingS,
            runSpacing: AppDimensions.spacingS,
            children: relatedRecipes.map((r) {
              return _RelatedChip(
                key: ValueKey(r.id),
                title: r.title,
                onRemove: () => _handleUnlink(context, r.id),
              );
            }).toList(),
          ),
          const SizedBox(height: AppDimensions.spacingS),
        ],

        // Link button — OutlinedButton is a Material primitive that already
        // carries its own Semantics; no extra wrapper needed per ui-conventions.
        OutlinedButton.icon(
          onPressed: () => _openPicker(context),
          icon: const Icon(Icons.link),
          label: Text(
            context.l10n.recipeRelatedLinkButton,
            style: AppTextStyles.bodyMedium,
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingL,
              vertical: AppDimensions.paddingM,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            side: BorderSide(color: cs.primary),
            foregroundColor: cs.primary,
          ),
        ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await RelatedRecipesPickerDialog.show(
      context,
      currentRecipeId: currentRecipeId,
      alreadyLinkedIds: relatedRecipes.map((r) => r.id).toSet(),
    );
    if (picked == null || picked.isEmpty) return;
    if (!context.mounted) return;

    for (final recipe in picked) {
      final ok = await onLink(recipe.id);
      if (!context.mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.recipeRelatedLinkSuccess)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.recipeRelatedLinkError)),
        );
      }
    }
  }

  Future<void> _handleUnlink(BuildContext context, String targetId) async {
    final ok = await onUnlink(targetId);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.recipeRelatedUnlinkSuccess)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.recipeRelatedUnlinkError)),
      );
    }
  }
}

/// Square chip with title + X button for one linked recipe.
class _RelatedChip extends StatelessWidget {
  final String title;
  final VoidCallback onRemove;

  const _RelatedChip({
    super.key,
    required this.title,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: context.l10n.a11yRelatedRecipeChip(title),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
          border: Border.all(
            color: cs.primary.withValues(
              alpha: AppDimensions.opacityMediumLight,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppDimensions.spacingS,
                end: AppDimensions.spacingXs,
                top: AppDimensions.spacingXs,
                bottom: AppDimensions.spacingXs,
              ),
              child: Text(
                title,
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: cs.primary,
                ),
              ),
            ),
            Semantics(
              label: context.l10n.a11yRemoveRelatedRecipe(title),
              button: true,
              child: InkWell(
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppDimensions.spacingXs,
                    end: AppDimensions.spacingS,
                    top: AppDimensions.spacingXs,
                    bottom: AppDimensions.spacingXs,
                  ),
                  child: Icon(
                    Icons.close,
                    size: AppDimensions.iconSizeS,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
