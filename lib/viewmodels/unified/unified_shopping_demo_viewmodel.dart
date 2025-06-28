// lib/viewmodels/unified/unified_shopping_demo_viewmodel.dart

/// Demo ViewModel för att testa Unified Shopping System
/// Kommer ersätta dina befintliga shopping ViewModels senare

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../../services/unified/unified_shopping_service.dart';
import '../../models/unified/unified_shopping_item.dart';
import '../../models/unified/unified_shopping_list.dart';

class UnifiedShoppingDemoViewModel extends ChangeNotifier {
  final UnifiedShoppingService _shoppingService =
      GetIt.instance<UnifiedShoppingService>();

  // ===== GETTERS - samma API som dina befintliga ViewModels =====

  List<UnifiedShoppingList> get lists => _shoppingService.lists;
  UnifiedShoppingList? get activeList => _shoppingService.activeList;
  List<UnifiedShoppingItem> get items => activeList?.items ?? [];
  bool get isLoading => _shoppingService.isLoading;
  String? get error => _shoppingService.error;
  bool get hasError => _shoppingService.hasError;

  // Shopping list stats - samma som du har idag
  int get totalItems => activeList?.totalItems ?? 0;
  int get boughtItems => activeList?.boughtItems ?? 0;
  int get unboughtItems => activeList?.unboughtItems ?? 0;
  double get completionPercentage => activeList?.completionPercentage ?? 0.0;
  String get listSummary => activeList?.summary ?? 'Ingen aktiv lista';
  bool get allItemsBought => activeList?.allItemsBought ?? false;

  UnifiedShoppingDemoViewModel() {
    // Lyssna på service changes
    _shoppingService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    notifyListeners();
  }

  // ===== DEMO METHODS - för att testa funktionaliteten =====

  Future<void> initializeDemo() async {
    try {
      await _shoppingService.initialize();

      // Om inga listor finns, skapa en demo-lista
      if (_shoppingService.lists.isEmpty) {
        await createDemoList();
      }
    } catch (e) {
      debugPrint('Fel vid demo-initialisering: $e');
    }
  }

  Future<void> createDemoList() async {
    await _shoppingService.createPersonalList(
      'Demo Inkopslista',
      items: [
        UnifiedShoppingItem.basic(
          name: 'Milk',
          amount: 1,
          unit: 'liter',
          category: 'Dairy',
        ),
        UnifiedShoppingItem.basic(
          name: 'Bread',
          amount: 2,
          unit: 'st',
          category: 'Bakery',
        ),
        UnifiedShoppingItem.basic(
          name: 'Apples',
          amount: 1,
          unit: 'kg',
          category: 'Fruit',
        ),
      ],
    );
  }

  // ===== LIST MANAGEMENT - samma metoder som dina befintliga ViewModels =====

  Future<void> createPersonalList(String name) async {
    await _shoppingService.createPersonalList(name);
  }

  Future<void> renameActiveList(String newName) async {
    if (activeList != null) {
      await _shoppingService.renameList(activeList!.id, newName);
    }
  }

  Future<void> deleteActiveList() async {
    if (activeList != null && lists.length > 1) {
      await _shoppingService.deleteList(activeList!.id);
    }
  }

  Future<void> setActiveList(String listId) async {
    await _shoppingService.setActiveList(listId);
  }

  // ===== ITEM MANAGEMENT - samma metoder som du har idag =====

  Future<void> addItem({
    required String name,
    required double amount,
    String unit = '',
    String category = 'Ovrigt',
  }) async {
    await _shoppingService.addItemToActiveList(
      name: name,
      amount: amount,
      unit: unit,
      category: category,
    );
  }

  Future<void> toggleItemBought(String itemId) async {
    await _shoppingService.toggleItemBought(itemId);
  }

  Future<void> removeItem(String itemId) async {
    await _shoppingService.removeItemFromActiveList(itemId);
  }

  Future<void> clearBoughtItems() async {
    await _shoppingService.clearBoughtItems();
  }

  Future<void> uncheckAllItems() async {
    await _shoppingService.uncheckAllItems();
  }

  // ===== DEMO ACTIONS =====

  Future<void> addDemoItems() async {
    final demoItems = [
      {'name': 'Eggs', 'amount': 12.0, 'unit': 'st', 'category': 'Dairy'},
      {'name': 'Butter', 'amount': 1.0, 'unit': 'st', 'category': 'Dairy'},
      {'name': 'Bananas', 'amount': 1.0, 'unit': 'kg', 'category': 'Fruit'},
      {'name': 'Rice', 'amount': 1.0, 'unit': 'kg', 'category': 'Pantry'},
    ];

    for (final item in demoItems) {
      await addItem(
        name: item['name'] as String,
        amount: item['amount'] as double,
        unit: item['unit'] as String,
        category: item['category'] as String,
      );
    }
  }

  Future<void> simulateShoppingTrip() async {
    // Simulera att vi handlar - bocka av hälften av artiklarna
    final itemsToCheck = items.take((items.length / 2).ceil()).toList();

    for (final item in itemsToCheck) {
      if (!item.bought) {
        await toggleItemBought(item.id);
        // Lägg till lite delay för att visa animationer
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  void clearError() {
    _shoppingService.clearError();
  }

  @override
  void dispose() {
    _shoppingService.removeListener(_onServiceUpdate);
    super.dispose();
  }
}
