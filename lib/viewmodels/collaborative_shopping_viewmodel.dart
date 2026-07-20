/// ViewModel managing collaborative shopping lists with real-time coordination and item management.

// lib/viewmodels/collaborative_shopping_viewmodel.dart

import 'package:clock/clock.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/shopping/shopping_presence_module.dart';
import 'package:collection/collection.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_permission_manager.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart'
    show ShoppingItemOperationsManager, ClaimOutcome, ClaimResult;
import 'package:butlery/viewmodels/collaborative_shopping/shopping_display_manager.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Shopping list item grouping mode for the collaborative view (BUT-238).
enum ShoppingViewMode {
  /// Default flat list — active items then completed.
  all,

  /// 3-section split: Min del / {name}s del / Otilldelat.
  myPart,

  /// Grouped by store zone (ShoppingCategory.defaultStoreOrder),
  /// with assignees visible inside each zone.
  byZone,
}

class CollaborativeShoppingViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final UnifiedShoppingService _shoppingService;
  final String listId;

  late final ShoppingPermissionManager _permissionManager;
  late final ShoppingItemOperationsManager _itemOperationsManager;
  late final ShoppingDisplayManager _displayManager;

  UnifiedShoppingList? _currentList;
  String _lastActivity = '';
  DateTime _lastActivityTime = clock.now();
  StreamSubscription<ShoppingServiceState>? _stateSubscription;

  // BUT-238: split-store state
  ShoppingViewMode _viewMode = ShoppingViewMode.all;
  final ShoppingPresenceModule? _presenceModule;
  StreamSubscription<List<Map<String, dynamic>>>? _presenceSubscription;
  StreamSubscription<void>? _heartbeatSubscription;
  List<Map<String, dynamic>> _activeShoppers = const [];

  CollaborativeShoppingViewModel({
    required this.listId,
    UnifiedShoppingService? shoppingService,
    UserService? userService,
    ShoppingPresenceModule? presenceModule,
  }) : _shoppingService =
           shoppingService ?? ServiceLocator.get<UnifiedShoppingService>(),
       _presenceModule =
           presenceModule ??
           (ServiceLocator.isRegistered<ShoppingPresenceModule>()
               ? ServiceLocator.get<ShoppingPresenceModule>()
               : null) {
    _permissionManager = ShoppingPermissionManager(listId);
    _itemOperationsManager = ShoppingItemOperationsManager(
      _shoppingService,
      listId,
    );
    _displayManager = ShoppingDisplayManager();

    _itemOperationsManager.addListener(_onManagerChanged);

    _initialize();
    _stateSubscription = _shoppingService.stateStream.listen(
      _onServiceStateChanged,
    );

    _startPresenceTracking();
  }

  void _onServiceStateChanged(ShoppingServiceState state) {
    if (isDisposed) return;
    if (state is ShoppingStateData) {
      final updated = state.lists.firstWhereOrNull((l) => l.id == listId);
      if (updated != null) {
        _currentList = updated;
        notifyListeners();
      }
    }
  }

  void _onManagerChanged() {
    notifyListeners();
  }

  // State accessors
  UnifiedShoppingList? get currentList => _currentList;
  bool get isAddingItem => _itemOperationsManager.isAddingItem;
  bool get hasData => _currentList != null;

  // List properties
  String get listTitle => _currentList?.name ?? AppLocale.current.commonLoading;
  String get listDescription => (_currentList?.description).orEmpty();
  bool get hasDescription => listDescription.isNotEmpty;

  // Permission system - delegate to permission manager
  bool get canEdit => _permissionManager.canEdit;
  bool get canView => _permissionManager.canView;
  bool canEditShoppingList(String listId) =>
      _permissionManager.canEditShoppingList(listId);
  bool canViewShoppingList(String listId) =>
      _permissionManager.canViewShoppingList(listId);

  // Progress tracking
  int get totalItems => _currentList?.totalItems ?? 0;
  int get completedItems => _currentList?.boughtItems ?? 0;
  int get completedItemsCount => completedItems;
  double get completionPercentage => totalItems > 0
      ? (completedItems.toDouble() / totalItems.toDouble()) * 100.0
      : 0.0;

  // Item collections
  List<UnifiedShoppingItem> get activeItems =>
      _currentList?.items.where((item) => !item.bought).toList() ?? [];
  List<UnifiedShoppingItem> get completedItemsList =>
      _currentList?.items.where((item) => item.bought).toList() ?? [];

  // Status and metadata - delegate to display manager
  String get statusText =>
      _displayManager.getStatusText(hasData, totalItems, completedItems);
  String get memberCountText =>
      _displayManager.getMemberCountText(_currentList);
  String get activitySummary =>
      _displayManager.getActivitySummary(_lastActivity, _lastActivityTime);

  Future<void> _initialize() async {
    await executeAsync(() async {
      await _loadList();
    });
  }

  Future<void> _loadList() async {
    try {
      AppLogger.info('📋 Laddar kollaborativ lista: $listId');

      var targetList = _shoppingService.lists.firstWhereOrNull(
        (list) => list.id == listId,
      );

      // If not in memory, try loading from service first
      if (targetList == null) {
        await _shoppingService.loadLists();
        targetList = _shoppingService.lists.firstWhereOrNull(
          (list) => list.id == listId,
        );
      }

      if (targetList != null) {
        _currentList = targetList;
        _updateActivity(AppLocale.current.statusListLoaded, clock.now());
        AppLogger.success('✅ Kollaborativ lista laddad: ${targetList.name}');
      } else {
        AppLogger.error('❌ Kollaborativ lista inte hittad: $listId');
        throw Exception(AppLocale.current.errorListNotFound);
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av kollaborativ lista', e);
      throw Exception(AppLocale.current.errorUnexpected);
    }
  }

  Future<void> refresh() async {
    await executeAsync(() async {
      await _loadList();
    });
  }

  Future<bool> addItem(String itemName) async {
    return await _itemOperationsManager.addItem(
      itemName,
      canEdit,
      () => _loadList(),
      _updateActivity,
    );
  }

  Future<bool> toggleItemCompletion(String itemId) async {
    return await _itemOperationsManager.toggleItemCompletion(
      itemId,
      _currentList,
      canEdit,
      () => _loadList(),
      _updateActivity,
    );
  }

  Future<bool> clearCompletedItems() async {
    return await _shoppingService.clearCompletedItems();
  }

  // --- BUT-238: claim / unclaim ------------------------------------------

  /// Claim an item ("Tar jag"). UI caller inspects [ClaimResult.outcome]:
  /// - [ClaimOutcome.claimed] → happy path.
  /// - [ClaimOutcome.conflict] → show "X tog den" snackbar.
  /// - [ClaimOutcome.denied] / [ClaimOutcome.error] → silent/log.
  Future<ClaimResult> claimItem(String itemId) {
    return _itemOperationsManager.claimItem(
      itemId,
      _currentList,
      canEdit,
      () => _loadList(),
      _updateActivity,
    );
  }

  /// Release a claim ("Lämna tillbaka"). Only the current assignee may
  /// unclaim — others must call [claimItem] to take over.
  Future<ClaimResult> unclaimItem(String itemId) {
    return _itemOperationsManager.unclaimItem(
      itemId,
      _currentList,
      canEdit,
      () => _loadList(),
      _updateActivity,
    );
  }

  /// Current user's Firebase Auth uid. Used by widgets to tag "Min del"
  /// items without touching `PermissionService` directly.
  String? get currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId;

  // --- BUT-238: view mode --------------------------------------------------

  ShoppingViewMode get viewMode => _viewMode;

  void setViewMode(ShoppingViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
  }

  /// Items assigned to the current user, active and unbought.
  List<UnifiedShoppingItem> get myItems {
    final uid = currentUserId;
    if (uid == null) return const [];
    return activeItems.where((i) => i.assignedToUserId == uid).toList();
  }

  /// Items assigned to someone else (not current user), still active.
  /// Kept in one bucket because the split-store UI greys them uniformly.
  List<UnifiedShoppingItem> get othersItems {
    final uid = currentUserId;
    return activeItems
        .where((i) => i.assignedToUserId != null && i.assignedToUserId != uid)
        .toList();
  }

  /// Items without any assignment — the "Otilldelat" bucket.
  List<UnifiedShoppingItem> get unassignedItems {
    return activeItems.where((i) => i.assignedToUserId == null).toList();
  }

  // --- BUT-238: presence ---------------------------------------------------

  /// Active shoppers on this list (for header indicator).
  /// Excludes the current user — header shows peers only.
  List<Map<String, dynamic>> get activeShoppers {
    final uid = currentUserId;
    return _activeShoppers
        .where((row) => row['userId'] != uid)
        .toList(growable: false);
  }

  bool get hasActiveShoppers => activeShoppers.isNotEmpty;

  void _startPresenceTracking() {
    final presence = _presenceModule;
    if (presence == null) return;

    // Fire-and-forget join. Heartbeat keeps the row fresh.
    unawaited(presence.showPresence(listId));
    _heartbeatSubscription = presence.startAutomaticPresenceTracking(listId);

    _presenceSubscription = presence.watchListPresence(listId).listen((rows) {
      if (isDisposed) return;
      _activeShoppers = rows;
      notifyListeners();
    });
  }

  // UI display helpers - delegate to display manager
  Color getStatusColor(ColorScheme cs, ButleryColors butleryColors) =>
      _displayManager.getStatusColor(cs, butleryColors, hasData, statusText);
  Color getProgressColor(ColorScheme cs, ButleryColors butleryColors) =>
      _displayManager.getProgressColor(cs, butleryColors, completionPercentage);
  String? getItemSubtitle(UnifiedShoppingItem item) =>
      _displayManager.getItemSubtitle(item);
  List<Widget> getItemTrailingWidgets(UnifiedShoppingItem item) =>
      _displayManager.getItemTrailingWidgets(item);

  // Private helpers
  @override
  void clearError() {
    // dispose() disposes _itemOperationsManager, so an unguarded call after
    // disposal notifies a dead ChangeNotifier and throws.
    if (isDisposed) return;

    _itemOperationsManager.clearError();
    super.clearError();
  }

  void _updateActivity(String activity, DateTime time) {
    _lastActivity = activity;
    _lastActivityTime = time;
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _presenceSubscription?.cancel();
    _heartbeatSubscription?.cancel();
    // Best-effort: mark ourselves inactive. Race-safe — TTL catches us
    // even if this write never lands (app killed, offline, etc.).
    final presence = _presenceModule;
    if (presence != null) {
      presence.stopAutomaticPresenceTracking(listId);
      unawaited(presence.hidePresence(listId));
    }
    _itemOperationsManager.removeListener(_onManagerChanged);
    _itemOperationsManager.dispose();
    AppLogger.info('🗑️ CollaborativeShoppingViewModel disposed');
    super.dispose();
  }
}
