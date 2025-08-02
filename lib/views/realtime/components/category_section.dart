// lib/views/realtime/components/category_section.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/realtime_menu_viewmodel.dart';
import 'package:butlery/widgets/common/content_cards/recipe_card.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart';

/// Category section widget för realtidsmenyer med drag-and-drop funktionalitet
/// 
/// Denna komponent ansvarar för:
/// - Visa kategorisektion med recept
/// - Drag-and-drop för att flytta recept mellan kategorier
/// - Kategorihantering (lägg till/ta bort/redigera)
/// - Animationer för mjuka interaktioner
class CategorySection extends StatefulWidget {
  final String categoryName;
  final List<Recipe> recipes;
  final bool canEdit;
  final VoidCallback? onAddRecipe;
  final Function(String categoryName)? onEditCategory;
  final Function(String categoryName)? onDeleteCategory;

  const CategorySection({
    super.key,
    required this.categoryName,
    required this.recipes,
    this.canEdit = false,
    this.onAddRecipe,
    this.onEditCategory,
    this.onDeleteCategory,
  });

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  bool _isExpanded = true;
  bool _isDragTarget = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    _expandController.forward();
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    if (mounted) setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RealtimeMenuViewModel>();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
        border: _isDragTarget
            ? Border.all(color: AppColors.primaryBlue, width: 2)
            : Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DragTarget<RecipeDragData>(
        onAcceptWithDetails: (details) => _handleRecipeDrop(context, viewModel, details.data),
        onWillAcceptWithDetails: (details) => _canAcceptDrop(details.data),
        onMove: (details) => _updateDragTarget(true),
        onLeave: (data) => _updateDragTarget(false),
        builder: (context, candidateData, rejectedData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryHeader(context, viewModel),
              AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: _expandAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: _buildRecipeList(context, viewModel),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryHeader(
    BuildContext context,
    RealtimeMenuViewModel viewModel,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Row(
        children: [
          // Expand/collapse icon
          AnimatedRotation(
            turns: _isExpanded ? 0.25 : 0,
            duration: const Duration(milliseconds: 300),
            child: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _toggleExpanded,
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingS),

          // Category name
          Expanded(
            child: Text(
              widget.categoryName,
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.sectionHeader,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Recipe count badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingS,
              vertical: AppDimensions.spacingXs,
            ),
            decoration: BoxDecoration(
              color: widget.recipes.isEmpty
                  ? AppColors.textLight.withValues(alpha: 0.2)
                  : AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
            ),
            child: Text(
              '${widget.recipes.length}',
              style: AppTextStyles.labelSmall.copyWith(
                color: widget.recipes.isEmpty
                    ? AppColors.textLight
                    : AppColors.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(width: AppDimensions.spacingS),

          // Category actions menu
          if (widget.canEdit) _buildCategoryActions(context),
        ],
      ),
    );
  }

  Widget _buildCategoryActions(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) => _handleCategoryAction(context, value),
      icon: const Icon(
        Icons.more_vert,
        size: 20,
        color: AppColors.textMedium,
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'add_recipe',
          child: Row(
            children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: AppDimensions.spacingS),
              Text('Lägg till recept', style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit_category',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: AppDimensions.spacingS),
              Text('Redigera kategori', style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'clear_category',
          child: Row(
            children: [
              Icon(Icons.clear_all, size: 18),
              SizedBox(width: AppDimensions.spacingS),
              Text('Rensa kategori', style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
        if (widget.recipes.isEmpty) {
          PopupMenuItem(
        }
            value: 'delete_category',
            child: Row(
              children: [
                const Icon(Icons.delete, size: 18, color: AppColors.error),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  'Ta bort kategori',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRecipeList(
    BuildContext context,
    RealtimeMenuViewModel viewModel,
  ) {
    if (widget.recipes.isEmpty) {
      return _buildEmptyState(context);
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        left: AppDimensions.paddingM,
        right: AppDimensions.paddingM,
        bottom: AppDimensions.paddingM,
      ),
      itemCount: widget.recipes.length,
      onReorder: widget.canEdit
          ? (oldIndex, newIndex) {
              _handleReorder(context, viewModel, oldIndex, newIndex);
            }
          : (oldIndex, newIndex) {},  // Provide empty callback when not editable
      itemBuilder: (context, index) {
        final recipe = widget.recipes[index];
        return _buildDraggableRecipeCard(
          context,
          viewModel,
          recipe,
          index,
        );
      },
    );
  }

  Widget _buildDraggableRecipeCard(
    BuildContext context,
    RealtimeMenuViewModel viewModel,
    Recipe recipe,
    int index,
  ) {
    final dragData = RecipeDragData(
      recipe: recipe,
      sourceCategory: widget.categoryName,
      sourceIndex: index,
    );

    return Container(
      key: ValueKey('${recipe.id}_$index'),
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: widget.canEdit
          ? Draggable<RecipeDragData>(
              data: dragData,
              feedback: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadius10),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: RecipeCard(
                    recipe: recipe,
                    style: RecipeCardStyle.compact,
                    margin: EdgeInsets.zero,
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: RecipeCard(
                  recipe: recipe,
                  style: RecipeCardStyle.compact,
                  margin: EdgeInsets.zero,
                ),
              ),
              child: RecipeCard(
                recipe: recipe,
                style: RecipeCardStyle.compact,
                margin: EdgeInsets.zero,
                onTap: () => _handleRecipeTap(context, recipe),
                onLongPress: widget.canEdit
                    ? () => _showRecipeOptions(context, viewModel, recipe, index)
                    : null,
              ),
            )
          : RecipeCard(
              recipe: recipe,
              style: RecipeCardStyle.compact,
              margin: EdgeInsets.zero,
              onTap: () => _handleRecipeTap(context, recipe),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        children: [
          const Icon(
            Icons.restaurant_menu,
            size: 48,
            color: AppColors.textLight,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            'Inga recept i denna kategori',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.canEdit) ...[
            const SizedBox(height: AppDimensions.spacingM),
            TextButton.icon(
              onPressed: widget.onAddRecipe,
              icon: const Icon(Icons.add),
              label: const Text('Lägg till recept'),
            ),
          ],
        ],
      ),
    );
  }

  // ===== EVENT HANDLERS =====

  void _handleCategoryAction(BuildContext context, String action) {
    final viewModel = context.read<RealtimeMenuViewModel>();

    switch (action) {
      case 'add_recipe':
        widget.onAddRecipe?.call();
        break;
      case 'edit_category':
        widget.onEditCategory?.call(widget.categoryName);
        break;
      case 'clear_category':
        _showClearCategoryDialog(context, viewModel);
        break;
      case 'delete_category':
        widget.onDeleteCategory?.call(widget.categoryName);
        break;
    }
  }

  void _handleReorder(
    BuildContext context,
    RealtimeMenuViewModel viewModel,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    viewModel.reorderRecipeInCategory(
      categoryName: widget.categoryName,
      fromIndex: oldIndex,
      toIndex: newIndex,
    );

    AppLogger.info('🔄 Recipe reordered in category ${widget.categoryName}: $oldIndex -> $newIndex');
  }

  void _handleRecipeDrop(
    BuildContext context,
    RealtimeMenuViewModel viewModel,
    RecipeDragData data,
  ) {
    setState(() => _isDragTarget = false);

    if (data.sourceCategory == widget.categoryName) {
      AppLogger.info('📍 Recipe dropped in same category, ignoring');
      return;
    }

    viewModel.moveRecipeBetweenCategories(
      fromCategory: data.sourceCategory,
      fromIndex: data.sourceIndex,
      toCategory: widget.categoryName,
    );

    AppLogger.info('🎯 Recipe moved: ${data.sourceCategory} -> ${widget.categoryName}');
  }

  bool _canAcceptDrop(RecipeDragData? data) {
    return data != null && 
           widget.canEdit && 
           data.sourceCategory != widget.categoryName;
  }

  void _updateDragTarget(bool isDragTarget) {
    if (mounted && _isDragTarget != isDragTarget) {
      setState(() => _isDragTarget = isDragTarget);
    }
  }

  void _handleRecipeTap(BuildContext context, Recipe recipe) {
    // Navigate to recipe detail view
    Navigator.pushNamed(context, '/recipe-detail', arguments: recipe);
  }

  void _showRecipeOptions(
    BuildContext context,
    RealtimeMenuViewModel viewModel,
    Recipe recipe,
    int index,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildRecipeOptionsSheet(
        context,
        viewModel,
        recipe,
        index,
      ),
    );
  }

  Widget _buildRecipeOptionsSheet(
    BuildContext context,
    RealtimeMenuViewModel viewModel,
    Recipe recipe,
    int index,
  ) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('Visa recept'),
            onTap: () {
              Navigator.pop(context);
              _handleRecipeTap(context, recipe);
            },
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline),
            title: const Text('Ta bort från kategori'),
            onTap: () {
              Navigator.pop(context);
              viewModel.removeRecipeFromCategory(
                categoryName: widget.categoryName,
                recipeIndex: index,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.move_to_inbox),
            title: const Text('Flytta till annan kategori'),
            onTap: () {
              Navigator.pop(context);
              _showMoveToCategoryDialog(context, viewModel, recipe, index);
            },
          ),
        ],
      ),
    );
  }

  void _showClearCategoryDialog(
    BuildContext context,
    RealtimeMenuViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rensa kategori'),
        content: Text(
          'Är du säker på att du vill ta bort alla ${widget.recipes.length} recept från kategorin "${widget.categoryName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              viewModel.clearCategory(widget.categoryName);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Rensa'),
          ),
        ],
      ),
    );
  }

  void _showMoveToCategoryDialog(
    BuildContext context,
    RealtimeMenuViewModel viewModel,
    Recipe recipe,
    int index,
  ) {
    final availableCategories = viewModel.categories
        .where((cat) => cat != widget.categoryName)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flytta recept'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableCategories.map((category) {
            return ListTile(
              title: Text(category),
              onTap: () {
                Navigator.pop(context);
                viewModel.moveRecipeBetweenCategories(
                  fromCategory: widget.categoryName,
                  fromIndex: index,
                  toCategory: category,
                );
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
        ],
      ),
    );
  }
}

/// Data class för drag-and-drop operationer
class RecipeDragData {
  final Recipe recipe;
  final String sourceCategory;
  final int sourceIndex;

  const RecipeDragData({
    required this.recipe,
    required this.sourceCategory,
    required this.sourceIndex,
  });

  @override
  String toString() {
    return 'RecipeDragData(recipe: ${recipe.title}, category: $sourceCategory, index: $sourceIndex)';
  }
}