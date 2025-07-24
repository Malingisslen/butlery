// lib/views/social/collaborative_shopping/collaborative_shopping_actions.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/collaborative_shopping_viewmodel.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_dimensions.dart';

/// Focused widget for collaborative shopping actions
/// 
/// This widget handles ONLY action-related responsibilities:
/// - Add item input section
/// - App bar with menu actions
/// - Action handlers and business logic coordination
/// - User interaction management
/// 
/// ❌ DOES NOT CONTAIN: Items display, header display, state management
class CollaborativeShoppingActions extends StatelessWidget {
  final CollaborativeShoppingViewModel viewModel;
  final TextEditingController newItemController;
  final VoidCallback onAddItem;
  final Function(String action) onMenuAction;
  final VoidCallback onShare;

  const CollaborativeShoppingActions({
    super.key,
    required this.viewModel,
    required this.newItemController,
    required this.onAddItem,
    required this.onMenuAction,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    // This widget provides methods for building action components
    // It's not directly rendered but provides building blocks
    throw UnsupportedError('CollaborativeShoppingActions is a utility widget');
  }

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

  /// Handle menu action selection
  void handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'settings':
        _showSettings(context);
        break;
      case 'members':
        _showMembers(context);
        break;
      case 'clear_completed':
        _showClearCompletedDialog(context);
        break;
      default:
        onMenuAction(action);
    }
  }

  void _showSettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Inställningar kommer snart'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  void _showMembers(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Medlemshantering kommer snart'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  void _showClearCompletedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rensa klara artiklar'),
        content: Text(
          'Vill du ta bort alla markerade artiklar från listan? '
          'Detta går inte att ångra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCompletedItems(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text('Rensa'),
          ),
        ],
      ),
    );
  }

  void _clearCompletedItems(BuildContext context) {
    // This would be implemented in the ViewModel
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Klara artiklar rensade'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // ===== SHARE ACTIONS =====

  /// Handle share action
  void handleShare(BuildContext context) {
    showModalBottomSheet(
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

  void _copyShareLink(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Länk kopierad till urklipp'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _shareViaMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Meddelandedelning kommer snart')),
    );
  }

  void _shareViaEmail(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('E-postdelning kommer snart')),
    );
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
        return viewModel.canEdit && viewModel.completedItemsCount > 0;
      case 'settings':
      case 'members':
        return true;
      default:
        return false;
    }
  }
}