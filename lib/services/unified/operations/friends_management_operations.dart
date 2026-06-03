import 'package:clock/clock.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart' as model;
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/l10n/app_locale.dart';

import 'package:butlery/services/user_service.dart' as user_svc;
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_relationship_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/notifications/notification_service.dart'
    as notif;
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Friends management operations handling request lifecycle, relationship management, user discovery, blocking, and notification integration.
class FriendsManagementOperations extends BaseService {
  @override
  String get serviceName => 'FriendsManagementOperations';

  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final List<model.UserProfile> Function() _getFriends;
  final List<FriendRequest> Function() _getIncomingRequests;
  final List<FriendRequest> Function() _getOutgoingRequests;
  final Set<String> Function() _getBlockedUsers;
  final FirebaseFirestore Function() _getFirestore;
  final FriendRelationshipRepository _relationshipRepository;
  final void Function(FriendRequest) _addOutgoingRequestInternal;
  final void Function(String) _removeOutgoingRequestInternal;
  final void Function(String) _removeIncomingRequestInternal;
  final void Function(model.UserProfile) _addFriendInternal;
  final void Function(String) _removeFriendInternal;
  final Future<void> Function(FriendRequest) _syncFriendRequestToFirebase;
  final Future<void> Function(FriendRequest) _updateFriendRequestStatus;
  final Future<void> Function() _refresh;

  late final user_svc.UserService _userService;

  FriendsManagementOperations({
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required List<model.UserProfile> Function() getFriends,
    required List<FriendRequest> Function() getIncomingRequests,
    required List<FriendRequest> Function() getOutgoingRequests,
    required Set<String> Function() getBlockedUsers,
    required FirebaseFirestore Function() getFirestore,
    required FriendRelationshipRepository relationshipRepository,
    required void Function(FriendRequest) addOutgoingRequestInternal,
    required void Function(String) removeOutgoingRequestInternal,
    required void Function(String) removeIncomingRequestInternal,
    required void Function(model.UserProfile) addFriendInternal,
    required void Function(String) removeFriendInternal,
    required Future<void> Function(FriendRequest) syncFriendRequestToFirebase,
    required Future<void> Function(FriendRequest) updateFriendRequestStatus,
    required Future<void> Function() refresh,
  })  : _getCurrentUserId = getCurrentUserId,
        _getCurrentUserDisplayName = getCurrentUserDisplayName,
        _getFriends = getFriends,
        _getIncomingRequests = getIncomingRequests,
        _getOutgoingRequests = getOutgoingRequests,
        _getBlockedUsers = getBlockedUsers,
        _getFirestore = getFirestore,
        _relationshipRepository = relationshipRepository,
        _addOutgoingRequestInternal = addOutgoingRequestInternal,
        _removeOutgoingRequestInternal = removeOutgoingRequestInternal,
        _removeIncomingRequestInternal = removeIncomingRequestInternal,
        _addFriendInternal = addFriendInternal,
        _removeFriendInternal = removeFriendInternal,
        _syncFriendRequestToFirebase = syncFriendRequestToFirebase,
        _updateFriendRequestStatus = updateFriendRequestStatus,
        _refresh = refresh {
    _userService = ServiceLocator.get<user_svc.UserService>();
  }

  /// Get NotificationService from DI (registered by MessagingModule)
  notif.NotificationService? get _notificationService =>
      ServiceLocator.tryGet<notif.NotificationService>();

