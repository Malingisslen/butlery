// BUT-1507: each caller of UnifiedFriendsService sees only the part it uses.
// The service implements all three; DI hands out the same instance under each
// (registerFriendsServiceRoles), so there is one friends state in memory.

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/types/service_states.dart';

/// The signed-in user's friends, requests, categories and blocks, read-only.
abstract interface class FriendsReader {
  Stream<FriendsServiceState> get stateStream;
  FriendsServiceState get currentState;
  List<UserProfile> get friends;

  /// Get friends list (for ViewModels)
  List<UserProfile> get friendsList;

  /// Look up a friend by UID, or null if [uid] isn't in the friends list.
  /// Centralizes the `friends.firstWhereOrNull` pattern that several
  /// callers (push senders, deep-link resolvers) need.
  UserProfile? friendByUid(String uid);
  List<FriendRequest> get incomingRequests;
  List<FriendRequest> get outgoingRequests;

  /// Get all friend requests (incoming and outgoing combined)
  List<FriendRequest> get friendRequests;
  List<FriendCategory> get categoriesList;

  /// Get category by ID (for ViewModels)
  FriendCategory? getCategoryById(String categoryId);
  Map<String, Set<String>> get friendCategoryRelationships;
  List<GroupInvitation> get sentInvitations;
  List<GroupInvitation> get receivedInvitations;
  Set<String> get blockedUsers;
  String? get currentUserId;
  bool get isInitialized;
  bool get isLoading;
  String? get error;
  bool get hasError;
}

/// Changing friendships, categories and invitations, and finding people.
abstract interface class FriendsActions {
  FriendsManagementOperations get management;
  FriendsCategoriesOperations get categories;
  FriendsInvitationsOperations get invitations;

  /// Search for users by query
  Future<List<UserProfile>> searchUsers(String query);

  /// Get friends of a specific user
  Future<List<UserProfile>> getFriendsOfUser(String userId);

  /// Get recent collaborators
  Future<List<UserProfile>> getRecentCollaborators();

  /// Cancel sent invitation (for ViewModels)
  Future<bool> cancelSentInvitation(String invitationId);
}

/// Loading, refreshing and clearing the friends state.
abstract interface class FriendsSession {
  /// Share dialogs await this when they open, so it runs once and later
  /// callers share the same load instead of repeating its reads and writes.
  Future<void> initialize();

  /// Internal method to refresh data (for operations classes)
  Future<void> refresh();

  /// Clear error state (for ViewModels)
  void clearError();

  /// Clear user-specific state only — does NOT dispose stream resources
  /// (the auth listener must survive to handle the next login).
  void resetForLogout();
}
