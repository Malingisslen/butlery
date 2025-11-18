import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository interface for social friendship and group management operations.
/// This interface provides comprehensive friend relationship management including
/// friend requests, mutual connections, friend categorization, and group invitations.
/// It serves as the foundation for social features in the Butlery platform,
/// managing complex social relationships and interaction workflows.
/// **Core Social Features:**
/// - **Friend Requests**: Send, accept, reject, and cancel friend requests
/// - **Mutual Friendships**: Establish and manage bidirectional friend relationships
/// - **Friend Categories**: Organize friends into custom categories and groups
/// - **Group Invitations**: Manage invitations to social groups and friend circles
/// - **Profile Integration**: Link social relationships with user profiles
/// - **Real-time Updates**: Stream-based social activity notifications
/// **Relationship Management:**
/// Handles the full lifecycle of social relationships from initial connection
/// requests through ongoing friendship maintenance. Supports complex social
/// structures including friend categories, group memberships, and invitation systems.
/// **Data Consistency:**
/// Ensures mutual friendship relationships remain synchronized, handles concurrent
/// social operations gracefully, and maintains data integrity across complex
/// social interaction patterns.
/// **Privacy and Security:**
/// Implements proper authorization checks for social operations, respects user
/// privacy settings, and prevents unauthorized access to social relationship data.
/// **Usage Examples:**
/// ```dart
/// final friendsRepo = ServiceLocator.get<FriendsRepository>();
/// // Send friend request
/// final success = await friendsRepo.sendFriendRequest(
///   targetUserId, 
///   message: 'Hi! Let\\'s connect on Butlery!'
/// );
/// // Accept incoming request
/// final requests = await friendsRepo.getIncomingRequests();
/// for (final request in requests) {
///   await friendsRepo.acceptFriendRequest(request.id);
/// }
/// // Organize friends into categories
/// final familyCategory = FriendCategory(
///   name: 'Family',
///   memberIds: familyFriendIds,
/// );
/// await friendsRepo.saveCategory(userId, familyCategory);
/// ```
abstract class FriendsRepository extends Repository<UserProfile> {
  /// Send a friend request to another user
  Future<bool> sendFriendRequest(String toUserId, {String? message});

  /// Accept an incoming friend request
  Future<bool> acceptFriendRequest(String requestId);

  /// Reject an incoming friend request
  Future<bool> rejectFriendRequest(String requestId);

  /// Remove an existing friend
  Future<bool> removeFriend(String friendUserId);

  /// Get all incoming friend requests for current user
  Future<List<FriendRequest>> getIncomingRequests();

  /// Get all sent friend requests for current user
  Future<List<FriendRequest>> getSentRequests();

  /// Check if a pending request already exists between two users
  Future<bool> requestExists(String fromUserId, String toUserId);

  /// Check if two users are friends
  Future<bool> areFriends(String userId1, String userId2);

  /// Add both users to each other's friends lists
  Future<void> addMutualFriends(String userId1, String userId2);

  /// Remove users from each other's friends lists
  Future<void> removeMutualFriends(String userId1, String userId2);

  /// Fetch ids of all friends for a user
  Future<List<String>> fetchFriendIds(String userId);

  /// Fetch profiles for a set of user ids
  Future<List<UserProfile>> fetchFriendProfiles(List<String> userIds);

  /// Cancel a previously sent friend request
  Future<bool> cancelFriendRequest(String requestId);

  // ===== Category methods =====

  /// Save a new category for the given user
  Future<void> saveCategory(String userId, FriendCategory category);

  /// Update an existing category with provided data
  Future<void> updateCategory(
      String userId, String categoryId, Map<String, dynamic> data);

  /// Delete a category for the given user
  Future<void> deleteCategory(String userId, String categoryId);

  /// Fetch all categories for a user
  Future<List<FriendCategory>> fetchCategories(String userId);

  /// Create a category for another user (used when joining groups)
  Future<void> createCategoryForUser(String userId, FriendCategory category);

  /// Update only the members list of a category
  Future<void> updateCategoryMembers(
      String userId, String categoryId, List<String> memberIds);

  /// Get a single category by id for a user
  Future<FriendCategory?> getCategory(String userId, String categoryId);

  // ===== Invitation methods =====

  /// Stream of received invitations for a user
  Stream<List<GroupInvitation>> receivedInvitationsStream(String userId);

  /// Stream of sent invitations for a user
  Stream<List<GroupInvitation>> sentInvitationsStream(String userId);

  /// Fetch a single invitation by id
  Future<GroupInvitation?> getInvitation(String invitationId);

  /// Save a new invitation
  Future<void> saveInvitation(GroupInvitation invitation);

  /// Update an invitation document
  Future<void> updateInvitation(
      String invitationId, Map<String, dynamic> data);

  /// Get document references for invitations that have expired
  Future<List<DocumentReference<Map<String, dynamic>>>> expiredInvitations(
      DateTime now);

  /// Get old invitations older than given cutoff for a user
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> oldInvitations(
      String userId, DateTime cutoffDate);

  /// Delete a list of documents
  Future<void> deleteDocuments(List<DocumentReference<Map<String, dynamic>>> refs);

  /// Update a list of documents with the provided data
  Future<void> updateDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs,
      Map<String, dynamic> data);

  /// Check if there is a pending invitation for user and group
  Future<bool> hasPendingInvitation(String groupId, String toUserId);
}
