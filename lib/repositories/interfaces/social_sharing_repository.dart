// lib/repositories/interfaces/social_sharing_repository.dart

import 'package:butlery/models/shared_content.dart';

/// Repository interface for social sharing operations
abstract class SocialSharingRepository {
  /// Share content to a group
  Future<void> shareToGroup(String groupId, SharedContent content);
  
  /// Share content to specific users
  Future<void> shareToUsers(List<String> userIds, SharedContent content);
  
  /// Get content shared with the current user
  Stream<List<SharedContent>> getSharedWithMe(String userId);
  
  /// Get content shared by the current user
  Stream<List<SharedContent>> getMySharedContent(String userId);
  
  /// Update sharing permissions
  Future<void> updateSharingPermissions(
    String contentId,
    List<String> addUserIds,
    List<String> removeUserIds,
  );
  
  /// Revoke sharing for specific content
  Future<void> revokeSharing(String contentId);
  
  /// Accept shared content
  Future<void> acceptSharedContent(String contentId, String userId);
  
  /// Decline shared content
  Future<void> declineSharedContent(String contentId, String userId);
  
  /// Get sharing statistics
  Future<Map<String, dynamic>> getSharingStats(String userId);
}