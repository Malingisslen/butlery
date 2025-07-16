// lib/viewmodels/friends_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/friend_request.dart';
import '../models/friend_category.dart';
import '../services/unified/unified_friends_service.dart';
import '../services/user_service.dart';
import '../services/permission_service.dart';
import '../core/utils/logger.dart'; // ✅ NYTT: För AppLogger

/// Represents the friendship status between two users
enum FriendshipStatus {
  /// Not friends and no pending requests
  none,
  /// Are friends
  friends,
  /// Current user has sent a request to the other user
  requestSent,
  /// Current user has received a request from the other user
  requestReceived,
  /// User is blocked
  blocked,
}


class FriendsViewModel extends ChangeNotifier {
  final UnifiedFriendsService _friendsService;
  final UserService _userService;
  final PermissionService _permissionService;

  // ✅ NYTT: Dispose-säkerhet
  bool _isDisposed = false;

  // Search state
  String _searchQuery = '';
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  // Selection state (för bulk operations)
  final Set<String> _selectedFriendIds = {};

  // ✅ UserProfile cache för request användare
  final Map<String, UserProfile> _requestUserProfiles = {};
  bool _isLoadingUserProfiles = false;

  // ✅ NYTT: Group creation state
  bool _isCreatingGroup = false;
  String? _groupCreationError;

  FriendsViewModel({
    required UnifiedFriendsService friendsService,
    required UserService userService,
    required PermissionService permissionService,
  })  : _friendsService = friendsService,
        _userService = userService,
        _permissionService = permissionService {
    // ✅ NYTT
    // ✅ VIKTIGT: Registrera listeners vid skapandet
    AppLogger.info('🔄 Registrerar ViewModel listeners...');
    _friendsService.addListener(_onFriendsServiceChanged);
    _userService.addListener(_onUserServiceChanged);
    AppLogger.success('✅ Alla ViewModel listeners registrerade');
  }

  // ===== GETTERS =====

  // Friends data from unified service
  List<UserProfile> get friends => _friendsService.friends;
  List<FriendRequest> get incomingRequests => _friendsService.incomingRequests;
  List<FriendRequest> get sentRequests => _friendsService.outgoingRequests;
  int get friendsCount => _friendsService.friends.length;
  int get pendingRequestsCount => _friendsService.incomingRequests.length;

  // Group data from unified friends service
  List<FriendCategory> get groups => _friendsService.categoriesList;
  List<FriendCategory> get groupsWithFriends => _friendsService.categoriesList
      .where((category) => category.friendCount > 0).toList();
  bool get isLoadingGroups => _friendsService.isLoading;
  String? get groupsError => _friendsService.error;
  int get groupsCount => groups.length;

  // Search state
  String get searchQuery => _searchQuery;
  List<UserProfile> get searchResults => List.unmodifiable(_searchResults);
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  bool get hasSearchResults => _searchResults.isNotEmpty;
  bool get hasSearchQuery => _searchQuery.isNotEmpty;

  // Service state
  bool get isLoading =>
      _friendsService.isLoading || _isLoadingUserProfiles || _isCreatingGroup;
  String? get error => _friendsService.error ?? _groupCreationError;
  bool get hasError => _friendsService.hasError || _groupCreationError != null;

  // Selection state
  Set<String> get selectedFriendIds => Set.unmodifiable(_selectedFriendIds);
  bool get hasSelectedFriends => _selectedFriendIds.isNotEmpty;
  int get selectedFriendsCount => _selectedFriendIds.length;

  // ✅ NYTT: Group creation state
  bool get isCreatingGroup => _isCreatingGroup;
  String? get groupCreationError => _groupCreationError;

  // ✅ UserProfile getters
  /// Hämta UserProfile för en användare i vänskapsförfrågningar
  UserProfile? getUserProfile(String userId) {
    return _requestUserProfiles[userId];
  }

  /// Kontrollera om vi laddar användaruppgifter
  bool get isLoadingUserProfiles => _isLoadingUserProfiles;

  // ===== SEARCH ACTIONS =====

  /// Update search query and trigger search
  Future<void> updateSearch(String query) async {
    _searchQuery = query.trim();

    if (_searchQuery.isEmpty) {
      _clearSearch();
      return;
    }

    if (_searchQuery.length < 2) {
      _searchResults = [];
      _searchError = 'Skriv minst 2 tecken för att söka';
      notifyListeners();
      return;
    }

    await _performSearch();
  }

  /// Clear search results
  void clearSearch() {
    _clearSearch();
    notifyListeners();
  }

  // ===== FRIEND REQUEST ACTIONS =====

  /// Send friend request to user
  Future<bool> sendFriendRequest(String userId, {String? message}) async {
    final success = await _friendsService.management.sendFriendRequest(userId, message: message);

    if (success) {
      // Remove from search results to show updated state
      _searchResults.removeWhere((user) => user.uid == userId);
      notifyListeners();
    }

    return success;
  }

