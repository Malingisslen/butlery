// lib/widgets/common/navigation_components.dart


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../models/recipe.dart';
import '../../viewmodels/recipe_selection_viewmodel.dart';
import '../../viewmodels/recipe_list_viewmodel.dart';
import '../../viewmodels/realtime/participant_tracker.dart';
import '../common/search_filter_widget.dart';
import '../common/state_widget.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';

/// 🎯 UNIFIED NavigationComponents - Alla navigation patterns på ett ställe
class NavigationComponents {
  // =====================================
  // 📱 RECIPE SELECTION DIALOGS
  // =====================================

  /// 🤝 Dialog för att välja recept att dela med en vän
  /// Replaces: RecipeSelectionDialog
  static Future<void> showRecipeSelector(
    BuildContext context, {
    required UserProfile friend,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => _RecipeSelectorDialog(friend: friend),
    );
  }

  /// 📋 Dialog för att välja recept för meny-kategori
  /// Replaces: MenuRecipeSelectionDialog
  static Future<List<Recipe>?> showMenuRecipeSelector(
    BuildContext context, {
    required String categoryName,
  }) async {
    return await showDialog<List<Recipe>>(
      context: context,
      builder: (context) => _MenuRecipeSelectorDialog(
        categoryName: categoryName,
      ),
    );
  }

  // =====================================
  // 🔄 REALTIME INDICATORS
  // =====================================

  /// ✏️ Indikator för vem som redigerar just nu
  /// Replaces: EditIndicator
  static Widget editIndicator({
    required String editorName,
    String? editorId,
    required String editingWhat,
    Color? color,
    bool isVisible = true,
    Duration animationDuration = const Duration(milliseconds: 300),
  }) {
    return _EditIndicatorWidget(
      editorName: editorName,
      editorId: editorId,
      editingWhat: editingWhat,
      color: color,
      isVisible: isVisible,
      animationDuration: animationDuration,
    );
  }

  /// 👥 Lista över aktiva deltagare med management
  /// Replaces: ParticipantList
  static Widget participantList({
    required List<ParticipantActivity> activities,
    required String currentUserId,
    bool canManageParticipants = false,
    Function(String userId)? onRemoveParticipant,
    Function(String userId)? onChangePermission,
  }) {
    return _ParticipantListWidget(
      activities: activities,
      currentUserId: currentUserId,
      canManageParticipants: canManageParticipants,
      onRemoveParticipant: onRemoveParticipant,
      onChangePermission: onChangePermission,
    );
  }

  /// 🌐 Connection status indikator
  /// Replaces: RealtimeStatusIndicator
  static Widget realtimeStatus({
    required bool isOnline,
    required String statusDescription,
    required String statusEmoji,
    bool showText = false,
    EdgeInsets? padding,
  }) {
    return _RealtimeStatusWidget(
      isOnline: isOnline,
      statusDescription: statusDescription,
      statusEmoji: statusEmoji,
      showText: showText,
      padding: padding ?? AppTheme.padding8,
    );
  }

  /// 📢 Expanderat status banner för större visningar
  static Widget realtimeStatusBanner({
    required bool isOnline,
    required String statusDescription,
    required String statusEmoji,
    VoidCallback? onRetry,
  }) {
    return _RealtimeStatusBanner(
      isOnline: isOnline,
      statusDescription: statusDescription,
      statusEmoji: statusEmoji,
      onRetry: onRetry,
    );
  }

  // =====================================
  // 💬 HELPER DIALOGS
  // =====================================

  /// ✅ Standard bekräftelse dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'OK',
    String cancelText = 'Avbryt',
    Color? confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.largeRadius,
            ),
            title: Text(title, style: AppTheme.sectionTitleStyle),
            content: Text(message, style: AppTheme.bodyStyle),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: AppTheme.secondaryButtonStyle,
                child: Text(cancelText, style: AppTheme.buttonTextStyle),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: confirmColor != null
                    ? TextButton.styleFrom(foregroundColor: confirmColor)
                    : AppTheme.primaryButtonStyle,
                child: Text(confirmText, style: AppTheme.buttonTextStyle),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// =====================================
