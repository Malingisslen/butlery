// lib/views/social/collaborative_shopping_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/collaborative_shopping_viewmodel.dart';
import '../../services/social_shopping_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Collaborative Shopping View - MVVM + AppTheme Compliant
/// File: views/social/collaborative_shopping_view.dart
/// Quick Guide: Real-time collaborative shopping med proper MVVM separation
/// Dependencies IN: CollaborativeShoppingViewModel, AppTheme
/// Dependencies OUT: Collaborative shopping UI med complete MVVM pattern
/// Data flow: View → ViewModel → Service, pure UI rendering
/// State management: ChangeNotifierProvider med ViewModel
/// Purpose: MVVM-compliant collaborative shopping experience
/// Common issues: ✅ LÖST: Proper separation, AppTheme usage, clean architecture
/// Performance: ⚡ Optimized rendering, efficient state management
/// Connected to: CollaborativeShoppingViewModel, SocialShoppingService
/// Used in phases: 18.4

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
      create: (_) => CollaborativeShoppingViewModel(
        socialShoppingService: sl<SocialShoppingService>(),
        userService: sl<UserService>(),
        listId: widget.listId,
      ),
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
          icon: AppTheme.actionIcon(context, Icons.share),
          onPressed: () => _shareList(context, viewModel),
        ),
        PopupMenuButton<String>(
          icon: AppTheme.actionIcon(context, Icons.more_vert),
          onSelected: (value) => _handleMenuAction(context, viewModel, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  AppTheme.actionIcon(context, Icons.settings),
                  AppTheme.smallHorizontalGap,
                  Text('Inställningar'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'members',
              child: Row(
                children: [
                  AppTheme.actionIcon(context, Icons.group),
                  AppTheme.smallHorizontalGap,
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
    if (viewModel.isLoading && !viewModel.hasData) {
      return _buildLoadingState(context);
    }

    if (!viewModel.hasData) {
      return _buildNotFoundState(context);
    }

    if (viewModel.hasError) {
      return _buildErrorState(context, viewModel);
    }

    return _buildListContent(context, viewModel);
  }

  // ===== STATES =====

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppTheme.mediumLoadingIndicator(),
          AppTheme.mediumGap,
          Text('Laddar gemensam lista...', style: AppTheme.subtitleStyle),
        ],
      ),
    );
  }

  Widget _buildNotFoundState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppTheme.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: AppTheme.iconSizeEmptyState,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            AppTheme.mediumGap,
            Text(
              'Lista hittades inte',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            AppTheme.smallGap,
            Text(
              'Listan kanske har tagits bort eller så har du inte tillgång längre',
              style: AppTheme.subtitleStyle,
              textAlign: TextAlign.center,
            ),
            AppTheme.largeGap,
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

  Widget _buildErrorState(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    return Center(
      child: Padding(
        padding: AppTheme.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppTheme.errorContainer(context, viewModel.error!),
            AppTheme.mediumGap,
            ElevatedButton.icon(
              onPressed: () {
                viewModel.clearError();
                viewModel.refresh();
              },
              icon: Icon(Icons.refresh),
              label: Text('Försök igen'),
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
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: AppTheme.dividerHeight,
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
            AppTheme.tinyGap,
            Text(
              viewModel.listDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],

          AppTheme.smallGap,
          _buildProgressSection(context, viewModel),
          AppTheme.smallGap,
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
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        viewModel.statusText,
        style: AppTheme.chipLabelStyle.copyWith(
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
        AppTheme.tinyGap,
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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
        AppTheme.infoIcon(context, icon: Icons.group),
        SizedBox(width: AppTheme.spacingXs),
        Text(
          viewModel.memberCountText,
          style: AppTheme.metadataStyle,
        ),
        AppTheme.smallHorizontalGap,
        AppTheme.infoIcon(context, icon: Icons.access_time),
        SizedBox(width: AppTheme.spacingXs),
        Expanded(
          child: Text(
            viewModel.activitySummary,
            style: AppTheme.metadataStyle,
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
        padding: AppTheme.cardPadding,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: AppTheme.dividerHeight,
            ),
          ),
        ),
        child: Row(
          children: [
            AppTheme.infoIcon(context, icon: Icons.visibility),
            AppTheme.smallHorizontalGap,
            Text(
              'Du kan bara visa denna lista',
              style: AppTheme.subtitleStyle.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: AppTheme.dividerHeight,
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
                        padding: EdgeInsets.all(AppTheme.spacingSm),
                        child: AppTheme.smallLoadingIndicator(),
                      )
                    : null,
              ),
              onSubmitted: (_) => _addItem(viewModel),
              enabled: !viewModel.isAddingItem,
            ),
          ),
          AppTheme.smallHorizontalGap,
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
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
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
    return Center(
      child: Padding(
        padding: AppTheme.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: AppTheme.iconSizeEmptyState,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            AppTheme.mediumGap,
            Text(
              'Inga artiklar än',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            AppTheme.smallGap,
            Text(
              viewModel.canEdit
                  ? 'Lägg till den första artikeln ovan'
                  : 'Väntar på att andra lägger till artiklar',
              style: AppTheme.subtitleStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedSeparator(
      BuildContext context, CollaborativeShoppingViewModel viewModel) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outline),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
            child: Text(
              'KLARA (${viewModel.completedItemsCount})',
              style: AppTheme.captionStyle.copyWith(
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
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      elevation: item.isPurchased ? 0 : AppTheme.elevationLow,
      color: item.isPurchased
          ? Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5)
          : null,
      child: ListTile(
        leading: Checkbox(
          value: item.isPurchased,
          onChanged:
              viewModel.canView ? (_) => _toggleItem(viewModel, item.id) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
        title: Text(
          item.displayText,
          style: TextStyle(
            decoration: item.isPurchased ? TextDecoration.lineThrough : null,
            color: item.isPurchased
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
            fontWeight: item.isPurchased ? FontWeight.normal : FontWeight.w500,
          ),
        ),
        subtitle: _buildItemSubtitle(context, viewModel, item),
        trailing: _buildItemTrailing(context, viewModel, item),
        onTap: viewModel.canView ? () => _toggleItem(viewModel, item.id) : null,
        dense: true,
        contentPadding: AppTheme.listItemPadding,
      ),
    );
  }

  Widget? _buildItemSubtitle(BuildContext context,
      CollaborativeShoppingViewModel viewModel, dynamic item) {
    final subtitle = viewModel.getItemSubtitle(item);
    return subtitle != null
        ? Text(subtitle,
            style: AppTheme.metadataStyle,
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
          backgroundColor: AppTheme.errorColor,
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
          backgroundColor: AppTheme.errorColor,
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
