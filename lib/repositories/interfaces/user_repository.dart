import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/user_profile.dart';

/// Repository interface for user profile data operations and management.
///
/// This interface extends the base Repository pattern to provide specialized
/// user profile operations including profile management, statistics tracking,
/// notification settings, and social features integration. It manages user
/// data persistence and synchronization across the Butlery social platform.
///
/// **Key User Operations:**
/// - **Profile Management**: CRUD operations for user profiles and settings
/// - **Statistics Tracking**: Friend counts, recipe metrics, and activity stats
/// - **Notification Management**: FCM token handling and notification preferences
/// - **Search and Discovery**: User search and profile discovery features
/// - **Social Integration**: Base user document management for social features
/// - **Online Status**: Real-time presence and availability tracking
///
/// **Social Platform Integration:**
/// This repository serves as the foundation for social features by managing
/// user profiles that integrate with friends, groups, and sharing systems.
/// It ensures consistent user data across all social interactions.
///
/// **Firebase Integration:**
/// Manages user profiles in Firestore with proper indexing for search and
/// discovery features. Also handles FCM token management for push notifications
/// and maintains user presence information for social features.
///
/// **Usage Examples:**
/// ```dart
/// final userRepo = sl<UserRepository>();
/// 
/// // Create or update user profile
/// final profile = UserProfile(
///   id: currentUserId,
///   displayName: 'John Doe',
///   email: 'john@example.com',
/// );
/// await userRepo.saveProfile(profile);
/// 
/// // Search for users
/// final searchResults = await userRepo.searchProfiles('john');
/// for (final user in searchResults) {
///   displayUserCard(user);
/// }
/// 
/// // Update notification settings
/// await userRepo.updateNotificationSettings(userId, true);
/// await userRepo.updateFCMToken(userId, fcmToken);
/// ```
abstract class UserRepository extends Repository<UserProfile> {
  /// Persist the given profile (create or update).
  Future<void> saveProfile(UserProfile profile);

  /// Fetch a profile by id.
  Future<UserProfile?> fetchProfile(String userId);

  /// Fetch multiple profiles by their ids.
  Future<List<UserProfile>> fetchProfiles(List<String> userIds);

  /// Update statistics for a profile.
  Future<void> updateProfileStats(
    String userId, {
    int? friendsCount,
    int? publicRecipeCount,
  });

  /// Update the online status for a user.
  Future<void> updateOnlineStatus(String userId, bool isOnline);

  /// Search for profiles matching a query
  Future<List<UserProfile>> searchProfiles(String query);

  /// Check if a display name is available
  Future<bool> isDisplayNameAvailable(String displayName);

  /// Update FCM token for push notifications
  Future<void> updateFCMToken(String userId, String token);

  /// Update notification settings
  Future<void> updateNotificationSettings(String userId, bool enabled);

  /// Clear FCM token (e.g., on logout)
  Future<void> clearFCMToken(String userId);

  /// Ensure base user document exists in 'users' collection for friends system
  Future<void> ensureBaseUserDocument(String userId);
}
