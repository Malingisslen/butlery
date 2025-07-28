// lib/widgets/common/input/shopping_list_selector.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/input/shopping_list_card.dart';
import 'package:butlery/widgets/common/input/shopping_list_actions.dart';

/// Shopping List Selector Widget
/// 
/// A comprehensive widget that allows users to:
/// - Select from existing shopping lists
/// - Create new shopping lists
/// - Add menu ingredients to selected lists
/// - Handle collaborative and personal lists
class ShoppingListSelector extends StatefulWidget {
  final VoidCallback? onListSelected;
  final Map<String, List<Recipe>>? menu;

  const ShoppingListSelector({
    super.key,
    this.onListSelected,
    this.menu,
  });

  @override
  State<ShoppingListSelector> createState() => _ShoppingListSelectorState();
}

class _ShoppingListSelectorState extends State<ShoppingListSelector> {
  late UnifiedShoppingViewModel _viewModel;
  String? _selectedListId;
  bool _isAddingToList = false;

  @override
  void initState() {
    super.initState();
    _viewModel = UnifiedShoppingViewModel();
    _selectedListId = _viewModel.activeList?.id;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return const StateWidget(
            type: StateType.loading,
            title: 'Laddar listor...',
          );
        }
        
        if (_viewModel.hasError) {
          return StateWidget(
            type: StateType.error,
            title: 'Fel vid laddning',
            subtitle: _viewModel.error,
            actionLabel: 'Försök igen',
            onAction: () => _viewModel.loadLists(),
          );
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: AppDimensions.spacingXl),
            _buildListsSection(context, _viewModel),
            if (widget.menu != null && _selectedListId != null) ...[
              const SizedBox(height: AppDimensions.spacingXl),
              _buildAddToListSection(context, _viewModel),
            ],
          ],
        );
      },
    );
  }

  /// Build header with title and create button
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.shopping_cart,
          size: AppDimensions.iconSizeAction,
          color: AppColors.primaryBlue,
        ),
        const SizedBox(width: AppDimensions.spacingM),
        const Expanded(
          child: Text(
            'Handlistor',
            style: AppTextStyles.headlineSmall,
          ),
        ),
        FilledButton.icon(
          onPressed: () => _createNewList(context),
          icon: const Icon(Icons.add, size: AppDimensions.iconSizeAction),
          label: const Text('Ny lista'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
          ),
        ),
      ],
    );
  }

  /// Build lists section
  Widget _buildListsSection(BuildContext context, UnifiedShoppingViewModel viewModel) {
    if (viewModel.lists.isEmpty) {
      return ShoppingListEmptyState(
        onCreateList: () => _createNewList(context),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: viewModel.lists.length,
      itemBuilder: (context, index) {
        final list = viewModel.lists[index];
        final isSelected = _selectedListId == list.id;
        
        return ShoppingListCard(
          list: list,
          viewModel: viewModel,
          isSelected: isSelected,
          onTap: () => _selectList(list.id),
        );
      },
    );
  }

  /// Build add to list section
  Widget _buildAddToListSection(BuildContext context, UnifiedShoppingViewModel viewModel) {
    final selectedList = viewModel.lists.firstWhere(
      (list) => list.id == _selectedListId,
      orElse: () => viewModel.lists.first,
    );

    final menuItems = _convertMenuToShoppingItems();
    
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant_menu,
                size: AppDimensions.iconSizeAction,
                color: AppColors.success,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: Text(
                  'Lägg till från meny',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            'Lägg till ${menuItems.length} artiklar från menyn i "${selectedList.name}"',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _previewMenuItems(context, menuItems),
                  icon: const Icon(Icons.preview),
                  label: const Text('Förhandsgranska'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.success),
                    foregroundColor: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isAddingToList ? null : () => _addMenuToList(context, viewModel, selectedList, menuItems),
                  icon: _isAddingToList 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.neutralLight),
                          ),
                        )
                      : const Icon(Icons.add_shopping_cart),
                  label: Text(_isAddingToList ? 'Lägger till...' : 'Lägg till'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Select a list
  void _selectList(String listId) {
    setState(() {
      _selectedListId = listId;
    });
    widget.onListSelected?.call();
  }

  /// Create new list
  Future<void> _createNewList(BuildContext context) async {
    final name = await ShoppingListActions.showCreateListDialog(context);
    
    if (name != null && name.isNotEmpty) {
      final success = await _viewModel.createList(name);
      
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Lista "$name" skapad'
                  : 'Kunde inte skapa lista: ${_viewModel.error ?? "Okänt fel"}',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );

        if (success) {
          setState(() {
            _selectedListId = _viewModel.activeList?.id;
          });
        }
      }
    }
  }

  /// Add menu items to selected list
  Future<void> _addMenuToList(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    UnifiedShoppingList selectedList,
    List<UnifiedShoppingItem> menuItems,
  ) async {
    final confirmed = await ShoppingListActions.showAddToListConfirmation(
      context,
      selectedList,
      menuItems.length,
    );

    if (confirmed) {
      setState(() {
        _isAddingToList = true;
      });

      try {
        final success = await viewModel.addItemsToList(selectedList.id, menuItems);
        
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? '${menuItems.length} artiklar tillagda i "${selectedList.name}"'
                    : 'Kunde inte lägga till artiklar: ${viewModel.error ?? "Okänt fel"}',
              ),
              backgroundColor: success ? AppColors.success : AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isAddingToList = false;
          });
        }
      }
    }
  }

  /// Preview menu items
  void _previewMenuItems(BuildContext context, List<UnifiedShoppingItem> items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Förhandsgranska artiklar'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.shopping_cart, size: AppDimensions.iconSizeM),
                title: Text(item.name),
                subtitle: item.quantity > 0 
                    ? Text('${item.quantity} ${item.unit}')
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stäng'),
          ),
        ],
      ),
    );
  }

  /// Convert menu recipes to shopping items
  List<UnifiedShoppingItem> _convertMenuToShoppingItems() {
    if (widget.menu == null) return [];

    final Map<String, UnifiedShoppingItem> itemMap = {};
    
    for (final dayRecipes in widget.menu!.values) {
      for (final recipe in dayRecipes) {
        for (final ingredient in recipe.ingredients) {
          final key = ingredient.toLowerCase().trim();
          
          if (itemMap.containsKey(key)) {
            // Combine quantities if possible
            final existingItem = itemMap[key]!;
            itemMap[key] = existingItem.copyWith(
              amount: existingItem.amount + 1,
            );
          } else {
            itemMap[key] = UnifiedShoppingItem(
              name: ingredient,
              amount: 1,
              unit: 'st',
              bought: false,
            );
          }
        }
      }
    }

    return itemMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}