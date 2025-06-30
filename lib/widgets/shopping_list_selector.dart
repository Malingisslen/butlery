// lib/widgets/shopping_list_selector.dart

/// 🛒 UNIFIED SHOPPING LIST SELECTOR - MENU INTEGRATION
/// Ersätter gamla selector med UnifiedShoppingService integration
/// Hanterar menu -> shopping list conversion med ingredienser

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/unified_shopping_viewmodel.dart';
import '../models/unified/unified_shopping_list.dart';
import '../models/unified/unified_shopping_item.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../core/utils/logger.dart';

class ShoppingListSelector extends StatefulWidget {
  final VoidCallback? onListSelected;
  final Map<String, List<Recipe>>? menu; // ✅ NY: Mottag meny data

  const ShoppingListSelector({
    super.key,
    this.onListSelected,
    this.menu, // ✅ NY: Menu parameter
  });

  @override
  State<ShoppingListSelector> createState() => _ShoppingListSelectorState();
}

class _ShoppingListSelectorState extends State<ShoppingListSelector> {
  late UnifiedShoppingViewModel _viewModel;
  String? _selectedListId;
  bool _isAddingToList = false; // ✅ NY: Loading state för tillägg

  @override
  void initState() {
    super.initState();
    _viewModel = UnifiedShoppingViewModel();
    _selectedListId = _viewModel.activeList?.id;
  }

  // ✅ NY: Konvertera meny till shopping items
  List<UnifiedShoppingItem> _convertMenuToShoppingItems() {
    if (widget.menu == null || widget.menu!.isEmpty) return [];

    final items = <UnifiedShoppingItem>[];
    final seenIngredients = <String>{};

    for (final entry in widget.menu!.entries) {
      for (final recipe in entry.value) {
        for (final ingredient in recipe.ingredients) {
          // Undvik duplicat ingredienser
          final normalizedIngredient = ingredient.toLowerCase().trim();
          if (!seenIngredients.contains(normalizedIngredient)) {
            seenIngredients.add(normalizedIngredient);

            // Skapa shopping item från ingrediens
            items.add(UnifiedShoppingItem.basic(
              name: ingredient.trim(),
              amount: 1.0, // Default amount
              unit: '', // Vi parsar inte enheter från ingrediens-strängar ännu
              category: _categorizeIngredient(ingredient),
            ));
          }
        }
      }
    }

    AppLogger.info('Konverterade ${items.length} unika ingredienser från meny');
    return items;
  }

  // ✅ NY: Enkel kategorisering av ingredienser
  String _categorizeIngredient(String ingredient) {
    final lowerIngredient = ingredient.toLowerCase();

    // Frukt & Grönt
    if (lowerIngredient.contains('tomat') ||
        lowerIngredient.contains('lök') ||
        lowerIngredient.contains('äpple') ||
        lowerIngredient.contains('banan') ||
        lowerIngredient.contains('morot') ||
        lowerIngredient.contains('gurka') ||
        lowerIngredient.contains('sallad') ||
        lowerIngredient.contains('potatis')) {
      return 'Frukt & Grönt';
    }

    // Mejeri
    if (lowerIngredient.contains('mjölk') ||
        lowerIngredient.contains('ost') ||
        lowerIngredient.contains('yoghurt') ||
        lowerIngredient.contains('smör') ||
        lowerIngredient.contains('grädde') ||
        lowerIngredient.contains('ägg')) {
      return 'Mejeri';
    }

    // Kött & Fisk
    if (lowerIngredient.contains('kött') ||
        lowerIngredient.contains('kyckling') ||
        lowerIngredient.contains('fisk') ||
        lowerIngredient.contains('fläsk') ||
        lowerIngredient.contains('nöt') ||
        lowerIngredient.contains('lax')) {
      return 'Kött & Fisk';
    }

    // Skafferi
    if (lowerIngredient.contains('mjöl') ||
        lowerIngredient.contains('socker') ||
        lowerIngredient.contains('salt') ||
        lowerIngredient.contains('olja') ||
        lowerIngredient.contains('pasta') ||
        lowerIngredient.contains('ris')) {
      return 'Skafferi';
    }

    // Default
    return 'Övrigt';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<UnifiedShoppingViewModel>(
        builder: (context, viewModel, child) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: AppTheme.cardPadding,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: AppTheme.bottomSheetBorderRadius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                _buildHeader(),

                AppTheme.mediumGap,

                // Main content
                Flexible(
                  child: _buildContent(viewModel),
                ),

                AppTheme.mediumGap,

                // Action buttons
                _buildActionButtons(viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.list_alt,
          color: AppTheme.primaryColor,
          size: AppTheme.iconSizeAction,
        ),
        AppTheme.smallHorizontalGap,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Välj inköpslista',
                style: AppTheme.sectionTitleStyle,
              ),
              // ✅ NY: Visa ingrediens-info om meny finns
              if (widget.menu != null) ...[
                AppTheme.tinyGap,
                Text(
                  '${_convertMenuToShoppingItems().length} ingredienser från menyn',
                  style: AppTheme.subtitleStyle.copyWith(
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: AppTheme.actionIcon(context, Icons.close),
          tooltip: 'Stäng',
        ),
      ],
    );
  }

