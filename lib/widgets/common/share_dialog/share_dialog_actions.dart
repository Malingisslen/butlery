// lib/widgets/common/share_dialog/share_dialog_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

class ShareDialogActions {
  static Widget buildActionButtons(
    BuildContext context,
    ShareContentType contentType,
    ShareMode selectedMode,
    bool supportsRealtimeSharing,
    bool hasSelectedFriends,
    bool isLoading,
    VoidCallback onCancel,
    VoidCallback onShare,
  ) {
    final shareButtonText = _getShareButtonText(
      context,
      contentType,
      selectedMode,
      supportsRealtimeSharing,
    );

    // BUG-019 fix: Use Material widget to ensure proper hit-testing on Flutter Web
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppDimensions.borderRadiusM),
        bottomRight: Radius.circular(AppDimensions.borderRadiusM),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: AppDimensions.opacityMediumLight),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: ActionButtons.outlinedButton(
                context,
                label: context.l10n.commonCancel,
                onPressed: isLoading ? null : onCancel,
                // Fix BUG-019: use isExpanded to fill container and fix hit-testing
                isExpanded: true,
                enablePressAnimation: false,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              flex: 4,
              child: ActionButtons.primaryButton(
                context,
                label: shareButtonText,
                onPressed: (!hasSelectedFriends || isLoading) ? null : onShare,
                isLoading: isLoading,
                // Fix BUG-019: use isExpanded to fill container and fix hit-testing
                isExpanded: true,
                enablePressAnimation: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _getShareButtonText(
    BuildContext context,
    ShareContentType contentType,
    ShareMode selectedMode,
    bool supportsRealtimeSharing,
  ) {
    if (selectedMode == ShareMode.realtime && supportsRealtimeSharing) {
      return context.l10n.shareCreateAndShare;
    } else {
      switch (contentType) {
        case ShareContentType.recipe:
          return context.l10n.shareRecipeTitle;
        case ShareContentType.menu:
          return context.l10n.shareMenuTitle;
        case ShareContentType.shoppingList:
          return context.l10n.shareShoppingListTitle;
        case ShareContentType.personalTag:
          return 'Dela tagg';
      }
    }
  }

  static Widget buildSelectionSummary(
    BuildContext context,
    int selectedCount,
    String contentTypeName,
  ) {
    if (selectedCount == 0) {
      final warningColor = context.butleryColors.warning;
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingL,
          vertical: AppDimensions.spacingS,
        ),
        decoration: BoxDecoration(
          color: warningColor.withValues(alpha: AppDimensions.opacityVeryLight),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          border: Border.all(
            color: warningColor.withValues(
                alpha: AppDimensions.opacityMediumLight),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: AppDimensions.iconSizeS,
              color: warningColor,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Text(
                context.l10n.shareSelectAtLeastOneFriend,
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: warningColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final successColor = context.butleryColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: successColor.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color:
              successColor.withValues(alpha: AppDimensions.opacityMediumLight),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: AppDimensions.iconSizeS,
            color: successColor,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              context.l10n.shareFriendsSelectedCount(selectedCount),
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: successColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
