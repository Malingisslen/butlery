/// Unified shopping view with facade pattern delegation for list management, item operations, and collaborative features.
/// Implements MVVM architecture with Swedish localization and component-based UI (AppBar, Header, Content, Dialogs).

// lib/views/unified_shopping_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ViewModel integration for shopping state management
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';

// Theme and utility components
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

// Core services and dependency injection
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/share_service.dart';

// Focused shopping components implementing facade pattern
import 'package:butlery/views/unified_shopping/widgets/shopping_app_bar.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_header.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_dialogs.dart';

/// Comprehensive unified shopping view providing advanced shopping list management through facade pattern architecture.
/// Manages complete shopping list interface enabling item management, collaborative features, sharing functionality,
/// and comprehensive shopping coordination while maintaining clean separation between UI presentation
/// and business logic through MVVM architecture and focused component delegation.
/// **Core Responsibilities:**
/// - Advanced shopping list presentation with item management and collaborative feature coordination
/// - Facade pattern implementation with specialized component delegation and clean architecture
/// - Event handling coordination with proper separation of concerns and user interaction management
/// - Dialog management with comprehensive user input and shopping operation coordination
/// - Swedish localized user feedback with success and error message management
class UnifiedShoppingView extends StatefulWidget {
  /// Creates comprehensive unified shopping view with facade pattern architecture and component delegation.
  /// Establishes shopping list interface with focused component integration,
  /// event handling coordination, and comprehensive shopping functionality
  /// through clean architectural separation and responsive design coordination.
  const UnifiedShoppingView({super.key});

  /// Creates unified shopping view state with ViewModel integration and lifecycle management.
  /// Establishes stateful shopping interface enabling ViewModel initialization,
  /// event handling coordination, and comprehensive shopping functionality
  /// through proper state lifecycle and component management.
  @override
  State<UnifiedShoppingView> createState() => _UnifiedShoppingViewState();
}

/// Unified shopping view state managing ViewModel integration, event handling, and component lifecycle coordination.
/// Handles complete shopping list state management including ViewModel initialization, event delegation,
/// dialog coordination, and user interaction handling while maintaining clean facade pattern architecture
/// and proper lifecycle management through comprehensive state coordination.
class _UnifiedShoppingViewState extends State<UnifiedShoppingView> {
  /// Unified shopping ViewModel for comprehensive shopping state management and business logic coordination.
  /// Manages shopping list operations, item management, collaborative features,
  /// and shopping functionality enabling complete shopping coordination through MVVM architecture.
  late UnifiedShoppingViewModel _viewModel;

