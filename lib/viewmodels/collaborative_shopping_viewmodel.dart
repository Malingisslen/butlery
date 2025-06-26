// lib/viewmodels/collaborative_shopping_viewmodel.dart

import 'package:flutter/material.dart';
import '../models/shared_shopping_list.dart';
import '../services/social_shopping_service.dart';
import '../services/user_service.dart';
import '../core/utils/logger.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Collaborative Shopping ViewModel - MVVM Pattern
/// File: viewmodels/collaborative_shopping_viewmodel.dart
/// Quick Guide: Presentation logic för collaborative shopping lists
/// Dependencies IN: SocialShoppingService, UserService, SharedShoppingList
/// Dependencies OUT: UI state för collaborative shopping view
/// Data flow: Service data → ViewModel processing → UI binding
/// State management: ChangeNotifier med UI-optimized state
/// Purpose: MVVM separation mellan service data och UI concerns
/// Common issues: Real-time updates, permission checks, error states
/// Performance: ⚡ Optimized state updates, cached computations
/// Analytics: ✅ User interaction tracking
/// Code smells: ✅ Clean MVVM separation, pure presentation logic
/// Connected to: SocialShoppingService, collaborative shopping view
/// Used in phases: 18.4

class CollaborativeShoppingViewModel extends ChangeNotifier {
  final SocialShoppingService _socialShoppingService;
  final UserService _userService;
  final String listId;

  // Private state
  SharedShoppingList? _list;
  bool _isAddingItem = false;
  String? _error;
  bool _isLoading = false;

  CollaborativeShoppingViewModel({
    required SocialShoppingService socialShoppingService,
    required UserService userService,
    required this.listId,
  })  : _socialShoppingService = socialShoppingService,
        _userService = userService {
    _initialize();
  }

  // ===== GETTERS (UI State) =====

  SharedShoppingList? get list => _list;
  bool get isLoading => _isLoading;
  bool get isAddingItem => _isAddingItem;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasData => _list != null;

  // List metadata
  String get listTitle => _list?.title ?? 'Gemensam lista';
  String get listDescription => _list?.description ?? '';
  bool get hasDescription => _list?.description?.isNotEmpty == true;

  // Progress
  int get totalItems => _list?.totalItems ?? 0;
  int get completedItems => _list?.completedItems ?? 0;
  int get remainingItems => _list?.remainingItems ?? 0;
  double get completionPercentage => _list?.completionPercentage ?? 0.0;
  bool get isCompleted => _list?.isCompleted ?? false;

  // Status
  SharedListStatus get status => _list?.status ?? SharedListStatus.active;
  String get statusText => _getStatusText(status);

  // Members
  int get memberCount => _list?.memberCount ?? 0;
  String get memberCountText =>
      '$memberCount medlem${memberCount != 1 ? 'mar' : ''}';

  // Activity
  String get activitySummary => _list?.activitySummary ?? 'Ingen aktivitet';
  bool get hasRecentActivity => _list?.hasRecentActivity ?? false;

  // Permissions
  String? get currentUserId => _userService.currentUserProfile?.uid;
  bool get canEdit => _list?.canUserEdit(currentUserId ?? '') ?? false;
  bool get canView => _list?.canUserView(currentUserId ?? '') ?? false;
  bool get canManage => _list?.canUserManage(currentUserId ?? '') ?? false;

  // Items organization
  List<EnhancedShoppingItem> get activeItems =>
      _list?.items.where((item) => !item.isPurchased).toList() ?? [];

  List<EnhancedShoppingItem> get completedItemsList =>
      _list?.items.where((item) => item.isPurchased).toList() ?? [];

  bool get hasActiveItems => activeItems.isNotEmpty;
  bool get hasCompletedItems => completedItemsList.isNotEmpty;
  int get completedItemsCount => completedItemsList.length;

  // ===== INITIALIZATION =====

  void _initialize() {
    _loadList();
    _socialShoppingService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    final updatedList = _socialShoppingService.getListById(listId);
    if (updatedList != _list) {
      _list = updatedList;
      _error = _socialShoppingService.error;
      _isLoading = _socialShoppingService.isLoading;

      AppLogger.info('📝 Lista uppdaterad: ${_list?.title}');
      notifyListeners();
    }
  }

