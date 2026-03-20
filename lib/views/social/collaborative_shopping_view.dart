/// Collaborative shopping view with real-time shared list management.

// lib/views/social/collaborative_shopping_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

// Focused components (Phase 9 refactoring)
import 'package:butlery/views/social/collaborative_shopping/collaborative_shopping_header.dart';
import 'package:butlery/views/social/collaborative_shopping/collaborative_shopping_items.dart';
import 'package:butlery/views/social/collaborative_shopping/collaborative_shopping_actions.dart';

/// Collaborative shopping view using facade pattern for real-time list coordination.
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
      create: (_) => CollaborativeShoppingViewModel(
        listId: widget.listId,
        shoppingService: ServiceLocator.get(),
      ),
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
            body: SafeArea(
              // ✅ RESPONSIVE: Center and constrain content on large screens
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: LayoutComponents.valueFor(
                      context: context,
                      mobile: double.infinity,
                      tablet: 800,
                      desktop: 900,
                    ),
                  ),
                  child: Column(
                    children: [
                      LayoutComponents.offlineIndicator(),
                      Expanded(child: _buildBody(context, viewModel)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    return LoadingStateBuilder<dynamic>(
      isLoading: viewModel.isLoading,
      error: viewModel.error,
      data: viewModel.currentList,
      loadingMessage: context.l10n.collaborativeLoadingSharedList,
      emptyBuilder: (context) => _buildNotFoundState(context),
      builder: (context, shoppingList) => _buildListContent(context, viewModel),
      onErrorRetry: () {
        viewModel.clearError();
        viewModel.refresh();
      },
    );
  }

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
              context.l10n.collaborativeListNotFound,
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              context.l10n.collaborativeListNoAccess,
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: Text(context.l10n.commonBack),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _addItem() async {
    final itemName = _newItemController.text.trim();
    if (itemName.isEmpty) return;

    final viewModel = context.read<CollaborativeShoppingViewModel>();
    final success = await viewModel.addItem(itemName);

    if (success) {
      _newItemController.clear();
    } else if (viewModel.hasError) {
      if (!mounted) return;
      SnackBarUtils.showError(context, viewModel.error!);
    }
  }

  Future<void> _toggleItem(String itemId) async {
    final viewModel = context.read<CollaborativeShoppingViewModel>();
    final success = await viewModel.toggleItemCompletion(itemId);

    if (!success && viewModel.hasError) {
      if (!mounted) return;
      SnackBarUtils.showError(context, viewModel.error!);
    }
  }

  void _shareList() {
    _actions.handleShare(context);
  }

  void _handleMenuAction(String action) {
    _actions.handleMenuAction(context, action);
  }
}
