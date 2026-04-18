/// Manager handling shopping item operations with error handling and state management.

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Outcome of a claim attempt — success, or "someone else took it first".
enum ClaimOutcome {
  claimed,
  unclaimed,
  conflict,
  denied,
  error,
}

/// Result bundle from [ShoppingItemOperationsManager.claimItem] carrying
/// the conflicting user's display name when [ClaimOutcome.conflict].
class ClaimResult {
  const ClaimResult(this.outcome, {this.conflictingDisplayName});

  final ClaimOutcome outcome;
  final String? conflictingDisplayName;

  bool get isSuccess =>
      outcome == ClaimOutcome.claimed || outcome == ClaimOutcome.unclaimed;
}

/// Manages shopping item operations including adding, toggling completion, and error handling.
class ShoppingItemOperationsManager extends ChangeNotifier {
  final UnifiedShoppingService _shoppingService;
  final String listId;

  bool _isAddingItem = false;
  String _error = '';

  ShoppingItemOperationsManager(this._shoppingService, this.listId);

  bool get isAddingItem => _isAddingItem;
  String get error => _error;
  bool get hasError => _error.isNotEmpty;

  void setError(String error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  Future<bool> addItem(
    String itemName,
    bool canEdit,
    Future<void> Function() onListRefresh,
    void Function(String activity, DateTime time) onActivityUpdate,
  ) async {
    if (itemName.trim().isEmpty || !canEdit) return false;

    _setAddingItem(true);

    try {
      AppLogger.info('➕ Lägger till artikel: $itemName');

      final success = await _shoppingService.addItemToActiveList(
        name: itemName.trim(),
        amount: 1.0,
        unit: '',
        category: AppLocale.current.categoryOther,
      );

      if (success) {
        await onListRefresh();
        onActivityUpdate(
            AppLocale.current.shoppingItemAdded(itemName), DateTime.now());
        AppLogger.success('✅ Artikel tillagd: $itemName');
        return true;
      } else {
        setError(AppLocale.current.errorCouldNotAddItem);
        AppLogger.error('❌ Kunde inte lägga till artikel: $itemName');
        return false;
      }
    } catch (e) {
      setError(AppLocale.current.errorCouldNotAddItem);
      AppLogger.error('❌ Exception vid tillägg av artikel', e);
      return false;
    } finally {
      _setAddingItem(false);
    }
  }

  Future<bool> toggleItemCompletion(
    String itemId,
    UnifiedShoppingList? currentList,
    bool canEdit,
    Future<void> Function() onListRefresh,
    void Function(String activity, DateTime time) onActivityUpdate,
  ) async {
    if (!canEdit) return false;

    try {
      AppLogger.info('🔄 Växlar artikel status: $itemId');

      final item = currentList?.items.firstWhere((i) => i.id == itemId);
      if (item == null) return false;

      final success = await _shoppingService.toggleItemBought(itemId);

      if (success) {
        await onListRefresh();
        onActivityUpdate(
          !item.bought
              ? AppLocale.current.shoppingItemMarkedComplete
              : AppLocale.current.shoppingItemMarkedIncomplete,
          DateTime.now(),
        );
        AppLogger.success('✅ Artikel status växlad: $itemId');
        return true;
      } else {
        setError(AppLocale.current.errorCouldNotUpdateItem);
        AppLogger.error('❌ Kunde inte växla artikel status: $itemId');
        return false;
      }
    } catch (e) {
      setError(AppLocale.current.errorCouldNotUpdateItem);
      AppLogger.error('❌ Exception vid växling av artikel status', e);
      return false;
    }
  }

  void _setAddingItem(bool adding) {
    _isAddingItem = adding;
    notifyListeners();
  }

  /// Claim an item — "Tar jag" / "I'll get this" (BUT-238).
  ///
  /// Last-writer-wins semantics at Firestore. To keep the UI honest,
  /// we pre-check local state: if another user already holds the claim,
  /// we refuse with [ClaimOutcome.conflict] and let the caller surface
  /// "Anna tog den — välj en annan".
  ///
  /// Routing: ViewModel → this manager → UnifiedShoppingService.updateItem.
  /// Widgets must never talk to the service directly.
  Future<ClaimResult> claimItem(
    String itemId,
    UnifiedShoppingList? currentList,
    bool canEdit,
    Future<void> Function() onListRefresh,
    void Function(String activity, DateTime time) onActivityUpdate,
  ) async {
    if (!canEdit) return const ClaimResult(ClaimOutcome.denied);

    try {
      final item = currentList?.items.firstWhere((i) => i.id == itemId);
      if (item == null) return const ClaimResult(ClaimOutcome.error);

      final permissionService = ServiceLocator.get<PermissionService>();
      final currentUser = permissionService.currentUser;
      if (currentUser == null) return const ClaimResult(ClaimOutcome.denied);

      final alreadyHeld = item.assignedToUserId;
      if (alreadyHeld != null && alreadyHeld != currentUser.uid) {
        // Pre-flight collision — someone else took it in local state.
        return ClaimResult(
          ClaimOutcome.conflict,
          conflictingDisplayName: item.assignedToDisplayName,
        );
      }

      final claimed = item.assign(
        userId: currentUser.uid,
        displayName: currentUser.displayName,
      );

      final success =
          await _shoppingService.updateCollaborativeItem(listId, claimed);
      if (success) {
        await onListRefresh();
        onActivityUpdate(
          AppLocale.current.shoppingItemClaimed(item.name),
          DateTime.now(),
        );
        return const ClaimResult(ClaimOutcome.claimed);
      }
      return const ClaimResult(ClaimOutcome.error);
    } catch (e) {
      AppLogger.error('claimItem failed', e);
      return const ClaimResult(ClaimOutcome.error);
    }
  }

  /// Release a claim — "Lämna tillbaka" (BUT-238). Only the current assignee
  /// may unclaim; anyone else with edit rights must use [claimItem] to take over.
  Future<ClaimResult> unclaimItem(
    String itemId,
    UnifiedShoppingList? currentList,
    bool canEdit,
    Future<void> Function() onListRefresh,
    void Function(String activity, DateTime time) onActivityUpdate,
  ) async {
    if (!canEdit) return const ClaimResult(ClaimOutcome.denied);

    try {
      final item = currentList?.items.firstWhere((i) => i.id == itemId);
      if (item == null) return const ClaimResult(ClaimOutcome.error);

      final permissionService = ServiceLocator.get<PermissionService>();
      final currentUser = permissionService.currentUser;
      if (currentUser == null) return const ClaimResult(ClaimOutcome.denied);

      if (item.assignedToUserId != currentUser.uid) {
        return const ClaimResult(ClaimOutcome.denied);
      }

      final released = item.unassign(
        userId: currentUser.uid,
        displayName: currentUser.displayName,
      );
      final success =
          await _shoppingService.updateCollaborativeItem(listId, released);
      if (success) {
        await onListRefresh();
        onActivityUpdate(
          AppLocale.current.shoppingItemUnclaimed(item.name),
          DateTime.now(),
        );
        return const ClaimResult(ClaimOutcome.unclaimed);
      }
      return const ClaimResult(ClaimOutcome.error);
    } catch (e) {
      AppLogger.error('unclaimItem failed', e);
      return const ClaimResult(ClaimOutcome.error);
    }
  }
}
