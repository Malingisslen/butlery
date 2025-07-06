// lib/widgets/shopping_list_selector.dart
// ✅ 100% AppTheme migrerad - ANVÄNDER ENDAST BEFINTLIGA APPTHEME PROPERTIES

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/unified_shopping_viewmodel.dart';
import '../models/unified/unified_shopping_list.dart';
import '../models/unified/unified_shopping_item.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../widgets/common/state_widget.dart';
import '../core/utils/logger.dart';

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

  List<UnifiedShoppingItem> _convertMenuToShoppingItems() {
    if (widget.menu == null || widget.menu!.isEmpty) return [];

    final items = <UnifiedShoppingItem>[];
    final seenIngredients = <String>{};

    for (final entry in widget.menu!.entries) {
      for (final recipe in entry.value) {
        for (final ingredient in recipe.ingredients) {
          final normalizedIngredient = ingredient.toLowerCase().trim();
          if (!seenIngredients.contains(normalizedIngredient)) {
            seenIngredients.add(normalizedIngredient);

            items.add(UnifiedShoppingItem.basic(
              name: ingredient.trim(),
              amount: 1.0,
              unit: '',
              category: _categorizeIngredient(ingredient),
            ));
          }
        }
      }
    }

    AppLogger.info('Konverterade ${items.length} unika ingredienser från meny');
    return items;
  }

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
                  width: AppTheme.iconSizeDisplay,
                  height: AppTheme.spacingXs,
                  margin: EdgeInsets.only(bottom: AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(AppTheme.spacingXxs),
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
        AppTheme.actionIcon(
          context,
          Icons.list_alt,
          color: AppTheme.primaryColor,
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
      return StateWidget.loading(message: 'Laddar listor...');
    }

    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error ?? 'Okänt fel',
      );
    }

    if (!viewModel.hasLists) {
      return StateWidget.empty(
        title: 'Inga inköpslistor',
        subtitle: 'Skapa din första lista för att komma igång',
        icon: Icons.list_alt,
      );
    }

    return _buildListSelection(viewModel);
  }

  Widget _buildListSelection(UnifiedShoppingViewModel viewModel) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: viewModel.lists.length,
      separatorBuilder: (context, index) => Divider(
        height: AppTheme.dividerHeight,
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
                decoration: AppTheme.successContainerDecoration,
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
            vertical: AppTheme.spacingXxs,
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
                style: AppTheme.captionStyle.copyWith(fontSize: 10),
              ),
              AppTheme.tinyGap,
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
              vertical: AppTheme.spacingXxs,
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
              vertical: AppTheme.spacingXxs,
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
                  size: AppTheme.iconSizeInfo,
                  color: AppTheme.warningColor,
                ),
                AppTheme.tinyGap,
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
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              AppTheme.actionIcon(context, Icons.edit),
              AppTheme.smallHorizontalGap,
              Text('Byt namn', style: AppTheme.bodyStyle),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              AppTheme.actionIcon(context, Icons.download),
              AppTheme.smallHorizontalGap,
              Text('Exportera', style: AppTheme.bodyStyle),
            ],
          ),
        ),
        if (viewModel.lists.length > 1) ...[
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                AppTheme.actionIcon(context, Icons.delete,
                    color: AppTheme.errorColor),
                AppTheme.smallHorizontalGap,
                Text(
                  'Ta bort',
                  style: AppTheme.errorTextStyle,
                ),
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
            icon: AppTheme.actionIcon(context, Icons.add),
            label: Text('Skapa ny lista', style: AppTheme.buttonTextStyle),
            style: AppTheme.secondaryButtonStyle,
          ),
        ),

        AppTheme.smallGap,

        // Lägg till knapp med loading
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _selectedListId != null && !_isAddingToList
                ? () => _addMenuToListAndNavigate(viewModel)
                : null,
            icon: _isAddingToList
                ? AppTheme.smallLoadingIndicator()
                : AppTheme.actionIcon(context, Icons.add_shopping_cart),
            label: Text(
              _isAddingToList
                  ? 'Lägger till...'
                  : widget.menu != null
                      ? 'Lägg till ingredienser'
                      : 'Öppna lista',
              style: AppTheme.buttonTextStyle,
            ),
            style: AppTheme.primaryButtonStyle,
          ),
        ),
      ],
    );
  }

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
              duration: const Duration(seconds: 3), // ✅ Hårdkodad duration
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

  Future<void> _showCreateListDialog(UnifiedShoppingViewModel viewModel) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            AppTheme.actionIcon(context, Icons.add_circle_outline),
            AppTheme.smallHorizontalGap,
            Text('Skapa ny lista', style: AppTheme.sectionTitleStyle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Listnamn *',
                labelStyle: AppTheme.formLabelStyle,
                hintText: 'T.ex. Veckohandling',
                hintStyle: AppTheme.inputHintStyle,
                border: const OutlineInputBorder(),
              ),
              style: AppTheme.bodyStyle,
              autofocus: true,
            ),
            AppTheme.mediumGap,
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Beskrivning (valfri)',
                labelStyle: AppTheme.formLabelStyle,
                hintText: 'Beskriv vad listan är till för',
                hintStyle: AppTheme.inputHintStyle,
                border: const OutlineInputBorder(),
              ),
              style: AppTheme.bodyStyle,
              maxLines: 2,
            ),
            AppTheme.mediumGap,
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
                  AppTheme.infoIcon(context),
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
            child: Text('Avbryt', style: AppTheme.buttonTextStyle),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.primaryButtonStyle,
            child: Text('Skapa', style: AppTheme.buttonTextStyle),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Listnamn krävs',
                style: AppTheme.bodyStyle.copyWith(color: Colors.white)),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return;
      }

      final success = await viewModel.createPersonalList(name);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lista "$name" skapad!',
                  style: AppTheme.bodyStyle.copyWith(color: Colors.white)),
              backgroundColor: AppTheme.successColor,
            ),
          );

          setState(() {
            _selectedListId = viewModel.activeList?.id;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Kunde inte skapa lista: ${viewModel.error ?? "Okänt fel"}',
                style: AppTheme.bodyStyle.copyWith(color: Colors.white),
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
        title: Text('Byt namn på lista', style: AppTheme.sectionTitleStyle),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Nytt namn',
            labelStyle: AppTheme.formLabelStyle,
            border: const OutlineInputBorder(),
          ),
          style: AppTheme.bodyStyle,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Avbryt', style: AppTheme.buttonTextStyle),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            style: AppTheme.primaryButtonStyle,
            child: Text('Spara', style: AppTheme.buttonTextStyle),
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
              style: AppTheme.bodyStyle.copyWith(color: Colors.white),
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
        content: Text(
          'Lista exporterad! ${exportText.length} tecken',
          style: AppTheme.bodyStyle.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _showDeleteDialog(
      UnifiedShoppingList list, UnifiedShoppingViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppTheme.errorColor),
            AppTheme.smallHorizontalGap,
            Text('Ta bort lista', style: AppTheme.sectionTitleStyle),
          ],
        ),
        content: Text(
          'Är du säker på att du vill ta bort "${list.name}"?\n\n'
          'Denna åtgärd kan inte ångras och alla ${list.totalItems} artiklar försvinner.',
          style: AppTheme.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Avbryt', style: AppTheme.buttonTextStyle),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text('Ta bort', style: AppTheme.buttonTextStyle),
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
              style: AppTheme.bodyStyle.copyWith(color: Colors.white),
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
