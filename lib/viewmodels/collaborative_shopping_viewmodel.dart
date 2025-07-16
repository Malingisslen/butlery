// lib/viewmodels/collaborative_shopping_viewmodel.dart

import 'package:flutter/material.dart';
import '../services/unified/unified_shopping_service.dart';
import '../services/user_service.dart';
import '../models/unified/unified_shopping_list.dart';
import '../models/unified/unified_shopping_item.dart';
import '../core/injection.dart';
import '../core/utils/logger.dart';
import '../core/permissions/permission_mixins.dart';
import '../theme/app_theme.dart';


class CollaborativeShoppingViewModel extends ChangeNotifier with BasePermissionMixin, ShoppingListPermissionMixin {
  final UnifiedShoppingService _shoppingService;
  final String listId;

  // Current list state
  UnifiedShoppingList? _currentList;

  // UI state
  bool _isLoading = false;
  bool _isAddingItem = false;
  String? _error;

  // Real-time activity (simulated for now)
  String _lastActivity = '';
  DateTime _lastActivityTime = DateTime.now();

  CollaborativeShoppingViewModel({
    required this.listId,
    UnifiedShoppingService? shoppingService,
    UserService? userService,
  }) : _shoppingService = shoppingService ?? sl<UnifiedShoppingService>() {
    _initialize();
  }

  // ===== GETTERS =====

  UnifiedShoppingList? get currentList => _currentList;
  bool get isLoading => _isLoading;
  bool get isAddingItem => _isAddingItem;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasData => _currentList != null;

  // List properties
  String get listTitle => _currentList?.name ?? 'Laddar...';
  String get listDescription => _currentList?.description ?? '';
  bool get hasDescription => listDescription.isNotEmpty;

  // Permission checks using ShoppingListPermissionMixin
  bool get canEdit => _currentList != null && 
      canEditShoppingList(_currentList!.id);
  bool get canView => _currentList != null && 
      canViewShoppingList(_currentList!.id);

  // Progress tracking
  int get totalItems => _currentList?.totalItems ?? 0;
  int get completedItems => _currentList?.boughtItems ?? 0;
  int get completedItemsCount => completedItems;
  double get completionPercentage =>
      totalItems > 0 ? (completedItems / totalItems) * 100 : 0;

  // Item lists
  List<UnifiedShoppingItem> get activeItems =>
      _currentList?.items.where((item) => !item.bought).toList() ?? [];

  List<UnifiedShoppingItem> get completedItemsList =>
      _currentList?.items.where((item) => item.bought).toList() ?? [];

  // Status and metadata
  String get statusText {
    if (!hasData) return 'Laddar...';
    if (totalItems == 0) return 'Tom lista';
    if (completedItems == totalItems) return 'Klar';
    return 'Pågående';
  }

  String get memberCountText {
    final count = _currentList?.memberCount ?? 0;
    return '$count ${count == 1 ? 'medlem' : 'medlemmar'}';
  }

  String get activitySummary {
    if (_lastActivity.isEmpty) return 'Ingen aktivitet';
    final timeAgo = _getTimeAgo(_lastActivityTime);
    return '$_lastActivity $timeAgo';
  }

  // ===== INITIALIZATION =====

  Future<void> _initialize() async {
    _setLoading(true);
    await _loadList();
    _setLoading(false);
  }

  Future<void> _loadList() async {
    try {
      AppLogger.info('📋 Laddar kollaborativ lista: $listId');

      // Hitta listan i unified service lists
      final targetList = _shoppingService.lists
          .cast<UnifiedShoppingList?>()
          .firstWhere((list) => list?.id == listId, orElse: () => null);

      if (targetList != null) {
        _currentList = targetList;
        _updateActivity('Lista laddad', DateTime.now());
        AppLogger.success('✅ Kollaborativ lista laddad: ${targetList.name}');
      } else {
        _setError('Lista hittades inte');
        AppLogger.error('❌ Kollaborativ lista inte hittad: $listId');
      }
    } catch (e) {
      _setError('Kunde inte ladda lista: $e');
      AppLogger.error('❌ Fel vid laddning av kollaborativ lista', e);
    }
  }

  // ===== PUBLIC ACTIONS =====

  Future<void> refresh() async {
    _clearError();
    await _loadList();
    notifyListeners();
  }

