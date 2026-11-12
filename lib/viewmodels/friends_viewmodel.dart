/// Friends ViewModel coordinating friend operations (requests, groups, search) with manager delegation.
/// Uses FriendsSearchManager, FriendsProfileCacheManager, FriendsSelectionManager for specialized functionality.

// lib/viewmodels/friends_viewmodel.dart

import 'dart:async';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:flutter/scheduler.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/auth/account_maturity_helper.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/friends/friend_lookups.dart';
import 'package:butlery/viewmodels/friends/friend_request_manager.dart';

export 'package:butlery/viewmodels/friends/friend_lookups.dart'
    show FriendshipStatus;
import 'package:butlery/viewmodels/friends/friends_search_manager.dart';
import 'package:butlery/viewmodels/friends/friends_profile_cache_manager.dart';
import 'package:butlery/viewmodels/friends/friends_selection_manager.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Coordinates social relationship operations through service and manager delegation.
class FriendsViewModel extends BaseViewModel {
  final UnifiedFriendsService _friendsService;
  final UserService _userService;
  final AnalyticsService _analyticsService;
  final PermissionService _permissionService;
  final AccountMaturityHelper _maturityHelper;
  final AuthRepository _authRepository;
  final AuthService? _authService;

  late final FriendsSearchManager _searchManager;
  late final FriendsProfileCacheManager _profileCacheManager;
  late final FriendsSelectionManager _selectionManager;
  late final FriendRequestManager _requests;
  late final FriendLookups _lookups;

  StreamSubscription? _friendsServiceSubscription;
  bool _isDisposed = false;
  bool _notifyScheduled = false;
  bool _isCreatingGroup = false;
  String? _groupCreationError;

  FriendsViewModel({
    required UnifiedFriendsService friendsService,
    required UserService userService,
    AnalyticsService? analyticsService,
    PermissionService? permissionService,
    AccountMaturityHelper? maturityHelper,
    AuthRepository? authRepository,
    AuthService? authService,
  }) : _friendsService = friendsService,
       _userService = userService,
       _analyticsService =
           analyticsService ?? ServiceLocator.get<AnalyticsService>(),
       _permissionService =
           permissionService ?? ServiceLocator.get<PermissionService>(),
       _maturityHelper = maturityHelper ?? AccountMaturityHelper(),
       _authRepository = authRepository ?? ServiceLocator.get<AuthRepository>(),
       _authService = authService ?? ServiceLocator.tryGet<AuthService>() {
    _searchManager = FriendsSearchManager(friendsService: friendsService);
    _profileCacheManager = FriendsProfileCacheManager(userService: userService);
    _selectionManager = FriendsSelectionManager();
    _lookups = FriendLookups(friendsService);
    _requests = FriendRequestManager(
      friendsService: friendsService,
      userService: userService,
      analyticsService: _analyticsService,
      authService: _authService,
      isAccountMatured: () => isAccountMatured,
      isDisposed: () => _isDisposed,
      hasSearchQuery: () => hasSearchQuery,
      incomingRequests: () => incomingRequests,
      onChanged: notifyListeners,
    );

    AppLogger.info('Registering Friends ViewModel service listeners...');
    _friendsServiceSubscription = _friendsService.stateStream.listen(
      (_) => _onFriendsServiceChanged(),
    );
    _userService.addListener(_onUserServiceChanged);
    _searchManager.addListener(_onSearchChanged);
    _profileCacheManager.addListener(_onProfileCacheChanged);
    _selectionManager.addListener(_onSelectionChanged);
    AppLogger.success(
      'All Friends ViewModel listeners registered successfully',
    );

    Future.delayed(Duration.zero, () {
      if (!_isDisposed) {
        _loadUserProfilesForRequests();
      }
    });
  }

