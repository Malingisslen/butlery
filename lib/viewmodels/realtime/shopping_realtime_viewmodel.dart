import 'package:flutter/foundation.dart';

import '../../models/unified/unified_shopping_list.dart';
import '../../services/unified/unified_shopping_service.dart';
import '../../core/injection.dart';

import 'realtime_base_viewmodel.dart';

/// View model exposing realtime shopping list data.
class ShoppingRealtimeViewModel
    extends RealtimeBaseViewModel<UnifiedShoppingService> {
  ShoppingRealtimeViewModel({UnifiedShoppingService? shoppingService})
      : super(shoppingService ?? sl<UnifiedShoppingService>());

  List<UnifiedShoppingList> get lists => service.lists;
  UnifiedShoppingList? get activeList => service.activeList;

  bool get isInitialized => service.isInitialized;
  bool get isLoading => service.isLoading;
  bool get isSyncing => service.isSyncing;

  String? get error => service.error;
  bool get hasError => service.hasError;

  Future<void> initialize() async => service.initialize();

  Future<bool> setActiveList(String listId) => service.setActiveList(listId);

  Future<bool> addItemToActiveList({
    required String name,
    required double amount,
    String unit = '',
    String category = 'Övrigt',
  }) =>
      service.addItemToActiveList(
        name: name,
        amount: amount,
        unit: unit,
        category: category,
      );

  Future<bool> toggleItemBought(String itemId) =>
      service.toggleItemBought(itemId);

  Future<bool> removeItemFromActiveList(String itemId) =>
      service.removeItemFromActiveList(itemId);
}
