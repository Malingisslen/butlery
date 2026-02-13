// lib/widgets/common/share_dialog/share_mode_selection.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

class ShareModeSelection {
  static Widget build(
    BuildContext context,
    ShareMode selectedMode,
    ShareContentType contentType,
    bool supportsRealtimeSharing,
    Function(ShareMode) onModeChanged,
  ) {
    if (!supportsRealtimeSharing) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.shareMethod,
          style: AppTextStyles.titleBold,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Column(
          children: [
            // Static Copy Option
            Container(
              margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
              child: InkWell(
                onTap: () => onModeChanged(ShareMode.staticCopy),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusM),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selectedMode == ShareMode.staticCopy
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusM),
                    color: selectedMode == ShareMode.staticCopy
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: AppDimensions.opacityMediumLight)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedMode == ShareMode.staticCopy
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selectedMode == ShareMode.staticCopy
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.shareStaticCopy,
                              style: AppTextStyles.contentTitle,
                            ),
                            const SizedBox(height: AppDimensions.spacingXs),
                            Text(
                              context.l10n.shareStaticCopyDescription,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Realtime Sharing Option
            InkWell(
              onTap: () => onModeChanged(ShareMode.realtime),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selectedMode == ShareMode.realtime
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusM),
                  color: selectedMode == ShareMode.realtime
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: AppDimensions.opacityMediumLight)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedMode == ShareMode.realtime
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selectedMode == ShareMode.realtime
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.shareRealtimeSharing,
                            style: AppTextStyles.contentTitle,
                          ),
                          const SizedBox(height: AppDimensions.spacingXs),
                          Text(
                            contentType == ShareContentType.shoppingList
                                ? context.l10n.shareRealtimeShoppingDescription
                                : context.l10n.shareRealtimeSharingDescription,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingXl),
      ],
    );
  }
}
