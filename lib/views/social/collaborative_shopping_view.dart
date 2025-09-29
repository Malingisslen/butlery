/// Comprehensive collaborative shopping view providing real-time shared shopping list management for Flutter applications.
///
/// This module implements sophisticated collaborative shopping interface following Single Responsibility Principle,
/// specializing in shared list management, real-time collaboration, item coordination, and comprehensive shopping functionality.
/// It provides complete collaborative shopping interface while maintaining clean separation from business logic,
/// data persistence, and state management through CollaborativeShoppingViewModel integration and modern component architecture.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles collaborative shopping UI presentation concerns through comprehensive shopping architecture:
/// - **Real-Time Collaboration Excellence**: Advanced shared list management with live updates and participant coordination
/// - **Item Management Intelligence**: Sophisticated item operations with completion tracking and collaborative editing
/// - **Facade Pattern Implementation**: Comprehensive component coordination with focused architecture and modular design
/// - **Action System Coordination**: Advanced user interactions with menu actions, sharing functionality, and list management
/// - **Swedish Localization Excellence**: Complete Swedish language support for collaborative operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - Collaborative shopping business logic and data operations (handled by CollaborativeShoppingViewModel and shopping services)
/// - Real-time synchronization algorithms (handled by shopping services and collaboration infrastructure)
/// - Item persistence and state management (handled by shopping services and data management systems)
/// - Sharing functionality implementation (handled by sharing services and social infrastructure)
///
/// **Collaborative Shopping View Architecture:**
/// - **Facade Pattern Coordination**: Advanced component orchestration with focused architecture and clean separation
/// - **Real-Time Collaboration System**: Comprehensive shared list management with live updates and participant tracking
/// - **Modular Component Integration**: Sophisticated component coordination with header, items, and actions specialization
/// - **Action Handler System**: Complete user interaction with menu actions, item operations, and sharing functionality
/// - **Error Handling and States**: Advanced state management with loading, error, and empty state coordination
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to collaborative shopping view
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => CollaborativeShoppingView(
///       listId: sharedListId,
///     ),
///   ),
/// );
/// 
/// // The view provides comprehensive collaborative shopping functionality:
/// // - Real-time shared list management with live updates and participant coordination
/// // - Advanced item operations with completion tracking and collaborative editing
/// // - Facade pattern architecture with focused component coordination
/// // - Complete action system with menu actions, sharing, and list management
/// // - Error handling with loading states, error recovery, and user guidance
/// 
/// // Integration with focused components (Phase 9 Refactored):
/// // - CollaborativeShoppingHeader for header display and progress tracking
/// // - CollaborativeShoppingItems for items list management and interaction
/// // - CollaborativeShoppingActions for actions coordination and user interactions
/// // - LoadingStateBuilder for comprehensive state management
/// ```

// lib/views/social/collaborative_shopping_view.dart (Phase 9 Refactored)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';

// Focused components (Phase 9 refactoring)
import 'package:butlery/views/social/collaborative_shopping/collaborative_shopping_header.dart';
import 'package:butlery/views/social/collaborative_shopping/collaborative_shopping_items.dart';
import 'package:butlery/views/social/collaborative_shopping/collaborative_shopping_actions.dart';

/// Comprehensive collaborative shopping view providing real-time shared shopping list management through advanced facade architecture.
///
/// Manages complete collaborative shopping interface enabling shared list management, real-time collaboration, item coordination,
/// and comprehensive shopping functionality while maintaining clean separation between UI presentation
/// and business logic through CollaborativeShoppingViewModel integration and focused component architecture.
///
/// **Core Responsibilities:**
/// - Advanced facade pattern coordination with focused component orchestration and clean architectural separation
/// - Real-time collaboration management with shared list coordination, live updates, and participant synchronization
/// - Item management operations with completion tracking, collaborative editing, and comprehensive item functionality
/// - Action system coordination with menu actions, sharing functionality, and comprehensive user interaction management
/// - Swedish localized shopping experience with comprehensive user feedback and collaborative guidance
///
/// **Phase 9 Refactored Architecture:**
/// This facade coordinates focused components maintaining 100% backward compatibility while providing clean modular architecture:
/// - CollaborativeShoppingHeader: Header display and progress tracking
/// - CollaborativeShoppingItems: Items list management and interaction coordination
/// - CollaborativeShoppingActions: Actions and user interactions coordination
class CollaborativeShoppingView extends StatefulWidget {
  /// Shopping list identifier for collaborative management and real-time coordination.
  /// 
  /// Contains shared list ID enabling collaborative management, real-time synchronization,
  /// participant coordination, and comprehensive shopping functionality.
  final String listId;

  /// Creates comprehensive collaborative shopping view with real-time shared list management coordination.
  /// 
  /// [listId] Shopping list identifier for collaborative management and real-time coordination
  /// 
  /// Establishes collaborative shopping interface with shared list management, real-time collaboration,
  /// item coordination, and comprehensive shopping functionality through
  /// CollaborativeShoppingViewModel integration and focused component architecture.
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
            const Text(
              'Lista hittades inte',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            const Text(
              'Listan kanske har tagits bort eller så har du inte tillgång längre',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Tillbaka'),
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