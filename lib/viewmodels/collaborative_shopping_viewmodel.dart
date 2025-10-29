/// ViewModel managing collaborative shopping lists with real-time coordination and item management.

// lib/viewmodels/collaborative_shopping_viewmodel.dart

import 'package:flutter/material.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_permission_manager.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_display_manager.dart';

class CollaborativeShoppingViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final UnifiedShoppingService _shoppingService;
  final String listId;

  late final ShoppingPermissionManager _permissionManager;
  late final ShoppingItemOperationsManager _itemOperationsManager;
  late final ShoppingDisplayManager _displayManager;

  UnifiedShoppingList? _currentList;
  String _lastActivity = '';
  DateTime _lastActivityTime = DateTime.now();

  CollaborativeShoppingViewModel({
    required this.listId,
    UnifiedShoppingService? shoppingService,
    UserService? userService,
  }) : _shoppingService = shoppingService ?? ServiceLocator.get<UnifiedShoppingService>() {
    _permissionManager = ShoppingPermissionManager(listId);
    _itemOperationsManager = ShoppingItemOperationsManager(_shoppingService, listId);
    _displayManager = ShoppingDisplayManager();

    _itemOperationsManager.addListener(_onManagerChanged);

    _initialize();
  }

  void _onManagerChanged() {
    notifyListeners();
  }

  // State accessors
  UnifiedShoppingList? get currentList => _currentList;
  bool get isAddingItem => _itemOperationsManager.isAddingItem;
  bool get hasData => _currentList != null;

  // List properties
  String get listTitle => _currentList?.name ?? 'Laddar...';
  String get listDescription => _currentList?.description ?? '';
  bool get hasDescription => listDescription.isNotEmpty;

  // Permission system - delegate to permission manager
  bool get canEdit => _permissionManager.canEdit;
  bool get canView => _permissionManager.canView;
  bool canEditShoppingList(String listId) => _permissionManager.canEditShoppingList(listId);
  bool canViewShoppingList(String listId) => _permissionManager.canViewShoppingList(listId);

  // Progress tracking
  int get totalItems => _currentList?.totalItems ?? 0;
  int get completedItems => _currentList?.boughtItems ?? 0;
  int get completedItemsCount => completedItems;
  double get completionPercentage =>
      totalItems > 0 ? (completedItems.toDouble() / totalItems.toDouble()) * 100.0 : 0.0;

  // Item collections
  List<UnifiedShoppingItem> get activeItems =>
      _currentList?.items.where((item) => !item.bought).toList() ?? [];
  List<UnifiedShoppingItem> get completedItemsList =>
      _currentList?.items.where((item) => item.bought).toList() ?? [];

  // Status and metadata - delegate to display manager
  String get statusText => _displayManager.getStatusText(hasData, totalItems, completedItems);
  String get memberCountText => _displayManager.getMemberCountText(_currentList);
  String get activitySummary => _displayManager.getActivitySummary(_lastActivity, _lastActivityTime);

  Future<void> _initialize() async {
    await executeAsync(() async {
      await _loadList();
    });
  }

  Future<void> _loadList() async {
    try {
      AppLogger.info('📋 Laddar kollaborativ lista: $listId');

      final targetList = _shoppingService.lists
          .cast<UnifiedShoppingList?>()
          .firstWhere((list) => list?.id == listId, orElse: () => null);

      if (targetList != null) {
        _currentList = targetList;
        _updateActivity('Lista laddad', DateTime.now());
        AppLogger.success('✅ Kollaborativ lista laddad: ${targetList.name}');
      } else {
        AppLogger.error('❌ Kollaborativ lista inte hittad: $listId');
        throw Exception('Lista hittades inte');
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av kollaborativ lista', e);
      throw Exception('Kunde inte ladda lista: $e');
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

  // UI display helpers - delegate to display manager
  Color getStatusColor() => _displayManager.getStatusColor(hasData, statusText);
  Color getProgressColor() => _displayManager.getProgressColor(completionPercentage);
  String? getItemSubtitle(UnifiedShoppingItem item) => _displayManager.getItemSubtitle(item);
  List<Widget> getItemTrailingWidgets(UnifiedShoppingItem item) =>
      _displayManager.getItemTrailingWidgets(item);

  // Private helpers
  @override
  void clearError() {
    _itemOperationsManager.clearError();
    setError('');
  }

  void _updateActivity(String activity, DateTime time) {
    _lastActivity = activity;
    _lastActivityTime = time;
  }

  @override
  void dispose() {
    _itemOperationsManager.removeListener(_onManagerChanged);
    _itemOperationsManager.dispose();
    AppLogger.info('🗑️ CollaborativeShoppingViewModel disposed');
    super.dispose();
  }
}
