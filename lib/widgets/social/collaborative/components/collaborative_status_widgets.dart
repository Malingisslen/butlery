// lib/widgets/social/collaborative/components/collaborative_status_widgets.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_participants_widgets.dart';

/// Status badges and banners for collaborative content
class CollaborativeStatusWidgets {
  /// Compact badge to show that content is shared/collaborative
  static Widget statusBadge({
    String? text,
    IconData icon = ButleryIcons.users,
    Color? color,
    EdgeInsets? padding,
    bool onInk = false,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final effectiveColor = color ?? (onInk ? cs.onPrimary : cs.onSurface);

        return Container(
          padding:
              padding ??
              const EdgeInsets.symmetric(
                horizontal: AppDimensions.space4,
                vertical: AppDimensions.space4,
              ),
          decoration: BoxDecoration(
            color: onInk
                ? AppModeColors.surfaceRaisedOnInk()
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            border: Border.all(
              color: onInk ? AppModeColors.borderOnInk() : cs.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ButleryIcon(
                icon,
                size: AppDimensions.iconSizeM,
                color: effectiveColor,
              ),
              const SizedBox(width: AppDimensions.space4),
              Text(
                text ?? context.l10n.collaborativeShared,
                style: AppTextStyles.labelLarge.copyWith(
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Larger banner for collaborative context - WITH REAL PARTICIPANTS
  static Widget banner({
    required String title,
    required String subtitle,
    String? contentId,
    String contentType = 'recipe',
    Color? backgroundColor,
    VoidCallback? onTap,
    Widget? trailing,
    BuildContext? context, // Needed to fetch real participants
  }) {
    return Builder(
      builder: (builderContext) {
        final cs = Theme.of(builderContext).colorScheme;
        final bgColor = backgroundColor ?? cs.surfaceContainerHighest;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.space12),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(color: cs.outlineVariant),
            ),
          ),
          child: Semantics(
            button: onTap != null,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
              child: Row(
                children: [
                  ButleryIcon(
                    ButleryIcons.users,
                    color: cs.onSurface,
                    size: AppDimensions.iconSizeM,
                  ),
                  const SizedBox(width: AppDimensions.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.bodyLargeBold.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // USE REAL PARTICIPANTS if context and contentId exist
                  if (context != null && contentId != null)
                    CollaborativeParticipantsWidgets.participantsList(
                      context: context,
                      contentId: contentId,
                      contentType: contentType,
                      maxVisible: 3,
                      avatarSize: 24,
                    )
                  // FALLBACK to trailing widget
                  else if (trailing != null)
                    trailing
                  // LAST FALLBACK - show just an icon
                  else
                    ButleryIcon(
                      ButleryIcons.users,
                      size: AppDimensions.iconSizeL,
                      color: cs.onSurface,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Smart collaborative banner with ViewModel integration
  static Widget smartBanner({
    required BuildContext context,
    required String contentId,
    String contentType = 'recipe',
    Recipe? recipe,
    Map<String, List<Recipe>>? menuData,
    String? title,
    String? subtitle,
  }) {
    return Consumer<CollaborativeStatusViewModel>(
      builder: (context, viewModel, child) {
        // Get status object and use .isCollaborative
        final status = contentType == 'recipe'
            ? viewModel.getRecipeCollaborativeStatus(contentId, recipe)
            : viewModel.getMenuCollaborativeStatus(
                contentId,
                menuData?.map(
                  (key, recipes) => MapEntry(
                    key,
                    recipes,
                  ),
                ),
              );

        final isCollaborative = status.isCollaborative;

        if (!isCollaborative) return const SizedBox.shrink();

        return banner(
          title: title ?? context.l10n.collaborativeEditingTogether,
          subtitle: subtitle ?? context.l10n.collaborativeSyncAutomatic,
          contentId: contentId,
          contentType: contentType,
          context: context,
        );
      },
    );
  }

  /// Force refresh for specific content via ViewModel
  static void refreshStatus(
    BuildContext context,
    String contentId, {
    String contentType = 'recipe',
  }) {
    try {
      final viewModel = context.read<CollaborativeStatusViewModel>();
      if (contentType == 'recipe') {
        viewModel.invalidateRecipeStatus(contentId);
      } else {
        viewModel.invalidateMenuStatus(contentId);
      }
    } catch (_) {
      // Silently ignore - status refresh is non-critical
    }
  }
}
