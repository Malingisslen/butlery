// lib/views/inkopslista_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // För SystemNavigator
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../viewmodels/shopping_list_viewmodel.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/empty_state.dart';
import '../widgets/action_button.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';

/// ✨ UPPDATERAD VY MED PERSISTENCE INTEGRATION
class InkopslistaView extends StatelessWidget {
  const InkopslistaView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<ShoppingListViewModel>(),
      child: const _InkopslistaViewContent(),
    );
  }
}

class _InkopslistaViewContent extends StatefulWidget {
  const _InkopslistaViewContent();

  @override
  State<_InkopslistaViewContent> createState() =>
      _InkopslistaViewContentState();
}

class _InkopslistaViewContentState extends State<_InkopslistaViewContent> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<ShoppingListViewModel>();

      // ✨ UPPDATERAT: Auto-load sparad state först
      viewModel.initializeWithAutoLoad();

      // Hämta meny från navigation arguments och generera om den skickades
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, List<Recipe>> && args.isNotEmpty) {
        // Ny meny skickad - generera från den
        viewModel.generateFromMenu(args);
      }
      // Om inga args finns använder vi den sparade staten från initializeWithAutoLoad()
    });
  }

  void _shareShoppingList(BuildContext context) async {
    final viewModel = context.read<ShoppingListViewModel>();
    await viewModel.shareShoppingList();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inköpslista delad!'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Visa clear all dialog
  Future<void> _showClearCheckedDialog(BuildContext context) async {
    final viewModel = context.read<ShoppingListViewModel>();

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rensa checkade artiklar?'),
        content: Text(
          'Vill du rensa alla ${viewModel.checkedCount} checkade artiklar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
            ),
            child: const Text('Rensa alla'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      viewModel.clearCheckedItems();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${viewModel.checkedCount} artiklar rensade'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  // ✨ NY METOD: Visa clear all shopping list dialog
  Future<void> _showClearAllShoppingListDialog(BuildContext context) async {
    final viewModel = context.read<ShoppingListViewModel>();

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rensa hela listan?'),
        content: Text(
          'Vill du rensa hela inköpslistan med ${viewModel.totalCount} artiklar?\n\n'
          'Detta kommer att ta bort både artiklar och sparad data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Rensa allt'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      await viewModel.clearSavedShoppingListState();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hela inköpslistan rensad'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  // Exit-dialog
  Future<void> _showExitDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avsluta Butlery?'),
        content: const Text('Vill du verkligen avsluta appen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Avsluta'),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ShoppingListViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _showExitDialog(context);
        }
      },
      child: MainLayoutMenu(
        currentIndex: 3,
        title: 'Inköpslista',
        actions: [
          if (viewModel.hasItems) ...[
            // Clear checked items
            if (viewModel.checkedCount > 0)
              IconButton(
                icon: AppTheme.actionIcon(context, Icons.clear_all),
                onPressed: () => _showClearCheckedDialog(context),
                tooltip: 'Rensa checkade (${viewModel.checkedCount})',
              ),

            // Share button
            IconButton(
              icon: AppTheme.actionIcon(context, Icons.share),
              onPressed: () => _shareShoppingList(context),
              tooltip: 'Dela inköpslista',
            ),

            // ✨ NYTT: Clear all button
            PopupMenuButton<String>(
              icon: AppTheme.actionIcon(context, Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'clear_all':
                    _showClearAllShoppingListDialog(context);
                    break;
                  case 'export':
                    _exportShoppingList(context, viewModel);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      const Icon(Icons.download),
                      SizedBox(width: AppTheme.spacingSm),
                      const Text('Exportera som text'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: AppTheme.errorColor),
                      SizedBox(width: AppTheme.spacingSm),
                      Text(
                        'Rensa allt',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
        body: _buildBody(context, viewModel),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ShoppingListViewModel viewModel) {
    if (viewModel.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppTheme.mediumLoadingIndicator(),
            AppTheme.mediumGap,
            Text(
              'Laddar inköpslista...',
              style: AppTheme.subtitleStyle,
            ),
          ],
        ),
      );
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
              ElevatedButton.icon(
                onPressed: viewModel.clearError,
                icon: const Icon(Icons.refresh),
                label: const Text('Försök igen'),
              ),
            ],
          ),
        ),
      );
    }

    if (!viewModel.hasItems) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Ingen inköpslista',
        subtitle: 'Skapa en veckomeny för att generera en inköpslista\n\n'
            '💡 Tips: Din senaste inköpslista sparas automatiskt!',
        actionLabel: 'Skapa veckomeny',
        onAction: () => Navigator.pushReplacementNamed(context, '/veckomeny'),
      );
    }

    return Column(
      children: [
        // ✨ UPPDATERAD: Header med persistence info
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Inköpslista',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              // ✨ NYTT: Persistence indicator
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.successColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.save,
                      size: 12,
                      color: AppTheme.successColor,
                    ),
                    SizedBox(width: AppTheme.spacingXs),
                    Text(
                      'AUTO-SPARAD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingXs),
          Text(
            '${viewModel.totalCount} artiklar${viewModel.checkedCount > 0 ? ' • ${viewModel.checkedCount} checkade' : ''}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),

          // Success indikator
          if (viewModel.allItemsChecked) ...[
            SizedBox(height: AppTheme.spacingSm),
            Container(
              padding: EdgeInsets.all(AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.smallRadius,
                border: Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: AppTheme.iconSizeInfo,
                  ),
                  SizedBox(width: AppTheme.spacingXs),
                  Expanded(
                    child: Text(
                      'Alla artiklar checkade! 🎉',
                      style: TextStyle(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      color: isChecked
          ? Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5)
          : null,
      child: ListTile(
        leading: Checkbox(
          value: isChecked,
          onChanged: (_) => viewModel.toggleItem(index),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(
          item,
          style: TextStyle(
            decoration: isChecked ? TextDecoration.lineThrough : null,
            color: isChecked
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
            fontWeight: isChecked ? FontWeight.normal : FontWeight.w500,
          ),
        ),
        onTap: () => viewModel.toggleItem(index),
        dense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingXs,
        ),
        // ✨ NYTT: Visual feedback för checked items
        trailing: isChecked
            ? Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
                size: AppTheme.iconSizeInfo,
              )
            : null,
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
          // ✨ UPPDATERAD: Update button med persistence feedback
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

  /// ✨ NYTT: Export shopping list som text
  void _exportShoppingList(
      BuildContext context, ShoppingListViewModel viewModel) {
    final textData = viewModel.exportAsText();

    Clipboard.setData(ClipboardData(text: textData));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Inköpslista kopierad till urklipp! (${viewModel.totalCount} artiklar)'),
        backgroundColor: AppTheme.successColor,
        action: SnackBarAction(
          label: 'Visa',
          textColor: Colors.white,
          onPressed: () => _showExportPreview(context, textData),
        ),
      ),
    );
  }

  /// ✨ NYTT: Visa export preview
  void _showExportPreview(BuildContext context, String textData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exporterad inköpslista'),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Text(
              textData,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stäng'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: textData));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kopierat till urklipp igen!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Kopiera igen'),
          ),
        ],
      ),
    );
  }
}
