// lib/services/unified/modules/shopping_initialization_module.dart

import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/core/utils/logger.dart';

/// Shopping service initialization module for loading lists and restoring active list.
class ShoppingInitializationModule {
  final AuthRepository authRepository;
  final ShoppingRepository shoppingRepository;
  final JsonCacheHelper Function() getCacheHelper;
  final List<UnifiedShoppingList> lists;
  final String? Function() getActiveListId;
  final void Function(String?) setActiveListId;
  final void Function() notifyListeners;
  final Future<void> Function() saveActiveListId;

  bool _isInitialized = false;

  // Bumped by [reset]. A load started under an older value belongs to an
  // account that has since signed out, so what it brings back is dropped.
  int _generation = 0;

  ShoppingInitializationModule({
    required this.authRepository,
    required this.shoppingRepository,
    required this.getCacheHelper,
    required this.lists,
    required this.getActiveListId,
    required this.setActiveListId,
    required this.notifyListeners,
    required this.saveActiveListId,
  });

  bool get isInitialized => _isInitialized;

  /// Called when the account signs out: lets the next account load afresh and
  /// makes any load still waiting on Firestore discard its answer.
  void reset() {
    _generation++;
    _isInitialized = false;
  }

  /// True while the load that captured [generation] still belongs to the
  /// signed-in account.
  bool isCurrent(int generation) => generation == _generation;

  int get generation => _generation;

  Future<void> initialize() async {
    // Early return if already initialized to prevent clearing local state
    // This fixes race condition when navigating after adding items
    if (_isInitialized) {
      AppLogger.info(
        'Shopping service already initialized, skipping reload',
        'ShoppingService',
      );
      return;
    }

    try {
      AppLogger.info('Initializing shopping service...', 'ShoppingService');
      AppLogger.info(
        'Authentication status: ${authRepository.currentUser != null ? "✅ Authenticated" : "❌ Not authenticated"}',
        'ShoppingService',
      );

      // Set user for cache helper
      final currentUser = authRepository.currentUser;
      if (currentUser != null) {
        getCacheHelper().setCurrentUser(currentUser.uid);
      }

      final generation = _generation;
      await loadLists();
      if (!isCurrent(generation)) return;
      await _restoreActiveList();
      if (!isCurrent(generation)) return;
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> loadLists() async {
    try {
      // Use shoppingRepository which includes both personal AND collaborative lists
      final generation = _generation;
      final loadedLists = await shoppingRepository.readAll();
      if (!isCurrent(generation)) return;
      lists.clear();
      lists.addAll(loadedLists);

      lists.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      AppLogger.info(
        'Sorted ${loadedLists.length} shopping lists alphabetically',
      );

      notifyListeners();
      AppLogger.success(
        '✅ Loaded ${loadedLists.length} shopping lists (personal + collaborative)',
      );
    } catch (e) {
      AppLogger.error('Failed to load shopping lists: $e');
      // Log error but don't rethrow to allow app to continue with empty lists
    }
  }

  /// Restore the last active list ID from cache, with smart fallback to first available list
  /// Respects already-set active list to prevent overwriting during navigation
  Future<void> _restoreActiveList() async {
    try {
      // Check if active list is already set (e.g., from setActiveList during navigation)
      if (getActiveListId() != null) {
        AppLogger.info(
          'Active list already set to ${getActiveListId()}, skipping restoration to preserve navigation choice',
          'ShoppingService',
        );
        return;
      }

      // Try to load saved active list ID only if no active list is currently set
      const activeListKey = 'active_list_id';
      final generation = _generation;
      final savedActiveListId = await getCacheHelper().loadActiveId(
        activeListKey,
      );
      if (!isCurrent(generation)) return;

      if (savedActiveListId != null &&
          lists.any((list) => list.id == savedActiveListId)) {
        // Saved list still exists, restore it
        setActiveListId(savedActiveListId);
        AppLogger.info(
          '✅ Restored active list from cache: $savedActiveListId',
          'ShoppingService',
        );
      } else if (lists.isNotEmpty) {
        // No saved list or it no longer exists, auto-select first list as fallback
        final firstList = lists.first;
        setActiveListId(firstList.id);

        // Save the fallback selection for next time
        await saveActiveListId();
        AppLogger.info(
          '✅ Auto-selected first list as active fallback: ${firstList.id} (${firstList.name})',
          'ShoppingService',
        );
      } else {
        // No lists available
        setActiveListId(null);
        AppLogger.info(
          'ℹ️  No lists available - activeListId set to null',
          'ShoppingService',
        );
      }

      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to restore active list: $e', 'ShoppingService');
      // Don't rethrow - continue with null active list
    }
  }
}
