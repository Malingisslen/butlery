// lib/widgets/common/share_dialog/share_dialog_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

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
      contentType,
      selectedMode,
      supportsRealtimeSharing,
    );
    
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppDimensions.borderRadiusM),
          bottomRight: Radius.circular(AppDimensions.borderRadiusM),
        ),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading ? null : onCancel,
              child: Text(
                'Avbryt',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: ElevatedButton(
              onPressed: (!hasSelectedFriends || isLoading) ? null : onShare,
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Text(
                      shareButtonText,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _getShareButtonText(
    ShareContentType contentType,
    ShareMode selectedMode,
    bool supportsRealtimeSharing,
  ) {
    if (selectedMode == ShareMode.realtime && supportsRealtimeSharing) {
      return 'Skapa & Dela';
    } else {
      switch (contentType) {
        case ShareContentType.recipe:
          return 'Dela recept';
        case ShareContentType.menu:
          return 'Dela meny';
        case ShareContentType.shoppingList:
          return 'Dela inköpslista';
      }
    }
  }

  static Widget buildSelectionSummary(
    BuildContext context,
    int selectedCount,
    String contentTypeName,
  ) {
    if (selectedCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingL,
          vertical: AppDimensions.spacingS,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 16,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Text(
              'Välj minst en vän för att dela $contentTypeName',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.smallRadius),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Text(
            '$selectedCount vän${selectedCount > 1 ? 'ner' : ''} valda',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}