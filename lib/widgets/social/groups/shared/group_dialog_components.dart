// lib/widgets/social/groups/shared/group_dialog_components.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Shared components for group dialogs
/// Contains reusable UI components that are used across multiple group dialog types
/// to reduce code duplication and maintain consistency.

/// Available emoji icons for groups
class GroupEmojiConstants {
  static const List<String> availableEmojis = [
    '👥',
    '🏠',
    '💼',
    '🎯',
    '⚽',
    '🎮',
    '📚',
    '🎵',
    '🍕',
    '☕',
    '💪',
    '🌟',
    '🔥',
    '💎',
    '🚀',
    '🎉',
    '💡',
    '🎨',
    '🌈',
    '⭐'
  ];
}

/// Reusable emoji selector widget
class EmojiSelector extends StatelessWidget {
  final String selectedEmoji;
  final Function(String) onEmojiSelected;
  final String? title;

  const EmojiSelector({
    super.key,
    required this.selectedEmoji,
    required this.onEmojiSelected,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title ?? context.l10n.groupSelectIcon,
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppDimensions.spacingS),
        Container(
          height: 60,
          padding: const EdgeInsets.all(AppDimensions.spacingS),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: GroupEmojiConstants.availableEmojis.length,
            itemBuilder: (context, index) {
              final emoji = GroupEmojiConstants.availableEmojis[index];
              final isSelected = emoji == selectedEmoji;

              return Semantics(
                label: context.l10n.a11yEmojiPicker(emoji),
                button: true,
                selected: isSelected,
                child: GestureDetector(
                  onTap: () => onEmojiSelected(emoji),
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(
                      right: AppDimensions.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadius8),
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: AppTextStyles.groupTitle,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Reusable error display widget
class ErrorDisplayWidget extends StatelessWidget {
  final String errorMessage;

  const ErrorDisplayWidget({
    super.key,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        border: Border.all(color: cs.error),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: cs.error,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              errorMessage,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable warning display widget
class WarningDisplayWidget extends StatelessWidget {
  final String warningMessage;

  const WarningDisplayWidget({
    super.key,
    required this.warningMessage,
  });

  @override
  Widget build(BuildContext context) {
    final warningColor = context.butleryColors.warning;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        border: Border.all(
          color:
              warningColor.withValues(alpha: AppDimensions.opacityMediumLight),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: warningColor,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              warningMessage,
              style: AppTextStyles.bodySmall.copyWith(
                color: warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable dialog header
class DialogHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onClose;

  const DialogHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadius12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Text(
            title,
            style: AppTextStyles.headlineSmall.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// Reusable dialog footer with actions
class DialogFooter extends StatelessWidget {
  final String primaryActionText;
  final String secondaryActionText;
  final VoidCallback? onPrimaryAction;
  final VoidCallback onSecondaryAction;
  final bool isLoading;
  final IconData primaryActionIcon;
  final Color? primaryActionColor;
  final Color? primaryActionForegroundColor;

  const DialogFooter({
    super.key,
    required this.primaryActionText,
    required this.secondaryActionText,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
    required this.isLoading,
    required this.primaryActionIcon,
    this.primaryActionColor,
    this.primaryActionForegroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppDimensions.borderRadius12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: isLoading ? null : onSecondaryAction,
            child: Text(secondaryActionText),
          ),
          const SizedBox(width: AppDimensions.spacingM),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: FilledButton.icon(
              onPressed: onPrimaryAction,
              style: primaryActionColor != null
                  ? FilledButton.styleFrom(
                      backgroundColor: primaryActionColor,
                      foregroundColor: primaryActionForegroundColor ??
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    )
                  : null,
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryActionForegroundColor ??
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Icon(primaryActionIcon),
              label: Text(primaryActionText),
            ),
          ),
        ],
      ),
    );
  }
}