  Future<bool> sendFriendRequest(String recipientId, {String? message}) async {
    // Validate input
    if (ValidationUtils.isNullOrEmpty(recipientId)) {
      return false;
    }

    final result = await executeServiceOperation(() async {
      // Check authentication
      final currentUserId = _getCurrentUserId();
      final currentUserDisplayName = _getCurrentUserDisplayName();

      if (ValidationUtils.isNullOrEmpty(currentUserId) ||
          ValidationUtils.isNullOrEmpty(currentUserDisplayName)) {
        throw Exception(AppLocale.current.errorAuthenticationPleaseLogin);
      }

      // Validate not sending to self
      if (recipientId == currentUserId) {
        throw Exception('Cannot send friend request to yourself');
      }

      // Check if already friends
      if (isFriend(recipientId)) {
        throw Exception('Already friends with this user');
      }

      // Check if request already exists
      if (hasOutgoingRequest(recipientId)) {
        throw Exception('Friend request already sent to this user');
      }

      // Check if there's an incoming request from this user
      if (hasIncomingRequest(recipientId)) {
        throw Exception('This user has already sent you a friend request');
      }

      // Block enforcement: cannot send friend request to blocked user
      if (isBlocked(recipientId)) {
        throw Exception('Cannot send friend request to a blocked user');
      }

      final request = FriendRequest.create(
        fromUserId: currentUserId!,
        toUserId: recipientId,
        message: message,
      );

      // Add to local state (optimistic update)
      _addOutgoingRequestInternal(request);

      try {
        // Send to Firebase
        await _syncFriendRequestToFirebase(request);
      } catch (e) {
        // Rollback optimistic update on Firebase write failure
        _removeOutgoingRequestInternal(request.id);
        rethrow;
      }

      // Send notification to recipient (non-critical, don't rollback on failure)
      final recipientDisplayName = 'User ${recipientId.substring(0, 6)}...';
      unawaited(_sendFriendRequestNotification(
        request,
        currentUserDisplayName ?? AppLocale.current.displayUnknownUser,
        recipientDisplayName,
      ));

      return true;
    }, operationName: 'Send Friend Request');
    return result == true;
  }

  Future<bool> acceptFriendRequest(String requestId) async {
    if (ValidationUtils.isNullOrEmpty(requestId)) {
      return false;
    }

    final result = await executeServiceOperation(() async {
      final request =
          _getIncomingRequests().where((r) => r.id == requestId).firstOrNull;

      if (request == null) {
        throw Exception('Friend request not found');
      }

      // Fetch real user profile for the friend request sender
      final userProfile = await _userService.getUserProfile(request.fromUserId);
      if (userProfile == null) {
        throw Exception(
          'Could not fetch user profile for friend request sender',
        );
      }

      final friend = userProfile;

      // Resolve the request document reference for atomic update
      final requestQuery = await _getFirestore()
          .collection(FirestoreCollections.socialRequests)
          .where('fromUserId', isEqualTo: request.fromUserId)
          .where('toUserId', isEqualTo: request.toUserId)
          .limit(1)
          .get();

      if (requestQuery.docs.isEmpty) {
        throw Exception('Friend request document not found in Firestore');
      }

      // Atomic: creates mutual friendship + marks request accepted in one transaction
      await _relationshipRepository.acceptFriendAtomically(
        _getCurrentUserId()!,
        request.fromUserId,
        requestDocRef: requestQuery.docs.first.reference,
      );

      // Update local state AFTER successful transaction
      _addFriendInternal(friend);
      _removeIncomingRequestInternal(requestId);

      // Send notification to the original sender (non-critical)
      unawaited(_sendFriendRequestAcceptedNotification(
        request,
        _getCurrentUserDisplayName() ?? AppLocale.current.displayUnknownUser,
      ));

      // Refresh state from Firebase to ensure consistency
      try {
        await _refresh();
        AppLogger.success('✅ State refreshed after friend request acceptance');
      } catch (e) {
        AppLogger.warning(
          '⚠️ State refresh failed after friend acceptance, but operation completed: $e',
        );
        // Don't fail the entire operation just because refresh failed
      }

      return true;
    }, operationName: 'Accept Friend Request');
    return result == true;
  }

