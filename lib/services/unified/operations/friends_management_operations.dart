// ignore: unused_import
import 'package:collection/collection.dart'; // Needed for .firstOrNull on dynamic _parent fields
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart' as model;
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/validation_utils.dart';

import 'package:butlery/services/user_service.dart' as user_svc;
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/notifications/notification_service.dart'
    as notif;
import 'package:butlery/services/notifications/notification_types.dart';

/// Friends management operations handling request lifecycle, relationship management, user discovery, blocking, and notification integration.
class FriendsManagementOperations extends BaseService {
  @override
  String get serviceName => 'FriendsManagementOperations';
  final UnifiedFriendsService _parent;
  late final user_svc.UserService _userService;
  notif.NotificationService? _notificationServiceInstance;

  FriendsManagementOperations(this._parent) {
    _userService = ServiceLocator.get<user_svc.UserService>();
    // NotificationService is now lazy initialized on first access
  }

  /// Lazy getter for notification service - initializes on first access after MessagingModule has loaded
  notif.NotificationService? get _notificationService {
    _notificationServiceInstance ??=
        safeExecuteSync<notif.NotificationService?>(
      () {
        final currentUserId = _parent.currentUserId;
        if (currentUserId != null) {
          final service = notif.NotificationService(userId: currentUserId);
          service.initialize();
          return service;
        }
        return null;
      },
      operationName: 'Initialize notification service',
      customErrorMessage: 'Could not initialize friend notifications',
    );
    return _notificationServiceInstance;
  }

