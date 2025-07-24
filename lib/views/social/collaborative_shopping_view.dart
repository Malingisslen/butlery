// lib/views/social/collaborative_shopping_view.dart (Phase 9 Refactored)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/collaborative_shopping_viewmodel.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../core/injection.dart';
import '../../widgets/common/loading_state_builder.dart';

// Focused components (Phase 9 refactoring)
import 'collaborative_shopping/collaborative_shopping_header.dart';
import 'collaborative_shopping/collaborative_shopping_items.dart';
import 'collaborative_shopping/collaborative_shopping_actions.dart';

/// Collaborative Shopping View - Main facade (Phase 9 Refactored)
/// 
/// This facade coordinates focused components:
/// - CollaborativeShoppingHeader: Header display and progress
/// - CollaborativeShoppingItems: Items list and management
/// - CollaborativeShoppingActions: Actions and user interactions
/// 
/// Maintains 100% backward compatibility while providing clean modular architecture.
class CollaborativeShoppingView extends StatefulWidget {
  final String listId;

  const CollaborativeShoppingView({
    super.key,
    required this.listId,
  });

  @override
  State<CollaborativeShoppingView> createState() =>
      _CollaborativeShoppingViewState();
}

class _CollaborativeShoppingViewState extends State<CollaborativeShoppingView> {
  final TextEditingController _newItemController = TextEditingController();
  
  // Focused components (Phase 9 refactoring)
  late CollaborativeShoppingActions _actions;

  @override
  void initState() {
    super.initState();
    // Actions component will be initialized in build method with current viewModel
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<CollaborativeShoppingViewModel>(param1: widget.listId),
      child: Consumer<CollaborativeShoppingViewModel>(
        builder: (context, viewModel, child) {
          // Initialize actions component with current viewModel
          _actions = CollaborativeShoppingActions(
            viewModel: viewModel,
            newItemController: _newItemController,
            onAddItem: _addItem,
            onMenuAction: _handleMenuAction,
            onShare: _shareList,
          );
          
          return Scaffold(
            appBar: _actions.buildAppBar(context),
            body: _buildBody(context, viewModel),
          );
        },
      ),
    );
  }

  // ===== BODY (Using Focused Components) =====

  Widget _buildBody(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    return LoadingStateBuilder<dynamic>(
      isLoading: viewModel.isLoading,
      error: viewModel.error,
      data: viewModel.currentList,
      loadingMessage: 'Laddar gemensam lista...',
      emptyBuilder: (context) => _buildNotFoundState(context),
      builder: (context, shoppingList) => _buildListContent(context, viewModel),
      onErrorRetry: () {
        viewModel.clearError();
        viewModel.refresh();
      },
    );
  }

  // ===== ERROR STATES =====

  Widget _buildNotFoundState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: AppDimensions.iconSizeXl,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            Text(
              'Lista hittades inte',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              'Listan kanske har tagits bort eller så har du inte tillgång längre',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back),
              label: Text('Tillbaka'),
            ),
          ],
        ),
      ),
    );
  }

  // ===== CONTENT (Using Focused Components) =====

  Widget _buildListContent(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    return Column(
      children: [
        CollaborativeShoppingHeader(viewModel: viewModel),
        _actions.buildAddItemSection(context),
        Expanded(
          child: CollaborativeShoppingItems(
            viewModel: viewModel,
            onToggleItem: _toggleItem,
          ),
        ),
      ],
    );
  }

  // ===== ACTION HANDLERS (Simplified Facade Methods) =====

  Future<void> _addItem() async {
    final itemName = _newItemController.text.trim();
    if (itemName.isEmpty) return;

    final viewModel = context.read<CollaborativeShoppingViewModel>();
    final success = await viewModel.addItem(itemName);

    if (success) {
      _newItemController.clear();
    } else if (viewModel.hasError) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _toggleItem(String itemId) async {
    final viewModel = context.read<CollaborativeShoppingViewModel>();
    final success = await viewModel.toggleItemCompletion(itemId);

    if (!success && viewModel.hasError) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _shareList() {
    _actions.handleShare(context);
  }

  void _handleMenuAction(String action) {
    _actions.handleMenuAction(context, action);
  }
}