// lib/views/social/shared_with_me/shared_menu_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/views/social/menu_preview_view.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_actions.dart';
import 'package:butlery/widgets/social/shared_card_header.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// SharedMenuCard - Card for displaying shared menus
/// Displays shared menu information with action buttons.
class SharedMenuCard {
  static Widget build(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedMenu sharedMenu,
  ) {
    final isRead = viewModel.menuViewModel.isMenuViewed(sharedMenu);
    final isImported = viewModel.menuViewModel.isMenuImported(sharedMenu);

    return Material(
      elevation:
          isRead ? AppDimensions.elevationLow : AppDimensions.elevationMedium,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      child: Semantics(
        label: context.l10n.a11ySharedMenu(sharedMenu.menuTitle),
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          onTap: () {
            if (!isRead) {
              viewModel.menuViewModel.markAsViewed(sharedMenu);
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChangeNotifierProvider.value(
                  value: viewModel,
                  child: MenuPreviewView(sharedMenu: sharedMenu),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: !isRead
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header med delningsinfo
                SharedCardHeader(
                  displayName: sharedMenu.sharedByDisplayName,
                  timestampText:
                      timeago.format(sharedMenu.sharedAt, locale: 'sv'),
                  isRead: isRead,
                  onDismiss: () => SharedContentActions.dismissMenu(
                    context,
                    viewModel,
                    sharedMenu,
                  ),
                  onUnshare: () => SharedContentActions.unshareMenu(
                    context,
                    sharedMenu,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingS),

                // Meny content
                _buildMenuContent(context, sharedMenu),

                // Message from the sharer
                if (sharedMenu.shareMessage?.isNotEmpty == true) ...[
                  const SizedBox(height: AppDimensions.spacingS),
                  _buildShareMessage(context, sharedMenu.shareMessage!),
                ],

                const SizedBox(height: AppDimensions.spacingS),

                // Action buttons
                _buildActionButtons(
                  context,
                  viewModel,
                  sharedMenu,
                  isRead,
                  isImported,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildMenuContent(BuildContext context, SharedMenu sharedMenu) {
    final isCollaborative =
        sharedMenu.realtimeMenuId != null && sharedMenu.allowCollaboration;

    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isCollaborative
                ? Theme.of(context).colorScheme.tertiaryContainer
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Icon(
            isCollaborative ? Icons.group : Icons.calendar_month,
            size: AppDimensions.iconSizeXl,
            color: isCollaborative
                ? Theme.of(context).colorScheme.onTertiaryContainer
                : Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sharedMenu.menuTitle,
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingXs,
                      vertical: AppDimensions.spacingXxs,
                    ),
                    decoration: BoxDecoration(
                      color: isCollaborative
                          ? Theme.of(context).colorScheme.tertiaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusXs),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCollaborative ? Icons.sync : Icons.content_copy,
                          size: AppDimensions.iconSizeXs,
                          color: isCollaborative
                              ? Theme.of(context)
                                  .colorScheme
                                  .onTertiaryContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppDimensions.spacingXxs),
                        Text(
                          isCollaborative
                              ? context.l10n.sharedLive
                              : context.l10n.sharedCopy,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isCollaborative
                                ? Theme.of(context)
                                    .colorScheme
                                    .onTertiaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                sharedMenu.menuSummary,
                style: AppTextStyles.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Row(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: AppDimensions.iconSizeS,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    context.l10n.menuRecipeCount(sharedMenu.totalRecipeCount),
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Icon(
                    Icons.category,
                    size: AppDimensions.iconSizeS,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    context.l10n
                        .sharedCategoryCount(sharedMenu.categories.length),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildShareMessage(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Text(
        '"$message"',
        style: AppTextStyles.bodySmall.copyWith(
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  static Widget _buildActionButtons(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedMenu sharedMenu,
    bool isRead,
    bool isImported,
  ) {
    return Row(
      children: [
        Expanded(
          child: ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonView,
            icon: Icons.visibility,
            onPressed: () {
              if (!isRead) {
                viewModel.menuViewModel.markAsViewed(sharedMenu);
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider.value(
                    value: viewModel,
                    child: MenuPreviewView(sharedMenu: sharedMenu),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Builder(builder: (context) {
            // Use per-item loading state to avoid spinner on all items
            final isThisMenuOperating =
                viewModel.menuViewModel.isItemOperating(sharedMenu.id);
            return ActionButtons.primaryButton(
              context,
              label: isImported
                  ? context.l10n.sharedImported
                  : context.l10n.sharedImport,
              icon: isImported ? Icons.check : Icons.download,
              isLoading: isThisMenuOperating,
              onPressed: isImported || isThisMenuOperating
                  ? null
                  : () => SharedContentActions.importMenu(
                        context,
                        viewModel,
                        sharedMenu,
                      ),
            );
          }),
        ),
      ],
    );
  }
}
