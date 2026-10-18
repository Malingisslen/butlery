// lib/views/social/shared_with_me/shared_shopping_list_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_actions.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/social/shared_content_row.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';

/// A shared shopping list as a [SharedContentRow]. Opening it shows the list
/// in a sheet.
class SharedShoppingListCard {
  static Widget build(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedShoppingList sharedShoppingList,
  ) {
    final l10n = context.l10n;
    final lists = viewModel.shoppingViewModel;
    final isRead = lists.isShoppingListViewed(sharedShoppingList);

    return SharedContentRow(
      leading: const SharedKindThumb(icon: ButleryIcons.shoppingCart),
      title: sharedShoppingList.listName,
      subtitle: l10n.sharedFromNameAgo(
        sharedShoppingList.sharedByDisplayName,
        sharedShoppingList.timeAgoText,
      ),
      message: sharedShoppingList.shareMessage,
      unread: !isRead,
      onOpen: () {
        if (!isRead) lists.markAsViewed(sharedShoppingList);
        _showShoppingListPreview(context, sharedShoppingList);
      },
      onActions: () => showSharedContentActions(
        context,
        title: sharedShoppingList.listName,
        onDismiss: () => SharedContentActions.dismissShoppingList(
          context,
          viewModel,
          sharedShoppingList,
        ),
        onUnshare: () => SharedContentActions.unshareShoppingList(
          context,
          viewModel,
          sharedShoppingList,
        ),
      ),
    );
  }

  static Widget _buildShareMessage(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Text(
        '”$message”',
        style: AppTextStyles.bodySmall.copyWith(
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  static void _showShoppingListPreview(
    BuildContext context,
    SharedShoppingList sharedShoppingList,
  ) {
    showButlerySheet<void>(
      context: context,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (sheetContext, scrollController) => _buildPreviewContent(
          sheetContext,
          sharedShoppingList,
          scrollController,
        ),
      ),
    );
  }

  static Widget _buildPreviewContent(
    BuildContext context,
    SharedShoppingList sharedShoppingList,
    ScrollController scrollController,
  ) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sharedShoppingList.listName,
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: AppDimensions.space4),
              Text(
                sharedShoppingList.sharingContextText,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (sharedShoppingList.shareMessage?.isNotEmpty ?? false) ...[
                const SizedBox(height: AppDimensions.space4),
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
              horizontal: AppDimensions.space16,
            ),
            itemCount: 1,
            itemBuilder: (context, index) {
              return ButleryItemRow(
                padded: false,
                leadingIcon: ButleryIcons.shoppingCart,
                title: context.l10n.shoppingItemCountText(
                  sharedShoppingList.itemCount,
                ),
                subtitle: context.l10n.sharedTapToSeeAllItems,
                showChevron: true,
              );
            },
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Row(
            children: [
              Expanded(
                child: ActionButtons.secondaryButton(
                  context,
                  label: context.l10n.commonClose,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