  Future<bool> rejectFriendRequest(String requestId) async {
    if (ValidationUtils.isNullOrEmpty(requestId)) {
      return false;
    }

    final result = await executeServiceOperation(() async {
      final request =
          _getIncomingRequests().where((r) => r.id == requestId).firstOrNull;

      if (request == null) {
        throw Exception('Friend request not found');
      }

      // Update request status
      final rejectedRequest = request.copyWith(
        status: FriendRequestStatus.rejected,
        respondedAt: clock.now(),
      );

      // Firebase first — local list.remove can't throw
      await _updateFriendRequestStatus(rejectedRequest);
      _removeIncomingRequestInternal(requestId);

      AppLogger.success('Friend request rejected from ${request.fromUserId}');
      return true;
    }, operationName: 'Reject Friend Request');
    return result == true;
  }

  Future<bool> cancelFriendRequest(String requestId) async {
    if (ValidationUtils.isNullOrEmpty(requestId)) {
      return false;
    }

    final result = await executeServiceOperation(() async {
      final request =
          _getOutgoingRequests().where((r) => r.id == requestId).firstOrNull;

      if (request == null) {
        throw Exception('Friend request not found');
      }

      // Update request status
      final cancelledRequest = request.copyWith(
        status: FriendRequestStatus.cancelled,
        respondedAt: clock.now(),
      );

      await _updateFriendRequestStatus(cancelledRequest);
      _removeOutgoingRequestInternal(requestId);

      AppLogger.success('Friend request cancelled to ${request.toUserId}');
      return true;
    }, operationName: 'Cancel Friend Request');
    return result == true;
  }

  Future<bool> removeFriend(String friendId) async {
    if (ValidationUtils.isNullOrEmpty(friendId)) {
      return false;
    }

    final result = await executeServiceOperation(() async {
      final friend = _getFriends().where((f) => f.uid == friendId).firstOrNull;

      if (friend == null) {
        throw Exception('Friend not found');
      }

      await _relationshipRepository.removeMutualFriends(
        _getCurrentUserId()!,
        friendId,
      );
      _removeFriendInternal(friendId);

      AppLogger.success('Removed friend: ${friend.displayName.maskedName}');
      return true;
    }, operationName: 'Remove Friend');
    return result == true;
  }

  Future<bool> blockUser(String userId) async {
    try {
      // Remove from friends if they are friends
      if (isFriend(userId)) {
        await removeFriend(userId);
      }

      // Remove pending friend requests via state manager and clean up Firebase
      final incomingFromBlocked =
          _getIncomingRequests().where((r) => r.fromUserId == userId).toList();
      final outgoingToBlocked =
          _getOutgoingRequests().where((r) => r.toUserId == userId).toList();

      for (final request in incomingFromBlocked) {
        _removeIncomingRequestInternal(request.id);
        // Delete from Firebase (cancelled requests use delete per C2 fix)
        await _updateFriendRequestStatus(request.copyWith(
          status: FriendRequestStatus.cancelled,
          respondedAt: clock.now(),
        ));
      }
      for (final request in outgoingToBlocked) {
        _removeOutgoingRequestInternal(request.id);
        await _updateFriendRequestStatus(request.copyWith(
          status: FriendRequestStatus.cancelled,
          respondedAt: clock.now(),
        ));
      }

      // Write to blocks collection (real-time stream updates in-memory cache)
      final blockRepo = ServiceLocator.get<FirebaseBlockRepository>();
      await blockRepo.blockUser(userId);

      AppLogger.success('User blocked');
      return true;
    } catch (e) {
      AppLogger.error('Failed to block user', e);
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      // Delete from blocks collection (real-time stream updates in-memory cache)
      final blockRepo = ServiceLocator.get<FirebaseBlockRepository>();
      await blockRepo.unblockUser(userId);

      AppLogger.success('User unblocked');
      return true;
    } catch (e) {
      AppLogger.error('Failed to unblock user', e);
      return false;
    }
  }

  /// BUT-993: bulk block. Loops [blockUser] per id with per-target error
  /// handling — one failure shouldn't strand the rest. A batched Firestore
  /// write isn't a clean optimisation here because each block also triggers
  /// removeFriend + cancel-pending-requests side-effects per user, which
  /// can't be coalesced into a single write op.
  ///
  /// Returns the count of blocks that landed.
  Future<int> blockUsers(List<String> userIds) async {
    if (userIds.isEmpty) return 0;
    var succeeded = 0;
    for (final userId in userIds) {
      if (await blockUser(userId)) succeeded++;
    }
    AppLogger.info('Bulk-block: $succeeded of ${userIds.length} succeeded');
    return succeeded;
  }

