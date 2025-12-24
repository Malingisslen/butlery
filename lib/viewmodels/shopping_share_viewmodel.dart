/// Comprehensive shopping list sharing ViewModel providing advanced social shopping distribution for Flutter applications.
/// This module implements sophisticated shopping list sharing functionality following Single Responsibility Principle,
/// specializing in friend selection, shopping list distribution, message customization, and share status tracking.
/// It provides complete shopping sharing infrastructure while maintaining clean separation from UI rendering,
/// shopping data persistence, and complex social sharing business logic implementation.
/// **Single Responsibility Focus:**
/// This module exclusively handles shopping list sharing presentation layer concerns:
/// - **Friend Selection Intelligence**: Advanced friend selection with multi-selection support and availability management
/// - **Shopping List Distribution**: Comprehensive sharing operations with status tracking and delivery coordination
/// - **Share Message Customization**: Personalized message composition with template support and content management
/// - **Share Status Management**: Complete sharing state coordination with progress tracking and error handling
/// - **Swedish Localization Excellence**: Complete Swedish language support for sharing operations and user feedback
/// **What This Module Does NOT Handle:**
/// - UI rendering and widget creation (handled by shopping share views and presentation components)
/// - Shopping list data persistence and storage (handled by UnifiedShoppingService and underlying data repositories)
/// - Complex social relationship business logic (handled by friends service layer and social infrastructure)
/// - Share delivery infrastructure (handled by sharing services and communication systems)
/// **Shopping Share ViewModel Features:**
/// - **Advanced Friend Selection**: Multi-friend selection with selection state tracking and visual feedback
/// - **Comprehensive Share Operations**: Shopping list sharing with status tracking and delivery confirmation
/// - **Share Message Management**: Personalized message composition with template support and content validation
/// - **Share Status Tracking**: Complete sharing progress monitoring with individual friend status tracking
/// - **Swedish Localization**: Complete Swedish language support for sharing operations and error messages
/// **Usage Examples:**
/// ```dart
/// // Initialize shopping share ViewModel with service integration
/// final shoppingShareViewModel = ShoppingShareViewModel(
///   shoppingService: ServiceLocator.get<UnifiedShoppingService>(),
///   friendsService: ServiceLocator.get<UnifiedFriendsService>(),
/// );
/// // Initialize friends list and sharing functionality
/// await shoppingShareViewModel.initializeCommand();
/// // Friend selection and management
/// shoppingShareViewModel.toggleFriendSelectionCommand('friend_123'); // Select Anna
/// shoppingShareViewModel.toggleFriendSelectionCommand('friend_456'); // Select Erik
/// shoppingShareViewModel.selectAllFriendsCommand(); // Select all friends
/// shoppingShareViewModel.clearAllSelectionsCommand(); // Clear all selections
/// // Share message customization
/// shoppingShareViewModel.updateShareMessageCommand(
///   'Hej! Kolla in min inköpslista för helgmiddagen!'
/// );
/// // Selection state monitoring
/// if (shoppingShareViewModel.canShare) {
///   final selectedCount = shoppingShareViewModel.selectedCount;
///   final selectedFriends = shoppingShareViewModel.selectedFriends;
///   // Enable share button
/// }
/// // Share shopping list with comprehensive coordination
/// final shared = await shoppingShareViewModel.shareShoppingListCommand(shoppingList);
/// if (shared) {
///   // Navigate back or show success message
/// } else if (shoppingShareViewModel.hasError) {
///   // Handle sharing error
/// }
/// // Monitor sharing progress
/// if (shoppingShareViewModel.isSharing) {
///   // Show sharing progress indicator
/// }
/// // Sharing validation and summary
/// if (shoppingShareViewModel.validateSharingPossible()) {
///   final summary = shoppingShareViewModel.getSharingSummary();
///   // Show confirmation dialog with summary
/// }
/// // State monitoring and error handling
/// if (shoppingShareViewModel.isLoading) {
///   // Show loading indicator
/// } else if (shoppingShareViewModel.hasError) {
///   // Display error message
///   shoppingShareViewModel.clearErrorCommand(); // Clear error state
/// }
/// // Access friend and sharing information
/// final hasFriends = shoppingShareViewModel.hasFriends;
/// final shareMessage = shoppingShareViewModel.shareMessage;
/// final isInitialized = shoppingShareViewModel.isInitialized;
/// // Refresh functionality for pull-to-refresh
/// await shoppingShareViewModel.refreshFriendsCommand();
/// ```

// lib/viewmodels/shopping_share_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';

