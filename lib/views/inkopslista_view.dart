// lib/views/inkopslista_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/shopping_item.dart';
import '../viewmodels/shopping_list_viewmodel.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/empty_state.dart';
import '../widgets/shopping_list_share_dialog.dart';
import '../widgets/add_shopping_item_dialog.dart';
import '../widgets/shopping_list_header.dart';
import '../widgets/shopping_item_tile.dart';
import '../widgets/shopping_list_selector.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';
import '../services/friends_service.dart';
import '../services/share_service.dart';
import '../core/constants/shopping_list_constants.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Shopping List View (Optimized)
/// File: views/inkopslista_view.dart
/// Quick Guide: Performance-optimerad multi-list shopping view
/// Dependencies IN: ShoppingListViewModel, shopping widgets
/// Dependencies OUT: Navigation, shopping dialogs
/// Data flow: View ↔ ViewModel ↔ Service ↔ Firebase/Hive
/// State management: Provider + Selector för optimerad rendering
/// Purpose: Högpresterande shopping list UI med smart state management
/// Common issues: Löst - onödiga rebuilds, memory leaks
/// Test coverage: 0% (TODO)
/// Performance: ⚡⚡ Optimerad med Selector och memoization
/// Analytics: ✅ User interactions tracking
/// Code smells: ✅ Refaktorerad till mindre komponenter
/// Connected to: ShoppingListViewModel, MultiShoppingListService
/// Used in phases: Enhanced shopping feature

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
  final ShareService _shareService = sl<ShareService>();
  final FriendsService _friendsService = sl<FriendsService>();

  @override
  void initState() {
    super.initState();

    // Hantera navigation arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, List<Recipe>>) {
        // Generera från meny
        context.read<ShoppingListViewModel>().generateFromMenu(args);
      }
    });
  }

  // ===== DIALOG HANDLERS =====

  Future<void> _showListSelector(BuildContext context) async {
    final viewModel = context.read<ShoppingListViewModel>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShoppingListSelector(viewModel: viewModel),
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final viewModel = context.read<ShoppingListViewModel>();
    final activeList = viewModel.activeList;
    if (activeList == null) return;

    // Använd en separat dialog widget för bättre minneshantering
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameListDialog(
        initialName: activeList.name,
      ),
    );

    if (newName != null && context.mounted) {
      final success = await viewModel.renameList(activeList.id, newName);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lista omdöpt'),
            backgroundColor: AppTheme.successColor,
            duration: ShoppingListConstants.snackBarDuration,
          ),
        );
      }
    }
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final item = await showDialog<ShoppingItem>(
      context: context,
      builder: (context) => const AddShoppingItemDialog(),
    );

    if (item != null && context.mounted) {
      final viewModel = context.read<ShoppingListViewModel>();

      try {
        final success = await viewModel.addItem(item);

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Artikel tillagd'),
              backgroundColor: AppTheme.successColor,
              duration: ShoppingListConstants.snackBarDuration,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Kunde inte lägga till artikel. Försök igen.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _shareWithFriends(BuildContext context) async {
    final viewModel = context.read<ShoppingListViewModel>();

    if (!viewModel.hasItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Inget att dela - listan är tom!'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // Hämta vänner
    await _friendsService.loadFriends();

    if (_friendsService.friends.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Du har inga vänner att dela med'),
            backgroundColor: AppTheme.warningColor,
            action: SnackBarAction(
              label: 'Lägg till vänner',
              textColor: Colors.white,
              onPressed: () => Navigator.pushNamed(context, '/friends'),
            ),
          ),
        );
      }
      return;
    }

    // Visa delningsdialog
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => ShoppingListShareDialog(
          shoppingItems: viewModel.shoppingItems,
          friends: _friendsService.friends,
          defaultTitle: viewModel.activeList?.name ?? 'Inköpslista',
        ),
      );
    }
  }

  Future<void> _shareSystemList(BuildContext context) async {
    final viewModel = context.read<ShoppingListViewModel>();

    try {
      await _shareService.shareShoppingList(viewModel.shoppingItems);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Inköpslista delad!'),
            backgroundColor: AppTheme.successColor,
            duration: ShoppingListConstants.snackBarDuration,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kunde inte dela listan. Försök igen.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showClearCheckedDialog(BuildContext context) async {
    final checkedCount = context.read<ShoppingListViewModel>().checkedCount;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rensa köpta artiklar?'),
        content: Text('Ta bort $checkedCount köpta artiklar från listan?'),
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.largeRadius,
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
            child: const Text('Rensa'),
          ),
        ],
      ),
    );

    if (shouldClear == true && context.mounted) {
      await context.read<ShoppingListViewModel>().clearCheckedItems();
    }
  }

  Future<void> _showExitDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avsluta Butlery?'),
        content: const Text('Vill du verkligen avsluta appen?'),
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.largeRadius,
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
            child: const Text('Avsluta'),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) {
      SystemNavigator.pop();
    }
  }

  void _handleMoreOptions(String value, BuildContext context) {
    switch (value) {
      case 'rename':
        _showRenameDialog(context);
        break;
      case 'clear_checked':
        _showClearCheckedDialog(context);
        break;
      case 'sync':
        context.read<ShoppingListViewModel>().forceSync();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synkar med molnet...'),
            duration: Duration(seconds: 1),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _showExitDialog(context);
        }
      },
      child: Selector<ShoppingListViewModel, bool>(
        selector: (_, vm) => vm.isLoading,
        builder: (context, isLoading, child) {
          return MainLayoutMenu(
            currentIndex: 3,
            title: 'Inköpslista',
            actions: _buildActions(context),
            body: isLoading ? _buildLoadingState() : _buildContent(context),
            floatingActionButton: _buildFAB(context),
          );
        },
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final hasLists = context.select<ShoppingListViewModel, bool>(
      (vm) => vm.hasLists,
    );

    if (!hasLists) return [];

    return [
      // Synk-status indikator
      Selector<ShoppingListViewModel, (bool, bool)>(
        selector: (_, vm) => (vm.needsSync, vm.isSyncing),
        builder: (context, data, child) {
          final (needsSync, isSyncing) = data;

          if (isSyncing) {
            return Padding(
              padding: EdgeInsets.only(right: AppTheme.spacingSm),
              child: AppTheme.smallLoadingIndicator(
                color: AppTheme.primaryColor,
              ),
            );
          } else if (needsSync) {
            return Padding(
              padding: EdgeInsets.only(right: AppTheme.spacingSm),
              child: Icon(
                Icons.sync_problem,
                color: AppTheme.warningColor,
                size: AppTheme.iconSizeInfo,
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),

      // Social delning
      IconButton(
        icon: Icon(
          Icons.group,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: () => _shareWithFriends(context),
        tooltip: 'Dela med vänner',
      ),

      // System delning
      Selector<ShoppingListViewModel, bool>(
        selector: (_, vm) => vm.hasItems,
        builder: (context, hasItems, child) {
          return IconButton(
            icon: AppTheme.actionIcon(context, Icons.share),
            onPressed: hasItems ? () => _shareSystemList(context) : null,
            tooltip: 'Dela lista',
          );
        },
      ),

      // Mer alternativ
      Selector<ShoppingListViewModel, int>(
        selector: (_, vm) => vm.checkedCount,
        builder: (context, checkedCount, child) {
          return PopupMenuButton<String>(
            icon: AppTheme.actionIcon(context, Icons.more_vert),
            onSelected: (value) => _handleMoreOptions(value, context),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: AppTheme.iconSizeInfo),
                    AppTheme.smallGap,
                    const Text('Byt namn'),
                  ],
                ),
              ),
              if (checkedCount > 0)
                PopupMenuItem(
                  value: 'clear_checked',
                  child: Row(
                    children: [
                      Icon(
                        Icons.remove_shopping_cart,
                        size: AppTheme.iconSizeInfo,
                        color: AppTheme.warningColor,
                      ),
                      AppTheme.smallGap,
                      Text(
                        'Rensa köpta ($checkedCount)',
                        style: TextStyle(color: AppTheme.warningColor),
                      ),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    Icon(Icons.sync, size: AppTheme.iconSizeInfo),
                    AppTheme.smallGap,
                    const Text('Synka nu'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ];
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppTheme.mediumLoadingIndicator(),
          AppTheme.mediumGap,
          Text(
            'Laddar inköpslistor...',
            style: AppTheme.subtitleStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        // Header med lista-väljare
        ShoppingListHeader(
          onListTap: () => _showListSelector(context),
        ),

        // Lista innehåll
        Expanded(
          child: Selector<ShoppingListViewModel, bool>(
            selector: (_, vm) => vm.hasLists,
            builder: (context, hasLists, child) {
              return hasLists
                  ? _buildListContent(context)
                  : _buildEmptyState(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListContent(BuildContext context) {
    return Selector<ShoppingListViewModel, bool>(
      selector: (_, vm) => vm.hasItems,
      builder: (context, hasItems, child) {
        if (!hasItems) {
          return Center(
            child: EmptyState(
              icon: Icons.add_shopping_cart,
              title: 'Listan är tom',
              subtitle:
                  'Lägg till artiklar med knappen nedan\neller generera från en veckomeny',
              actionLabel: 'Gå till veckomeny',
              onAction: () =>
                  Navigator.pushReplacementNamed(context, '/veckomeny'),
            ),
          );
        }

        return const _ShoppingListContent();
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Inga inköpslistor',
        subtitle:
            'Skapa din första lista genom att\ngenerera från en veckomeny',
        actionLabel: 'Skapa veckomeny',
        onAction: () => Navigator.pushReplacementNamed(context, '/veckomeny'),
      ),
    );
  }

  FloatingActionButton? _buildFAB(BuildContext context) {
    final hasLists = context.select<ShoppingListViewModel, bool>(
      (vm) => vm.hasLists,
    );

    if (!hasLists) return null;

    return FloatingActionButton.extended(
      onPressed: () => _showAddItemDialog(context),
      icon: const Icon(Icons.add),
      label: const Text('Lägg till artikel'),
      backgroundColor: AppTheme.primaryColor,
    );
  }
}

// Separat widget för lista innehåll med optimerad rendering
class _ShoppingListContent extends StatelessWidget {
  const _ShoppingListContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<ShoppingListViewModel>();

    return Selector<ShoppingListViewModel,
        (List<ShoppingItem>, List<ShoppingItem>, List<String>)>(
      selector: (_, vm) => (
        vm.unboughtItems,
        vm.boughtItems,
        vm.formattedItems,
      ),
      builder: (context, data, child) {
        final (unboughtItems, boughtItems, formattedItems) = data;

        return RefreshIndicator(
          onRefresh: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Synkar med molnet...'),
                duration: Duration(seconds: 1),
              ),
            );
            await viewModel.refresh();
          },
          child: CustomScrollView(
            slivers: [
              // Icke-köpta artiklar
              if (unboughtItems.isNotEmpty) ...[
                SliverPadding(
                  padding: EdgeInsets.only(top: AppTheme.spacingSm),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = unboughtItems[index];
                        final originalIndex = viewModel.getOriginalIndex(item);

                        return ShoppingItemTile(
                          key: ValueKey(
                              '${viewModel.activeListId}_unbought_$index'),
                          item: item,
                          formattedText: formattedItems[originalIndex],
                          onToggle: () => viewModel.toggleItem(originalIndex),
                          onDismissed: () async {
                            try {
                              await viewModel.removeItem(originalIndex);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${item.name} borttagen'),
                                    action: SnackBarAction(
                                      label: 'Ångra',
                                      onPressed: () => viewModel.undoRemove(),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'Kunde inte ta bort artikel'),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                      childCount: unboughtItems.length,
                    ),
                  ),
                ),
              ],

              // Separator
              if (boughtItems.isNotEmpty && unboughtItems.isNotEmpty) ...[
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingMd,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: _BoughtItemsSeparator(),
                  ),
                ),
              ],

              // Köpta artiklar
              if (boughtItems.isNotEmpty) ...[
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = boughtItems[index];
                      final originalIndex = viewModel.getOriginalIndex(item);

                      return ShoppingItemTile(
                        key:
                            ValueKey('${viewModel.activeListId}_bought_$index'),
                        item: item,
                        formattedText: formattedItems[originalIndex],
                        onToggle: () => viewModel.toggleItem(originalIndex),
                        onDismissed: () async {
                          try {
                            await viewModel.removeItem(originalIndex);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${item.name} borttagen'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      const Text('Kunde inte ta bort artikel'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                    childCount: boughtItems.length,
                  ),
                ),
              ],

              // Extra padding för FAB
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom:
                      AppTheme.spacingXxl + ShoppingListConstants.fabPadding,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Separator widget
class _BoughtItemsSeparator extends StatelessWidget {
  const _BoughtItemsSeparator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                size: AppTheme.iconSizeInfo,
                color: AppTheme.successColor,
              ),
              SizedBox(width: AppTheme.spacingSm),
              Text(
                'Inköpt',
                style: AppTheme.subtitleStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Divider(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

// Dialog för att byta namn på lista
class _RenameListDialog extends StatefulWidget {
  final String initialName;

  const _RenameListDialog({required this.initialName});

  @override
  State<_RenameListDialog> createState() => _RenameListDialogState();
}

class _RenameListDialogState extends State<_RenameListDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _focusNode = FocusNode();

    // Sätt fokus och markera all text
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Byt namn på lista',
        style: AppTheme.sectionTitleStyle,
      ),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: 'Listnamn',
          hintText: 'T.ex. Veckans inköp',
          border: OutlineInputBorder(
            borderRadius: AppTheme.mediumRadius,
          ),
        ),
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.largeRadius,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Spara'),
        ),
      ],
    );
  }

  void _submit() {
    final newName = _controller.text.trim();
    if (newName.isNotEmpty && newName != widget.initialName) {
      Navigator.pop(context, newName);
    } else {
      Navigator.pop(context);
    }
  }
}
