// lib/widgets/social/groups/shared/group_dialog_components.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_close_button.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';

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
    '⭐',
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
        const SizedBox(height: AppDimensions.space4),
        // Fixed-size emoji grid (48x48 cells) — clamp text-scaling so the
        // glyph fits inside its cell at 200% system text scale (BUT-547 /
        // WCAG 1.4.4). Without this clamp the emoji clips at large scales.
        // The horizontal scroll keeps the picker accessible regardless.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: ButleryOutlinedBox(
            height: 60,
            padding: const EdgeInsets.all(AppDimensions.space4),
            borderColor: Theme.of(context).colorScheme.outline,
            radius: AppDimensions.radiusControl,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: GroupEmojiConstants.availableEmojis.length,
              itemBuilder: (context, index) {
                final emoji = GroupEmojiConstants.availableEmojis[index];
                final isSelected = emoji == selectedEmoji;

                return Semantics(
                  label: context.l10n.a11yEmojiPicker,
                  button: true,
                  selected: isSelected,
                  child: GestureDetector(
                    onTap: () => onEmojiSelected(emoji),
                    child: ButleryOutlinedBox(
                      width: AppDimensions.minTouchTarget,
                      height: AppDimensions.minTouchTarget,
                      margin: const EdgeInsetsDirectional.only(
                        end: AppDimensions.space4,
                      ),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      radius: AppDimensions.radiusControl,
                      borderColor: isSelected
                          ? Theme.of(context).colorScheme.onSurface
                          : null,
                      borderWidth: 2,
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
  Widget build(BuildContext context) => InlineError(what: errorMessage);
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
    final warningColor = AppModeColors.textWarning(
      Theme.of(context).brightness,
    );
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space8),
      decoration: BoxDecoration(
        color: context.modeColors.surfaceTintWarning,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.info,
            color: warningColor,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.space4),
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
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        // The header fills the dialog's top edge, so its corners follow the
        // dialog's own radius, 8 (Komponentark v1:336), not the card's 12.
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusControl),
        ),
      ),
      child: Row(
        children: [
          ButleryIcon(
            icon,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(width: AppDimensions.space4),
          Text(
            title,
            style: AppTextStyles.headlineSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          ButleryCloseButton(
            semanticLabel: context.l10n.commonClose,
            onPressed: onClose,
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

  const DialogFooter({
    super.key,
    required this.primaryActionText,
    required this.secondaryActionText,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
    required this.isLoading,
    required this.primaryActionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        // The footer fills the dialog's bottom edge: dialog radius 8
        // (Komponentark v1:336).
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppDimensions.radiusControl),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ButleryTextButton(
            label: secondaryActionText,
            onPressed: isLoading ? null : onSecondaryAction,
          ),
          const SizedBox(width: AppDimensions.space8),
          ActionButtons.primaryButton(
            context,
            label: primaryActionText,
            icon: primaryActionIcon,
            isLoading: isLoading,
            onPressed: onPrimaryAction,
          ),
        ],
      ),
    );
  }
}
