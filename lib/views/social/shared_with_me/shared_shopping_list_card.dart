// lib/views/social/shared_with_me/shared_shopping_list_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_actions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/social/shared_content_row.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

/// A shared shopping list as a [SharedContentRow]. Opening it shows the list
/// in a sheet whose last step is joining; the row's own control joins at once.
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
      saved: lists.isShoppingListJoined(sharedShoppingList),
      saving: lists.isOperating,
      saveLabel: l10n.sharedJoin,
      savedLabel: l10n.sharedMember,
      onSave: () => SharedContentActions.joinShoppingList(
        context,
        viewModel,
        sharedShoppingList,
      ),
      onOpen: () {
        if (!isRead) lists.markAsViewed(sharedShoppingList);
        _showShoppingListPreview(context, viewModel, sharedShoppingList);
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
    SharedContentCoordinatorViewModel viewModel,
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
          context,
          viewModel,
          sharedShoppingList,
          scrollController,
        ),
      ),
    );
  }

  /// [pageContext] outlives the sheet: joining shows its result and navigates
  /// after the sheet has closed, which the sheet's own context cannot.
  static Widget _buildPreviewContent(
    BuildContext context,
    BuildContext pageContext,
    SharedContentCoordinatorViewModel viewModel,
    SharedShoppingList sharedShoppingList,
    ScrollController scrollController,
  ) {
    final isJoined = viewModel.shoppingViewModel.isShoppingListJoined(
      sharedShoppingList,
    );

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
              return ListTile(
                leading: const ButleryIcon(
                  ButleryIcons.shoppingCart,
                  size: AppDimensions.iconSizeM,
                ),
                title: Text(
                  context.l10n.shoppingItemCountText(
                    sharedShoppingList.itemCount,
                  ),
                ),
                subtitle: Text(context.l10n.sharedTapToSeeAllItems),
                trailing: const ButleryChevron(),
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
              const SizedBox(width: AppDimensions.space8),
              Expanded(
                child: ActionButtons.primaryButton(
                  context,
                  label: isJoined
                      ? context.l10n.sharedAlreadyMember
                      : context.l10n.sharedJoinList,
                  icon: isJoined
                      ? ButleryIcons.check
                      : ButleryIcons.shoppingCart,
                  isLoading: viewModel.shoppingViewModel.isOperating,
                  onPressed: isJoined || viewModel.shoppingViewModel.isOperating
                      ? null
                      : () {
                          Navigator.pop(context);
                          SharedContentActions.joinShoppingList(
                            pageContext,
                            viewModel,
                            sharedShoppingList,
                          );
                        },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
