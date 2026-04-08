// lib/views/social/collaborative_shopping/collaborative_shopping_actions.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:butlery/core/base/base_action_handler.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Refactored CollaborativeShoppingActions using BaseActionHandler
/// This class handles ONLY action-related responsibilities:
/// - Add item input section
/// - App bar with menu actions
/// - Action handlers and business logic coordination
/// - User interaction management
/// ❌ DOES NOT CONTAIN: Items display, header display, state management
class CollaborativeShoppingActions extends BaseActionHandler
    with ActionStateMixin {
  final CollaborativeShoppingViewModel viewModel;
  final TextEditingController newItemController;
  final VoidCallback onAddItem;
  final Function(String action) onMenuAction;
  final VoidCallback onShare;

  @override
  String get serviceName => 'CollaborativeShoppingActions';

  CollaborativeShoppingActions({
    required this.viewModel,
    required this.newItemController,
    required this.onAddItem,
    required this.onMenuAction,
    required this.onShare,
  });

  PreferredSizeWidget buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(viewModel.listTitle),
      actions: [
        _buildShareAction(context),
        _buildMenuActions(context),
      ],
    );
  }

  Widget _buildShareAction(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share),
      onPressed: onShare,
      tooltip: context.l10n.collaborativeShareList,
    );
  }

  Widget _buildMenuActions(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: onMenuAction,
      tooltip: context.l10n.collaborativeMoreActions,
      itemBuilder: (context) => [
        if (viewModel.canEdit)
          _buildPopupMenuItem(
            value: 'clear_completed',
            icon: Icons.clear_all,
            label: context.l10n.collaborativeClearCompleted,
          ),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: AppDimensions.spacingM),
          Text(label),
        ],
      ),
    );
  }

  Widget buildAddItemSection(BuildContext context) {
    if (!viewModel.canEdit) {
      return _buildReadOnlySection(context);
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: AppDimensions.borderWidthThin,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _buildItemInput(context)),
          const SizedBox(width: AppDimensions.spacingM),
          _buildAddButton(context),
        ],
      ),
    );
  }

  Widget _buildReadOnlySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: AppDimensions.opacityHalf),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: AppDimensions.borderWidthThin,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Text(
            context.l10n.collaborativeViewOnly,
            style: AppTextStyles.titleMedium.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemInput(BuildContext context) {
    return TextField(
      controller: newItemController,
      decoration: InputDecoration(
        hintText: context.l10n.collaborativeAddItemHint,
        suffixIcon: viewModel.isAddingItem
            ? const Padding(
                padding: EdgeInsets.all(AppDimensions.spacingS),
                child: SizedBox(
                  width: AppDimensions.iconSizeS,
                  height: AppDimensions.iconSizeS,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      onSubmitted: (_) => onAddItem(),
      enabled: !viewModel.isAddingItem,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: viewModel.isAddingItem ? null : onAddItem,
      icon: Icon(viewModel.isAddingItem ? Icons.hourglass_empty : Icons.add),
      label: Text(viewModel.isAddingItem
          ? context.l10n.collaborativeAdding
          : context.l10n.collaborativeAdd),
    );
  }

  Future<void> handleMenuAction(BuildContext context, String action) async {
    if (!validateContext(context)) return;

    switch (action) {
      case 'clear_completed':
        await _clearCompletedItems(context);
        break;
      default:
        onMenuAction(action);
    }
  }

  /// Clear completed items using BaseActionHandler
  Future<void> _clearCompletedItems(BuildContext context) async {
    if (!validateContext(context)) return;

    final completedItems = viewModel.completedItemsList;

    if (completedItems.isEmpty) {
      showInfoMessage(context, context.l10n.collaborativeNoCompletedItems);
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        return await viewModel.clearCompletedItems();
      },
      confirmationTitle: context.l10n.collaborativeClearCompletedConfirm,
      confirmationMessage: context.l10n
          .collaborativeClearCompletedMessage(completedItems.length),
      confirmActionText: context.l10n.collaborativeClearAll,
      confirmationIcon: Icons.clear_all,
      isDangerous: true,
      successMessage: context.l10n
          .collaborativeCompletedItemsCleared(completedItems.length),
      errorMessage: context.l10n.collaborativeCouldNotClearCompleted,
      metadata: {
        'completed_count': completedItems.length,
        'action': 'clear_completed_items',
      },
    );
  }

  Future<void> handleShare(BuildContext context) async {
    if (!validateContext(context)) return;

    await showModalBottomSheet(
      context: context,
      builder: (context) => _buildShareSheet(context),
    );
  }

  Widget _buildShareSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.collaborativeShareList,
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(context.l10n.collaborativeCopyLink),
            subtitle: Text(context.l10n.collaborativeCopyLinkDescription),
            onTap: () {
              Navigator.pop(context);
              _copyShareLink(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: Text(context.l10n.collaborativeSendMessage),
            subtitle: Text(context.l10n.collaborativeSendMessageDescription),
            onTap: () {
              Navigator.pop(context);
              _shareViaMessage(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: Text(context.l10n.collaborativeSendEmail),
            subtitle: Text(context.l10n.collaborativeSendEmailDescription),
            onTap: () {
              Navigator.pop(context);
              _shareViaEmail(context);
            },
          ),
          const SizedBox(height: AppDimensions.spacingL),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
          ),
        ],
      ),
    );
  }

  String get _shareUrl =>
      'https://butlery.app/shopping?id=${Uri.encodeComponent(viewModel.listId)}';

  Future<void> _copyShareLink(BuildContext context) async {
    await executeAction(
      context: context,
      action: () async {
        await Clipboard.setData(ClipboardData(text: _shareUrl));
        return true;
      },
      successMessage: context.l10n.collaborativeLinkCopied,
      metadata: {
        'list_id': viewModel.listId,
        'action': 'copy_share_link',
      },
    );
  }

  Future<void> _shareViaMessage(BuildContext context) async {
    await executeAction(
      context: context,
      action: () async {
        await SharePlus.instance.share(ShareParams(text: _shareUrl));
        return true;
      },
      errorMessage: context.l10n.errorGeneric,
      metadata: {'list_id': viewModel.listId, 'action': 'share_via_message'},
    );
  }

  Future<void> _shareViaEmail(BuildContext context) async {
    await executeAction(
      context: context,
      action: () async {
        final uri = Uri(
          scheme: 'mailto',
          queryParameters: {
            'subject': viewModel.listTitle,
            'body': _shareUrl,
          },
        );
        return await launchUrl(uri);
      },
      errorMessage: context.l10n.errorGeneric,
      metadata: {'list_id': viewModel.listId, 'action': 'share_via_email'},
    );
  }

  bool shouldShowAddItemSection() {
    return viewModel.canView; // Show for viewers (read-only) and editors
  }

  /// Check if item input should be enabled
  bool isItemInputEnabled() {
    return viewModel.canEdit && !viewModel.isAddingItem;
  }

  /// Get add button text based on current state
  String getAddButtonText(BuildContext context) {
    if (viewModel.isAddingItem) {
      return context.l10n.commonAdding;
    }
    return context.l10n.commonAdd;
  }

  /// Get add button icon based on current state
  IconData getAddButtonIcon() {
    if (viewModel.isAddingItem) {
      return Icons.hourglass_empty;
    }
    return Icons.add;
  }

  /// Check if menu action is available
  bool isMenuActionAvailable(String action) {
    switch (action) {
      case 'clear_completed':
        return viewModel.canEdit && viewModel.completedItemsList.isNotEmpty;
      default:
        return false;
    }
  }
}