// 🔒 PRIVATE IMPLEMENTATION WIDGETS
// =====================================

/// 🤝 Dialog för receptdelning med vänner
class _RecipeSelectorDialog extends StatelessWidget {
  final UserProfile friend;

  const _RecipeSelectorDialog({required this.friend});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          sl<RecipeSelectionViewModel>(param1: friend)..loadRecipes(),
      child: Consumer<RecipeSelectionViewModel>(
        builder: (context, viewModel, child) {
          return AlertDialog(
            title: Text(
              'Dela recept med ${friend.displayName}',
              style: AppTheme.sectionTitleStyle,
            ),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildRecipeSelectorContent(context, viewModel),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Avbryt', style: AppTheme.buttonTextStyle),
              ),
              if (viewModel.hasSelectedRecipes)
                FilledButton.icon(
                  onPressed: viewModel.isSharing
                      ? null
                      : () => _shareSelectedRecipes(context, viewModel),
                  style: AppTheme.primaryButtonStyle,
                  icon: viewModel.isSharing
                      ? SizedBox(
                          width: AppTheme.iconSizeAction,
                          height: AppTheme.iconSizeAction,
                          child: AppTheme.smallLoadingIndicator(),
                        )
                      : AppTheme.actionIcon(context, Icons.share),
                  label: Text(
                    viewModel.isSharing
                        ? 'Delar...'
                        : 'Dela (${viewModel.selectedCount})',
                    style: AppTheme.buttonTextStyle,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecipeSelectorContent(
      BuildContext context, RecipeSelectionViewModel viewModel) {
    if (viewModel.isLoading) {
      return StateWidget.loading(message: 'Laddar recept...');
    }

    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error!,
        onAction: viewModel.loadRecipes,
      );
    }

    if (!viewModel.hasRecipes) {
      return StateWidget.noRecipes(
        onAction: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/laggTill');
        },
      );
    }

    return Column(
      children: [
        // Sök och filter
        SearchFilterWidget.searchOnly(
          searchQuery: viewModel.searchQuery,
          onSearchChanged: viewModel.updateSearch,
          searchHint: 'Sök recept...',
          padding: EdgeInsets.all(AppTheme.spacingMd),
          showStats: true,
          resultCount: viewModel.hasSearchResults
              ? viewModel.filteredRecipes.length
              : null,
        ),

        // Info och actions
        if (viewModel.searchQuery.isNotEmpty || viewModel.hasSelectedRecipes)
          _buildSelectorInfo(context, viewModel),

        Divider(height: AppTheme.dividerHeight, color: AppTheme.dividerColor),

        // Receptlista
        Expanded(
          child: viewModel.hasSearchResults
              ? ListView.builder(
                  itemCount: viewModel.filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = viewModel.filteredRecipes[index];
                    return _RecipeListItem(
                      recipe: recipe,
                      isSelected: viewModel.isRecipeSelected(recipe.id),
                      isAlreadyShared:
                          viewModel.isRecipeAlreadyShared(recipe.id),
                      onSelectionChanged: (selected) {
                        viewModel.toggleRecipeSelection(recipe.id);
                      },
                    );
                  },
                )
              : StateWidget.noSearchResults(onAction: viewModel.clearSearch),
        ),
      ],
    );
  }