  Future<bool> sendFriendRequest(String recipientId, {String? message}) async {
    // Validate input
    if (ValidationUtils.isNullOrEmpty(recipientId)) {
      return false;
    }

    final result = await executeServiceOperation(() async {
      // Check authentication
      final currentUserId = _parent.currentUserId;
      final currentUserDisplayName = _parent.currentUserDisplayName;

      if (ValidationUtils.isNullOrEmpty(currentUserId) ||
          ValidationUtils.isNullOrEmpty(currentUserDisplayName)) {
        throw Exception('Autentiseringsfel. Logga in igen.');
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

      final request = FriendRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fromUserId: currentUserId!,
        toUserId: recipientId,
        message: message,
        sentAt: DateTime.now(),
        status: FriendRequestStatus.pending,
      );

      // Add to local state (optimistic update)
      _parent.addOutgoingRequestInternal(request);

      // Send to Firebase
      await _parent.syncFriendRequestToFirebase(request);

      // Send notification to recipient
      final recipientDisplayName = 'User ${recipientId.substring(0, 6)}...';
      await _sendFriendRequestNotification(
        request,
        currentUserDisplayName ?? 'Unknown User',
        recipientDisplayName,
      );

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
          _parent.incomingRequests.where((r) => r.id == requestId).firstOrNull;

      if (request == null) {
        throw Exception('Friend request not found');
      }

      // Update request status
      final acceptedRequest = request.copyWith(
        status: FriendRequestStatus.accepted,
        respondedAt: DateTime.now(),
      );

      // ULTRATHINK FIX: Fetch real user profile instead of creating fake one
      final userProfile = await _userService.getUserProfile(request.fromUserId);
      if (userProfile == null) {
        throw Exception(
          'Could not fetch user profile for friend request sender',
        );
      }

      final friend = userProfile;

      // Update local state
      _parent.addFriendInternal(friend);
      _parent.removeIncomingRequestInternal(requestId);

      // Add mutual friends with counter updates using relationship repository
      await _parent.relationshipRepository.addMutualFriends(
        _parent.currentUserId!,
        request.fromUserId,
      );
      await _parent.updateFriendRequestStatus(acceptedRequest);

      // Send notification to the original sender
      await _sendFriendRequestAcceptedNotification(
        request,
        _parent.currentUserDisplayName ?? 'Unknown User',
      );

      // ULTRATHINK FIX: Refresh state from Firebase to ensure consistency
      try {
        await _parent.refresh();
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
    try {
      final request =
          _parent.incomingRequests.where((r) => r.id == requestId).firstOrNull;

      if (request == null) {
        AppLogger.error('Friend request not found');
        return false;
      }

      // Update request status
      final rejectedRequest = request.copyWith(
        status: FriendRequestStatus.rejected,
        respondedAt: DateTime.now(),
      );

      // Remove from local state
      _parent.removeIncomingRequestInternal(requestId);

      // Update in Firebase
      await _parent.updateFriendRequestStatus(rejectedRequest);

      AppLogger.success('Friend request rejected from ${request.fromUserId}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to reject friend request', e);
      return false;
    }
  }

  Future<bool> cancelFriendRequest(String requestId) async {
    try {
      final request =
          _parent.outgoingRequests.where((r) => r.id == requestId).firstOrNull;

      if (request == null) {
        AppLogger.error('Friend request not found');
        return false;
      }

      // Update request status
      final cancelledRequest = request.copyWith(
        status: FriendRequestStatus.cancelled,
        respondedAt: DateTime.now(),
      );

      // Remove from local state
      _parent.removeOutgoingRequestInternal(requestId);

      // Update in Firebase
      await _parent.updateFriendRequestStatus(cancelledRequest);

      AppLogger.success('Friend request cancelled to ${request.toUserId}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to cancel friend request', e);
      return false;
    }
  }

  Future<bool> removeFriend(String friendId) async {
    try {
      final friend =
          _parent.friends.where((f) => f.uid == friendId).firstOrNull;

      if (friend == null) {
        AppLogger.error('Friend not found');
        return false;
      }

      // Remove from local state
      _parent.removeFriendInternal(friendId);

      // Remove mutual friends with counter updates using relationship repository
      await _parent.relationshipRepository.removeMutualFriends(
        _parent.currentUserId!,
        friendId,
      );

      AppLogger.success('Removed friend: ${friend.displayName}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to remove friend', e);
      return false;
    }
  }

  Future<bool> blockUser(String userId) async {
    try {
      // Remove from friends if they are friends
      if (isFriend(userId)) {
        await removeFriend(userId);
      }

      // Remove any pending friend requests
      _parent.incomingRequests.removeWhere((r) => r.fromUserId == userId);
      _parent.outgoingRequests.removeWhere((r) => r.toUserId == userId);

      // Add to blocked users
      _parent.addBlockedUserInternal(userId);

      // Sync to Firebase
      await _parent.syncBlockedUsers();

      AppLogger.success('User blocked');
      return true;
    } catch (e) {
      AppLogger.error('Failed to block user', e);
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      // Remove from blocked users
      _parent.removeBlockedUserInternal(userId);

      // Sync to Firebase
      await _parent.syncBlockedUsers();

      AppLogger.success('User unblocked');
      return true;
    } catch (e) {
      AppLogger.error('Failed to unblock user', e);
      return false;
    }
  }

  List<model.UserProfile> getAllFriends() {
    return List.unmodifiable(_parent.friends);
  }

  model.UserProfile? getFriendById(String friendId) {
    return _parent.friends.where((f) => f.uid == friendId).firstOrNull;
  }

  bool isFriend(String userId) {
    return _parent.friends.any((f) => f.uid == userId);
  }

  List<model.UserProfile> getOnlineFriends() {
    // model.UserProfile doesn't have isOnline property, so return all friends for now
    return _parent.friends.toList();
  }

  List<model.UserProfile> getFriendsByCategory(String category) {
    // This would need to be implemented with category relationships
    return _parent.friends.toList();
  }

  List<model.UserProfile> searchFriends(String query) {
    final searchTerm = query.toLowerCase();
    return _parent.friends
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
    return List.unmodifiable(_parent.incomingRequests);
  }

  List<FriendRequest> getOutgoingRequests() {
    return List.unmodifiable(_parent.outgoingRequests);
  }

  bool hasOutgoingRequest(String userId) {
    return _parent.outgoingRequests.any(
      (r) => r.toUserId == userId && r.status == FriendRequestStatus.pending,
    );
  }

  bool hasIncomingRequest(String userId) {
    return _parent.incomingRequests.any(
      (r) => r.fromUserId == userId && r.status == FriendRequestStatus.pending,
    );
  }

  int getIncomingRequestCount() {
    return _parent.incomingRequests.length;
  }

  bool isBlocked(String userId) {
    return _parent.blockedUsers.contains(userId);
  }

  List<String> getBlockedUsers() {
    return List.unmodifiable(_parent.blockedUsers);
  }

  Map<String, dynamic> getFriendStats() {
    final totalFriends = _parent.friends.length;
    const onlineFriends = 0; // model.UserProfile doesn't have isOnline property
    final categoryCounts = <String, int>{};

    return {
      'totalFriends': totalFriends,
      'onlineFriends': onlineFriends,
      'offlineFriends': totalFriends - onlineFriends,
      'incomingRequests': _parent.incomingRequests.length,
      'outgoingRequests': _parent.outgoingRequests.length,
      'blockedUsers': _parent.blockedUsers.length,
      'categoryCounts': categoryCounts,
    };
  }

  Future<List<model.UserProfile>> getMutualFriends(String userId) async {
    try {
      if (_parent.currentUserId == null) {
        AppLogger.error('Cannot get mutual friends: User not authenticated');
        return [];
      }

      if (userId == _parent.currentUserId) {
        AppLogger.error('Cannot get mutual friends with yourself');
        return [];
      }

      // Get current user's friends
      final currentUserFriends = _parent.friends.map((f) => f.uid).toSet();

      if (currentUserFriends.isEmpty) {
        AppLogger.debug('No friends to compare for mutual friends');
        return [];
      }

      // Query Firebase for the target user's friends
      final firestore = _parent.firestore;
      final targetUserFriendsQuery = await firestore
          .collection('userFriends')
          .doc(userId)
          .collection('friends')
          .get();

      // Get target user's friend IDs
      final targetUserFriendIds =
          targetUserFriendsQuery.docs.map((doc) => doc.id).toSet();

      // Find intersection (mutual friends)
      final mutualFriendIds =
          currentUserFriends.intersection(targetUserFriendIds).toList();

      if (mutualFriendIds.isEmpty) {
        AppLogger.debug('No mutual friends found with user $userId');
        return [];
      }

      // Get model.UserProfile objects for mutual friends
      final mutualFriends = <model.UserProfile>[];
      for (final friendId in mutualFriendIds) {
        final friend =
            _parent.friends.where((f) => f.uid == friendId).firstOrNull;
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
          'message': request.message ?? '',
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
