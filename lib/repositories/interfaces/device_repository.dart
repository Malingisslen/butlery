/// Repository interface for device and FCM token management.
/// Extracted from NotificationsRepository to separate device concerns.
abstract class DeviceRepository {
  /// Save FCM token to Firestore (per-device model)
  Future<void> saveTokenToFirestore(
      String docId, Map<String, dynamic> tokenData);

  /// Update device information
  Future<void> updateDeviceInfo(String docId, Map<String, dynamic> deviceData);

  /// Update token timestamp without changing token data
  Future<void> updateTokenTimestamp(String docId);

  /// Remove old token by marking device as inactive via direct doc lookup
  Future<void> removeOldToken(String userId, String deviceId);

  /// Get all active tokens for a user
  Future<List<String>> getAllUserTokens(String userId);

  /// Mark device as inactive
  Future<void> markDeviceInactive(String docId);

  /// Cleanup old devices for a user
  Future<void> cleanupOldDevices(String userId, DateTime olderThan);
}
