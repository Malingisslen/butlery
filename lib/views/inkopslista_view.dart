// lib/views/inkopslista_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../viewmodels/shopping_list_viewmodel.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/empty_state.dart';
import '../widgets/action_button.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';

/// ✨ UPPDATERAD VY MED SHOPPINGLISTVIEWMODEL
class InkopslistaView extends StatelessWidget {
  const InkopslistaView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final viewModel = sl<ShoppingListViewModel>();

        // Hämta meny från navigation arguments
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final menu =
              (args is Map<String, List<Recipe>>)
                  ? args
                  : <String, List<Recipe>>{};
          viewModel.generateFromMenu(menu);
        });

        return viewModel;
      },
      child: const _InkopslistaViewContent(),
    );
  }
}

class _InkopslistaViewContent extends StatelessWidget {
  const _InkopslistaViewContent();

  void _shareShoppingList(BuildContext context) async {
    final viewModel = context.read<ShoppingListViewModel>();
    await viewModel.shareShoppingList();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inköpslista kopierad till urklipp'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ShoppingListViewModel>();

    return MainLayoutMenu(
      currentIndex: 3,
      title: 'Inköpslista',
      actions: [
        if (viewModel.hasItems) ...[
          if (viewModel.checkedCount > 0)
            IconButton(
              icon: AppTheme.actionIcon(context, Icons.clear_all),
              onPressed: viewModel.clearCheckedItems,
              tooltip: 'Rensa alla checkade',
            ),
          IconButton(
            icon: AppTheme.actionIcon(context, Icons.share),
            onPressed: () => _shareShoppingList(context),
            tooltip: 'Dela inköpslista',
          ),
        ],
      ],
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, ShoppingListViewModel viewModel) {
    if (viewModel.isLoading) {
      return Center(child: AppTheme.mediumLoadingIndicator());
    }

    if (viewModel.hasError) {
      return Center(
        child: Padding(
          padding: AppTheme.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppTheme.errorContainer(context, viewModel.error!),
              AppTheme.mediumGap,
              ElevatedButton(
                onPressed: viewModel.clearError,
                child: const Text('Försök igen'),
              ),
            ],
          ),
        ),
      );
    }

    if (!viewModel.hasItems) {
      return EmptyState.noShoppingList(
        onAction: () => Navigator.pushReplacementNamed(context, '/veckomeny'),
      );
    }

    return Column(
      children: [
        // Header med statistik
        _buildHeader(context, viewModel),

        // Lista med ingredienser
        Expanded(
          child: RefreshIndicator(
            onRefresh: viewModel.refresh,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
              itemCount: viewModel.formattedItems.length,
              itemBuilder: (context, index) {
                return _buildShoppingItem(context, viewModel, index);
              },
            ),
          ),
        ),

        // Bottom action bar
        _buildActionBar(context, viewModel),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ShoppingListViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inköpslista',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: AppTheme.spacingXs),
          Text(
            '${viewModel.totalCount} artiklar${viewModel.checkedCount > 0 ? ' • ${viewModel.checkedCount} checkade' : ''}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          // Success indikator
          if (viewModel.allItemsChecked)
            Padding(
              padding: EdgeInsets.only(top: AppTheme.spacingSm),
              child: Row(
                children: [
                  AppTheme.successIcon(context),
                  SizedBox(width: AppTheme.spacingXs),
                  Text(
                    'Alla artiklar checkade!',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShoppingItem(
    BuildContext context,
    ShoppingListViewModel viewModel,
    int index,
  ) {
    final item = viewModel.formattedItems[index];
    final isChecked = viewModel.checkedItems[index] ?? false;

    return Card(
      key: ValueKey('shopping_item_$index'),
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXxs,
      ),
      elevation: 0,
      color:
          isChecked
              ? Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : null,
      child: ListTile(
        leading: Checkbox(
          value: isChecked,
          onChanged: (_) => viewModel.toggleItem(index),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(
          item,
          style: TextStyle(
            decoration: isChecked ? TextDecoration.lineThrough : null,
            color:
                isChecked
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
          ),
        ),
        onTap: () => viewModel.toggleItem(index),
        dense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingXs,
        ),
      ),
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    ShoppingListViewModel viewModel,
  ) {
    if (!viewModel.hasItems) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ActionButton.outlined(
              label: 'Uppdatera',
              icon: Icons.refresh,
              onPressed: viewModel.isLoading ? null : viewModel.refresh,
              isLoading: viewModel.isLoading,
            ),
          ),
          SizedBox(width: AppTheme.spacingSm + 4),
          Expanded(
            child: ActionButton.primary(
              label: 'Dela lista',
              icon: Icons.share,
              onPressed: () => _shareShoppingList(context),
            ),
          ),
        ],
      ),
    );
  }
}