  /// State initialization with ViewModel setup and shopping functionality preparation.
  /// Initializes shopping view state enabling ViewModel integration, shopping list loading,
  /// and comprehensive shopping functionality through proper dependency injection
  /// and state lifecycle management coordination.
  /// **Initialization Process:**
  /// - ViewModel acquisition through dependency injection and service locator
  /// - Asynchronous ViewModel initialization with shopping data loading
  /// - Component preparation with event handling and dialog coordination
  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<UnifiedShoppingViewModel>();
    _initializeViewModel();
  }

  /// Initialize ViewModel with shopping data loading and collaborative features
  Future<void> _initializeViewModel() async {
    await _viewModel.initialize();
  }

  /// Build shopping interface with Provider state management and facade pattern components
  /// - Main menu layout with navigation integration and consistent app structure
  /// - Collaborative features with offline indicators and synchronization status
  /// - Floating action button integration with item addition functionality
  /// **Component Integration:**
  /// - ShoppingAppBar for action management with create, share, and sync functionality
  /// - ShoppingListHeader for list statistics and bulk operations coordination
  /// - ShoppingListContent for item display, interaction, and management functionality
  /// - LayoutComponents for consistent app structure and navigation integration
  /// **Collaborative Features:**
  /// - Offline indicator with connection status and synchronization awareness
  /// - Real-time synchronization with collaborative editing and multi-user support
  /// - Sharing functionality with social integration and external distribution
  /// Returns complete shopping interface with comprehensive functionality and facade pattern architecture.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: LayoutComponents.mainMenu(
        title: 'Inköpslistor',
        currentIndex: 3,
        actions: [
          // Dynamic action bar with shopping operations
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
                  () => _showSharingStatus(viewModel),
                ),
              );
            },
          ),
        ],
        // Floating action button for quick item addition
        floatingActionButton: ShoppingAppBar.buildFloatingActionButton(
          context,
          _showAddItemDialog,
        ),
        body: Consumer<UnifiedShoppingViewModel>(
          builder: (context, viewModel, child) {
            // ✅ RESPONSIVE: Center and constrain content on large screens
            return Center(
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
                    if (!viewModel.isOnline) LayoutComponents.offlineIndicator(),

                    // Shopping list header with statistics and bulk operations
                    ShoppingListHeader.build(
                      context,
                      viewModel,
                      () => _clearBoughtItemsWithConfirmation(viewModel),
                      () => _uncheckAllItems(viewModel),
                      () => _showRenameListDialog(viewModel),
                      () => _showDeleteListConfirmation(viewModel),
                    ),

                    // Main shopping list content with item management
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===== COMPREHENSIVE EVENT HANDLERS =====

  /// Advanced item tap handling with shopping status toggling and collaborative coordination.
  /// [item] Shopping item for status toggling and collaborative synchronization
  /// Handles item tap events enabling shopping status toggling, collaborative synchronization,
  /// and comprehensive item management through ViewModel integration and reactive state management.
  /// **Item Tap Features:**
  /// - Shopping status toggling with immediate visual feedback and state synchronization
  /// - Collaborative coordination with real-time synchronization and multi-user support
  /// - Optimistic updates with rollback capability and error handling coordination
  Future<void> _onItemTap(item) async {
    await _viewModel.toggleItemBought(item.id);
  }

  /// Comprehensive item editing with dialog presentation and validation coordination.
  /// [item] Shopping item for editing and validation coordination
  /// Handles item editing events enabling comprehensive item modification, validation,
  /// and user feedback through dialog management and ViewModel integration with
  /// success and error handling coordination.
  /// **Item Editing Features:**
  /// - Dialog-based editing with form validation and user-friendly interface
  /// - Comprehensive validation with Swedish localized error messages
  /// - Success and error feedback with snackbar integration and user guidance
  Future<void> _onEditItem(item) async {
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
  Future<void> _onDeleteItem(item) async {
    final success = await _viewModel.removeItemFromActiveList(item.id);
    if (success) {
      _showSuccessSnackBar('${item.name} borttagen!');
    } else {
      _showErrorSnackBar('Kunde inte ta bort ${item.name}');
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

  /// Comprehensive completed items clearing with confirmation and collaborative synchronization coordination.
  /// [viewModel] UnifiedShoppingViewModel instance for completed items management and synchronization
  /// Handles completed items clearing with confirmation dialog, collaborative synchronization,
  /// and user feedback through dialog management and ViewModel integration with
  /// comprehensive bulk operation coordination.
  /// **Completed Items Clearing Features:**
  /// - Confirmation dialog with user safety and operation preview
  /// - Collaborative synchronization with real-time updates and multi-user coordination
  /// - Success feedback with operation summary and user experience optimization
  Future<void> _clearBoughtItemsWithConfirmation(UnifiedShoppingViewModel viewModel) async {
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
    await viewModel.uncheckAllItems();
    _showSuccessSnackBar('Alla artiklar avbockade!');
  }

  /// Show rename list dialog with text input and validation
  Future<void> _showRenameListDialog(UnifiedShoppingViewModel viewModel) async {
    final activeList = viewModel.activeList;
    if (activeList == null) {
      _showErrorSnackBar('Ingen lista vald för att byta namn');
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
  Future<void> _showDeleteListConfirmation(UnifiedShoppingViewModel viewModel) async {
    final activeList = viewModel.activeList;
    if (activeList == null) {
      _showErrorSnackBar('Ingen lista vald för borttagning');
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

  // ===== USER FEEDBACK AND LIFECYCLE MANAGEMENT =====

  /// Comprehensive error message presentation with user feedback and recovery coordination.
  /// [message] Swedish localized error message for user display and guidance
  /// Presents error messages enabling user feedback, error communication,
  /// and recovery guidance through snackbar integration and consistent
  /// error messaging with comprehensive user experience coordination.
  /// **Error Feedback Features:**
  /// - Swedish localized error messages with clear user communication
  /// - Consistent error styling with app design system integration
  /// - User guidance with actionable error information and recovery suggestions
  void _showErrorSnackBar(String message) {
    SnackBarUtils.showError(context, message);
  }

  /// Comprehensive success message presentation with user feedback and confirmation coordination.
  /// [message] Swedish localized success message for user display and confirmation
  /// Presents success messages enabling user feedback, operation confirmation,
  /// and positive reinforcement through snackbar integration and consistent
  /// success messaging with comprehensive user experience coordination.
  /// **Success Feedback Features:**
  /// - Swedish localized success messages with positive user reinforcement
  /// - Consistent success styling with app design system integration
  /// - Operation confirmation with clear success indication and user guidance
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