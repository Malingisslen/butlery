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
import 'package:butlery/widgets/common/input/editable_menu_items_preview_dialog.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/styled/styled_widgets.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

/// Shopping List Selector Widget
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
  List<UnifiedShoppingItem>? _filteredMenuItems;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<UnifiedShoppingViewModel>();
    _selectedListId = _viewModel.activeList?.id;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.borderRadiusL),
          ),
        ),
        child: AnimatedBuilder(
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

            return ListView(
              controller: scrollController,
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
        ),
      ),
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
            'Inköpslistor',
            style: AppTextStyles.headlineSmall,
          ),
        ),
        Flexible(
          child: SizedBox(
            height: 40,
            child: StyledButton.primary(
              text: 'Ny lista',
              icon: const Icon(Icons.add),
              onPressed: () => _createNewList(context),
            ),
          ),
        ),
      ],
    );
  }

  /// Build lists section
  Widget _buildListsSection(
      BuildContext context, UnifiedShoppingViewModel viewModel) {
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
  Widget _buildAddToListSection(
      BuildContext context, UnifiedShoppingViewModel viewModel) {
    final selectedList = viewModel.lists.firstWhere(
      (list) => list.id == _selectedListId,
      orElse: () => viewModel.lists.first,
    );

    // Initialize filtered items if not already set
    _filteredMenuItems ??= _convertMenuToShoppingItems();
    final menuItems = _filteredMenuItems!;

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
            menuItems.isEmpty
                ? 'Inga artiklar valda från menyn'
                : 'Lägg till ${menuItems.length} artiklar från menyn i "${selectedList.name}"',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Row(
            children: [
              Expanded(
                child: ActionButtons.outlinedButton(
                  context,
                  label: 'Förhandsgranska',
                  icon: Icons.preview,
                  onPressed: () => _previewAndEditMenuItems(context, menuItems),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: StyledButton.primary(
                  text: _isAddingToList
                      ? 'Lägger till...'
                      : menuItems.isEmpty
                          ? 'Inga artiklar att lägga till'
                          : 'Lägg till',
                  icon: _isAddingToList
                      ? null
                      : const Icon(Icons.add_shopping_cart),
                  onPressed: (_isAddingToList || menuItems.isEmpty)
                      ? null
                      : () => _addMenuToList(
                          context, viewModel, selectedList, menuItems),
                  isLoading: _isAddingToList,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Select a list
  Future<void> _selectList(String listId) async {
    await _viewModel.setActiveList(listId); // Activate in service layer
    if (mounted) {
      setState(() {
        _selectedListId = listId;
      });
    }
    // Don't call onListSelected here - only call it after successful ingredient addition
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
          // Auto-select the newly created list
          final newListId =
              _viewModel.lists.isNotEmpty ? _viewModel.lists.last.id : null;
          if (newListId != null) {
            await _viewModel.setActiveList(newListId);
            if (mounted) {
              setState(() {
                _selectedListId = newListId;
              });
            }
          }
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
      if (mounted) {
        setState(() {
          _isAddingToList = true;
        });
      }

      try {
        final success =
            await viewModel.addItemsToList(selectedList.id, menuItems);

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

          // Call onListSelected callback on success to let parent handle navigation
          if (success) {
            widget.onListSelected?.call();
          }
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

  /// Preview and edit menu items
  Future<void> _previewAndEditMenuItems(
      BuildContext context, List<UnifiedShoppingItem> items) async {
    final selectedList = _viewModel.lists.firstWhere(
      (list) => list.id == _selectedListId,
      orElse: () => _viewModel.lists.first,
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditableMenuItemsPreviewDialog(
        items: List.from(items), // Create a copy to avoid modifying original
        selectedListName: selectedList.name,
      ),
    );

    if (result != null && mounted) {
      final editedItems = result['items'] as List<UnifiedShoppingItem>?;
      final shouldAddToList = result['addToList'] as bool? ?? false;

      if (editedItems != null) {
        setState(() {
          _filteredMenuItems = editedItems;
        });

        // If user chose to add to list, do it automatically
        if (shouldAddToList &&
            editedItems.isNotEmpty &&
            mounted &&
            context.mounted) {
          await _addMenuToList(context, _viewModel, selectedList, editedItems);
        }
      }
    }
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
              amount:
                  0, // No additional amount since ingredient already contains quantity
              unit:
                  '', // No additional unit since ingredient already contains unit
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
    // Don't dispose shared ViewModel instance from ServiceLocator
    super.dispose();
  }
}
