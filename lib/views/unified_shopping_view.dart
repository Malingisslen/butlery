// lib/views/unified_shopping_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ViewModels
import '../viewmodels/unified_shopping_viewmodel.dart';

// Models
import '../models/unified/unified_shopping_item.dart';
import '../models/user_profile.dart'; // ✅ LÄGG TILL: För UserProfile

// Widgets
import '../widgets/main_layout_menu.dart';
import '../widgets/empty_state.dart';
import '../widgets/offline_indicator.dart';
import '../widgets/universal_share_dialog.dart';
import '../widgets/add_shopping_item_dialog.dart';

// Theme
import '../theme/app_theme.dart';

// Core
import '../core/injection.dart';
import '../core/utils/logger.dart'; // ✅ LÄGG TILL: För AppLogger

// Services
import '../services/share_service.dart';
import '../services/friends_service.dart'; // ✅ LÄGG TILL: För FriendsService

/// 🎯 FÖRBÄTTRAD UNIFIED SHOPPING VIEW
/// ✅ Kategorigruppering + smart formatering + ingen hamburgermeny
class UnifiedShoppingView extends StatefulWidget {
  const UnifiedShoppingView({super.key});

  @override
  State<UnifiedShoppingView> createState() => _UnifiedShoppingViewState();
}

