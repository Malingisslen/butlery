// lib/services/unified/friends/friends_service_stubs.dart

/// Consolidated friends service coordinator providing access to specialized friend services.
/// This coordinator is a simplified implementation providing access to sync, presence, and cache services.
class FriendsServiceCoordinator {
  FriendsServiceCoordinator();

  // Service getters (simplified implementations)
  FriendsSyncService get sync => FriendsSyncService();
  FriendsPresenceService get presence => FriendsPresenceService();
  FriendsCacheService get cache => FriendsCacheService();

  // Initialization methods (simplified)
  Future<void> initialize() async {}
  Future<void> refresh() async {}
  void clearError() {}
  void dispose() {}
}

/// Consolidated friends sync service (simplified)
class FriendsSyncService {
  FriendsSyncService();
}

/// Consolidated friends presence service (simplified)
class FriendsPresenceService {
  FriendsPresenceService();
}

/// Consolidated friends cache service (simplified)
class FriendsCacheService {
  FriendsCacheService();
}
