// lib/repositories/interfaces/connectivity_repository.dart

/// Repository interface for connectivity monitoring
abstract class ConnectivityRepository {
  /// Stream of connection status changes
  Stream<bool> get connectionStream;
  
  /// Check current Firebase connection status
  Future<bool> checkFirebaseConnection();
  
  /// Monitor Firebase connection changes
  Stream<bool> monitorFirebaseConnection();
  
  /// Test connectivity with a specific endpoint
  Future<bool> testEndpoint(String endpoint);
  
  /// Get current connection quality
  Future<ConnectionQuality> getConnectionQuality();
}

/// Connection quality levels
enum ConnectionQuality {
  excellent,
  good,
  fair,
  poor,
  offline,
}