  Widget _buildSelectorInfo(
      BuildContext context, RecipeSelectionViewModel viewModel) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Row(
        children: [
          if (viewModel.searchQuery.isNotEmpty)
            Text(
              '${viewModel.filteredCount} av ${viewModel.totalCount} recept',
              style: AppTheme.captionStyle,
            ),
          if (viewModel.hasSelectedRecipes) ...[
            if (viewModel.searchQuery.isNotEmpty) const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXs,
                vertical: AppTheme.spacingXxs,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.chipRadius,
              ),
              child: Text(
                '${viewModel.selectedCount} valda',
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (viewModel.hasSelectedRecipes)
            TextButton(
              onPressed: viewModel.clearSelections,
              child: Text('Rensa val', style: AppTheme.buttonTextStyle),
            )
          else if (viewModel.searchQuery.isNotEmpty)
            TextButton(
              onPressed: viewModel.clearSearch,
              child: Text('Rensa', style: AppTheme.buttonTextStyle),
            ),
        ],
      ),
    );
  }

  Future<void> _shareSelectedRecipes(
      BuildContext context, RecipeSelectionViewModel viewModel) async {
    final shareMessage = viewModel.getShareMessage();
    final success = await viewModel.shareSelectedRecipes();

    if (success && context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shareMessage,
            style: AppTheme.bodyStyle.copyWith(color: AppTheme.neutralLight),
          ),
          backgroundColor: AppTheme.successColor,
          duration: AppTheme.wait3s,
        ),
      );
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.error ?? 'Kunde inte dela recept',
            style: AppTheme.bodyStyle.copyWith(color: AppTheme.neutralLight),
          ),
          backgroundColor: AppTheme.errorColor,
          duration: AppTheme.wait3s,
        ),
      );
    }
  }
}

/// 📋 Dialog för meny-kategori receptval
class _MenuRecipeSelectorDialog extends StatefulWidget {
  final String categoryName;

  const _MenuRecipeSelectorDialog({required this.categoryName});

  @override
  State<_MenuRecipeSelectorDialog> createState() =>
      _MenuRecipeSelectorDialogState();
}

class _MenuRecipeSelectorDialogState extends State<_MenuRecipeSelectorDialog> {
  final Set<String> _selectedRecipeIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<RecipeListViewModel>(),
      child: Consumer<RecipeListViewModel>(
        builder: (context, viewModel, child) {
          return AlertDialog(
            title: Text('Lägg till recept i ${widget.categoryName}'),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildMenuSelectorContent(context, viewModel),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Avbryt'),
              ),
              if (_selectedRecipeIds.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => _addSelectedRecipes(context, viewModel),
                  style: AppTheme.primaryButtonStyle,
                  icon: const Icon(Icons.add),
                  label: Text('Lägg till (${_selectedRecipeIds.length})'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuSelectorContent(
      BuildContext context, RecipeListViewModel viewModel) {
    if (viewModel.isLoading) {
      return StateWidget.loading(message: 'Laddar recept...');
    }

    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error!,
        onAction: viewModel.refresh,
      );
    }

    if (viewModel.recipes.isEmpty) {
      return StateWidget.noRecipes(
        onAction: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/laggTill');
        },
      );
    }

    final filteredRecipes = _searchQuery.isEmpty
        ? viewModel.recipes
        : viewModel.recipes.where((recipe) {
            return recipe.title
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                recipe.mealType
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                recipe.description
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());
          }).toList();

    return Column(
      children: [
        SearchFilterWidget.searchOnly(
          searchQuery: _searchQuery,
          onSearchChanged: (query) {
            setState(() {
              _searchQuery = query;
            });
          },
          searchHint: 'Sök recept att lägga till...',
          autofocus: true,
          padding: EdgeInsets.all(AppTheme.spacingMd),
          showStats: true,
          resultCount: filteredRecipes.length,
        ),
        if (_selectedRecipeIds.isNotEmpty) _buildMenuSelectorInfo(),
        const Divider(height: 1),
        Expanded(
          child: filteredRecipes.isEmpty && _searchQuery.isNotEmpty
              ? StateWidget.noSearchResults(
                  onAction: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : ListView.builder(
                  itemCount: filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = filteredRecipes[index];
                    final isSelected = _selectedRecipeIds.contains(recipe.id);

                    return _MenuRecipeListItem(
                      recipe: recipe,
                      isSelected: isSelected,
                      onSelectionChanged: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedRecipeIds.add(recipe.id);
                          } else {
                            _selectedRecipeIds.remove(recipe.id);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMenuSelectorInfo() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingXs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.chipRadius,
            ),
            child: Text(
              '${_selectedRecipeIds.length} valda',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedRecipeIds.clear();
              });
            },
            child: const Text('Rensa val'),
          ),
        ],
      ),
    );
  }

  void _addSelectedRecipes(
      BuildContext context, RecipeListViewModel viewModel) {
    final selectedRecipes = viewModel.recipes
        .where((recipe) => _selectedRecipeIds.contains(recipe.id))
        .toList();

    Navigator.pop(context, selectedRecipes);
  }
}

