// lib/widgets/social/groups/shared/group_dialog_components.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
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
        // Fixed-size emoji grid (44x44 cells) — clamp text-scaling so the
        // glyph fits inside its cell at 200% system text scale (BUT-547 /
        // WCAG 1.4.4). Without this clamp the emoji clips at large scales.
        // The horizontal scroll keeps the picker accessible regardless.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Container(
            height: 60,
            padding: const EdgeInsets.all(AppDimensions.space4),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
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
                      margin: const EdgeInsetsDirectional.only(
                        end: AppDimensions.space4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusControl,
                        ),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
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
        color: context.modeColors.surfaceTintDanger,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.triangleAlert,
            color: cs.onErrorContainer,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.space4),
          Expanded(
            child: Text(
              errorMessage,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onErrorContainer,
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
    final warningColor = AppModeColors.textWarning(
      Theme.of(context).brightness,
    );
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingM),
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
      padding: const EdgeInsets.all(AppDimensions.spacingL),
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
          IconButton(
            onPressed: onClose,
            icon: const ButleryIcon(ButleryIcons.x),
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
        // The footer fills the dialog's bottom edge: dialog radius 8
        // (Komponentark v1:336).
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppDimensions.radiusControl),
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
            // Working keeps the name and draws the plate line along the
            // bottom edge, never a spinner (Komponentark v1:365, :372).
            child: BusyButtonSemantics(
              busy: isLoading,
              name: primaryActionText,
              child: Builder(
                builder: (context) {
                  final ButtonStyle? own = primaryActionColor != null
                      ? FilledButton.styleFrom(
                          backgroundColor: primaryActionColor,
                          foregroundColor:
                              primaryActionForegroundColor ??
                              Theme.of(context).colorScheme.onPrimary,
                        )
                      : null;
                  return FilledButton.icon(
                    onPressed: isLoading
                        ? PlateLineButton.ignore
                        : onPrimaryAction,
                    style: isLoading
                        ? PlateLineButton.busyStyle(
                            own,
                            Theme.of(context).filledButtonTheme.style,
                          )
                        : own,
                    icon: ButleryIcon(primaryActionIcon),
                    label: Text(primaryActionText),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
