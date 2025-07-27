import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/user_profile.dart';

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
