/// Friends ViewModel coordinating friend operations (requests, groups, search) with manager delegation.
/// Uses FriendsSearchManager, FriendsProfileCacheManager, FriendsSelectionManager for specialized functionality.

// lib/viewmodels/friends_viewmodel.dart

import 'dart:async';
import 'package:collection/collection.dart';
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
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/friends/friends_search_manager.dart';
import 'package:butlery/viewmodels/friends/friends_profile_cache_manager.dart';
import 'package:butlery/viewmodels/friends/friends_selection_manager.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Friendship status between current user and another user
enum FriendshipStatus { none, friends, requestSent, requestReceived, blocked }

/// Coordinates social relationship operations through service and manager delegation.
class FriendsViewModel extends BaseViewModel {
  final UnifiedFriendsService _friendsService;
  final UserService _userService;
  final AnalyticsService _analyticsService;
  final PermissionService _permissionService;
  final AccountMaturityHelper _maturityHelper;
  final AuthRepository _authRepository;

  late final FriendsSearchManager _searchManager;
  late final FriendsProfileCacheManager _profileCacheManager;
  late final FriendsSelectionManager _selectionManager;

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
  }) : _friendsService = friendsService,
       _userService = userService,
       _analyticsService =
           analyticsService ?? ServiceLocator.get<AnalyticsService>(),
       _permissionService =
           permissionService ?? ServiceLocator.get<PermissionService>(),
       _maturityHelper = maturityHelper ?? AccountMaturityHelper(),
       _authRepository =
           authRepository ?? ServiceLocator.get<AuthRepository>() {
    _searchManager = FriendsSearchManager(friendsService: friendsService);
    _profileCacheManager = FriendsProfileCacheManager(userService: userService);
    _selectionManager = FriendsSelectionManager();

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
  /// explicit `setError(...)` — e.g. the maturity-gate guidance in
  /// `sendFriendRequest` (BUT-1417) — actually surfaces. Without it this
  /// override shadowed the mixin's `_error`, so `setError` writes were
  /// invisible. Placed last to preserve the existing precedence of the
  /// service/group/search errors; the maturity gate early-returns before any
  /// of those can be set, so its message still shows.
  @override
  String? get error =>
      _friendsService.error ??
      _groupCreationError ??
      _searchManager.searchError ??
      super.error;

  /// Error presence indicator.
  ///
  /// Mirrors the [error] getter: includes `super.hasError` so an explicit
  /// `setError(...)` (e.g. the BUT-1417 maturity-gate guidance) registers as
  /// present. Without this, a view that guards on `hasError` before rendering
  /// an error banner would silently suppress the maturity message even though
  /// `error` returns it.
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

  /// Send friend request to user
  Future<bool> sendFriendRequest(String userId, {String? message}) async {
    // Client-side mirror of the server isAccountMatured() gate (BUT-659).
    // The server is still the authority; this prevents the opaque
    // permission-denied that new accounts would otherwise see.
    if (!isAccountMatured) {
      setError(AppLocale.current.newAccountSocialBlocked);
      notifyListeners();
      return false;
    }

    AppLogger.info('🔄 Sending friend request to ${userId.maskedUserId}...');

    final success = await _friendsService.management.sendFriendRequest(
      userId,
      message: message,
    );

    if (success) {
      AppLogger.success(
        '✅ Friend request sent successfully to ${userId.maskedUserId}',
      );

      // Track friend request sent
      await _analyticsService.logFriendRequestSent(
        recipientId: userId,
        source: hasSearchQuery ? 'search' : 'discovery',
      );

      // Clear search to show clean state after successful request
      _searchManager.clearSearch();

      // Notify UI of friend request state change
      notifyListeners();

      AppLogger.debug(
        '🔄 UI notified of friend request state change with search cleared',
      );
    } else {
      AppLogger.error(
        '❌ Failed to send friend request to ${userId.maskedUserId}',
      );
    }

    return success;
  }

  /// Block a user. The service also drops the friendship and cancels pending
  /// requests both ways — unblocking does not restore any of it, and it is the
  /// service that records the analytics, so a caller that skips this ViewModel
  /// still counts.
  Future<bool> blockUser(String userId) async {
    final success = await _friendsService.management.blockUser(userId);
    if (success) notifyListeners();
    return success;
  }

  /// Unblock a user
  Future<bool> unblockUser(String userId) async {
    final success = await _friendsService.management.unblockUser(userId);
    if (success) notifyListeners();
    return success;
  }

  /// Accept incoming friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    // Find the request to get sender ID for analytics. The request may have
    // already vanished (cancelled on another device / double-tap) — don't
    // throw; the service safely no-ops on a missing request.
    final request = incomingRequests.firstWhereOrNull((r) => r.id == requestId);

    final success = await _friendsService.management.acceptFriendRequest(
      requestId,
    );

    if (success) {
      // Track friend request accepted (only when we still have the sender id).
      if (request != null) {
        await _analyticsService.logFriendRequestAccepted(
          senderId: request.fromUserId,
        );
      }
      // First-friend milestone fires at most once per user (BUT-593).
      await _analyticsService.social.logFirstFriendIfMilestone(
        userId: _userService.currentUserId,
        joinedAt: _userService.currentUserProfile?.joinedAt,
      );
    }

    return success;
  }

  /// Reject incoming friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    // Look up sender id before mutation removes it from state. The request may
    // have already vanished (cancelled on another device / double-tap) — don't
    // throw; the service safely no-ops on a missing request.
    final request = incomingRequests.firstWhereOrNull((r) => r.id == requestId);

    final success = await _friendsService.management.rejectFriendRequest(
      requestId,
    );

    if (success && request != null) {
      await _analyticsService.social.logFriendRequestRejected(
        senderId: request.fromUserId,
      );
    }

    return success;
  }

  /// Cancel sent friend request
  Future<bool> cancelSentRequest(String requestId) async {
    return await _friendsService.management.cancelFriendRequest(requestId);
  }

  /// Accept several incoming requests. Loops [acceptFriendRequest] rather than
  /// the service method it wraps, because the analytics for an accept live on
  /// this ViewModel — a batch built on the service layer would write the
  /// friendships and record none of them.
  ///
  /// Returns the ids that landed — a request can legitimately have vanished
  /// from another device, so one failure must not strand the rest, and the
  /// caller needs to know which ones to stop offering.
  Future<List<String>> acceptFriendRequests(List<String> requestIds) =>
      _runBatch(requestIds, acceptFriendRequest);

  /// Reject several incoming requests. See [acceptFriendRequests].
  Future<List<String>> rejectFriendRequests(List<String> requestIds) =>
      _runBatch(requestIds, rejectFriendRequest);

  /// Cancel several sent requests. [cancelSentRequest] adds nothing of its own,
  /// so this exists for one contract towards the view rather than for the
  /// analytics reason the other two have.
  Future<List<String>> cancelSentRequests(List<String> requestIds) =>
      _runBatch(requestIds, cancelSentRequest);

  /// Each id keeps the per-request analytics of the single-request path,
  /// which this adds a catch around: one id that throws must not strand the
  /// ids after it.
  Future<List<String>> _runBatch(
    List<String> requestIds,
    Future<bool> Function(String) operation,
  ) async {
    final succeeded = <String>[];
    for (final requestId in List<String>.of(requestIds)) {
      try {
        if (await operation(requestId)) succeeded.add(requestId);
      } catch (e) {
        AppLogger.error('❌ Batch operation failed for one request: $e');
      }
    }
    if (succeeded.isNotEmpty) notifyListeners();
    return succeeded;
  }

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

  /// Get friends in a specific group.
  List<UserProfile> getFriendsInGroup(String groupId) {
    return _friendsService.categories.getFriendsInCategory(groupId);
  }

  /// Check if group name is available.
  bool isGroupNameAvailable(String name) {
    return _friendsService.categories.getCategoryByName(name) == null;
  }

  /// Get groups for a specific friend.
  List<FriendCategory> getGroupsForFriend(String friendUserId) {
    return _friendsService.categories.getCategoriesForFriend(friendUserId);
  }

  /// Search groups.
  List<FriendCategory> searchGroups(String query) {
    if (query.trim().isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _friendsService.categoriesList
        .where((category) => category.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Get relationship status with user
  FriendshipStatus getFriendshipStatus(String userId) {
    // Check if user is already a friend
    if (_friendsService.friends.any((friend) => friend.uid == userId)) {
      return FriendshipStatus.friends;
    }

    // Check if there's an outgoing request
    if (_friendsService.outgoingRequests.any(
      (request) => request.toUserId == userId,
    )) {
      return FriendshipStatus.requestSent;
    }

    // Check if there's an incoming request
    if (_friendsService.incomingRequests.any(
      (request) => request.fromUserId == userId,
    )) {
      return FriendshipStatus.requestReceived;
    }

    // Check if user is blocked
    if (_friendsService.blockedUsers.contains(userId)) {
      return FriendshipStatus.blocked;
    }

    return FriendshipStatus.none;
  }

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
      notifyListeners();
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
