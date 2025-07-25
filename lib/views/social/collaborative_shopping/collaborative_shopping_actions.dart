// lib/views/social/collaborative_shopping/collaborative_shopping_actions.dart

import 'package:flutter/material.dart';
import '../../../core/base/base_action_handler.dart';
import '../../../viewmodels/collaborative_shopping_viewmodel.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_dimensions.dart';

/// Refactored CollaborativeShoppingActions using BaseActionHandler
/// 
/// This class handles ONLY action-related responsibilities:
/// - Add item input section
/// - App bar with menu actions
/// - Action handlers and business logic coordination
/// - User interaction management
/// 
/// ❌ DOES NOT CONTAIN: Items display, header display, state management
class CollaborativeShoppingActions extends BaseActionHandler with ActionStateMixin {
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

  // ===== APP BAR ACTIONS =====

  /// Build app bar for collaborative shopping view
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
      tooltip: 'Dela lista',
    );
  }

  Widget _buildMenuActions(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: onMenuAction,
      tooltip: 'Fler åtgärder',
      itemBuilder: (context) => [
        _buildPopupMenuItem(
          value: 'settings',
          icon: Icons.settings,
          label: 'Inställningar',
        ),
        _buildPopupMenuItem(
          value: 'members',
          icon: Icons.group,
          label: 'Hantera medlemmar',
        ),
        if (viewModel.canEdit) ...[
          const PopupMenuDivider(),
          _buildPopupMenuItem(
            value: 'clear_completed',
            icon: Icons.clear_all,
            label: 'Rensa klara artiklar',
          ),
        ],
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

  // ===== ADD ITEM SECTION =====

  /// Build add item section widget
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
            .withValues(alpha: 0.5),
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
            color: AppColors.textMedium,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Text(
            'Du kan bara visa denna lista',
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
        hintText: 'Lägg till artikel...',
        suffixIcon: viewModel.isAddingItem
            ? Padding(
                padding: EdgeInsets.all(AppDimensions.spacingS),
                child: SizedBox(
                  width: AppDimensions.iconSizeS,
                  height: AppDimensions.iconSizeS,
                  child: const CircularProgressIndicator(strokeWidth: 2),
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
      label: Text(viewModel.isAddingItem ? 'Lägger till...' : 'Lägg till'),
    );
  }

  // ===== ACTION HANDLERS =====

  /// Handle menu action selection using BaseActionHandler
  Future<void> handleMenuAction(BuildContext context, String action) async {
    if (!validateContext(context)) return;

    switch (action) {
      case 'settings':
        await _showSettings(context);
        break;
      case 'members':
        await _showMembers(context);
        break;
      case 'clear_completed':
        await _clearCompletedItems(context);
        break;
      default:
        onMenuAction(action);
    }
  }

  Future<void> _showSettings(BuildContext context) async {
    showInfoMessage(context, 'Inställningar kommer snart');
  }

  Future<void> _showMembers(BuildContext context) async {
    showInfoMessage(context, 'Medlemshantering kommer snart');
  }

  /// Clear completed items using BaseActionHandler
  Future<void> _clearCompletedItems(BuildContext context) async {
    if (!validateContext(context)) return;

    final completedItems = viewModel.completedItemsList;
    
    if (completedItems.isEmpty) {
      showInfoMessage(context, 'Inga klarmarkerade artiklar att rensa');
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // In real implementation, this would call viewModel.clearCompletedItems()
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      },
      confirmationTitle: 'Rensa klara artiklar?',
      confirmationMessage: 'Vill du ta bort alla ${completedItems.length} klarmarkerade artiklar?',
      confirmActionText: 'Rensa alla',
      confirmationIcon: Icons.clear_all,
      isDangerous: true,
      successMessage: '${completedItems.length} klarmarkerade artiklar borttagna',
      errorMessage: 'Kunde inte rensa klarmarkerade artiklar',
      metadata: {
        'completed_count': completedItems.length,
        'action': 'clear_completed_items',
      },
    );
  }

  // ===== SHARE ACTIONS =====

  /// Handle share action using BaseActionHandler
  Future<void> handleShare(BuildContext context) async {
    if (!validateContext(context)) return;

    await showModalBottomSheet(
      context: context,
      builder: (context) => _buildShareSheet(context),
    );
  }

  Widget _buildShareSheet(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dela lista',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          ListTile(
            leading: Icon(Icons.link),
            title: Text('Kopiera länk'),
            subtitle: Text('Dela med länk som fungerar i alla appar'),
            onTap: () {
              Navigator.pop(context);
              _copyShareLink(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.message),
            title: Text('Skicka meddelande'),
            subtitle: Text('Dela via SMS eller meddelande-app'),
            onTap: () {
              Navigator.pop(context);
              _shareViaMessage(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.email),
            title: Text('Skicka e-post'),
            subtitle: Text('Dela via e-post med detaljer'),
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
              child: Text('Avbryt'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyShareLink(BuildContext context) async {
    await executeAction(
      context: context,
      action: () async {
        // In real implementation, copy link to clipboard
        await Future.delayed(const Duration(milliseconds: 200));
        return true;
      },
      successMessage: 'Länk kopierad till urklipp',
      metadata: {
        'list_id': viewModel.listId,
        'action': 'copy_share_link',
      },
    );
  }

  Future<void> _shareViaMessage(BuildContext context) async {
    showInfoMessage(context, 'Meddelandedelning kommer snart');
  }

  Future<void> _shareViaEmail(BuildContext context) async {
    showInfoMessage(context, 'E-postdelning kommer snart');
  }

  // ===== UTILITY METHODS =====

  /// Check if add item section should be shown
  bool shouldShowAddItemSection() {
    return viewModel.canView; // Show for viewers (read-only) and editors
  }

  /// Check if item input should be enabled
  bool isItemInputEnabled() {
    return viewModel.canEdit && !viewModel.isAddingItem;
  }

  /// Get add button text based on current state
  String getAddButtonText() {
    if (viewModel.isAddingItem) {
      return 'Lägger till...';
    }
    return 'Lägg till';
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
      case 'settings':
      case 'members':
        return true;
      default:
        return false;
    }
  }
}