  /// BUT-993: bulk unblock. Loops [unblockUser] per id with per-target
  /// error handling. Unlike [blockUsers], the underlying op is a single
  /// blocks-collection delete — a future optimisation could batch all
  /// deletes into one Firestore `WriteBatch`. Loop kept for symmetry with
  /// [blockUsers] until a real perf signal forces the batch path.
  ///
  /// Returns the count of unblocks that landed.
  Future<int> unblockUsers(List<String> userIds) async {
    if (userIds.isEmpty) return 0;
    var succeeded = 0;
    for (final userId in userIds) {
      if (await unblockUser(userId)) succeeded++;
    }
    AppLogger.info('Bulk-unblock: $succeeded of ${userIds.length} succeeded');
    return succeeded;
  }

  List<model.UserProfile> getAllFriends() {
    return List.unmodifiable(_getFriends());
  }

  model.UserProfile? getFriendById(String friendId) {
    return _getFriends().where((f) => f.uid == friendId).firstOrNull;
  }

  bool isFriend(String userId) {
    return _getFriends().any((f) => f.uid == userId);
  }

  List<model.UserProfile> getOnlineFriends() {
    // model.UserProfile doesn't have isOnline property, so return all friends for now
    return _getFriends().toList();
  }

  List<model.UserProfile> getFriendsByCategory(String category) {
    // This would need to be implemented with category relationships
    return _getFriends().toList();
  }

  List<model.UserProfile> searchFriends(String query) {
    final searchTerm = query.toLowerCase();
    return _getFriends()
        .where((f) => f.displayName.toLowerCase().contains(searchTerm))
        .toList();
  }

  Future<List<model.UserProfile>> searchUsers(String query) async {
    try {
      AppLogger.info('Searching users with query: $query');

      // Search current friends first
      final currentFriends = searchFriends(query);

      // Search for new users from UserService
      final allUsers = await _userService.searchUsers(query);

      // Combine results, prioritizing current friends
      final combinedResults = <model.UserProfile>[];

      // Add current friends first
      combinedResults.addAll(currentFriends);

      // Add new users that aren't already friends
      final currentFriendIds = currentFriends.map((f) => f.uid).toSet();
      final newUsers = allUsers
          .where((user) => !currentFriendIds.contains(user.uid))
          .toList();
      combinedResults.addAll(newUsers);

      // Defense-in-depth: filter out current user even though the repository
      // layer should already exclude them from search results.
      final currentUserId = _getCurrentUserId();
      if (currentUserId != null) {
        combinedResults.removeWhere((user) => user.uid == currentUserId);
      }

      AppLogger.info(
        'Search returned ${currentFriends.length} current friends and ${newUsers.length} new users',
      );
      return combinedResults;
    } catch (e) {
      AppLogger.error('Failed to search users', e);
      return [];
    }
  }

  List<FriendRequest> getIncomingRequests() {
    return List.unmodifiable(_getIncomingRequests());
  }

  List<FriendRequest> getOutgoingRequests() {
    return List.unmodifiable(_getOutgoingRequests());
  }

  bool hasOutgoingRequest(String userId) {
    return _getOutgoingRequests().any(
      (r) => r.toUserId == userId && r.status == FriendRequestStatus.pending,
    );
  }

  bool hasIncomingRequest(String userId) {
    return _getIncomingRequests().any(
      (r) => r.fromUserId == userId && r.status == FriendRequestStatus.pending,
    );
  }

  int getIncomingRequestCount() {
    return _getIncomingRequests().length;
  }

  bool isBlocked(String userId) {
    return _getBlockedUsers().contains(userId);
  }