  Widget _buildContent(UnifiedShoppingViewModel viewModel) {
    if (viewModel.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTheme.mediumLoadingIndicator(),
            AppTheme.smallGap,
            Text(
              'Laddar listor...',
              style: AppTheme.subtitleStyle,
            ),
          ],
        ),
      );
    }

    if (viewModel.hasError) {
      return Center(
        child: AppTheme.errorContainer(
          context,
          viewModel.error ?? 'Okänt fel',
          icon: Icons.error_outline,
        ),
      );
    }

    if (!viewModel.hasLists) {
      return const EmptyState(
        icon: Icons.list_alt,
        title: 'Inga inköpslistor',
        subtitle: 'Skapa din första lista för att komma igång',
      );
    }

    return _buildListSelection(viewModel);
  }

  Widget _buildListSelection(UnifiedShoppingViewModel viewModel) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: viewModel.lists.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: AppTheme.dividerColor,
      ),
      itemBuilder: (context, index) {
        final list = viewModel.lists[index];
        final isSelected = _selectedListId == list.id;
        final isActive = viewModel.activeList?.id == list.id;

        return _buildListTile(list, isSelected, isActive, viewModel);
      },
    );
  }

  Widget _buildListTile(
    UnifiedShoppingList list,
    bool isSelected,
    bool isActive,
    UnifiedShoppingViewModel viewModel,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
      decoration: BoxDecoration(
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.05)
            : AppTheme.cardColor,
      ),
      child: ListTile(
        contentPadding: AppTheme.listItemPadding,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Radio button
            Radio<String>(
              value: list.id,
              groupValue: _selectedListId,
              onChanged: (value) {
                setState(() {
                  _selectedListId = value;
                });
              },
              activeColor: AppTheme.primaryColor,
            ),

            // Lista typ ikon
            Icon(
              list.isCollaborative ? Icons.people : Icons.person,
              color: list.isCollaborative
                  ? AppTheme.accentColor
                  : AppTheme.textSecondary,
              size: AppTheme.iconSizeInfo,
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                list.name,
                style: AppTheme.cardTitleStyle.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (isActive) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: AppTheme.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.chipRadius,
                  border: Border.all(
                    color: AppTheme.successColor,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  'AKTIV',
                  style: AppTheme.chipLabelStyle.copyWith(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTheme.tinyGap,
            Text(
              list.summary,
              style: AppTheme.subtitleStyle,
            ),
            AppTheme.tinyGap,
            _buildListMetadata(list),
          ],
        ),
        trailing: _buildListActions(list, viewModel),
        onTap: () {
          setState(() {
            _selectedListId = list.id;
          });
        },
      ),
    );
  }

  Widget _buildListMetadata(UnifiedShoppingList list) {
    return Wrap(
      spacing: AppTheme.spacingSm,
      children: [
        // Sync status
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spacingXs,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: _getSyncStatusColor(list).withValues(alpha: 0.1),
            borderRadius: AppTheme.chipRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                list.syncStatusEmoji,
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(width: 2),
              Text(
                _getSyncStatusText(list),
                style: AppTheme.captionStyle.copyWith(
                  color: _getSyncStatusColor(list),
                ),
              ),
            ],
          ),
        ),

        // Kollaborativ info
        if (list.isCollaborative) ...[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingXs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.chipRadius,
            ),
            child: Text(
              '${list.memberCount} medlemmar',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.accentColor,
              ),
            ),
          ),
        ],

        // Recent activity
        if (list.hasRecentActivity) ...[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingXs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.chipRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  size: 10,
                  color: AppTheme.warningColor,
                ),
                const SizedBox(width: 2),
                Text(
                  'Aktiv',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildListActions(
      UnifiedShoppingList list, UnifiedShoppingViewModel viewModel) {
    return PopupMenuButton<String>(
      icon: AppTheme.actionIcon(context, Icons.more_vert),
      onSelected: (action) => _handleListAction(action, list, viewModel),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit),
              SizedBox(width: 8),
              Text('Byt namn'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.download),
              SizedBox(width: 8),
              Text('Exportera'),
            ],
          ),
        ),
        if (viewModel.lists.length > 1) ...[
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: AppTheme.errorColor),
                SizedBox(width: 8),
                Text('Ta bort', style: TextStyle(color: AppTheme.errorColor)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(UnifiedShoppingViewModel viewModel) {
    return Column(
      children: [
        // Skapa ny lista knapp
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showCreateListDialog(viewModel),
            icon: const Icon(Icons.add),
            label: const Text('Skapa ny lista'),
            style: OutlinedButton.styleFrom(
              padding: AppTheme.buttonPadding,
            ),
          ),
        ),

        AppTheme.smallGap,

        // ✅ UPPDATERAD: Lägg till knapp med loading
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _selectedListId != null && !_isAddingToList
                ? () => _addMenuToListAndNavigate(viewModel)
                : null,
            icon: _isAddingToList
                ? AppTheme.smallLoadingIndicator()
                : const Icon(Icons.add_shopping_cart),
            label: Text(_isAddingToList
                ? 'Lägger till...'
                : widget.menu != null
                    ? 'Lägg till ingredienser'
                    : 'Öppna lista'),
            style: AppTheme.primaryButtonStyle,
          ),
        ),
      ],
    );
  }

  // ✅ NY: Lägg till meny-ingredienser till lista och navigera
  Future<void> _addMenuToListAndNavigate(
      UnifiedShoppingViewModel viewModel) async {
    if (_selectedListId == null) return;

    setState(() {
      _isAddingToList = true;
    });

    try {
      // Sätt aktiv lista om det inte redan är det
      if (_selectedListId != viewModel.activeList?.id) {
        final success = await viewModel.setActiveList(_selectedListId!);
        if (!success) {
          throw Exception('Kunde inte aktivera lista');
        }
      }

      // Lägg till ingredienser från meny om det finns
      if (widget.menu != null) {
        final ingredientItems = _convertMenuToShoppingItems();

        for (final item in ingredientItems) {
          await viewModel.addItemToActiveList(
            name: item.name,
            amount: item.amount,
            unit: item.unit,
            category: item.category,
          );
        }

        AppLogger.success(
            '✅ Lade till ${ingredientItems.length} ingredienser från meny');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Lade till ${ingredientItems.length} ingredienser från menyn'),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      // Navigera till shopping view
      if (mounted) {
        widget.onListSelected?.call();
        Navigator.pushReplacementNamed(context, '/unified-shopping');
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid tillägg av ingredienser: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte lägga till ingredienser: $e'),
            backgroundColor: AppTheme.errorColor,
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

  // Helper methods
  Color _getSyncStatusColor(UnifiedShoppingList list) {
    switch (list.syncStatus) {
      case SyncStatus.synced:
        return AppTheme.successColor;
      case SyncStatus.pending:
        return AppTheme.warningColor;
      case SyncStatus.conflict:
        return AppTheme.errorColor;
      case SyncStatus.local:
        return AppTheme.textTertiary;
      case SyncStatus.error:
        return AppTheme.errorColor;
    }
  }

  String _getSyncStatusText(UnifiedShoppingList list) {
    switch (list.syncStatus) {
      case SyncStatus.synced:
        return 'Synkad';
      case SyncStatus.pending:
        return 'Synkar...';
      case SyncStatus.conflict:
        return 'Konflikt';
      case SyncStatus.local:
        return 'Lokal';
      case SyncStatus.error:
        return 'Fel';
    }
  }

  // ✅ UPPDATERAD: Endast personliga listor
  Future<void> _showCreateListDialog(UnifiedShoppingViewModel viewModel) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline),
            SizedBox(width: 8),
            Text('Skapa ny lista'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Listnamn *',
                hintText: 'T.ex. Veckohandling',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            AppTheme.mediumGap,
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Beskrivning (valfri)',
                hintText: 'Beskriv vad listan är till för',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            AppTheme.mediumGap,
            // ✅ INFO: Bara personliga listor
            Container(
              padding: AppTheme.cardPadding,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.mediumRadius,
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: AppTheme.iconSizeInfo,
                  ),
                  AppTheme.smallHorizontalGap,
                  Expanded(
                    child: Text(
                      'Listan skapas som personlig. Du kan dela den med vänner senare.',
                      style: AppTheme.captionStyle.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skapa'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listnamn krävs'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return;
      }

      // ✅ SKAPA ENDAST PERSONLIG LISTA
      final success = await viewModel.createPersonalList(name);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lista "$name" skapad!'),
              backgroundColor: AppTheme.successColor,
            ),
          );

          // Uppdatera vald lista till den nya
          setState(() {
            _selectedListId = viewModel.activeList?.id;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Kunde inte skapa lista: ${viewModel.error ?? "Okänt fel"}',
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleListAction(
    String action,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
  ) async {
    switch (action) {
      case 'rename':
        await _showRenameDialog(list, viewModel);
        break;
      case 'export':
        await _exportList(list, viewModel);
        break;
      case 'delete':
        await _showDeleteDialog(list, viewModel);
        break;
    }
  }

  Future<void> _showRenameDialog(
      UnifiedShoppingList list, UnifiedShoppingViewModel viewModel) async {
    final nameController = TextEditingController(text: list.name);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Byt namn på lista'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nytt namn',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Spara'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != list.name && mounted) {
      final success = await viewModel.renameActiveList(result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Lista omdöpt till "$result"'
                  : 'Kunde inte byta namn: ${viewModel.error ?? "Okänt fel"}',
            ),
            backgroundColor:
                success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _exportList(
      UnifiedShoppingList list, UnifiedShoppingViewModel viewModel) async {
    final exportText = viewModel.exportListAsText();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lista exporterad! ${exportText.length} tecken'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _showDeleteDialog(
      UnifiedShoppingList list, UnifiedShoppingViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Ta bort lista'),
          ],
        ),
        content: Text(
          'Är du säker på att du vill ta bort "${list.name}"?\n\n'
          'Denna åtgärd kan inte ångras och alla ${list.totalItems} artiklar försvinner.',
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
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await viewModel.deleteActiveList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Lista "${list.name}" borttagen'
                  : 'Kunde inte ta bort lista: ${viewModel.error ?? "Okänt fel"}',
            ),
            backgroundColor:
                success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );

        if (success) {
          setState(() {
            _selectedListId = viewModel.activeList?.id;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}
