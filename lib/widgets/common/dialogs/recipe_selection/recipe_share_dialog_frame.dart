// lib/widgets/common/dialogs/recipe_selection/recipe_share_dialog_frame.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// The friend and group recipe-sharing dialogs' shared frame: title, content
/// and the cancel and share actions. Takes plain values because the two
/// dialogs use different view models.
class RecipeShareDialogFrame extends StatelessWidget {
  final String recipientName;
  final Widget content;
  final bool hasSelectedRecipes;
  final int selectedCount;
  final bool isSharing;
  final VoidCallback onShare;

  const RecipeShareDialogFrame({
    super.key,
    required this.recipientName,
    required this.content,
    required this.hasSelectedRecipes,
    required this.selectedCount,
    required this.isSharing,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        context.l10n.dialogShareRecipesWith(recipientName),
        style: AppTextStyles.headlineSmall,
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: content,
      ),
      actions: [
        const DialogCancelButton(),
        if (hasSelectedRecipes)
          // The theme's ink filled button (onPrimary on primary in both
          // schemes); sharing says so and draws the plate line along
          // its bottom edge, never a spinner
          BusyButtonSemantics(
            busy: isSharing,
            name: '${context.l10n.commonShare} ($selectedCount)',
            busyLabel: context.l10n.dialogSharing,
            child: FilledButton.icon(
              onPressed: isSharing ? PlateLineButton.ignore : onShare,
              style: isSharing
                  ? PlateLineButton.busyStyle(
                      null,
                      Theme.of(context).filledButtonTheme.style,
                    )
                  : null,
              icon: const ButleryIcon(ButleryIcons.share2),
              label: Text(
                isSharing
                    ? context.l10n.dialogSharing
                    : '${context.l10n.commonShare} ($selectedCount)',
              ),
            ),
          ),
      ],
    );
  }
}
