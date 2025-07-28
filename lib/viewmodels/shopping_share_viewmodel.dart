// lib/viewmodels/shopping_share_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';


class ShoppingShareViewModel extends ChangeNotifier with StateNotifierMixin, AsyncOperationMixin {
  final UnifiedShoppingService _shoppingService;
  final UnifiedFriendsService _friendsService;

  // ==================== STATE PROPERTIES ====================

  bool _isSharing = false;
  List<UserProfile> _friends = [];
  final List<String> _selectedFriendIds = [];
  String _shareMessage = '';
  bool _initialized = false;

  // ==================== CONSTRUCTOR ====================

  ShoppingShareViewModel({
    required UnifiedShoppingService shoppingService,
    required UnifiedFriendsService friendsService,
  })  : _shoppingService = shoppingService,
        _friendsService = friendsService;

  // ==================== GETTERS ====================

  bool get isSharing => _isSharing;
  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<String> get selectedFriendIds => List.unmodifiable(_selectedFriendIds);
  String get shareMessage => _shareMessage;
  bool get isInitialized => _initialized;

  // ==================== COMPUTED PROPERTIES ====================

  bool get canShare => _selectedFriendIds.isNotEmpty && !_isSharing;
  bool get hasFriends => _friends.isNotEmpty;
  int get selectedCount => _selectedFriendIds.length;

  List<UserProfile> get selectedFriends {
    return _friends
        .where((friend) => _selectedFriendIds.contains(friend.uid))
        .toList();
  }

  // ==================== INITIALIZATION COMMAND ====================

  /// Command: Initialize ViewModel
  Future<void> initializeCommand() async {
    if (_initialized) return;

    debugPrint('🔄 ShoppingShareViewModel: Initialiserar...');

    _setLoading(true);
    _clearError();

    try {
      await _loadFriends();
      _initialized = true;
      debugPrint('✅ ShoppingShareViewModel: Initiering klar');
    } catch (e) {
      _setError('Kunde inte ladda vänner: $e');
      debugPrint('❌ ShoppingShareViewModel: Initiering misslyckades - $e');
    } finally {
      _setLoading(false);
    }
  }

  // ==================== FRIEND SELECTION COMMANDS ====================

  /// Command: Toggle friend selection
  void toggleFriendSelectionCommand(String friendId) {
    debugPrint('🔄 ShoppingShareViewModel: Togglar vän $friendId');

    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
      debugPrint('   → Avmarkerad');
    } else {
      _selectedFriendIds.add(friendId);
      debugPrint('   → Markerad');
    }