/// 🍽️ Recipe list item för friend sharing
class _RecipeListItem extends StatelessWidget {
  final Recipe recipe;
  final bool isSelected;
  final bool isAlreadyShared;
  final ValueChanged<bool> onSelectionChanged;

  const _RecipeListItem({
    required this.recipe,
    required this.isSelected,
    required this.isAlreadyShared,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: AppTheme.listItemPadding,
      leading: ClipRRect(
        borderRadius: AppTheme.mediumRadius,
        child: recipe.imageUrls.isNotEmpty
            ? Image.network(
                recipe.imageUrls.first,
                width: AppTheme.iconSizeDisplay,
                height: AppTheme.iconSizeDisplay,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              recipe.title,
              style: isAlreadyShared
                  ? AppTheme.cardTitleStyle
                      .copyWith(color: AppTheme.sharedRecipeTextColor)
                  : AppTheme.cardTitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isAlreadyShared)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXs,
                vertical: AppTheme.spacingXxs,
              ),
              decoration: AppTheme.sharedChipDecoration,
              child: Text('Delad', style: AppTheme.sharedChipTextStyle),
            ),
        ],
      ),
      subtitle: _buildRecipeSubtitle(),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) => onSelectionChanged(value ?? false),
        activeColor: isAlreadyShared
            ? AppTheme.sharedRecipeTextColor
            : AppTheme.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.chipRadius),
      ),
      onTap: () => onSelectionChanged(!isSelected),
    );
  }

  Widget _buildRecipeSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.mealType,
          style: isAlreadyShared
              ? AppTheme.captionStyle.copyWith(
                  color: AppTheme.sharedRecipeTextColor,
                  fontWeight: FontWeight.w600,
                )
              : AppTheme.captionStyle.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
        ),
        if (recipe.description.isNotEmpty)
          Text(
            recipe.description,
            style: isAlreadyShared
                ? AppTheme.captionStyle
                    .copyWith(color: AppTheme.sharedRecipeTextColor)
                : AppTheme.captionStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        AppTheme.tinyGap,
        Row(
          children: [
            if (recipe.timeMinutes != null) ...[
              Icon(
                Icons.access_time,
                size: AppTheme.iconSizeInfo,
                color: isAlreadyShared
                    ? AppTheme.sharedRecipeIconColor
                    : AppTheme.textSecondary,
              ),
              AppTheme.tinyGap,
              Text(
                '${recipe.timeMinutes} min',
                style: isAlreadyShared
                    ? AppTheme.captionStyle.copyWith(
                        color: AppTheme.sharedRecipeIconColor,
                        fontSize: AppTheme.microText.fontSize,
                      )
                    : AppTheme.captionStyle.copyWith(fontSize: AppTheme.microText.fontSize),
              ),
            ],
            if (recipe.portions != null) ...[
              if (recipe.timeMinutes != null) ...[
                AppTheme.smallGap,
                Text('•', style: AppTheme.captionStyle),
                AppTheme.smallGap,
              ],
              Icon(
                Icons.people,
                size: AppTheme.iconSizeInfo,
                color: isAlreadyShared
                    ? AppTheme.sharedRecipeIconColor
                    : AppTheme.textSecondary,
              ),
              AppTheme.tinyGap,
              Text(
                '${recipe.portions} port',
                style: isAlreadyShared
                    ? AppTheme.captionStyle.copyWith(
                        color: AppTheme.sharedRecipeIconColor,
                        fontSize: AppTheme.microText.fontSize,
                      )
                    : AppTheme.captionStyle.copyWith(fontSize: AppTheme.microText.fontSize),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: AppTheme.iconSizeDisplay,
      height: AppTheme.iconSizeDisplay,
      decoration: BoxDecoration(
        color: isAlreadyShared
            ? AppTheme.sharedRecipeBackgroundColor
            : AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Icon(
        Icons.restaurant_menu,
        color: isAlreadyShared
            ? AppTheme.sharedRecipeIconColor
            : AppTheme.primaryColor,
        size: AppTheme.iconSizeAction,
      ),
    );
  }
}

/// 🍽️ Recipe list item för menu kategori
class _MenuRecipeListItem extends StatelessWidget {
  final Recipe recipe;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;

  const _MenuRecipeListItem({
    required this.recipe,
    required this.isSelected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: AppTheme.listItemPadding,
      leading: ClipRRect(
        borderRadius: AppTheme.mediumRadius,
        child: recipe.imageUrls.isNotEmpty
            ? Image.network(
                recipe.imageUrls.first,
                width: AppTheme.iconSizeDisplay,
                height: AppTheme.iconSizeDisplay,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
      title: Text(
        recipe.title,
        style: AppTheme.cardTitleStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _buildMenuRecipeSubtitle(),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) => onSelectionChanged(value ?? false),
        activeColor: AppTheme.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.chipRadius),
      ),
      onTap: () => onSelectionChanged(!isSelected),
    );
  }

  Widget _buildMenuRecipeSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.mealType,
          style: AppTheme.captionStyle.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (recipe.description.isNotEmpty) ...[
          AppTheme.tinyGap,
          Text(
            recipe.description,
            style: AppTheme.captionStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        AppTheme.tinyGap,
        Row(
          children: [
            if (recipe.timeMinutes != null) ...[
              Icon(
                Icons.access_time,
                size: AppTheme.iconSizeInfo,
                color: AppTheme.textSecondary,
              ),
              SizedBox(width: AppTheme.spacingXxs),
              Text(
                '${recipe.timeMinutes} min',
                style: AppTheme.captionStyle.copyWith(fontSize: AppTheme.microText.fontSize),
              ),
            ],
            if (recipe.portions != null) ...[
              if (recipe.timeMinutes != null) ...[
                SizedBox(width: AppTheme.spacingSm),
                Text('•', style: AppTheme.captionStyle),
                SizedBox(width: AppTheme.spacingSm),
              ],
              Icon(
                Icons.people,
                size: AppTheme.iconSizeInfo,
                color: AppTheme.textSecondary,
              ),
              SizedBox(width: AppTheme.spacingXxs),
              Text(
                '${recipe.portions} port',
                style: AppTheme.captionStyle.copyWith(fontSize: AppTheme.microText.fontSize),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: AppTheme.iconSizeDisplay,
      height: AppTheme.iconSizeDisplay,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Icon(
        Icons.restaurant_menu,
        color: AppTheme.primaryColor,
        size: AppTheme.iconSizeAction,
      ),
    );
  }
}

/// ✏️ Edit indicator widget
class _EditIndicatorWidget extends StatefulWidget {
  final String editorName;
  final String? editorId;
  final String editingWhat;
  final Color? color;
  final bool isVisible;
  final Duration animationDuration;

  const _EditIndicatorWidget({
    required this.editorName,
    this.editorId,
    required this.editingWhat,
    this.color,
    this.isVisible = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<_EditIndicatorWidget> createState() => _EditIndicatorWidgetState();
}

class _EditIndicatorWidgetState extends State<_EditIndicatorWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: AppTheme.wait2s,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isVisible) {
      _fadeController.forward();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_EditIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _fadeController.forward();
        _pulseController.repeat(reverse: true);
      } else {
        _fadeController.reverse();
        _pulseController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTheme.primaryColor;

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.editorName} redigerar ${widget.editingWhat}',
                  style: TextStyle(
                    fontSize: AppTheme.smallText.fontSize,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

/// 👥 Participant list widget
class _ParticipantListWidget extends StatelessWidget {
  final List<ParticipantActivity> activities;
  final String currentUserId;
  final bool canManageParticipants;
  final Function(String userId)? onRemoveParticipant;
  final Function(String userId)? onChangePermission;

  const _ParticipantListWidget({
    required this.activities,
    required this.currentUserId,
    this.canManageParticipants = false,
    this.onRemoveParticipant,
    this.onChangePermission,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: AppTheme.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppTheme.actionIcon(
                  context,
                  Icons.people,
                  color: AppTheme.primaryColor,
                ),
                AppTheme.smallHorizontalGap,
                Text(
                  'Deltagare (${activities.length})',
                  style: AppTheme.sectionTitleStyle,
                ),
                const Spacer(),
                _buildOnlineIndicator(),
              ],
            ),
            AppTheme.mediumGap,
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: activities.map((activity) {
                return _buildParticipantChip(context, activity);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineIndicator() {
    final onlineCount = activities.where((a) => a.isOnline).length;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppTheme.spacingSm,
            height: AppTheme.spacingSm,
            decoration: BoxDecoration(
              color: AppTheme.successColor,
              borderRadius: BorderRadius.circular(AppTheme.spacingXs),
            ),
          ),
          AppTheme.tinyGap,
          Text(
            '$onlineCount online',
            style: AppTheme.successTextStyle.copyWith(fontSize: AppTheme.smallText.fontSize),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantChip(
      BuildContext context, ParticipantActivity activity) {
    final isCurrentUser = activity.userId == currentUserId;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.iconSizeAction),
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : AppTheme.dividerColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              _buildSimpleAvatar(activity.displayName, 24),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: AppTheme.spacingSm,
                  height: AppTheme.spacingSm,
                  decoration: BoxDecoration(
                    color: activity.isOnline
                        ? AppTheme.successColor
                        : AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(AppTheme.spacingXs),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          AppTheme.smallHorizontalGap,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCurrentUser ? 'Du' : activity.displayName,
                style: isCurrentUser
                    ? AppTheme.bodyStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      )
                    : AppTheme.bodyStyle,
              ),
              Text(
                activity.isOnline ? 'Online' : 'Offline',
                style: AppTheme.captionStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleAvatar(String displayName, double size) {
    final initials = _getInitials(displayName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTheme.bodyStyle.copyWith(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      final word = words[0];
      return word.length >= 2
          ? '${word[0]}${word[1]}'.toUpperCase()
          : word[0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }
}

/// 🌐 Realtime status widget
class _RealtimeStatusWidget extends StatelessWidget {
  final bool isOnline;
  final String statusDescription;
  final String statusEmoji;
  final bool showText;
  final EdgeInsets? padding;

  const _RealtimeStatusWidget({
    required this.isOnline,
    required this.statusDescription,
    required this.statusEmoji,
    this.showText = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: statusDescription,
      child: Container(
        padding: padding ?? AppTheme.padding8,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                statusEmoji,
                key: ValueKey(statusEmoji),
                style: TextStyle(fontSize: AppTheme.bodyStyle.fontSize),
              ),
            ),
            if (showText) ...[
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  statusDescription,
                  key: ValueKey(statusDescription),
                  style: TextStyle(
                    fontSize: AppTheme.smallText.fontSize,
                    color: isOnline
                        ? Theme.of(context).colorScheme.onSurface
                        : AppTheme.errorColor,
                    fontWeight: isOnline ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 📢 Realtime status banner
class _RealtimeStatusBanner extends StatelessWidget {
  final bool isOnline;
  final String statusDescription;
  final String statusEmoji;
  final VoidCallback? onRetry;

  const _RealtimeStatusBanner({
    required this.isOnline,
    required this.statusDescription,
    required this.statusEmoji,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: AppTheme.errorColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Text(statusEmoji, style: TextStyle(fontSize: AppTheme.iconSizeInfo.toDouble())),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                  ),
                ),
                Text(statusDescription, style: TextStyle(fontSize: AppTheme.bodyStyle.fontSize)),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Försök igen'),
            ),
        ],
      ),
    );
  }
}