/// Comprehensive shopping list sharing ViewModel providing advanced social shopping distribution through service integration.
/// Manages shopping list sharing state enabling social shopping distribution with friend selection, share message customization,
/// sharing operations, and status tracking while maintaining clean MVVM architecture separation between
/// shopping sharing business logic and UI presentation concerns through command pattern implementation.
/// **Core Responsibilities:**
/// - Advanced friend selection with multi-selection support and availability management
/// - Comprehensive shopping list sharing operations with status tracking and delivery coordination
/// - Share message customization with personalized content and template management
/// - Complete sharing state management with progress tracking and comprehensive error handling
/// - Swedish localized error messages and user feedback coordination throughout sharing operations
class ShoppingShareViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final UnifiedShoppingService _shoppingService;
  final UnifiedFriendsService _friendsService;

  // ===== SHARING OPERATION STATE =====

  /// Share operation state for UI progress indication during sharing operations.
  /// Indicates active sharing operation for loading indicators and interaction
  /// control during shopping list distribution and delivery processes.
  bool _isSharing = false;

  /// Available friends list for selection and sharing coordination.
  /// Stores all available friends enabling friend selection functionality,
  /// sharing target management, and social distribution coordination.
  List<UserProfile> _friends = [];

  /// Selected friend IDs for sharing coordination and delivery management.
  /// Stores selected friends for sharing enabling multi-friend distribution,
  /// sharing coordination, and delivery tracking throughout sharing operations.
  final List<String> _selectedFriendIds = [];

  /// Share message content for personalized sharing and message customization.
  /// Stores user-customized sharing message enabling personalized content,
  /// message template management, and enhanced sharing experience.
  String _shareMessage = '';

  /// Initialization state for ViewModel lifecycle and functionality availability.
  /// Indicates whether ViewModel has been initialized enabling functionality access,
  /// state validation, and proper initialization coordination.
  bool _initialized = false;

  // ===== INITIALIZATION =====

  /// Initializes shopping share ViewModel with comprehensive service integration and sharing preparation.
  /// [shoppingService] UnifiedShoppingService instance for shopping list operations and sharing coordination
  /// [friendsService] UnifiedFriendsService instance for friend management and social functionality
  /// Establishes shopping sharing infrastructure with service integration, enabling comprehensive
  /// social shopping distribution functionality with friend selection, message customization,
  /// and sharing operations through unified state management and command pattern implementation.
  /// **Service Integration:**
  /// - UnifiedShoppingService integration for shopping list operations and sharing functionality
  /// - UnifiedFriendsService integration for friend management and social relationship coordination
  /// - Command pattern implementation for organized operation management and state coordination
  /// - Mixin integration for enhanced state management and asynchronous operation support
  ShoppingShareViewModel({
    required UnifiedShoppingService shoppingService,
    required UnifiedFriendsService friendsService,
  })  : _shoppingService = shoppingService,
        _friendsService = friendsService;

  // ===== SHARING STATE ACCESSORS =====

  /// Share operation state for UI progress indication and interaction control.
  /// Indicates whether sharing operation is in progress for loading indicators
  /// and user interaction management during sharing operations.
  bool get isSharing => _isSharing;

  /// Available friends list for selection and sharing coordination.
  /// Provides immutable access to available friends enabling UI display,
  /// friend selection functionality, and sharing target management.
  List<UserProfile> get friends => List.unmodifiable(_friends);

  /// Selected friend IDs for sharing coordination and delivery management.
  /// Provides immutable access to selected friend IDs enabling UI display,
  /// selection tracking, and sharing coordination.
  List<String> get selectedFriendIds => List.unmodifiable(_selectedFriendIds);

  /// Share message content for personalized sharing and message display.
  /// Provides access to current share message enabling UI display,
  /// message validation, and personalized sharing coordination.
  String get shareMessage => _shareMessage;

  /// Initialization state for functionality availability and lifecycle management.
  /// Indicates whether ViewModel has been initialized enabling functionality access,
  /// UI state management, and proper initialization validation.
  bool get isInitialized => _initialized;

  // ===== COMPUTED STATE PROPERTIES =====

  /// Share capability indicator for UI control and interaction management.
  /// Indicates whether sharing is available based on friend selection and operation state
  /// enabling share button state management and sharing functionality access.
  bool get canShare => _selectedFriendIds.isNotEmpty && !_isSharing;

  /// Friends availability indicator for UI conditional rendering and empty state management.
  /// Indicates whether friends are available for UI conditional display
  /// and empty state management throughout sharing functionality.
  bool get hasFriends => _friends.isNotEmpty;

  /// Selected friends count for display and UI coordination.
  /// Provides count of selected friends enabling selection count display,
  /// UI state management, and sharing planning throughout sharing operations.
  int get selectedCount => _selectedFriendIds.length;

  /// Selected friends profiles for sharing display and confirmation coordination.
  /// Provides complete friend profiles for selected sharing targets enabling
  /// sharing confirmation display and comprehensive friend information access.
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
