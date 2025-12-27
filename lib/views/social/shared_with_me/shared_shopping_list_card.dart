/// Shared shopping list card component providing consistent UI patterns matching recipe/menu sharing design.
/// This component implements unified shared shopping list display following Single Responsibility Principle,
/// matching the patterns established by SharedRecipeCard and SharedMenuCard for consistent user experience.
/// It provides complete shopping list preview capabilities while maintaining clean separation from
/// business logic and ensuring consistent behavior across all shared content types.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_actions.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

/// SharedShoppingListCard - Card for displaying shared shopping lists
/// Displays shared shopping list information with view/join/dismiss actions
/// following consistent patterns established by recipe and menu cards.
class SharedShoppingListCard {
  static Widget build(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedShoppingList sharedShoppingList,
  ) {
    final isRead =
        viewModel.shoppingViewModel.isShoppingListViewed(sharedShoppingList);
    final isJoined =
        viewModel.shoppingViewModel.isShoppingListJoined(sharedShoppingList);

    return Material(
      elevation:
          isRead ? AppDimensions.elevationLow : AppDimensions.elevationMedium,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        onTap: () {
          if (!isRead) {
            viewModel.shoppingViewModel.markAsViewed(sharedShoppingList);
          }
          _showShoppingListPreview(context, viewModel, sharedShoppingList);
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
              // Header with sharing info
              _buildHeader(context, viewModel, sharedShoppingList, isRead),
              const SizedBox(height: AppDimensions.spacingS),

              // Shopping list content
              _buildShoppingListContent(context, sharedShoppingList),

              // Message from sharer
              if (sharedShoppingList.shareMessage?.isNotEmpty ?? false) ...[
                const SizedBox(height: AppDimensions.spacingS),
                _buildShareMessage(context, sharedShoppingList.shareMessage!),
              ],

              const SizedBox(height: AppDimensions.spacingS),

              // Action buttons
              _buildActionButtons(
                context,
                viewModel,
                sharedShoppingList,
                isRead,
                isJoined,
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
    SharedShoppingList sharedShoppingList,
    bool isRead,
  ) {
    return Row(
      children: [
        SocialAvatarComponents.avatar(
          size: ImageSize.small,
          displayName: sharedShoppingList.sharedByDisplayName,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delat av ${sharedShoppingList.sharedByDisplayName}',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                sharedShoppingList.timeAgoText,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Dismiss button
        Material(
          color: Theme.of(context)
              .colorScheme
              .errorContainer
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            onTap: () => SharedContentActions.dismissShoppingList(
              context,
              viewModel,
              sharedShoppingList,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.spacingXs),
              constraints: const BoxConstraints(
                minWidth: AppDimensions.iconSizeAction + AppDimensions.spacingS,
                minHeight:
                    AppDimensions.iconSizeAction + AppDimensions.spacingS,
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
            margin: const EdgeInsetsDirectional.only(
                start: AppDimensions.spacingXs),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  static Widget _buildShoppingListContent(
    BuildContext context,
    SharedShoppingList sharedShoppingList,
  ) {
    return Row(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Icon(
            Icons.shopping_cart,
            size: AppDimensions.iconSizeXxl,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sharedShoppingList.listName,
                style: AppTextStyles.titleMedium,
              ),
              if (sharedShoppingList.listDescription?.isNotEmpty == true) ...[
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  sharedShoppingList.listDescription!,
                  style: AppTextStyles.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppDimensions.spacingXs),
              // Item summary preview
              Text(
                sharedShoppingList.itemCountText,
                style: AppTextStyles.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Row(
                children: [
                  Icon(
                    Icons.shopping_basket,
                    size: AppDimensions.iconSizeS,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    sharedShoppingList.itemCountText,
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Icon(
                    Icons.person,
                    size: AppDimensions.iconSizeS,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    sharedShoppingList.originalOwnerDisplayName,
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
    SharedShoppingList sharedShoppingList,
    bool isRead,
    bool isJoined,
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
                viewModel.shoppingViewModel.markAsViewed(sharedShoppingList);
              }
              _showShoppingListPreview(context, viewModel, sharedShoppingList);
            },
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: ActionButtons.primaryButton(
            context,
            label: isJoined ? 'Medlem' : 'Gå med',
            icon: isJoined ? Icons.check : Icons.add_shopping_cart,
            isLoading: viewModel.shoppingViewModel.isOperating,
            onPressed: isJoined || viewModel.shoppingViewModel.isOperating
                ? null
                : () => SharedContentActions.joinShoppingList(
                      context,
                      viewModel,
                      sharedShoppingList,
                    ),
          ),
        ),
      ],
    );
  }

  // Helper method to show shopping list preview
  static void _showShoppingListPreview(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedShoppingList sharedShoppingList,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => _buildPreviewContent(
          context,
          viewModel,
          sharedShoppingList,
          scrollController,
        ),
      ),
    );
  }

  static Widget _buildPreviewContent(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedShoppingList sharedShoppingList,
    ScrollController scrollController,
  ) {
    final isJoined =
        viewModel.shoppingViewModel.isShoppingListJoined(sharedShoppingList);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 32,
            height: 4,
            margin:
                const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sharedShoppingList.listName,
                  style: AppTextStyles.headlineSmall,
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  sharedShoppingList.sharingContextText,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (sharedShoppingList.shareMessage?.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppDimensions.spacingS),
                  _buildShareMessage(context, sharedShoppingList.shareMessage!),
                ],
              ],
            ),
          ),

          // Items list
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingL),
              // Issue #015: Items in subcollection - show placeholder
              itemCount: 1,
              itemBuilder: (context, index) {
                // Note: Items need to be loaded from repository.getItems() for display
                return ListTile(
                  leading: const Icon(Icons.shopping_basket_outlined,
                      size: AppDimensions.iconSizeM),
                  title: Text('${sharedShoppingList.itemCount} artiklar'),
                  subtitle: const Text('Tryck för att se alla artiklar'),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: AppDimensions.iconSizeS),
                );
              },
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Row(
              children: [
                Expanded(
                  child: ActionButtons.secondaryButton(
                    context,
                    label: 'Stäng',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: ActionButtons.primaryButton(
                    context,
                    label: isJoined ? 'Redan medlem' : 'Gå med i lista',
                    icon: isJoined ? Icons.check : Icons.add_shopping_cart,
                    isLoading: viewModel.shoppingViewModel.isOperating,
                    onPressed:
                        isJoined || viewModel.shoppingViewModel.isOperating
                            ? null
                            : () {
                                SharedContentActions.joinShoppingList(
                                  context,
                                  viewModel,
                                  sharedShoppingList,
                                );
                                Navigator.pop(context);
                              },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
