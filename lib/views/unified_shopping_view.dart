// lib/views/unified_shopping_view.dart - FACADE PATTERN

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ViewModels
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';

// Theme
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

// Core
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/share_service.dart';

// Focused Components
import 'package:butlery/views/unified_shopping/widgets/shopping_app_bar.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_header.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_dialogs.dart';

class UnifiedShoppingView extends StatefulWidget {
  const UnifiedShoppingView({super.key});

  @override
  State<UnifiedShoppingView> createState() => _UnifiedShoppingViewState();
}

class _UnifiedShoppingViewState extends State<UnifiedShoppingView> {
  late UnifiedShoppingViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<UnifiedShoppingViewModel>();
    _initializeViewModel();
  }

  Future<void> _initializeViewModel() async {
    await _viewModel.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: LayoutComponents.mainMenu(
        title: 'Inköpslistor',
        currentIndex: 3,
        actions: [
          Consumer<UnifiedShoppingViewModel>(
            builder: (context, viewModel, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: ShoppingAppBar.buildActions(
                  context,
                  viewModel,
                  _showCreateListDialog,
                  _showShoppingShareDialog,
                  _shareListExternally,
                  () => _showSyncStatus(viewModel),
                ),
              );
            },
          ),
        ],
        floatingActionButton: ShoppingAppBar.buildFloatingActionButton(
          context,
          _showAddItemDialog,
        ),
        body: Consumer<UnifiedShoppingViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              children: [
                // Offline indicator
                if (!viewModel.isOnline) LayoutComponents.offlineIndicator(),

                // List header
                ShoppingListHeader.build(
                  context,
                  viewModel,
                  () => _clearBoughtItemsWithConfirmation(viewModel),
                  () => _uncheckAllItems(viewModel),
                ),

                // Main content
                Expanded(
                  child: ShoppingListContent.build(
                    context,
                    viewModel,
                    _onItemTap,
                    _onEditItem,
                    _onDeleteItem,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===== EVENT HANDLERS =====

  Future<void> _onItemTap(item) async {
    await _viewModel.toggleItemBought(item.id);
  }

  Future<void> _onEditItem(item) async {
    await ShoppingDialogs.showEditItemDialog(
      context,
      item,
      _viewModel,
      _showSuccessSnackBar,
      _showErrorSnackBar,
    );
  }

  Future<void> _onDeleteItem(item) async {
    final success = await _viewModel.removeItemFromActiveList(item.id);
    if (success) {
      _showSuccessSnackBar('${item.name} borttagen!');
    } else {
      _showErrorSnackBar('Kunde inte ta bort ${item.name}');
    }
  }

  Future<void> _showAddItemDialog() async {
    await ShoppingDialogs.showAddItemDialog(
      context,
      _viewModel,
      _showSuccessSnackBar,
      _showErrorSnackBar,
    );
  }

  Future<void> _showShoppingShareDialog() async {
    await ShoppingDialogs.showShareDialog(context, _viewModel);
  }

  void _shareListExternally() {
    if (_viewModel.activeList == null) return;

    final shareService = ServiceLocator.get<ShareService>();
    shareService.shareShoppingList(_viewModel.items);
  }

  Future<void> _showSyncStatus(UnifiedShoppingViewModel viewModel) async {
    await ShoppingDialogs.showSyncStatus(context, viewModel);
  }

  Future<void> _showCreateListDialog() async {
    await ShoppingDialogs.showCreateListDialog(
      context,
      _viewModel,
      _showSuccessSnackBar,
    );
  }

  Future<void> _clearBoughtItemsWithConfirmation(UnifiedShoppingViewModel viewModel) async {
    await ShoppingDialogs.showClearCompletedConfirmation(
      context,
      viewModel,
      _showSuccessSnackBar,
    );
  }

  Future<void> _uncheckAllItems(UnifiedShoppingViewModel viewModel) async {
    await viewModel.uncheckAllItems();
    _showSuccessSnackBar('Alla artiklar avbockade!');
  }

  // ===== SNACKBAR HELPERS =====

  void _showErrorSnackBar(String message) {
    SnackBarUtils.showError(context, message);
  }

  void _showSuccessSnackBar(String message) {
    SnackBarUtils.showSuccess(context, message);
  }

  @override
  void dispose() {
    super.dispose();
  }
}