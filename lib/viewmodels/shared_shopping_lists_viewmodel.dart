/// ViewModel for the SharedShoppingListsView displaying collaborative shopping lists.
/// Uses UnifiedShoppingService to load collaborative lists the user participates in.

import 'package:flutter/foundation.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';

class SharedShoppingListsViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final UnifiedShoppingService _shoppingService;

  List<UnifiedShoppingList> _sharedLists = [];

  SharedShoppingListsViewModel({
    UnifiedShoppingService? shoppingService,
  }) : _shoppingService =
            shoppingService ?? ServiceLocator.get<UnifiedShoppingService>() {
    loadSharedLists();
  }

  List<UnifiedShoppingList> get sharedLists => List.unmodifiable(_sharedLists);

  Future<void> loadSharedLists() async {
    try {
      await executeAsync(() async {
        await _shoppingService.loadLists();
        _sharedLists = _shoppingService.collaborativeLists;
      }, errorPrefix: 'Kunde inte ladda delade inköpslistor');
    } catch (_) {
      // Error already captured by StateNotifierMixin
    }
  }

  Future<void> refreshData() async {
    await loadSharedLists();
  }
}
