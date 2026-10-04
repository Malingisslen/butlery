// lib/widgets/common/share_dialog/share_mode_selection.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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
              margin: const EdgeInsets.only(bottom: AppDimensions.space4),
              child: Semantics(
                label: context.l10n.a11yShareModeStaticCopy,
                button: true,
                selected: selectedMode == ShareMode.staticCopy,
                child: Material(
                  type: MaterialType.transparency,
                  child: PressFill(
                    surface: selectedMode == ShareMode.staticCopy
                        ? PressSurface.raised
                        : PressSurface.base,
                    child: InkWell(
                      onTap: () => onModeChanged(ShareMode.staticCopy),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusControl,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusControl,
                          ),
                          color: selectedMode == ShareMode.staticCopy
                              ? Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest
                              : null,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingL),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedMode == ShareMode.staticCopy
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusControl,
                            ),
                          ),
                          child: Row(
                            children: [
                              ButleryIcon(
                                selectedMode == ShareMode.staticCopy
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: selectedMode == ShareMode.staticCopy
                                    ? Theme.of(context).colorScheme.onSurface
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
                                    const SizedBox(
                                      height: AppDimensions.spacingXs,
                                    ),
                                    Text(
                                      context.l10n.shareStaticCopyDescription,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
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
                  ),
                ),
              ),
            ),

            // Realtime Sharing Option
            Semantics(
              label: context.l10n.a11yShareModeRealtime,
              button: true,
              selected: selectedMode == ShareMode.realtime,
              child: Material(
                type: MaterialType.transparency,
                child: PressFill(
                  surface: selectedMode == ShareMode.realtime
                      ? PressSurface.raised
                      : PressSurface.base,
                  child: InkWell(
                    onTap: () => onModeChanged(ShareMode.realtime),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusControl,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusControl,
                        ),
                        color: selectedMode == ShareMode.realtime
                            ? Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest
                            : null,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingL),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedMode == ShareMode.realtime
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusControl,
                          ),
                        ),
                        child: Row(
                          children: [
                            ButleryIcon(
                              selectedMode == ShareMode.realtime
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: selectedMode == ShareMode.realtime
                                  ? Theme.of(context).colorScheme.onSurface
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
                                  const SizedBox(
                                    height: AppDimensions.spacingXs,
                                  ),
                                  Text(
                                    contentType == ShareContentType.shoppingList
                                        ? context
                                              .l10n
                                              .shareRealtimeShoppingDescription
                                        : context
                                              .l10n
                                              .shareRealtimeSharingDescription,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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