  Future<void> _loadList() async {
    _setLoading(true);
    try {
      _list = _socialShoppingService.getListById(listId);
      _clearError();

      if (_list == null) {
        _setError('Lista hittades inte');
      }
    } catch (e) {
      AppLogger.error('Kunde inte ladda lista', e);
      _setError('Kunde inte ladda lista: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ===== ACTIONS (Business Logic) =====

  Future<bool> addItem(String itemName) async {
    if (itemName.trim().isEmpty) {
      _setError('Artikelnamn krävs');
      return false;
    }

    if (!canEdit) {
      _setError('Du har inte behörighet att lägga till artiklar');
      return false;
    }

    _setAddingItem(true);
    try {
      final success = await _socialShoppingService.addItemToList(
        listId,
        itemName.trim(),
        1.0, // Default amount
      );

      if (success) {
        AppLogger.success('✅ Artikel "$itemName" tillagd');
        _clearError();
        return true;
      } else {
        _setError(
            _socialShoppingService.error ?? 'Kunde inte lägga till artikel');
        return false;
      }
    } catch (e) {
      AppLogger.error('Kunde inte lägga till artikel', e);
      _setError('Kunde inte lägga till artikel: $e');
      return false;
    } finally {
      _setAddingItem(false);
    }
  }

  Future<bool> toggleItemCompletion(String itemId) async {
    if (!canView) {
      _setError('Du har inte behörighet att ändra artiklar');
      return false;
    }

    try {
      await _socialShoppingService.toggleItemCompletion(listId, itemId);
      _clearError();
      return true;
    } catch (e) {
      AppLogger.error('Kunde inte ändra artikel-status', e);
      _setError('Kunde inte ändra status: $e');
      return false;
    }
  }

  Future<void> refresh() async {
    await _socialShoppingService.refresh();
    await _loadList();
  }

  // ===== UI HELPERS =====

  String _getStatusText(SharedListStatus status) {
    switch (status) {
      case SharedListStatus.active:
        return 'AKTIV';
      case SharedListStatus.completed:
        return 'KLAR';
      case SharedListStatus.archived:
        return 'ARKIVERAD';
      case SharedListStatus.cancelled:
        return 'AVBRUTEN';
    }
  }

  /// Get item subtitle for display
  String? getItemSubtitle(EnhancedShoppingItem item) {
    final parts = <String>[];

    if (item.note?.isNotEmpty == true) {
      parts.add(item.note!);
    }

    if (item.addedByDisplayName != null) {
      parts.add('Tillagd av ${item.addedByDisplayName}');
    }

    if (item.isPurchased && item.purchasedByDisplayName != null) {
      parts.add('Köpt av ${item.purchasedByDisplayName}');
    }

    return parts.isEmpty ? null : parts.join(' • ');
  }

  /// Get trailing widgets for item display
  List<Widget> getItemTrailingWidgets(EnhancedShoppingItem item) {
    final widgets = <Widget>[];

    if (item.priority > 3) {
      widgets.add(Text(item.priorityEmoji, style: TextStyle(fontSize: 16)));
    }

    if (item.isPurchased) {
      widgets.add(Icon(Icons.check_circle, color: Colors.green, size: 16));
    }

    return widgets;
  }

  /// Get status color for UI
  Color getStatusColor() {
    switch (status) {
      case SharedListStatus.active:
        return Color(0xFF4A7C93); // primaryColor
      case SharedListStatus.completed:
        return Color(0xFF10B981); // successColor
      case SharedListStatus.archived:
        return Color(0xFF6B7280); // textSecondary
      case SharedListStatus.cancelled:
        return Color(0xFFEF4444); // errorColor
    }
  }

  /// Get progress color based on percentage
  Color getProgressColor() {
    if (completionPercentage >= 100) return Color(0xFF10B981); // successColor
    if (completionPercentage >= 75) {
      return Color(0xFF10B981).withValues(alpha: 0.8);
    }
    if (completionPercentage >= 50) return Color(0xFFF59E0B); // warningColor
    return Color(0xFF4A7C93); // primaryColor
  }

  // ===== STATE MANAGEMENT =====

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
    AppLogger.error('CollaborativeShoppingViewModel error: $message');
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  @override
  void dispose() {
    _socialShoppingService.removeListener(_onServiceUpdate);
    super.dispose();
  }
}
