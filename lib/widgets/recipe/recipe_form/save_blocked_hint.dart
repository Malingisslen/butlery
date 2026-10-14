import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_save_blocker.dart';

/// The line above a disabled Spara that says what is missing, so a greyed
/// button is never left unexplained.
class SaveBlockedHint extends StatelessWidget {
  final RecipeSaveBlocker blocker;

  const SaveBlockedHint({super.key, required this.blocker});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space8),
      child: Text(
        switch (blocker) {
          RecipeSaveBlocker.title => l10n.recipeSaveNeedsTitle,
          RecipeSaveBlocker.ingredients => l10n.recipeSaveNeedsIngredient,
          RecipeSaveBlocker.instructions => l10n.recipeSaveNeedsInstruction,
        },
        key: const ValueKey('recipe-save-blocked-hint'),
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
