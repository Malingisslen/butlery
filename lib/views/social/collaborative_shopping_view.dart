// lib/views/social/collaborative_shopping_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/collaborative_shopping_viewmodel.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_dimensions.dart';
import '../../core/injection.dart';
import '../../widgets/common/state_widget.dart';
import '../../widgets/common/loading_state_builder.dart';


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

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<CollaborativeShoppingViewModel>(param1: widget.listId),
      child: Consumer<CollaborativeShoppingViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: _buildAppBar(context, viewModel),
            body: _buildBody(context, viewModel),
          );
        },
      ),
    );
  }

  // ===== APP BAR =====

  PreferredSizeWidget _buildAppBar(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    return AppBar(
      title: Text(viewModel.listTitle),
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () => _shareList(context, viewModel),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleMenuAction(context, viewModel, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  const Icon(Icons.settings),
                  const SizedBox(width: AppDimensions.spacingM),
                  Text('Inställningar'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'members',
              child: Row(
                children: [
                  const Icon(Icons.group),
                  const SizedBox(width: AppDimensions.spacingM),
                  Text('Hantera medlemmar'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===== BODY =====

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

  // ===== STATES =====

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
              'Lista hittades inte',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              'Listan kanske har tagits bort eller så har du inte tillgång längre',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back),
              label: Text('Tillbaka'),
            ),
          ],
        ),
      ),
    );
  }


  // ===== CONTENT =====

  Widget _buildListContent(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    return Column(
      children: [
        _buildListHeader(context, viewModel),
        _buildAddItemSection(context, viewModel),
        Expanded(child: _buildItemsList(context, viewModel)),
      ],
    );
  }

  Widget _buildListHeader(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: AppDimensions.borderWidthThin,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and status
          Row(
            children: [
              Expanded(
                child: Text(
                  viewModel.listTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              _buildStatusBadge(context, viewModel),
            ],
          ),

          // Description
          if (viewModel.hasDescription) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              viewModel.listDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: AppDimensions.spacingM),
          _buildProgressSection(context, viewModel),
          const SizedBox(height: AppDimensions.spacingM),
          _buildMetadata(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    final color = viewModel.getStatusColor();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        viewModel.statusText,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProgressSection(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    final progress = viewModel.completionPercentage / 100;
    final progressColor = viewModel.getProgressColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${viewModel.completedItems} av ${viewModel.totalItems} klara',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              '${viewModel.completionPercentage.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMetadata(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    return Row(
      children: [
        Icon(Icons.group, color: AppColors.textMedium, size: AppDimensions.iconSizeM),
        SizedBox(width: AppDimensions.spacingXs),
        Text(
          viewModel.memberCountText,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
        ),
        const SizedBox(width: AppDimensions.spacingM),
        Icon(Icons.access_time, color: AppColors.textMedium, size: AppDimensions.iconSizeM),
        SizedBox(width: AppDimensions.spacingXs),
        Expanded(
          child: Text(
            viewModel.activitySummary,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAddItemSection(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    if (!viewModel.canEdit) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: AppDimensions.borderWidthThin,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.visibility, color: AppColors.textMedium, size: AppDimensions.iconSizeM),
            const SizedBox(width: AppDimensions.spacingM),
            Text(
              'Du kan bara visa denna lista',
              style: AppTextStyles.titleMedium.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: AppDimensions.borderWidthThin,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _newItemController,
              decoration: InputDecoration(
                hintText: 'Lägg till artikel...',
                suffixIcon: viewModel.isAddingItem
                    ? Padding(
                        padding: EdgeInsets.all(AppDimensions.spacingS),
                        child: SizedBox(
                          width: AppDimensions.iconSizeS,
                          height: AppDimensions.iconSizeS,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onSubmitted: (_) => _addItem(viewModel),
              enabled: !viewModel.isAddingItem,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingM),
          FilledButton.icon(
            onPressed:
                viewModel.isAddingItem ? null : () => _addItem(viewModel),
            icon: Icon(Icons.add),
            label: Text('Lägg till'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    if (viewModel.totalItems == 0) {
      return _buildEmptyItemsState(context, viewModel);
    }

    final activeItems = viewModel.activeItems;
    final completedItems = viewModel.completedItemsList;

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      itemCount: activeItems.length +
          (completedItems.isNotEmpty ? completedItems.length + 1 : 0),
      itemBuilder: (context, index) {
        if (index < activeItems.length) {
          return _buildItemCard(context, viewModel, activeItems[index]);
        } else if (index == activeItems.length && completedItems.isNotEmpty) {
          return _buildCompletedSeparator(context, viewModel);
        } else {
          final completedIndex = index - activeItems.length - 1;
          return _buildItemCard(
              context, viewModel, completedItems[completedIndex]);
        }
      },
    );
  }

  Widget _buildEmptyItemsState(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    return StateWidget.empty(
      title: 'Inga artiklar än',
      subtitle: viewModel.canEdit
          ? 'Lägg till den första artikeln ovan'
          : 'Väntar på att andra lägger till artiklar',
      icon: Icons.shopping_cart_outlined,
    );
  }

  Widget _buildCompletedSeparator(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingS,
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outline),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingS),
            child: Text(
              'KLARA (${viewModel.completedItemsCount})',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context,
      CollaborativeShoppingViewModel viewModel, dynamic item) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      elevation: item.bought ? 0 : AppDimensions.elevationLow,
      color: item.bought
          ? Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5)
          : null,
      child: ListTile(
        leading: Checkbox(
          value: item.bought,
          onChanged:
              viewModel.canView ? (_) => _toggleItem(viewModel, item.id) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
        ),
        title: Text(
          item.displayText,
          style: TextStyle(
            decoration: item.bought ? TextDecoration.lineThrough : null,
            color: item.bought
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
            fontWeight: item.bought ? FontWeight.normal : FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _buildItemSubtitle(context, viewModel, item),
        trailing: _buildItemTrailing(context, viewModel, item),
        onTap: viewModel.canView ? () => _toggleItem(viewModel, item.id) : null,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
      ),
    );
  }

  Widget? _buildItemSubtitle(BuildContext context,
      CollaborativeShoppingViewModel viewModel, dynamic item) {
    final subtitle = viewModel.getItemSubtitle(item);
    return subtitle != null
        ? Text(subtitle,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
            maxLines: 2,
            overflow: TextOverflow.ellipsis)
        : null;
  }

  Widget? _buildItemTrailing(BuildContext context,
      CollaborativeShoppingViewModel viewModel, dynamic item) {
    final widgets = viewModel.getItemTrailingWidgets(item);
    return widgets.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }

  // ===== ACTIONS =====

  Future<void> _addItem(CollaborativeShoppingViewModel viewModel) async {
    final itemName = _newItemController.text.trim();
    if (itemName.isEmpty) return;

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

  Future<void> _toggleItem(
      CollaborativeShoppingViewModel viewModel, String itemId) async {
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

  void _shareList(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Delningsfunktion kommer snart')),
    );
  }

  void _handleMenuAction(BuildContext context,
      CollaborativeShoppingViewModel viewModel, String action) {
    switch (action) {
      case 'settings':
        _showSettings(context, viewModel);
        break;
      case 'members':
        _showMembers(context, viewModel);
        break;
    }
  }

  void _showSettings(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Inställningar kommer snart')),
    );
  }

  void _showMembers(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Medlemshantering kommer snart')),
    );
  }
}
