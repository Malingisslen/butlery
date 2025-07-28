// lib/widgets/social/collaborative/components/collaborative_status_widgets.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_participants_widgets.dart';

/// Status badges, banners, and app bars for collaborative content
class CollaborativeStatusWidgets {
  /// Compact badge to show that content is shared/collaborative
  static Widget statusBadge({
    String text = 'Delat',
    IconData icon = Icons.people,
    Color? color,
    EdgeInsets? padding,
  }) {
    final effectiveColor = color ?? AppColors.primaryBlue;

    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingS,
            vertical: AppDimensions.spacingXs,
          ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.chipRadius),
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeM,
            color: effectiveColor,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: effectiveColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
    final bgColor =
        backgroundColor ?? AppColors.primaryBlue.withValues(alpha: 0.1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.smallRadius),
        child: Row(
          children: [
            const Icon(
              Icons.people,
              color: AppColors.primaryBlue,
              size: AppDimensions.iconSizeAction,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryBlue,
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
              const Icon(
                Icons.people_outline,
                size: 24,
                color: AppColors.primaryBlue,
              ),
          ],
        ),
      ),
    );
  }

  /// AppBar with collaborative background color and smart status detection
  static PreferredSizeWidget appBar({
    required BuildContext context,
    required String contentId,
    String contentType = 'recipe',
    Recipe? recipe,
    Map<String, List<Recipe>>? menuData,
    String? title,
    List<Widget>? actions,
  }) {
    return _CollaborativeAppBar(
      contentId: contentId,
      contentType: contentType,
      recipe: recipe,
      menuData: menuData,
      title: title,
      actions: actions,
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
            ? viewModel.getRecipeCollaborativeStatus(
                contentId, 
                recipe
              )
            : viewModel.getMenuCollaborativeStatus(
                contentId, 
                menuData?.map((key, recipes) => MapEntry(
                  key,
                  recipes,
                ))
              );

        final isCollaborative = status.isCollaborative;

        if (!isCollaborative) return const SizedBox.shrink();

        return banner(
          title: title ?? 'Du redigerar tillsammans med andra',
          subtitle:
              subtitle ?? 'Ändringar synkas automatiskt med andra deltagare',
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
    } catch (e) {
      debugPrint('Could not refresh collaborative status: $e');
    }
  }
}

/// Private AppBar widget that properly implements PreferredSizeWidget
class _CollaborativeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String contentId;
  final String contentType;
  final Recipe? recipe;
  final Map<String, List<Recipe>>? menuData;
  final String? title;
  final List<Widget>? actions;

  const _CollaborativeAppBar({
    required this.contentId,
    this.contentType = 'recipe',
    this.recipe,
    this.menuData,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CollaborativeStatusViewModel>(
      builder: (context, viewModel, child) {
        // Get collaborative status
        final status = contentType == 'recipe'
            ? viewModel.getRecipeCollaborativeStatus(contentId, recipe)
            : viewModel.getMenuCollaborativeStatus(
                contentId,
                menuData?.map((key, recipes) => MapEntry(key, recipes)),
              );

        final isCollaborative = status.isCollaborative;
        final participants = status.participants;

        return AppBar(
          title: Text(title ?? 'Innehåll'),
          backgroundColor: isCollaborative
              ? AppColors.primaryBlue.withValues(alpha: 0.1)
              : null,
          elevation: isCollaborative ? 2 : null,
          actions: [
            // Show collaborative badge if content is collaborative
            if (isCollaborative) ...[
              Padding(
                padding: const EdgeInsets.only(right: AppDimensions.spacingS),
                child: Center(
                  child: Tooltip(
                    message: participants.isNotEmpty
                        ? 'Delat med ${participants.length} ${participants.length == 1 ? 'person' : 'personer'}'
                        : 'Delat innehåll',
                    child: CollaborativeStatusWidgets.statusBadge(
                      text: participants.isNotEmpty 
                          ? '${participants.length}'
                          : 'Delat',
                      icon: Icons.people,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
            ],
            
            // Include other actions
            if (actions != null) ...actions!,
          ],
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}