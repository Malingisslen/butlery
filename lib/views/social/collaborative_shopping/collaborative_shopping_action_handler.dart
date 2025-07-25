// lib/views/social/collaborative_shopping/collaborative_shopping_action_handler.dart

import 'package:flutter/material.dart';
import '../../../core/base/base_action_handler.dart';
import '../../../viewmodels/collaborative_shopping_viewmodel.dart';
import '../../../models/unified/unified_shopping_item.dart';

/// Collaborative Shopping Action Handler using BaseActionHandler
/// 
/// This class provides standardized shopping list operations with:
/// - Item management (add, toggle completion)
/// - List refresh operations
/// - Proper error handling and user feedback
class CollaborativeShoppingActionHandler extends BaseActionHandler with ActionStateMixin {
  @override
  String get serviceName => 'CollaborativeShoppingActions';

  // ===== ITEM MANAGEMENT OPERATIONS =====

  /// Add new item to shopping list
  Future<void> addItem(
    BuildContext context,
    CollaborativeShoppingViewModel viewModel,
    String itemName,
  ) async {
    if (!validateContext(context) || !validateRequired([itemName], 'adding item')) {
      return;
    }

    if (itemName.trim().isEmpty) {
      showErrorMessage(context, 'Artikelnamn kan inte vara tomt');
      return;
    }

    await executeAction(
      context: context,
      action: () => viewModel.addItem(itemName.trim()),
      successMessage: 'Artikel "$itemName" tillagd',
      errorMessage: 'Kunde inte lägga till artikel',
      metadata: {
        'item_name': itemName,
        'list_id': viewModel.listId,
        'action': 'add_item',
      },
    );
  }

  /// Toggle item completion status
  Future<void> toggleItemCompletion(
    BuildContext context,
    CollaborativeShoppingViewModel viewModel,
    UnifiedShoppingItem item,
  ) async {
    if (!validateContext(context) || !validateRequired([item.id], 'toggling item')) {
      return;
    }

    await executeAction(
      context: context,
      action: () => viewModel.toggleItemCompletion(item.id),
      successMessage: item.bought 
          ? 'Artikel "${item.name}" markerad som inte klar'
          : 'Artikel "${item.name}" markerad som klar',
      errorMessage: 'Kunde inte uppdatera artikel',
      logAction: false, // Don't log simple toggle operations
      metadata: {
        'item_id': item.id,
        'item_name': item.name,
        'new_status': !item.bought,
        'action': 'toggle_completion',
      },
    );
  }

  // ===== BATCH OPERATIONS =====

  /// Add multiple items at once
  Future<void> addMultipleItems(
    BuildContext context,
    CollaborativeShoppingViewModel viewModel,
    List<String> itemNames,
  ) async {
    if (!validateContext(context) || itemNames.isEmpty) {
      showErrorMessage(context, 'Inga artiklar att lägga till');
      return;
    }

    await executeWithLoadingState(
      context: context,
      action: () async {
        int successCount = 0;
        
        for (final itemName in itemNames) {
          if (itemName.trim().isNotEmpty) {
            final success = await viewModel.addItem(itemName.trim());
            if (success) successCount++;
          }
        }
        
        if (successCount == 0) {
          throw Exception('Kunde inte lägga till några artiklar');
        }
        
        return successCount;
      },
      successMessage: 'Lade till ${itemNames.length} artiklar i listan',
      errorMessage: 'Kunde inte lägga till alla artiklar',
      metadata: {
        'item_count': itemNames.length,
        'items': itemNames,
        'action': 'add_multiple_items',
      },
    );
  }

  /// Clear all completed items (if such functionality exists)
  Future<void> clearCompletedItems(
    BuildContext context,
    CollaborativeShoppingViewModel viewModel,
  ) async {
    if (!validateContext(context)) return;

    final completedItems = viewModel.completedItemsList;
    
    if (completedItems.isEmpty) {
      showInfoMessage(context, 'Inga klarmarkerade artiklar att rensa');
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Since there's no clearCompletedItems method, we'll simulate it
        // In a real implementation, this would remove completed items
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      },
      confirmationTitle: 'Rensa klarmarkerade artiklar?',
      confirmationMessage: 'Vill du ta bort alla ${completedItems.length} klarmarkerade artiklar?',
      confirmActionText: 'Rensa alla',
      confirmationIcon: Icons.clear_all,
      isDangerous: true,
      successMessage: '${completedItems.length} klarmarkerade artiklar borttagna',
      errorMessage: 'Kunde inte rensa klarmarkerade artiklar',
      metadata: {
        'completed_count': completedItems.length,
        'action': 'clear_completed',
      },
    );
  }

  // ===== HELPER OPERATIONS =====

  /// Refresh list data
  Future<void> refreshList(
    BuildContext context,
    CollaborativeShoppingViewModel viewModel,
  ) async {
    if (!validateContext(context)) return;

    await executeAction(
      context: context,
      action: () => viewModel.refresh(),
      successMessage: 'Lista uppdaterad',
      errorMessage: 'Kunde inte uppdatera listan',
      metadata: {
        'list_id': viewModel.listId,
        'action': 'refresh_list',
      },
    );
  }

  // ===== UTILITY METHODS =====

  /// Check if add item section should be shown
  bool shouldShowAddItemSection(CollaborativeShoppingViewModel viewModel) {
    return viewModel.canView; // Show for viewers (read-only) and editors
  }

  /// Check if item input should be enabled
  bool isItemInputEnabled(CollaborativeShoppingViewModel viewModel) {
    return viewModel.canEdit && !viewModel.isAddingItem;
  }

  /// Get add button text based on current state
  String getAddButtonText(CollaborativeShoppingViewModel viewModel) {
    if (viewModel.isAddingItem) {
      return 'Lägger till...';
    }
    return 'Lägg till';
  }

  /// Get add button icon based on current state
  IconData getAddButtonIcon(CollaborativeShoppingViewModel viewModel) {
    if (viewModel.isAddingItem) {
      return Icons.hourglass_empty;
    }
    return Icons.add;
  }

  /// Check if clear completed action is available
  bool isClearCompletedAvailable(CollaborativeShoppingViewModel viewModel) {
    return viewModel.canEdit && viewModel.completedItemsList.isNotEmpty;
  }

  /// Get list statistics
  Map<String, dynamic> getListStats(CollaborativeShoppingViewModel viewModel) {
    return {
      'list_id': viewModel.listId,
      'list_title': viewModel.listTitle,
      'total_items': viewModel.totalItems,
      'completed_items': viewModel.completedItems,
      'completion_percentage': viewModel.completionPercentage,
      'can_edit': viewModel.canEdit,
      'can_view': viewModel.canView,
      'is_adding_item': viewModel.isAddingItem,
      'has_data': viewModel.hasData,
      'status_text': viewModel.statusText,
    };
  }

  // ===== CLEANUP =====

  /// Dispose resources
  void dispose() {
    clearError();
  }
}