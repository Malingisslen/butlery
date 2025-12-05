// lib/views/social/shared_with_me/shared_menu_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/views/social/menu_preview_view.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_actions.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
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
      elevation: isRead ? AppDimensions.elevationLow : AppDimensions.elevationMedium,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
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
              _buildHeader(context, viewModel, sharedMenu, isRead),
              const SizedBox(height: AppDimensions.spacingS),

              // Meny content
              _buildMenuContent(context, sharedMenu),

              // Message från delaren
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
    );
  }

  static Widget _buildHeader(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedMenu sharedMenu,
    bool isRead,
  ) {
    return Row(
      children: [
        SocialComponents.avatar(
          size: ImageSize.small,
          displayName: sharedMenu.sharedByDisplayName,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delat av ${sharedMenu.sharedByDisplayName}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      fontWeight: isRead
                          ? FontWeight.normal
                          : FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              Text(
                timeago.format(sharedMenu.sharedAt, locale: 'sv'),
                style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        // Dismiss knapp
        Material(
          color: Theme.of(context)
              .colorScheme
              .errorContainer
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            onTap: () => SharedContentActions.dismissMenu(
              context,
              viewModel,
              sharedMenu,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.spacingXs),
              constraints: const BoxConstraints(
                minWidth: AppDimensions.iconSizeAction + AppDimensions.spacingS,
                minHeight: AppDimensions.iconSizeAction + AppDimensions.spacingS,
              ),
              child: Icon(
                Icons.close,
                size: AppDimensions.iconSizeM,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (!isRead)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(left: AppDimensions.spacingXs),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  static Widget _buildMenuContent(BuildContext context, SharedMenu sharedMenu) {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Icon(
            Icons.calendar_month,
            size: AppDimensions.iconSizeXl,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sharedMenu.menuTitle,
                style: AppTextStyles.titleMedium,
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
                    '${sharedMenu.totalRecipeCount} recept',
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
                    '${sharedMenu.categories.length} kategorier',
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
            label: 'Visa',
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
              label: isImported ? 'Importerat' : 'Importera',
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