class _UnifiedShoppingViewState extends State<UnifiedShoppingView> {
  late UnifiedShoppingViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<UnifiedShoppingViewModel>();
    _initializeViewModel();
  }

  Future<void> _initializeViewModel() async {
    await _viewModel.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: MainLayoutMenu(
        title: 'Inköpslistor',
        currentIndex: 3, // Shopping list är tab 3
        actions: [
          // ✨ DIREKTA IKONER som receptdesignen
          Consumer<UnifiedShoppingViewModel>(
            builder: (context, viewModel, child) {
              final canShare = viewModel.hasItems;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ny lista-knapp
                  IconButton(
                    icon: AppTheme.actionIcon(context, Icons.add),
                    onPressed: _showCreateListDialog,
                    tooltip: 'Ny lista',
                  ),

                  // Dela med vänner-knapp (social)
                  IconButton(
                    icon: AppTheme.actionIcon(
                      context,
                      Icons.people_outline,
                      color: canShare ? null : AppTheme.textTertiary,
                    ),
                    onPressed: canShare ? _showShoppingShareDialog : null,
                    tooltip:
                        canShare ? 'Dela med vänner' : 'Inga artiklar att dela',
                  ),

                  // Dela externt-knapp
                  IconButton(
                    icon: AppTheme.actionIcon(
                      context,
                      Icons.share,
                      color: canShare ? null : AppTheme.textTertiary,
                    ),
                    onPressed: canShare ? _shareListExternally : null,
                    tooltip:
                        canShare ? 'Dela externt' : 'Inga artiklar att dela',
                  ),

                  // Sync status indicator
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      icon: Icon(
                        viewModel.isOnline ? Icons.cloud_done : Icons.cloud_off,
                        color: viewModel.isOnline ? Colors.green : Colors.grey,
                      ),
                      onPressed: () => _showSyncStatus(viewModel),
                      tooltip: viewModel.isOnline ? 'Online' : 'Offline',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddItemDialog(),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: AppTheme.elevationHigh,
          icon: AppTheme.actionIcon(
            context,
            Icons.add,
            color: Colors.white,
          ),
          label: Text(
            'Lägg till vara',
            style: AppTheme.buttonTextStyle.copyWith(color: Colors.white),
          ),
        ),
        body: Consumer<UnifiedShoppingViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              children: [
                // Offline indicator
                if (!viewModel.isOnline) const OfflineIndicator(),

                // Lista header
                _buildListHeader(viewModel),

                // Huvudinnehåll
                Expanded(
                  child: _buildMainContent(viewModel),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildListHeader(UnifiedShoppingViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lista-väljare dropdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: viewModel.activeList?.id,
                hint: const Text('Välj lista'),
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                onChanged: (listId) {
                  if (listId != null) {
                    viewModel.setActiveList(listId);
                  }
                },
                items: viewModel.lists.map((list) {
                  return DropdownMenuItem<String>(
                    value: list.id,
                    child: Text(
                      '${list.name} (${list.items.length} varor)',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ✅ Statistik borttagen - visas nu i dropdown istället
        ],
      ),
    );
  }

  // ✅ Metod borttagen - används inte längre

  Widget _buildMainContent(UnifiedShoppingViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Laddar inköpslistor...'),
          ],
        ),
      );
    }

    if (viewModel.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Fel: ${viewModel.error}',
              style: const TextStyle(
                color: AppTheme.errorColor,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                viewModel.clearError();
                _initializeViewModel();
              },
              child: const Text('Försök igen'),
            ),
          ],
        ),
      );
    }

    if (!viewModel.hasItems) {
      return const EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Inga artiklar i listan',
        subtitle: 'Tryck på + för att lägga till din första artikel',
      );
    }

    return _buildCategorizedItemsList(viewModel);
  }

  // ✅ NY: Kategoriserad lista istället för enkel lista
  Widget _buildCategorizedItemsList(UnifiedShoppingViewModel viewModel) {
    final itemsByCategory = viewModel.itemsByCategory;
    final boughtItemsByCategory = <String, List<UnifiedShoppingItem>>{};
    final activeItemsByCategory = <String, List<UnifiedShoppingItem>>{};

    // Separera köpta och aktiva items per kategori
    for (final category in itemsByCategory.keys) {
      final categoryItems = itemsByCategory[category]!;
      activeItemsByCategory[category] =
          categoryItems.where((item) => !item.bought).toList();
      boughtItemsByCategory[category] =
          categoryItems.where((item) => item.bought).toList();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ✅ AKTIVA ARTIKLAR - grupperade per kategori
        ...activeItemsByCategory.entries
            .where((entry) => entry.value.isNotEmpty)
            .map((entry) => _buildCategorySection(
                  entry.key,
                  entry.value,
                  viewModel,
                  isCompleted: false,
                )),

        // ✅ KÖPTA ARTIKLAR - egen sektion
        if (viewModel.boughtItems > 0) ...[
          const SizedBox(height: 24),
          _buildCompletedItemsHeader(viewModel),
          const SizedBox(height: 8),
          ...boughtItemsByCategory.entries
              .where((entry) => entry.value.isNotEmpty)
              .map((entry) => _buildCategorySection(
                    entry.key,
                    entry.value,
                    viewModel,
                    isCompleted: true,
                  )),
        ],
      ],
    );
  }

  // ✅ NY: Bygg kategori-sektion med header
  Widget _buildCategorySection(
    String category,
    List<UnifiedShoppingItem> items,
    UnifiedShoppingViewModel viewModel, {
    bool isCompleted = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kategori-header
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 12),
          child: Row(
            children: [
              _getCategoryIcon(category, isCompleted),
              const SizedBox(width: 8),
              Text(
                category,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isCompleted
                      ? Colors.grey.shade600
                      : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isCompleted ? Colors.grey : AppTheme.primaryColor)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isCompleted
                        ? Colors.grey.shade600
                        : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Artiklar i kategorin
        ...items.map((item) => _buildItemTile(item, viewModel, isCompleted)),

        const SizedBox(height: 8),
      ],
    );
  }

  // ✅ Kategori-ikoner för visuell tydlighet
  Widget _getCategoryIcon(String category, bool isCompleted) {
    IconData iconData;
    switch (category.toLowerCase()) {
      case 'frukt & grönt':
        iconData = Icons.eco;
        break;
      case 'mejeri':
        iconData = Icons.local_drink;
        break;
      case 'kött & fisk':
        iconData = Icons.set_meal;
        break;
      case 'bröd':
        iconData = Icons.bakery_dining;
        break;
      case 'skafferi':
        iconData = Icons.kitchen;
        break;
      case 'fryst':
        iconData = Icons.ac_unit;
        break;
      case 'dryck':
        iconData = Icons.local_cafe;
        break;
      case 'snacks & godis':
        iconData = Icons.cookie;
        break;
      case 'städ & hygien':
        iconData = Icons.cleaning_services;
        break;
      default:
        iconData = Icons.shopping_basket;
    }

    return Icon(
      iconData,
      size: 18,
      color: isCompleted ? Colors.grey.shade600 : AppTheme.primaryColor,
    );
  }

  Widget _buildCompletedItemsHeader(UnifiedShoppingViewModel viewModel) {
    return Row(
      children: [
        Icon(
          Icons.check_circle,
          size: 20,
          color: Colors.green.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inhandlade varor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '${viewModel.boughtItems} varor',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => _clearBoughtItemsWithConfirmation(viewModel),
          icon: Icon(Icons.delete,
              size: 18, color: Colors.grey.shade600), // ✅ Soptunna-ikon
          label: Text(
            'Töm',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ],
    );
  }

  // ✅ FÖRBÄTTRAD: Item tile utan hamburgermeny
  Widget _buildItemTile(UnifiedShoppingItem item,
      UnifiedShoppingViewModel viewModel, bool isCompleted) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) {
        viewModel.removeItem(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} borttagen'),
            action: SnackBarAction(
              label: 'Ångra',
              onPressed: () {
                // TODO: Implementera undo functionality
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Checkbox(
            value: item.bought,
            onChanged: (_) => viewModel.toggleItemBought(item.id),
            activeColor: AppTheme.successColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          title: Text(
            item.displayText, // ✅ Använder förbättrade displayText
            style: item.bought
                ? TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey.shade500,
                    fontSize: 16,
                  )
                : const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
          ),
          // ✅ Ingen subtitle med kategori längre - kategorin är redan i headern

          // ✅ Redigera-knapp istället för hamburgermeny
          trailing: item.bought
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: () => _showEditItemDialog(item),
                  tooltip: 'Redigera',
                ),
        ),
      ),
    );
  }

  // ==================== DIALOG METODER ====================

  void _showShoppingShareDialog() {
    if (_viewModel.activeList == null) return;

    // ✅ SÄKER: Hämta vänner direkt från FriendsService
    List<UserProfile> availableFriends = [];

    try {
      final friendsService =
          sl<FriendsService>(); // Du kanske redan har denna som field
      availableFriends = friendsService.friends;
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte hämta vänner för shopping sharing: $e');
      availableFriends = [];
    }

    showDialog(
      context: context,
      builder: (context) => UniversalShareDialog.shoppingList(
        shoppingList: _viewModel.activeList!,
        initialMessage: "Kolla min inköpslista!",
        availableFriends: availableFriends, // ✅ SÄKER: null eller lista
      ),
    );
  }

  // ✅ FÖRBÄTTRAD: Använd ny dialog
  void _showAddItemDialog() {
    showDialog<UnifiedShoppingItem>(
      context: context,
      builder: (context) => const AddUnifiedShoppingItemDialog(),
    ).then((item) {
      if (item != null) {
        _addItemFromDialog(item);
      }
    });
  }

  // ✅ NY: Redigera befintlig artikel
  void _showEditItemDialog(UnifiedShoppingItem item) {
    showDialog<UnifiedShoppingItem>(
      context: context,
      builder: (context) => AddUnifiedShoppingItemDialog(initialItem: item),
    ).then((editedItem) {
      if (editedItem != null) {
        _editItemFromDialog(item.id, editedItem);
      }
    });
  }

  // ✅ FÖRBÄTTRAD: Hantera ny artikel från dialog
  Future<void> _addItemFromDialog(UnifiedShoppingItem item) async {
    try {
      final success = await _viewModel.addItem(
        name: item.name,
        amount: item.amount,
        unit: item.unit,
        category: item.category,
      );

      if (success) {
        _showSuccessSnackBar('${item.name} tillagd i listan!');
      } else {
        _showErrorSnackBar('Kunde inte lägga till ${item.name}');
      }
    } catch (e) {
      _showErrorSnackBar('Fel vid tillägg: $e');
    }
  }

  // ✅ NY: Hantera redigerad artikel
  Future<void> _editItemFromDialog(
      String itemId, UnifiedShoppingItem editedItem) async {
    try {
      // TODO: Implementera edit-funktionalitet i ViewModel
      // För nu, ta bort gamla och lägg till ny
      final removed = await _viewModel.removeItem(itemId);
      if (removed) {
        final success = await _viewModel.addItem(
          name: editedItem.name,
          amount: editedItem.amount,
          unit: editedItem.unit,
          category: editedItem.category,
        );

        if (success) {
          _showSuccessSnackBar('${editedItem.name} uppdaterad!');
        } else {
          _showErrorSnackBar('Kunde inte uppdatera ${editedItem.name}');
        }
      } else {
        _showErrorSnackBar('Kunde inte ta bort gamla ${editedItem.name}');
      }
    } catch (e) {
      _showErrorSnackBar('Fel vid uppdatering: $e');
    }
  }

  void _clearBoughtItemsWithConfirmation(UnifiedShoppingViewModel viewModel) {
    if (viewModel.boughtItems == 0) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Töm inhandlade varor',
          style: AppTheme.cardTitleStyle,
        ),
        content: Text(
          'Vill du ta bort alla ${viewModel.boughtItems} inhandlade varor från listan?',
          style: AppTheme.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: AppTheme.secondaryButtonStyle,
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              viewModel.clearBoughtItems();
              _showSuccessSnackBar('Inhandlade varor rensade!');
            },
            style: AppTheme.primaryButtonStyle.copyWith(
              backgroundColor: WidgetStateProperty.all(AppTheme.errorColor),
            ),
            child: const Text('Töm'),
          ),
        ],
      ),
    );
  }

  void _shareListExternally() {
    if (_viewModel.activeList == null) return;

    final shareService = sl<ShareService>();
    shareService.shareShoppingList(_viewModel.items);
  }

  void _showSyncStatus(UnifiedShoppingViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            AppTheme.infoIcon(context, icon: Icons.sync),
            SizedBox(width: AppTheme.spacingSm),
            Text(
              'Synkroniseringsstatus',
              style: AppTheme.cardTitleStyle,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow(
              'Status',
              viewModel.isOnline ? "Online" : "Offline",
              viewModel.isOnline ? AppTheme.successColor : AppTheme.errorColor,
            ),
            AppTheme.smallGap,
            if (viewModel.activeList != null)
              _buildStatusRow(
                'Lista',
                viewModel.activeList!.name,
                Theme.of(context).colorScheme.onSurface,
              ),
            AppTheme.smallGap,
            _buildStatusRow(
              'Artiklar',
              '${viewModel.totalItems} totalt',
              Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: AppTheme.primaryButtonStyle,
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: AppTheme.formLabelStyle,
        ),
        Text(
          value,
          style: AppTheme.bodyStyle.copyWith(color: valueColor),
        ),
      ],
    );
  }

  void _showCreateListDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Skapa ny lista',
          style: AppTheme.cardTitleStyle,
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: AppTheme.bodyStyle,
          decoration: InputDecoration(
            labelText: 'Listnamn',
            labelStyle: AppTheme.formLabelStyle,
            hintText: 'T.ex. Veckohandling',
            hintStyle: AppTheme.inputHintStyle,
            border: OutlineInputBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
            contentPadding: AppTheme.inputPadding,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: AppTheme.secondaryButtonStyle,
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                _viewModel.createPersonalList(name);
                Navigator.pop(context);
                _showSuccessSnackBar('Lista "$name" skapad!');
              }
            },
            style: AppTheme.primaryButtonStyle,
            child: const Text('Skapa'),
          ),
        ],
      ),
    );
  }

  // ===== SNACKBAR HELPERS =====

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTheme.errorTextStyle,
        ),
        backgroundColor: AppTheme.errorColor,
        duration: AppTheme.animationDurationDelay,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTheme.successTextStyle,
        ),
        backgroundColor: AppTheme.successColor,
        duration: AppTheme.animationDurationDelay,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
