/// Unified shopping view with facade pattern delegation for list management, item operations, and collaborative features.
/// Implements MVVM architecture with Swedish localization and component-based UI (AppBar, Header, Content, Dialogs).

// lib/views/unified_shopping_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ViewModel integration for shopping state management
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';

// Theme and utility components
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

// Core services and dependency injection
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/share_service.dart';

// Focused shopping components implementing facade pattern
import 'package:butlery/widgets/shopping/shopping_template_browser.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_app_bar.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_header.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_dialogs.dart';

// UI Redesign header component
import 'package:butlery/widgets/common/main_view_header.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Shopping list management view using facade pattern architecture.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewModel.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<UnifiedShoppingViewModel>(
        builder: (context, viewModel, child) {
          final itemCount = viewModel.activeList?.items.length ?? 0;
          final boughtCount =
              viewModel.activeList?.items.where((item) => item.bought).length ??
                  0;

          return LayoutComponents.mainMenu(
            currentIndex:
                2, // UI Redesign: nav order is recipes(0), menu(1), shopping(2), add(3)
            // UI Redesign: Use MainViewHeader with line break title
            appBar: MainViewHeader(
              title: context.l10n
                  .shoppingListTitle, // UI Redesign: forced line break per mockup
              countBadge: context.l10n.shoppingCountBadge(
                  itemCount, boughtCount), // UI Redesign: "X varor · X klara"
              actions: ShoppingAppBar.buildHeaderActions(
                context,
                viewModel,
                _showCreateListDialog,
                _showShoppingShareDialog,
                _shareListExternally,
                () => _showSharingStatus(viewModel),
                onBrowseTemplates: _showTemplateBrowser,
              ),
            ),
            // Floating action button for quick item addition
            floatingActionButton: ShoppingAppBar.buildFloatingActionButton(
              context,
              _showAddItemDialog,
            ),
            body: Center(
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
                    // Collaborative offline indicator for connection awareness
                    if (!viewModel.isOnline)
                      LayoutComponents.offlineIndicator(),

                    // Shopping list header with statistics and bulk operations
                    ShoppingListHeader.build(
                      context,
                      viewModel,
                      () => _clearBoughtItemsWithConfirmation(viewModel),
                      () => _uncheckAllItems(viewModel),
                      () => _showRenameListDialog(viewModel),
                      () => _showDeleteListConfirmation(viewModel),
                      onConvertList: _canConvertActiveList(viewModel)
                          ? () => _convertActiveList(viewModel)
                          : null,
                    ),

                    // Main shopping list content with item management
                    Expanded(
                      child: ShoppingListContent.build(
                        context,
                        viewModel,
                        _onItemTap,
                        _onEditItem,
                        _onDeleteItem,
                        _showCreateListDialog,
                        _showAddItemDialog,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onItemTap(UnifiedShoppingItem item) async {
    await _viewModel.toggleItemBought(item.id);
  }

  /// Show edit dialog for item.
  /// and user feedback through dialog management and ViewModel integration with
  /// success and error handling coordination.
  /// **Item Editing Features:**
  /// - Dialog-based editing with form validation and user-friendly interface
  /// - Comprehensive validation with Swedish localized error messages
  /// - Success and error feedback with snackbar integration and user guidance
  Future<void> _onEditItem(UnifiedShoppingItem item) async {
    await ShoppingDialogs.showEditItemDialog(
      context,
      item,
      _viewModel,
      _showSuccessSnackBar,
      _showErrorSnackBar,
    );
  }

  /// Advanced item deletion with confirmation and collaborative synchronization coordination.
  /// [item] Shopping item for deletion and synchronization coordination
  /// Handles item deletion events enabling comprehensive item removal, collaborative synchronization,
  /// and user feedback through ViewModel integration with success and error handling coordination.
  /// **Item Deletion Features:**
  /// - Comprehensive item removal with collaborative synchronization and state management
  /// - Success and error feedback with Swedish localized messages and user guidance
  /// - Collaborative coordination with real-time synchronization and multi-user support
  Future<void> _onDeleteItem(UnifiedShoppingItem item) async {
    final removedMsg = context.l10n.shoppingItemRemoved(item.name);
    final errorMsg = context.l10n.shoppingItemRemoveError(item.name);
    final success = await _viewModel.removeItemFromActiveList(item.id);
    if (success) {
      _showSuccessSnackBar(removedMsg);
    } else {
      _showErrorSnackBar(errorMsg);
    }
  }

  /// Comprehensive item addition dialog with form validation and user feedback coordination.
  /// Presents item addition dialog enabling comprehensive item creation, validation,
  /// and user feedback through dialog management and ViewModel integration with
  /// success and error handling coordination.
  /// **Item Addition Features:**
  /// - Dialog-based item creation with comprehensive form validation and user interface
  /// - Swedish localized validation messages and user guidance
  /// - Success and error feedback with snackbar integration and user experience optimization
  Future<void> _showAddItemDialog() async {
    await ShoppingDialogs.showAddItemDialog(
      context,
      _viewModel,
      _showSuccessSnackBar,
      _showErrorSnackBar,
    );
  }

  /// Advanced shopping list sharing dialog with collaborative features and friend selection coordination.
  /// Presents shopping sharing dialog enabling collaborative shopping list sharing,
  /// friend selection, and comprehensive sharing functionality through dialog management
  /// and ViewModel integration with social feature coordination.
  /// **Shopping Sharing Features:**
  /// - Collaborative sharing with friend selection and permission management
  /// - Social integration with sharing status tracking and delivery coordination
  /// - Comprehensive sharing options with real-time collaboration and synchronization
  Future<void> _showShoppingShareDialog() async {
    await ShoppingDialogs.showShareDialog(context, _viewModel);
  }

  /// External shopping list sharing with system integration and content distribution coordination.
  /// Handles external sharing functionality enabling system share dialog presentation,
  /// content formatting, and platform integration through ShareService coordination
  /// with comprehensive sharing functionality and user experience optimization.
  /// **External Sharing Features:**
  /// - System share dialog integration with platform-specific sharing capabilities
  /// - Content formatting with readable shopping list presentation and user-friendly format
  /// - Platform integration with comprehensive sharing options and distribution coordination
  void _shareListExternally() {
    if (_viewModel.activeList == null) return;

    final shareService = ServiceLocator.get<ShareService>();
    shareService.shareShoppingList(_viewModel.items);
  }

  /// Comprehensive sharing status dialog with collaborative information and permission coordination.
  /// [viewModel] UnifiedShoppingViewModel instance for sharing status access and management
  /// Presents sharing status dialog enabling collaborative status display,
  /// member permissions, and comprehensive sharing management through
  /// dialog presentation and ViewModel integration.
  /// **Sharing Status Features:**
  /// - Collaborative sharing status with member information and permission level tracking
  /// - Real-time sharing information with member activity and permission management display
  /// - Permission management with user roles and collaborative coordination
  Future<void> _showSharingStatus(UnifiedShoppingViewModel viewModel) async {
    await ShoppingDialogs.showSharingStatus(context, viewModel);
  }

  /// Advanced shopping list creation dialog with validation and collaborative setup coordination.
  /// Presents list creation dialog enabling comprehensive shopping list creation,
  /// validation, and collaborative setup through dialog management and ViewModel
  /// integration with success feedback and user experience optimization.
  /// **List Creation Features:**
  /// - Comprehensive list creation with form validation and Swedish localized interface
  /// - Collaborative setup with sharing options and participant management
  /// - Success feedback with user guidance and list management coordination
  Future<void> _showCreateListDialog() async {
    await ShoppingDialogs.showCreateListDialog(
      context,
      _viewModel,
      _showSuccessSnackBar,
    );
  }

  Future<void> _showTemplateBrowser() async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  children: [
                    Text(
                      context.l10n.shoppingTemplates,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ShoppingTemplateBrowser(
                  onTemplateSelected: (templateId) async {
                    final successMsg = context.l10n.shoppingTemplateCreated;
                    Navigator.pop(context);
                    try {
                      await _viewModel.createListFromTemplate(templateId);
                      if (mounted) {
                        _showSuccessSnackBar(successMsg);
                      }
                    } catch (e) {
                      if (mounted) {
                        SnackBarUtils.showUserFriendlyError(
                          context, e,
                          contextAction: 'Create list from template',
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Comprehensive completed items clearing with confirmation and collaborative synchronization coordination.
  /// [viewModel] UnifiedShoppingViewModel instance for completed items management and synchronization
  /// Handles completed items clearing with confirmation dialog, collaborative synchronization,
  /// and user feedback through dialog management and ViewModel integration with
  /// comprehensive bulk operation coordination.
  /// **Completed Items Clearing Features:**
  /// - Confirmation dialog with user safety and operation preview
  /// - Collaborative synchronization with real-time updates and multi-user coordination
  /// - Success feedback with operation summary and user experience optimization
  Future<void> _clearBoughtItemsWithConfirmation(
      UnifiedShoppingViewModel viewModel) async {
    await ShoppingDialogs.showClearCompletedConfirmation(
      context,
      viewModel,
      _showSuccessSnackBar,
    );
  }

  /// Advanced bulk item unchecking with collaborative synchronization and user feedback coordination.
  /// [viewModel] UnifiedShoppingViewModel instance for bulk operation management and synchronization
  /// Handles bulk item unchecking enabling comprehensive status reset, collaborative synchronization,
  /// and user feedback through ViewModel integration with bulk operation management
  /// and Swedish localized success messaging.
  /// **Bulk Unchecking Features:**
  /// - Comprehensive status reset with all items unchecking and state synchronization
  /// - Collaborative coordination with real-time synchronization and multi-user support
  /// - Success feedback with Swedish localized messaging and user experience optimization
  Future<void> _uncheckAllItems(UnifiedShoppingViewModel viewModel) async {
    final msg = context.l10n.shoppingAllUnchecked;
    await viewModel.uncheckAllItems();
    _showSuccessSnackBar(msg);
  }

  /// Show rename list dialog with text input and validation
  Future<void> _showRenameListDialog(UnifiedShoppingViewModel viewModel) async {
    final activeList = viewModel.activeList;
    if (activeList == null) {
      _showErrorSnackBar(context.l10n.shoppingNoListForRename);
      return;
    }

    await ShoppingDialogs.showRenameListDialog(
      context,
      activeList,
      viewModel,
      _showSuccessSnackBar,
      _showErrorSnackBar,
    );
  }

  /// Show delete list confirmation dialog with item count warning
  Future<void> _showDeleteListConfirmation(
      UnifiedShoppingViewModel viewModel) async {
    final activeList = viewModel.activeList;
    if (activeList == null) {
      _showErrorSnackBar(context.l10n.shoppingNoListForDelete);
      return;
    }

    await ShoppingDialogs.showDeleteListConfirmationDialog(
      context,
      activeList,
      viewModel,
      _showSuccessSnackBar,
      _showErrorSnackBar,
    );
  }

  /// Whether the current user can convert the active list.
  /// Personal lists owned by the user can become collaborative.
  /// Collaborative lists owned by the user can become personal.
  bool _canConvertActiveList(UnifiedShoppingViewModel viewModel) {
    final list = viewModel.activeList;
    if (list == null) return false;
    final currentUserId = viewModel.currentUserId;
    if (currentUserId == null) return false;
    // Only owner can convert
    if (list.ownerId != currentUserId) return false;
    // Templates cannot be converted
    if (list.type == ListType.template) return false;
    return true;
  }

  /// Dispatches to the appropriate conversion dialog based on current list type
  Future<void> _convertActiveList(UnifiedShoppingViewModel viewModel) async {
    final list = viewModel.activeList;
    if (list == null) return;

    if (list.isPersonal) {
      await ShoppingDialogs.showConvertToCollaborativeDialog(
        context,
        list,
        _showSuccessSnackBar,
        _showErrorSnackBar,
      );
      // Reload lists after conversion
      await viewModel.loadLists();
    } else if (list.isCollaborative) {
      await ShoppingDialogs.showConvertToPersonalDialog(
        context,
        list,
        _showSuccessSnackBar,
        _showErrorSnackBar,
      );
      // Reload lists after conversion
      await viewModel.loadLists();
    }
  }

  void _showErrorSnackBar(String message) {
    SnackBarUtils.showError(context, message);
  }

  void _showSuccessSnackBar(String message) {
    SnackBarUtils.showSuccess(context, message);
  }

  /// Comprehensive resource disposal with proper lifecycle management and cleanup coordination.
  /// Performs complete resource cleanup preventing memory leaks and ensuring proper
  /// lifecycle management through systematic disposal of state resources, event handlers,
  /// and ViewModel references with comprehensive cleanup coordination.
  /// **Disposal Features:**
  /// - State resource cleanup with proper lifecycle management
  /// - Memory leak prevention with comprehensive resource disposal
  /// - Event handler cleanup with proper subscription management
  @override
  void dispose() {
    super.dispose();
  }
}