    notifyListeners();
  }

  /// Command: Select all friends
  void selectAllFriendsCommand() {
    debugPrint('🔄 ShoppingShareViewModel: Markerar alla vänner');

    _selectedFriendIds.clear();
    _selectedFriendIds.addAll(_friends.map((f) => f.uid));

    debugPrint('   → ${_selectedFriendIds.length} vänner markerade');
    notifyListeners();
  }

  /// Command: Clear all selections
  void clearAllSelectionsCommand() {
    debugPrint('🔄 ShoppingShareViewModel: Rensar alla markeringar');

    _selectedFriendIds.clear();

    debugPrint('   → Alla markeringar rensade');
    notifyListeners();
  }

  // ==================== MESSAGE COMMANDS ====================

  /// Command: Update share message
  void updateShareMessageCommand(String message) {
    _shareMessage = message.trim();
    notifyListeners();
  }

  // ==================== SHARE COMMANDS ====================

  /// Command: Share shopping list with selected friends - FIXAD VERSION
  Future<bool> shareShoppingListCommand(
      UnifiedShoppingList shoppingList) async {
    if (!canShare) {
      _setError('Kan inte dela - välj minst en vän');
      return false;
    }

    debugPrint(
        '🔄 ShoppingShareViewModel: Delar inköpslista "${shoppingList.name}" med ${_selectedFriendIds.length} vänner');

    _setSharing(true);
    _clearError();

    try {
      // ✅ FIXAT: Använd rätt metod som finns i SocialRecipeService
      // Konvertera UnifiedShoppingList till ShareData format
      final shareData = {
        'type': 'shopping_list',
        'listId': shoppingList.id,
        'listName': shoppingList.name,
        'itemCount': shoppingList.totalItems,
        'items': shoppingList.items
            .map((item) => {
                  'name': item.name,
                  'amount': item.amount,
                  'unit': item.unit,
                  'category': item.category,
                  'bought': item.bought,
                })
            .toList(),
        'message': _shareMessage.isNotEmpty
            ? _shareMessage
            : 'Kolla in min inköpslista!',
        'sharedAt': DateTime.now().toIso8601String(),
      };
      
      debugPrint('Share data prepared: ${shareData['itemCount']} items');

      // Dela med varje vald vän via UnifiedShoppingService
      bool allSuccessful = true;
      for (final friendId in _selectedFriendIds) {
        try {
          final success = await _shoppingService.sharing.shareListWithFriend(
            shoppingList.id,
            friendId,
          );

          if (success) {
            debugPrint('   ✅ Delad med vän: $friendId');
          } else {
            debugPrint('   ❌ Misslyckades med vän $friendId');
            allSuccessful = false;
          }
        } catch (e) {
          debugPrint('   ❌ Misslyckades med vän $friendId: $e');
          allSuccessful = false;
        }
      }

      if (allSuccessful) {
        debugPrint('🎉 ShoppingShareViewModel: Delning slutförd framgångsrikt');
        return true;
      } else {
        _setError('Vissa delningar misslyckades');
        return false;
      }
    } catch (e) {
      _setError('Misslyckades med delning: $e');
      debugPrint('❌ ShoppingShareViewModel: Delning misslyckades - $e');
      return false;
    } finally {
      _setSharing(false);
    }
  }

  // ==================== HELPER COMMANDS ====================

  /// Command: Refresh friends list
  Future<void> refreshFriendsCommand() async {
    debugPrint('🔄 ShoppingShareViewModel: Uppdaterar vänlista');

    _setLoading(true);
    _clearError();

    try {
      await _loadFriends();
      debugPrint('✅ ShoppingShareViewModel: Vänlista uppdaterad');
    } catch (e) {
      _setError('Kunde inte uppdatera vänlista: $e');
      debugPrint(
          '❌ ShoppingShareViewModel: Vänlista-uppdatering misslyckades - $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Command: Clear error
  void clearErrorCommand() {
    _clearError();
  }

  // ==================== PRIVATE HELPER METHODS ====================

  Future<void> _loadFriends() async {
    try {
      _friends = _friendsService.management.getAllFriends();
      debugPrint('   → Laddade ${_friends.length} vänner');
    } catch (e) {
      debugPrint('   ❌ Kunde inte ladda vänner: $e');
      throw Exception('Kunde inte ladda vänner');
    }
  }

  void _setLoading(bool loading) {
    if (isLoading != loading) {
      setLoading(loading);
      notifyListeners();
    }
  }

  void _setSharing(bool sharing) {
    if (_isSharing != sharing) {
      _isSharing = sharing;
      notifyListeners();
    }
  }

  void _setError(String error) {
    setError(error);
  }

  void _clearError() {
    clearError();
  }

  // ==================== VALIDATION METHODS ====================

  /// Validate that sharing is possible
  bool validateSharingPossible() {
    if (_friends.isEmpty) {
      _setError('Du har inga vänner att dela med');
      return false;
    }

    if (_selectedFriendIds.isEmpty) {
      _setError('Välj minst en vän att dela med');
      return false;
    }

    return true;
  }

  /// Get sharing summary for confirmation
  String getSharingSummary() {
    final friendNames = selectedFriends.map((f) => f.displayName).join(', ');
    return 'Dela med: $friendNames';
  }

  // ==================== DISPOSE ====================

  @override
  void dispose() {
    debugPrint('🗑️ ShoppingShareViewModel: Disposing');
    super.dispose();
  }
}
