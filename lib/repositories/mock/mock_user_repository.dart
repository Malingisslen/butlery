import '../interfaces/user_repository.dart';
import '../../models/user_profile.dart';
import 'in_memory_repository.dart';

/// In-memory implementation of [UserRepository] for tests.
class MockUserRepository extends InMemoryRepository<UserProfile>
    implements UserRepository {
  MockUserRepository() : super((p) => p.uid);

  @override
  Future<void> saveProfile(UserProfile profile) async {
    items[profile.uid] = profile;
  }

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    return items[userId];
  }

  @override
  Future<List<UserProfile>> fetchProfiles(List<String> userIds) async {
    return [
      for (final id in userIds)
        if (items.containsKey(id)) items[id]!
    ];
  }

  @override
  Future<void> updateProfileStats(
    String userId, {
    int? friendsCount,
    int? publicRecipeCount,
  }) async {
    final profile = items[userId];
    if (profile == null) return;
    items[userId] = profile.copyWith(
      friendsCount: friendsCount ?? profile.friendsCount,
      publicRecipeCount: publicRecipeCount ?? profile.publicRecipeCount,
    );
  }

  @override
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    final profile = items[userId];
    if (profile == null) return;
    items[userId] = profile.copyWith(isOnline: isOnline);
  }

  @override
  Future<List<UserProfile>> searchProfiles(String query) async {
    return items.values
        .where((p) => p.matchesSearchTerm(query))
        .toList();
  }

  @override
  Future<bool> isDisplayNameAvailable(String displayName) async {
    return !items.values.any((p) => p.displayName == displayName);
  }

  @override
  Future<void> updateFCMToken(String userId, String token) async {
    final profile = items[userId];
    if (profile == null) return;
    items[userId] = profile.copyWith(
      fcmToken: token,
      fcmTokenUpdatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> updateNotificationSettings(String userId, bool enabled) async {
    final profile = items[userId];
    if (profile == null) return;
    items[userId] = profile.copyWith(notificationsEnabled: enabled);
  }

  @override
  Future<void> clearFCMToken(String userId) async {
    final profile = items[userId];
    if (profile == null) return;
    items[userId] = profile.copyWith(
      fcmToken: null,
      fcmTokenUpdatedAt: null,
    );
  }

  @override
  Future<void> ensureBaseUserDocument(String userId) async {
    // Mock implementation - no-op for testing
    return;
  }
}