  /// Accept incoming friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    return await _friendsService.management.acceptFriendRequest(requestId);
  }

  /// Reject incoming friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    return await _friendsService.management.rejectFriendRequest(requestId);
  }

  /// Cancel sent friend request
  Future<bool> cancelSentRequest(String requestId) async {
    return await _friendsService.management.cancelFriendRequest(requestId);
  }

  /// Remove friend (unfriend)
  Future<bool> removeFriend(String friendUserId) async {
    final success = await _friendsService.management.removeFriend(friendUserId);

    if (success) {
      // Clear selection if removed friend was selected
      _selectedFriendIds.remove(friendUserId);
      notifyListeners();
    }

    return success;
  }

  // ===== ✅ NYTT: GROUP ACTIONS =====

  /// Skapa ny grupp
  Future<bool> createGroup({
    required String name,
    String? description,
    String? emoji,
    List<String>? selectedFriendIds,
  }) async {
    try {
      _isCreatingGroup = true;
      _groupCreationError = null;
      notifyListeners();

      AppLogger.info('🔄 Skapar grupp: $name');

      final categoryId = await _friendsService.categories.createCategory(
        name: name,
        description: description ?? '',
        initialMemberIds: selectedFriendIds,
      );

      final success = categoryId != null;
      if (success) {
        AppLogger.success('✅ Grupp "$name" skapad!');
      } else {
        _groupCreationError = _friendsService.error ?? 'Kunde inte skapa grupp';
      }

      return success;
    } catch (e) {
      AppLogger.error('❌ Fel vid skapande av grupp', e);
      _groupCreationError = 'Fel vid skapande av grupp: $e';
      return false;
    } finally {
      _isCreatingGroup = false;
      notifyListeners();
    }
  }

  /// Hämta vänner för en specifik grupp
  List<UserProfile> getFriendsInGroup(String groupId) {
    return _friendsService.categories.getFriendsInCategory(groupId);
  }

  /// Kontrollera om gruppmamn är tillgängligt
  bool isGroupNameAvailable(String name) {
    return _friendsService.categories.getCategoryByName(name) == null;
  }

  /// Hämta grupper för en specifik vän
  List<FriendCategory> getGroupsForFriend(String friendUserId) {
    return _friendsService.categories.getCategoriesForFriend(friendUserId);
  }

  /// Sök grupper
  List<FriendCategory> searchGroups(String query) {
    if (query.trim().isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _friendsService.categoriesList
        .where((category) => category.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // ===== UTILITY METHODS =====

  /// Get relationship status with user
  FriendshipStatus getFriendshipStatus(String userId) {
    // Check if user is already a friend
    if (_friendsService.friends.any((friend) => friend.uid == userId)) {
      return FriendshipStatus.friends;
    }
    
    // Check if there's an outgoing request
    if (_friendsService.outgoingRequests.any((request) => request.toUserId == userId)) {
      return FriendshipStatus.requestSent;
    }
    
    // Check if there's an incoming request
    if (_friendsService.incomingRequests.any((request) => request.fromUserId == userId)) {
      return FriendshipStatus.requestReceived;
    }
    
    return FriendshipStatus.none;
  }

  /// Get mutual friends with user
  Future<List<UserProfile>> getMutualFriends(String userId) async {
    // TODO: Implement mutual friends in UnifiedFriendsService
    return [];
  }

  /// Check if user can be added as friend
  bool canSendFriendRequest(String userId) {
    if (!_permissionService.isAuthenticated || _permissionService.currentUserId == userId) return false;

    final status = getFriendshipStatus(userId);
    return status == FriendshipStatus.none;
  }

  // ===== SELECTION ACTIONS =====

  /// Toggle friend selection
  void toggleFriendSelection(String friendId) {
    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
    } else {
      _selectedFriendIds.add(friendId);
    }
    notifyListeners();
  }

  /// Select all friends
  void selectAllFriends() {
    _selectedFriendIds.clear();
    _selectedFriendIds.addAll(friends.map((f) => f.uid));
    notifyListeners();
  }

  /// Clear all selections
  void clearSelection() {
    _selectedFriendIds.clear();
    notifyListeners();
  }

  /// Get selected friends as UserProfile objects
  List<UserProfile> getSelectedFriends() {
    return friends.where((f) => _selectedFriendIds.contains(f.uid)).toList();
  }
  
  /// Get profile picture URL for a user
  String? getAvatarUrlForUser(String userId) {
    final profile = getUserProfile(userId);
    return profile?.avatarUrl;
  }

  // ===== USER PROFILE MANAGEMENT =====

  /// Ladda användaruppgifter för alla användare i vänskapsförfrågningar
  Future<void> loadUserProfilesForRequests() async {
    // ✅ SÄKER: Kontrollera dispose innan asynkrona operationer
    if (_isDisposed) return;

    try {
      _isLoadingUserProfiles = true;
      // Don't call notifyListeners() immediately during potential build phase

      // Samla alla unika userId från requests
      final userIds = <String>{};

      // Lägg till från inkommande förfrågningar
      for (final request in incomingRequests) {
        userIds.add(request.fromUserId);
      }

      // Lägg till från skickade förfrågningar
      for (final request in sentRequests) {
        userIds.add(request.toUserId);
      }

      // Ta bort användare vi redan har i cache
      final uncachedUserIds = userIds
          .where((userId) => !_requestUserProfiles.containsKey(userId))
          .toList();

      if (uncachedUserIds.isNotEmpty) {
        AppLogger.info(
          '👥 Laddar ${uncachedUserIds.length} användaruppgifter för förfrågningar',
        );

        // Hämta användaruppgifter i batch för prestanda
        final profiles = await _userService.getUserProfiles(uncachedUserIds);

        // ✅ SÄKER: Kontrollera dispose efter asynkron operation
        if (_isDisposed) return;

        // Uppdatera cache
        for (final profile in profiles) {
          _requestUserProfiles[profile.uid] = profile;
        }

        // Logga resultat
        AppLogger.success(
          '✅ ${profiles.length}/${uncachedUserIds.length} användaruppgifter laddade',
        );

        // Logga saknade profiler (för debugging)
        final loadedIds = profiles.map((p) => p.uid).toSet();
        final missingIds =
            uncachedUserIds.where((id) => !loadedIds.contains(id));
        if (missingIds.isNotEmpty) {
          AppLogger.warning(
            '⚠️ Kunde inte ladda profiler för: ${missingIds.join(', ')}',
          );
        }
      }
    } catch (e) {
      AppLogger.error('❌ Kunde inte ladda användaruppgifter: $e');
    } finally {
      if (!_isDisposed) {
        _isLoadingUserProfiles = false;
        // Use scheduleMicrotask to avoid calling notifyListeners during build
        scheduleMicrotask(() {
          if (!_isDisposed) {
            notifyListeners();
          }
        });
      }
    }
  }

  /// Rensa användaruppgifter cache (användbart vid refresh)
  void clearUserProfilesCache() {
    _requestUserProfiles.clear();
    AppLogger.info('🗑️ Cache för användaruppgifter rensad');
  }

  /// Hämta displayName för en användare (med fallback)
  String getDisplayNameForUser(String userId) {
    final profile = getUserProfile(userId);
    if (profile != null) {
      return profile.displayName;
    }

    // Fallback under laddning
    return 'Användare ${userId.substring(0, 6)}...';
  }

  /// Hämta avatar URL för en användare
  String? getProfilePictureUrlForUser(String userId) {
    final profile = getUserProfile(userId);
    return profile?.avatarUrl;
  }

  /// Kontrollera om en användare är online
  bool isUserOnline(String userId) {
    final profile = getUserProfile(userId);
    return profile?.isOnline ?? false;
  }

  // ===== PRIVATE METHODS =====

  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty) return;

    try {
      _isSearching = true;
      _searchError = null;
      notifyListeners();

      final results = await _friendsService.management.searchUsers(_searchQuery);

      // ✅ SÄKER: Kontrollera dispose efter asynkron operation
      if (_isDisposed) return;

      _searchResults = results;

      AppLogger.info(
        '🔍 Search for "$_searchQuery" returned ${_searchResults.length} results',
      );
    } catch (e) {
      _searchError = 'Sökningen misslyckades: $e';
      AppLogger.error('Search failed', e);
    } finally {
      if (!_isDisposed) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  void _clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _searchError = null;
  }

  // ✅ SÄKRA LISTENER METODER
  void _onFriendsServiceChanged() {
    // ✅ SÄKER: Kontrollera om ViewModel är disposed innan notifiering
    if (!_isDisposed) {
      loadUserProfilesForRequests();
      notifyListeners();
    } else {
      AppLogger.warning(
          '⚠️ Ignorerar friends service change - ViewModel är disposed');
    }
  }

  void _onUserServiceChanged() {
    // ✅ SÄKER: Kontrollera om ViewModel är disposed innan notifiering
    if (!_isDisposed) {
      notifyListeners();
    } else {
      AppLogger.warning(
          '⚠️ Ignorerar user service change - ViewModel är disposed');
    }
  }


  /// Clear errors
  void clearError() {
    if (!_isDisposed) {
      _friendsService.clearError();
      _searchError = null;
      _groupCreationError = null;
      notifyListeners();
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    // ✅ SÄKER: Kontrollera dispose före asynkrona operationer
    if (_isDisposed) return;

    // Rensa cache innan refresh
    clearUserProfilesCache();

    // Note: UnifiedFriendsService handles its own refresh through Firebase listeners
    // No need to manually refresh as it's reactive
    
    // Ladda användaruppgifter för nya förfrågningar
    await loadUserProfilesForRequests();
  }

  @override
  void dispose() {
    // ✅ MARKERA som disposed för säkerhet
    _isDisposed = true;

    // ✅ KRITISK FIX: FriendsViewModel är en SINGLETON som ska leva
    AppLogger.warning(
        '⚠️ FriendsViewModel.dispose() anropad - IGNORERAS för singleton safety');

    // ✅ ANROPA super.dispose() för att uppfylla @mustCallSuper
    // Men ta INTE bort listeners eller rensa state
    super.dispose();
  }
}

