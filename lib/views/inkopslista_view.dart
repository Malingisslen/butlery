// lib/views/inkopslista_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/recipe.dart';
import '../services/shopping_list_service.dart';
import '../utils/text_utils.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/empty_state.dart';
import '../widgets/action_button.dart';
import '../theme/app_theme.dart';

/// Vy för att visa inköpslista baserat på menyerna som skickats in.
/// Förväntar sig att `arguments` är en `Map<String, List<Recipe>>` från VeckomenyView.
class InkopslistaView extends StatefulWidget {
  const InkopslistaView({super.key});

  @override
  State<InkopslistaView> createState() => _InkopslistaViewState();
}

class _InkopslistaViewState extends State<InkopslistaView> {
  List<String> _shoppingList = [];
  Map<int, bool> _checkedItems = {};
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateShoppingList();
    });
  }

  Future<void> _generateShoppingList() async {
    setState(() {
      _isLoading = true;
    });

    final args = ModalRoute.of(context)?.settings.arguments;
    final menu =
        (args is Map<String, List<Recipe>>) ? args : <String, List<Recipe>>{};

    if (menu.isEmpty) {
      setState(() {
        _shoppingList = [];
        _isLoading = false;
      });
      return;
    }

    // Simulera lite latency
    await Future.delayed(const Duration(milliseconds: 200));

    // Använd den nya ShoppingListService
    final service = ShoppingListService();
    final shoppingItems = service.createShoppingListFromMenu(menu);

    // Konvertera ShoppingItem till String för den befintliga UI:n
    final displayList =
        shoppingItems.map((item) {
          if (item.unit.isNotEmpty) {
            final amountStr =
                item.amount == 1.0
                    ? ''
                    : '${toSwedishHalfFraction(item.amount)} ';
            return '$amountStr${item.unit} ${item.name}';
          } else {
            final amountStr =
                item.amount == 1.0
                    ? ''
                    : '${toSwedishHalfFraction(item.amount)} ';
            return '$amountStr${item.name}';
          }
        }).toList();

    setState(() {
      _shoppingList = displayList;
      _checkedItems = {}; // Återställ checkboxar
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  Future<void> _refreshShoppingList() async {
    setState(() {
      _isRefreshing = true;
    });
    await _generateShoppingList();
  }

  void _shareShoppingList() {
    if (_shoppingList.isEmpty) return;

    final text =
        'Inköpslista:\n\n${_shoppingList.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isChecked = _checkedItems[index] ?? false;
          return '${isChecked ? '✓' : '•'} $item';
        }).join('\n')}';

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Inköpslista kopierad till urklipp'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleItem(int index) {
    setState(() {
      _checkedItems[index] = !(_checkedItems[index] ?? false);
    });
  }

  void _clearCheckedItems() {
    setState(() {
      _checkedItems.clear();
    });
  }

  int get _checkedCount =>
      _checkedItems.values.where((checked) => checked).length;
  int get _totalCount => _shoppingList.length;

  @override
  Widget build(BuildContext context) {
    return MainLayoutMenu(
      currentIndex: 3,
      title: 'Inköpslista',
      actions: [
        if (_shoppingList.isNotEmpty) ...[
          if (_checkedCount > 0)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearCheckedItems,
              tooltip: 'Rensa alla checkade',
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareShoppingList,
            tooltip: 'Dela inköpslista',
          ),
        ],
      ],
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _shoppingList.isEmpty
              ? EmptyState.noShoppingList(
                onAction:
                    () => Navigator.pushReplacementNamed(context, '/veckomeny'),
              )
              : Column(
                children: [
                  // Header med statistik
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inköpslista',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_totalCount artiklar${_checkedCount > 0 ? ' • $_checkedCount checkade' : ''}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (_checkedCount > 0 && _checkedCount == _totalCount)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color:
                                      AppTheme
                                          .successColor, // ✅ Använder theme färg istället för Colors.green
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Alla artiklar checkade!',
                                  style: TextStyle(
                                    color:
                                        AppTheme
                                            .successColor, // ✅ Använder theme färg istället för Colors.green
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Lista med ingredienser
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _shoppingList.length,
                      itemBuilder: (context, index) {
                        final item = _shoppingList[index];
                        final isChecked = _checkedItems[index] ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          elevation: 0,
                          color:
                              isChecked
                                  ? Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5)
                                  : null,
                          child: ListTile(
                            leading: Checkbox(
                              value: isChecked,
                              onChanged: (value) => _toggleItem(index),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            title: Text(
                              item,
                              style: TextStyle(
                                decoration:
                                    isChecked
                                        ? TextDecoration.lineThrough
                                        : null,
                                color:
                                    isChecked
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant
                                        : null,
                              ),
                            ),
                            onTap: () => _toggleItem(index),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom action bar
                  if (_shoppingList.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ActionButton.outlined(
                              label: 'Uppdatera',
                              icon: Icons.refresh,
                              onPressed: _refreshShoppingList,
                              isLoading: _isRefreshing,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ActionButton.primary(
                              label: 'Dela lista',
                              icon: Icons.share,
                              onPressed: _shareShoppingList,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }
}