  Future<bool> addItem(String itemName) async {
    if (itemName.trim().isEmpty || !canEdit) return false;

    _setAddingItem(true);

    try {
      AppLogger.info('➕ Lägger till artikel: $itemName');

      // Använd unified service för att lägga till artikel
      final success = await _shoppingService.addItemToActiveList(
        name: itemName.trim(),
        amount: 1.0, // Default amount
        unit: '', // Default unit
        category: 'Övrigt', // Default category
      );

      if (success) {
        await _loadList(); // Uppdatera lokal state
        _updateActivity('La till "$itemName"', DateTime.now());
        AppLogger.success('✅ Artikel tillagd: $itemName');
        return true;
      } else {
        _setError('Kunde inte lägga till artikel');
        AppLogger.error('❌ Kunde inte lägga till artikel: $itemName');
        return false;
      }
    } catch (e) {
      _setError('Fel vid tillägg av artikel: $e');
      AppLogger.error('❌ Exception vid tillägg av artikel', e);
      return false;
    } finally {
      _setAddingItem(false);
    }
  }

  Future<bool> toggleItemCompletion(String itemId) async {
    if (!canView) return false;

    try {
      AppLogger.info('🔄 Växlar artikel status: $itemId');

      // Hitta artikeln lokalt
      final item = _currentList?.items.firstWhere((i) => i.id == itemId);
      if (item == null) return false;

      // Använd unified service
      final success = await _shoppingService.toggleItemBought(itemId);

      if (success) {
        await _loadList(); // Uppdatera lokal state
        _updateActivity(
          item.bought ? 'Markerade som klar' : 'Markerade som ej klar',
          DateTime.now(),
        );
        AppLogger.success('✅ Artikel status växlad: $itemId');
        return true;
      } else {
        _setError('Kunde inte uppdatera artikel');
        AppLogger.error('❌ Kunde inte växla artikel status: $itemId');
        return false;
      }
    } catch (e) {
      _setError('Fel vid uppdatering: $e');
      AppLogger.error('❌ Exception vid växling av artikel status', e);
      return false;
    }
  }

  // ===== UI HELPERS =====

  Color getStatusColor() {
    if (!hasData) return AppTheme.textSecondary;

    switch (statusText) {
      case 'Klar':
        return AppTheme.successColor;
      case 'Pågående':
        return AppTheme.warningColor;
      case 'Tom lista':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color getProgressColor() {
    if (completionPercentage == 100) return AppTheme.successColor;
    if (completionPercentage > 50) return AppTheme.warningColor;
    return AppTheme.primaryColor;
  }

  String? getItemSubtitle(UnifiedShoppingItem item) {
    final parts = <String>[];

    // Kvantitet och enhet
    if (item.amount > 1 || item.unit.isNotEmpty) {
      final quantityText = item.amount > 1 ? '${item.amount}' : '';
      final unitText = item.unit.isNotEmpty ? item.unit : '';
      if (quantityText.isNotEmpty || unitText.isNotEmpty) {
        parts.add('$quantityText $unitText'.trim());
      }
    }

    // Kategori
    if (item.category.isNotEmpty && item.category != 'Övrigt') {
      parts.add(item.category);
    }

    // Status info för köpta artiklar
    if (item.bought) {
      parts.add('✓ Inhandlad');
    }

    return parts.isNotEmpty ? parts.join(' • ') : null;
  }

  List<Widget> getItemTrailingWidgets(UnifiedShoppingItem item) {
    // Enkel implementation - kan utökas med fler widgets
    return [];
  }

  // ===== PRIVATE HELPERS =====

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setAddingItem(bool adding) {
    _isAddingItem = adding;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void clearError() {
    _clearError();
  }

  void _updateActivity(String activity, DateTime time) {
    _lastActivity = activity;
    _lastActivityTime = time;
    // Note: I real implementation, detta skulle skickas till andra användare
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'just nu';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m sedan';
    if (difference.inHours < 24) return '${difference.inHours}h sedan';
    return '${difference.inDays}d sedan';
  }

  // ===== DISPOSE =====

  @override
  void dispose() {
    AppLogger.info('🗑️ CollaborativeShoppingViewModel disposed');
    super.dispose();
  }
}
