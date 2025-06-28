// lib/views/unified_shopping_demo_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/unified/unified_shopping_demo_viewmodel.dart';
import '../widgets/main_layout_menu.dart';
import '../theme/app_theme.dart';

class UnifiedShoppingDemoView extends StatefulWidget {
  const UnifiedShoppingDemoView({super.key});

  @override
  State<UnifiedShoppingDemoView> createState() =>
      _UnifiedShoppingDemoViewState();
}

class _UnifiedShoppingDemoViewState extends State<UnifiedShoppingDemoView> {
  late UnifiedShoppingDemoViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = UnifiedShoppingDemoViewModel();
    _initializeDemo();
  }

  Future<void> _initializeDemo() async {
    await _viewModel.initializeDemo();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: MainLayoutMenu(
        title: 'Unified Shopping Demo',
        currentIndex: 2, // Shopping list tab
        body: Consumer<UnifiedShoppingDemoViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Laddar unified shopping system...'),
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
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        viewModel.clearError();
                        _initializeDemo();
                      },
                      child: const Text('Försök igen'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Header med lista-info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewModel.activeList?.name ?? 'Ingen aktiv lista',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        viewModel.listSummary,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (viewModel.totalItems > 0) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: viewModel.completionPercentage / 100,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            viewModel.allItemsBought
                                ? AppTheme.successColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${viewModel.completionPercentage.toInt()}% klart',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),

                // Demo action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: viewModel.addDemoItems,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Demo-artiklar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: viewModel.totalItems > 0
                              ? viewModel.simulateShoppingTrip
                              : null,
                          icon: const Icon(Icons.shopping_cart_checkout),
                          label: const Text('Simulera'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Lista med artiklar
                Expanded(
                  child: viewModel.items.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Inga artiklar i listan',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tryck på "Lägg till demo-artiklar" för att börja',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: viewModel.items.length,
                          itemBuilder: (context, index) {
                            final item = viewModel.items[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Checkbox(
                                  value: item.bought,
                                  onChanged: (_) =>
                                      viewModel.toggleItemBought(item.id),
                                  activeColor: AppTheme.successColor,
                                ),
                                title: Text(
                                  item.displayText,
                                  style: item.bought
                                      ? const TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                                subtitle: item.category.isNotEmpty
                                    ? Text(
                                        item.category,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                                trailing: item.isCollaborative
                                    ? const Tooltip(
                                        message: 'Collaborative item',
                                        child: Icon(
                                          Icons.people,
                                          size: 16,
                                          color: Colors.blue,
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () =>
                                            viewModel.removeItem(item.id),
                                        color: AppTheme.errorColor,
                                      ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom action buttons
                if (viewModel.items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: viewModel.boughtItems > 0
                                ? viewModel.clearBoughtItems
                                : null,
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Rensa'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: viewModel.boughtItems > 0
                                ? viewModel.uncheckAllItems
                                : null,
                            icon: const Icon(Icons.check_box_outline_blank),
                            label: const Text('Avmarkera'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}