  // Coalesce rapid-fire notifications into max 1 per frame to prevent
  // Consumer rebuild saturation that freezes the UI on Android.
  @override
  void notifyListeners() {
    if (_isDisposed || _notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_isDisposed) {
        super.notifyListeners();
      }
    });
  }

  List<UserProfile> get friends => _friendsService.friends;
  List<FriendRequest> get incomingRequests => _friendsService.incomingRequests;
  List<FriendRequest> get sentRequests => _friendsService.outgoingRequests;
  int get friendsCount => _friendsService.friends.length;
  int get pendingRequestsCount => _friendsService.incomingRequests.length;

  List<FriendCategory> get groups => _friendsService.categoriesList;
  List<FriendCategory> get groupsWithFriends => _friendsService.categoriesList
      .where((category) => category.friendCount > 0)
      .toList();
  bool get isLoadingGroups => _friendsService.isLoading;
  String? get groupsError => _friendsService.error;
  int get groupsCount => groups.length;

  /// Current search query
  String get searchQuery => _searchManager.searchQuery;

  /// Search results for user discovery
  List<UserProfile> get searchResults => _searchManager.searchResults;

  /// Whether a network search is in progress
  bool get isSearching => _searchManager.isSearching;

  /// Search error message
  String? get searchError => _searchManager.searchError;

  /// True when the last search failed because the backend was unavailable
  /// (BUT-1442) — the view shows a degraded notice instead of "no users found".
  bool get searchDegraded => _searchManager.searchDegraded;

  /// Search results availability
  bool get hasSearchResults => _searchManager.hasSearchResults;

  /// Search query presence
  bool get hasSearchQuery => _searchManager.hasSearchQuery;

  /// Comprehensive loading state combining all operations
  @override
  bool get isLoading =>
      _friendsService.isLoading ||
      _profileCacheManager.isLoadingUserProfiles ||
      _isCreatingGroup;

  /// Comprehensive error state.
  ///
  /// `super.error` (the BaseViewModel-set message) is appended LAST so an
  /// explicit `setError(...)` actually surfaces. Without it this
  /// override shadowed the mixin's `_error`, so `setError` writes were
  /// invisible. Placed last to preserve the existing precedence of the
  /// service/group/search errors.
  @override
  String? get error =>
      _friendsService.error ??
      _groupCreationError ??
      _searchManager.searchError ??
      super.error;

  /// Error presence indicator.
  ///
  /// Mirrors the [error] getter: includes `super.hasError` so an explicit
  /// `setError(...)` registers as present.
  @override
  bool get hasError =>
      _friendsService.hasError ||
      _groupCreationError != null ||
      _searchManager.searchError != null ||
      super.hasError;

  /// Selected friend IDs
  Set<String> get selectedFriendIds => _selectionManager.selectedFriendIds;

  /// Friend selection availability
  bool get hasSelectedFriends => _selectionManager.hasSelectedFriends;

  /// Selected friends count
  int get selectedFriendsCount => _selectionManager.selectedFriendsCount;

  /// Group creation operation state for UI progress indication during group formation.
  /// Indicates active group creation for loading indicators and interaction
  /// control during group creation operations.
  bool get isCreatingGroup => _isCreatingGroup;

  /// Group creation error message for user feedback and creation error recovery.
  /// Provides group creation specific error messages for comprehensive error
  /// handling and user guidance during group formation.
  String? get groupCreationError => _groupCreationError;

  /// Retrieves cached user profile
  UserProfile? getUserProfile(String userId) =>
      _profileCacheManager.getUserProfile(userId);

  /// User profile loading state
  bool get isLoadingUserProfiles => _profileCacheManager.isLoadingUserProfiles;

  /// Updates search query with validation and search execution
  Future<void> updateSearch(String query) => _searchManager.updateSearch(query);

  /// Clears search results and state
  void clearSearch() => _searchManager.clearSearch();

  /// True when the current account has passed the anti-spam maturity gate.
  /// Unmatured accounts should see guidance instead of a raw permission-denied.
  bool get isAccountMatured => _maturityHelper.isMatured(
    profile: _userService.currentUserProfile,
    firebaseUser: _authRepository.currentUser,
  );

  bool isSendingTo(String userId) => _requests.isSendingTo(userId);

  bool isAccepting(String requestId) => _requests.isAccepting(requestId);

  bool get blockedByUnverifiedEmail => _requests.blockedByUnverifiedEmail;

  Future<bool> resendVerificationEmail() => _requests.resendVerificationEmail();

  Future<bool> sendFriendRequest(String userId, {String? message}) =>
      _requests.sendFriendRequest(userId, message: message);

  /// Block a user. The service also drops the friendship and cancels pending
  /// requests both ways — unblocking does not restore any of it, and it is the
  /// service that records the analytics, so a caller that skips this ViewModel
  /// still counts.
  Future<BlockOutcome> blockUser(String userId) async {
    final outcome = await _friendsService.management.blockUser(userId);
    if (outcome.blockLanded) notifyListeners();
    return outcome;
  }

  /// Whether [userId] is blocked, read straight from the blocked set.
  ///
  /// Deliberately NOT [getFriendshipStatus]. That method answers with a
  /// single enum and tests `friends` / `requestSent` / `requestReceived`
  /// BEFORE `blocked`, so while a block's cleanup is still in flight — or
  /// failed — it answers `friends` about someone who IS blocked. Every
  /// surface whose job is to hide or gate a blocked person asks this
  /// instead, so the safety answer never depends on the read order
  /// (BUT-2022). The asymmetry between the two is the decision.
  bool isBlocked(String userId) => _friendsService.management.isBlocked(userId);

  /// Unblock a user
  Future<bool> unblockUser(String userId) async {
    final success = await _friendsService.management.unblockUser(userId);
    if (success) notifyListeners();
    return success;
  }

  Future<bool> acceptFriendRequest(String requestId) =>
      _requests.acceptFriendRequest(requestId);

  Future<bool> rejectFriendRequest(String requestId) =>
      _requests.rejectFriendRequest(requestId);

  Future<bool> cancelSentRequest(String requestId) =>
      _requests.cancelSentRequest(requestId);

  Future<List<String>> acceptFriendRequests(List<String> requestIds) =>
      _requests.acceptFriendRequests(requestIds);

  Future<List<String>> rejectFriendRequests(List<String> requestIds) =>
      _requests.rejectFriendRequests(requestIds);

  Future<List<String>> cancelSentRequests(List<String> requestIds) =>
      _requests.cancelSentRequests(requestIds);

  /// Remove friend (unfriend)
  Future<bool> removeFriend(String friendUserId) async {
    final success = await _friendsService.management.removeFriend(friendUserId);

    if (success) {
      // Clear selection if removed friend was selected
      _selectionManager.removeFromSelection(friendUserId);
      await _analyticsService.social.logFriendRemoved(friendId: friendUserId);
      notifyListeners();
    }

    return success;
  }

  /// Create new group.
  Future<bool> createGroup({
    required String name,
    String? description,
    String? emoji,
    List<String>? selectedFriendIds,
  }) async {
    _isCreatingGroup = true;
    _groupCreationError = null;
    notifyListeners();

    try {
      final result = await executeAsync(() async {
        AppLogger.info('🔄 Skapar grupp: $name');

        final categoryId = await _friendsService.categories.createCategory(
          name: name,
          description: description.orEmpty(),
          initialMemberIds: selectedFriendIds,
        );

        final success = categoryId != null;
        if (success) {
          AppLogger.success('✅ Grupp "$name" skapad!');
          return true;
        } else {
          _groupCreationError =
              _friendsService.error ??
              AppLocale.current.errorCouldNotCreateGroup;
          throw Exception(_groupCreationError!);
        }
      });

      return result;
    } finally {
      _isCreatingGroup = false;
      notifyListeners();
    }
  }

  List<UserProfile> getFriendsInGroup(String groupId) =>
      _lookups.getFriendsInGroup(groupId);

  bool isGroupNameAvailable(String name) => _lookups.isGroupNameAvailable(name);

  List<FriendCategory> getGroupsForFriend(String friendUserId) =>
      _lookups.getGroupsForFriend(friendUserId);

  List<FriendCategory> searchGroups(String query) =>
      _lookups.searchGroups(query);

  /// Relationship status with a user. The precedence is documented on
  /// [FriendLookups.getFriendshipStatus]; surfaces that gate on blocking call
  /// [isBlocked] instead.
  FriendshipStatus getFriendshipStatus(String userId) =>
      _lookups.getFriendshipStatus(userId);

  /// Get mutual friends with user
  Future<List<UserProfile>> getMutualFriends(String userId) async {
    if (_isDisposed) return [];

    return await executeAsync(() async {
      return await _friendsService.management.getMutualFriends(userId);
    });
  }

  /// Auth state from PermissionService (the project's standard auth source)
  bool get isAuthenticated => _permissionService.isAuthenticated;
  String? get currentUserId => _permissionService.currentUserId;

  bool canSendFriendRequest(String userId) {
    if (!isAuthenticated || currentUserId == userId) return false;

    final status = getFriendshipStatus(userId);
    return status == FriendshipStatus.none;
  }

  /// Toggle friend selection
  void toggleFriendSelection(String friendId) =>
      _selectionManager.toggleFriendSelection(friendId);

  /// Select all friends
  void selectAllFriends() => _selectionManager.selectAllFriends(friends);

  /// Clear all selections
  void clearSelection() => _selectionManager.clearSelection();

  /// Get selected friends as UserProfile objects
  List<UserProfile> getSelectedFriends() =>
      _selectionManager.getSelectedFriends(friends);

  /// Get profile picture URL for a user
  String? getAvatarUrlForUser(String userId) =>
      _profileCacheManager.getAvatarUrlForUser(userId);

  /// Loads user profiles for all users in friend requests
  Future<void> loadUserProfilesForRequests() => _loadUserProfilesForRequests();

  /// Clears user profile cache
  void clearUserProfilesCache() => _profileCacheManager.clearCache();

  /// Gets display name for a user
  String getDisplayNameForUser(String userId) =>
      _profileCacheManager.getDisplayNameForUser(userId);

  /// Gets avatar URL for a user
  String? getProfilePictureUrlForUser(String userId) =>
      _profileCacheManager.getProfilePictureUrlForUser(userId);

  /// Checks if a user is online
  bool isUserOnline(String userId) => _profileCacheManager.isUserOnline(userId);

  // Private helper to load profiles
  Future<void> _loadUserProfilesForRequests() async {
    if (_isDisposed) return;

    await _profileCacheManager.loadUserProfilesForRequests(
      incomingRequests: incomingRequests,
      sentRequests: sentRequests,
    );
  }

  void _onSearchChanged() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _onProfileCacheChanged() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _onSelectionChanged() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _onFriendsServiceChanged() {
    if (!_isDisposed) {
      loadUserProfilesForRequests();
    }
  }

  void _onUserServiceChanged() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Clear errors
  @override
  void clearError() {
    if (!_isDisposed) {
      _friendsService.clearError();
      _groupCreationError = null;
      super.clearError();
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    if (_isDisposed) return;

    // Clear cache before refresh
    clearUserProfilesCache();

    // Note: UnifiedFriendsService handles its own refresh through Firebase listeners
    // No need to manually refresh as it's reactive

    // Load user profiles for new requests
    await loadUserProfilesForRequests();
  }

  @override
  void dispose() {
    _isDisposed = true;

    AppLogger.info('🧹 FriendsViewModel.dispose() - Cleaning up resources');

    // Remove service listeners
    _friendsServiceSubscription?.cancel();
    _userService.removeListener(_onUserServiceChanged);

    // Remove manager listeners BEFORE disposing managers
    _searchManager.removeListener(_onSearchChanged);
    _profileCacheManager.removeListener(_onProfileCacheChanged);
    _selectionManager.removeListener(_onSelectionChanged);

    // Dispose managers
    _searchManager.dispose();
    _profileCacheManager.dispose();
    _selectionManager.dispose();

    _notifyScheduled = false;

    super.dispose();
  }
}
