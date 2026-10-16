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
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/buttons/saffron_square_button.dart';

/// Refactored CollaborativeShoppingActions using BaseActionHandler
/// This class handles ONLY action-related responsibilities:
/// - Add item input section
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

  List<Widget> buildBarActions(BuildContext context) => [
    _buildShareAction(context),
    _buildMenuActions(context),
  ];

  Widget _buildShareAction(BuildContext context) {
    return AppIconButton(
      icon: ButleryIcons.share2,
      onPressed: onShare,
      semanticLabel: context.l10n.collaborativeShareList,
    );
  }

  Widget _buildMenuActions(BuildContext context) {
    return ButleryMenu<String>(
      semanticLabel: context.l10n.collaborativeMoreActions,
      onSelected: onMenuAction,
      choices: [
        if (viewModel.canEdit)
          ButleryMenuChoice(
            value: 'clear_completed',
            icon: ButleryIcons.listX,
            label: context.l10n.collaborativeClearCompleted,
          ),
      ],
    );
  }

  Widget buildAddItemSection(BuildContext context) {
    if (!viewModel.canEdit) {
      return _buildReadOnlySection(context);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.layoutMargin,
        AppDimensions.space4,
        AppDimensions.layoutMargin,
        AppDimensions.space12,
      ),
      child: Row(
        children: [
          Expanded(child: _buildItemInput(context)),
          const SizedBox(width: AppDimensions.space8),
          _buildAddButton(context),
        ],
      ),
    );
  }

  Widget _buildReadOnlySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: AppDimensions.borderWidthThin,
          ),
        ),
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.eye,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.space8),
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
    return StyledInput(
      controller: newItemController,
      hint: context.l10n.collaborativeAddItemHint,
      // Adding: the plate line in the field's end, named for the screen
      // reader (produktregler.md, B-18).
      suffixIcon: viewModel.isAddingItem
          ? Padding(
              padding: const EdgeInsets.all(AppDimensions.space4),
              child: SizedBox(
                width: AppDimensions.iconSizeL,
                child: PlateLine(semanticLabel: context.l10n.loadingGeneric),
              ),
            )
          : null,
      onSubmitted: (_) => onAddItem(),
      enabled: !viewModel.isAddingItem,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildAddButton(BuildContext context) {
    final adding = viewModel.isAddingItem;
    return SaffronSquareButton(
      semanticLabel: context.l10n.collaborativeAdd,
      busy: adding,
      busyLabel: context.l10n.collaborativeAdding,
      onPressed: onAddItem,
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
      confirmationMessage: context.l10n.collaborativeClearCompletedMessage(
        completedItems.length,
      ),
      confirmActionText: context.l10n.collaborativeClearAll,
      confirmationIcon: ButleryIcons.listX,
      isDangerous: true,
      successMessage: context.l10n.collaborativeCompletedItemsCleared(
        completedItems.length,
      ),
      errorMessage: context.l10n.collaborativeCouldNotClearCompleted,
      metadata: {
        'completed_count': completedItems.length,
        'action': 'clear_completed_items',
      },
    );
  }

  Future<void> handleShare(BuildContext context) async {
    if (!validateContext(context)) return;

    await showButlerySheet<void>(
      context: context,
      builder: (context) => _buildShareSheet(context),
    );
  }

  Widget _buildShareSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.collaborativeShareList,
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: AppDimensions.space12),
          ButleryItemRow(
            padded: false,
            leadingIcon: ButleryIcons.link,
            title: context.l10n.collaborativeCopyLink,
            subtitle: context.l10n.collaborativeCopyLinkDescription,
            onTap: () {
              Navigator.pop(context);
              _copyShareLink(context);
            },
          ),
          ButleryItemRow(
            padded: false,
            leadingIcon: ButleryIcons.messageSquare,
            title: context.l10n.collaborativeSendMessage,
            subtitle: context.l10n.collaborativeSendMessageDescription,
            onTap: () {
              Navigator.pop(context);
              _shareViaMessage(context);
            },
          ),
          ButleryItemRow(
            padded: false,
            leadingIcon: ButleryIcons.mail,
            title: context.l10n.collaborativeSendEmail,
            subtitle: context.l10n.collaborativeSendEmailDescription,
            onTap: () {
              Navigator.pop(context);
              _shareViaEmail(context);
            },
          ),
          const SizedBox(height: AppDimensions.space12),
          SizedBox(
            width: double.infinity,
            child: ButleryTextButton(
              onPressed: () => Navigator.pop(context),
              label: context.l10n.commonCancel,
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
      return ButleryIcons.hourglass;
    }
    return ButleryIcons.plus;
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