  List<String> getBlockedUsers() {
    return List.unmodifiable(_getBlockedUsers());
  }

  Map<String, dynamic> getFriendStats() {
    final totalFriends = _getFriends().length;
    const onlineFriends = 0; // model.UserProfile doesn't have isOnline property
    final categoryCounts = <String, int>{};

    return {
      'totalFriends': totalFriends,
      'onlineFriends': onlineFriends,
      'offlineFriends': totalFriends - onlineFriends,
      'incomingRequests': _getIncomingRequests().length,
      'outgoingRequests': _getOutgoingRequests().length,
      'blockedUsers': _getBlockedUsers().length,
      'categoryCounts': categoryCounts,
    };
  }

  Future<List<model.UserProfile>> getMutualFriends(String userId) async {
    try {
      if (_getCurrentUserId() == null) {
        AppLogger.error('Cannot get mutual friends: User not authenticated');
        return [];
      }

      if (userId == _getCurrentUserId()) {
        AppLogger.error('Cannot get mutual friends with yourself');
        return [];
      }

      // Get current user's friends
      final currentUserFriends = _getFriends().map((f) => f.uid).toSet();

      if (currentUserFriends.isEmpty) {
        AppLogger.debug('No friends to compare for mutual friends');
        return [];
      }

      // Query Firebase for the target user's friends
      final firestore = _getFirestore();
      final targetUserFriendsQuery = await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userFriends)
          .get();

      // Get target user's friend IDs
      final targetUserFriendIds =
          targetUserFriendsQuery.docs.map((doc) => doc.id).toSet();

      // Find intersection (mutual friends)
      final mutualFriendIds =
          currentUserFriends.intersection(targetUserFriendIds).toList();

      if (mutualFriendIds.isEmpty) {
        AppLogger.debug(
            'No mutual friends found with user ${userId.maskedUserId}');
        return [];
      }

      // Get model.UserProfile objects for mutual friends
      final mutualFriends = <model.UserProfile>[];
      for (final friendId in mutualFriendIds) {
        final friend =
            _getFriends().where((f) => f.uid == friendId).firstOrNull;
        if (friend != null) {
          mutualFriends.add(friend);
        }
      }

      AppLogger.success(
        'Found ${mutualFriends.length} mutual friends with user $userId',
      );
      return mutualFriends;
    } catch (e) {
      AppLogger.error('Failed to get mutual friends', e);
      return [];
    }
  }

  Future<void> _sendFriendRequestNotification(
    FriendRequest request,
    String senderDisplayName,
    String recipientDisplayName,
  ) async {
    if (_notificationService == null) {
      AppLogger.debug(
        'Notification service not available - skipping friend request notification',
      );
      return;
    }

    try {
      await _notificationService!.sendImmediateNotification(
        targetUserIds: [request.toUserId],
        strategy: NotificationStrategy.friendRequest,
        variables: {'senderName': senderDisplayName},
        additionalData: {
          'senderUserId': request.fromUserId,
          'requestId': request.id,
          'message': request.message.orEmpty(),
        },
      );

      AppLogger.success(
        'Friend request notification sent to $recipientDisplayName',
      );
    } catch (e) {
      AppLogger.warning('Failed to send friend request notification: $e');
    }
  }

  Future<void> _sendFriendRequestAcceptedNotification(
    FriendRequest request,
    String acceptorDisplayName,
  ) async {
    if (_notificationService == null) {
      AppLogger.debug(
        'Notification service not available - skipping friend request accepted notification',
      );
      return;
    }

    try {
      await _notificationService!.sendImmediateNotification(
        targetUserIds: [request.fromUserId],
        strategy: NotificationStrategy.friendRequestAccepted,
        variables: {'acceptorName': acceptorDisplayName},
        additionalData: {
          'acceptorUserId': request.toUserId,
          'requestId': request.id,
        },
      );

      AppLogger.success(
        'Friend request accepted notification sent to ${request.fromUserId}',
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to send friend request accepted notification: $e',
      );
    }
  }
}
