// lib/widgets/recipe/related_recipes_editor.dart
//
// BUT-1057: "Relaterade recept" section for the recipe edit form.
// Shows existing relatedRecipeIds as removable square chips, with a
// "+ Länka relaterat recept" button that opens the picker dialog.

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/chips/butlery_removable_chip.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
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
        const SizedBox(height: AppDimensions.space4),

        // Chips for currently linked recipes
        if (relatedRecipes.isNotEmpty) ...[
          Wrap(
            spacing: AppDimensions.space4,
            runSpacing: AppDimensions.space4,
            children: relatedRecipes.map((r) {
              return ButleryRemovableChip(
                key: ValueKey(r.id),
                label: r.title,
                onRemove: () => _handleUnlink(context, r.id),
                removeLabel: context.l10n.a11yRemoveRelatedRecipe,
              );
            }).toList(),
          ),
          const SizedBox(height: AppDimensions.space4),
        ],

        // Link button — OutlinedButton is a Material primitive that already
        // carries its own Semantics; no extra wrapper needed per ui-conventions.
        ActionButtons.outlinedButton(
          context,
          label: context.l10n.recipeRelatedLinkButton,
          icon: ButleryIcons.link,
          onPressed: () => _openPicker(context),
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
        SnackBarUtils.showSuccess(
          context,
          context.l10n.recipeRelatedLinkSuccess,
        );
      } else {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.recipeRelatedLinkError,
        );
      }
    }
  }

  Future<void> _handleUnlink(BuildContext context, String targetId) async {
    final ok = await onUnlink(targetId);
    if (!context.mounted) return;
    if (ok) {
      SnackBarUtils.showSuccess(
        context,
        context.l10n.recipeRelatedUnlinkSuccess,
      );
    } else {
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.recipeRelatedUnlinkError,
      );
    }
  }
}
