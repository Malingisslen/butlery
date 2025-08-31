// lib/widgets/common/share_dialog/share_mode_selection.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
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
    if (!supportsRealtimeSharing || contentType == ShareContentType.shoppingList) {
      return const SizedBox.shrink();
    }

    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delningssätt',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        
        RadioGroup<ShareMode>(
          onChanged: (ShareMode? mode) => onModeChanged(mode!),
          child: Column(
            children: [
              // Static Copy Option
              Container(
                margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
                child: InkWell(
                  onTap: () => onModeChanged(ShareMode.staticCopy),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedMode == ShareMode.staticCopy
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                      color: selectedMode == ShareMode.staticCopy
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : null,
                    ),
                    child: Row(
                      children: [
                        const Radio<ShareMode>(
                          value: ShareMode.staticCopy,
                        ),
                        const SizedBox(width: AppDimensions.spacingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Statisk kopia',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacingXs),
                              Text(
                                'Skicka en kopia som mottagaren kan ändra fritt',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                      color: selectedMode == ShareMode.realtime
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : null,
                    ),
                    child: Row(
                      children: [
                        const Radio<ShareMode>(
                          value: ShareMode.realtime,
                        ),
                        const SizedBox(width: AppDimensions.spacingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Realtidsdelning',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: AppDimensions.spacingM),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppDimensions.spacingXs,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                                    ),
                                    child: Text(
                                      'NYTT',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimensions.spacingXs),
                              Text(
                                'Alla kan redigera tillsammans i realtid',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        ),
        
        const SizedBox(height: AppDimensions.spacingXl),
      ],
    );
  }

}