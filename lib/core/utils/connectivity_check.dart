/// Comprehensive connectivity validation utility providing reliable internet and Firebase connection testing.
///
/// This utility class implements sophisticated connectivity validation using multiple DNS servers, timeout management,
/// and specialized Firebase connectivity testing. It provides reliable connectivity detection for applications requiring
/// robust network validation with graceful degradation strategies and comprehensive error handling throughout
/// different network conditions and connectivity scenarios.
///
/// **Architecture Integration:**
/// - Uses [InternetAddress.lookup] for DNS-based connectivity validation with multiple server fallbacks
/// - Integrates with [ConnectivityRepository] for Firebase-specific connectivity testing and validation
/// - Coordinates with [AppLogger] for detailed connectivity debugging and performance monitoring
/// - Implements timeout-based validation preventing hanging operations in poor network conditions
/// - Provides comprehensive connectivity result categorization for appropriate application responses
///
/// **Connectivity Validation Features:**
/// - **Basic Internet Testing**: Simple DNS lookup validation with Google DNS for rapid connectivity detection
/// - **Robust Multi-Server Testing**: Multiple DNS server validation with Cloudflare, Google, and direct IP fallbacks
/// - **Firebase Connectivity**: Specialized Firebase database connectivity testing through repository abstraction
/// - **Comprehensive Results**: Detailed connectivity categorization including none, limited, full, and unknown states
/// - **Timeout Management**: Configurable timeout handling preventing indefinite waiting in poor network conditions
/// - **Error Recovery**: Graceful error handling with appropriate fallback strategies and detailed logging
///
/// **DNS Server Strategy:**
/// - **Primary**: Google DNS (google.com) for general internet connectivity validation
/// - **Secondary**: Cloudflare (cloudflare.com) for alternative CDN-based validation
/// - **Tertiary**: Direct IP addresses (1.1.1.1, 8.8.8.8) for DNS-independent validation
/// - **Timeout**: Progressive timeout strategies from 3-5 seconds for optimal performance
///
/// **Usage Examples:**
/// ```dart
/// // Basic internet connectivity check
/// final hasInternet = await ConnectivityCheck.hasInternetConnection();
/// 
/// // Robust multi-server connectivity validation
/// final isConnected = await ConnectivityCheck.hasRobustInternetConnection();
/// 
/// // Firebase-specific connectivity testing
/// final firebaseOnline = await ConnectivityCheck.hasFirebaseConnectivity();
/// 
/// // Comprehensive connectivity analysis
/// final result = await ConnectivityCheck.checkConnectivity();
/// switch (result) {
///   case ConnectivityResult.full:
///     // Enable all online features
///     break;
///   case ConnectivityResult.limited:
///     // Enable basic features, disable Firebase-dependent functionality
///     break;
///   case ConnectivityResult.none:
///     // Switch to offline mode
///     break;
/// }
/// ```

import 'dart:io';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Connectivity validation utility providing reliable internet and Firebase connection testing with comprehensive error handling.
///
/// This utility class implements multiple validation strategies for different connectivity requirements, from basic
/// internet connectivity to specialized Firebase database connectivity. It provides timeout-managed validation with
/// graceful degradation and comprehensive connectivity result categorization for optimal application behavior.
///
/// **Static Utility Design:**
/// All methods are static for convenient access without instantiation overhead, providing pure utility functions
/// with comprehensive error handling and timeout management for reliable connectivity validation across different
/// network conditions and device environments.
class ConnectivityCheck {
  /// Performs basic internet connectivity validation using Google DNS with timeout management.
  ///
  /// This method provides rapid internet connectivity detection through a single DNS lookup to Google's
  /// reliable DNS servers. It implements a 3-second timeout for responsive validation without hanging
  /// operations in poor network conditions, making it ideal for quick connectivity checks.
  ///
  /// Returns `true` if internet connectivity is available, `false` if offline or connection fails
  ///
  /// **Validation Strategy:**
  /// - **DNS Target**: google.com for reliable, globally available DNS resolution
  /// - **Timeout**: 3 seconds for responsive validation without indefinite waiting
  /// - **Error Handling**: Comprehensive exception handling for SocketException and general errors
  /// - **Performance**: Single DNS lookup for rapid connectivity validation
  ///
  /// **Usage Examples:**
  /// ```dart
  /// // Quick connectivity check before network operations
  /// if (await ConnectivityCheck.hasInternetConnection()) {
  ///   // Proceed with network operations
  ///   await syncData();
  /// } else {
  ///   // Handle offline state
  ///   showOfflineMessage();
  /// }
  /// ```
  ///
  /// **Performance:** O(1) - Single DNS lookup with 3-second timeout
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Performs comprehensive connectivity validation using multiple DNS servers with progressive fallback strategies.
  ///
  /// This method implements robust connectivity detection by testing multiple DNS servers including domain names
  /// and direct IP addresses. It provides reliable connectivity validation even when individual DNS servers
  /// are unavailable, ensuring accurate connectivity detection across various network conditions.
  ///
  /// Returns `true` if any DNS server responds successfully, `false` if all servers fail
  ///
  /// **Multi-Server Strategy:**
  /// - **google.com**: Primary DNS target for general internet connectivity
  /// - **cloudflare.com**: Secondary CDN-based validation for alternative routing
  /// - **1.1.1.1**: Cloudflare's direct IP for DNS-independent validation
  /// - **8.8.8.8**: Google's direct IP for redundant DNS-independent validation
  ///
  /// **Validation Features:**
  /// - **Progressive Fallback**: Tests servers sequentially until one succeeds
  /// - **Extended Timeout**: 5-second timeout per server for reliable validation
  /// - **Mixed Validation**: Combines domain and IP-based validation strategies
  /// - **Comprehensive Coverage**: Multiple providers ensure broad connectivity detection
  ///
  /// **Usage Examples:**
  /// ```dart
  /// // Reliable connectivity check before critical operations
  /// final isOnline = await ConnectivityCheck.hasRobustInternetConnection();
  /// if (isOnline) {
  ///   await performCriticalSync();
  /// } else {
  ///   enableOfflineMode();
  /// }
  /// ```
  ///
  /// **Performance:** O(n) - Up to 4 DNS lookups with 5-second timeout each
  static Future<bool> hasRobustInternetConnection() async {
    final dnsServers = [
      'google.com',
      'cloudflare.com',
      '1.1.1.1',
      '8.8.8.8',
    ];

    for (final server in dnsServers) {
      try {
        final result = await InternetAddress.lookup(server)
            .timeout(const Duration(seconds: 5));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          return true;
        }
      } on SocketException catch (_) {
        continue;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// Validates Firebase database connectivity through repository abstraction with comprehensive error handling.
  ///
  /// This method performs specialized Firebase connectivity testing using the connectivity repository pattern
  /// to ensure proper Firebase database access. It provides isolated Firebase connectivity validation
  /// independent of general internet connectivity, enabling accurate Firebase-specific feature management.
  ///
  /// Returns `true` if Firebase database connectivity is available, `false` if Firebase is unreachable
  ///
  /// **Firebase Validation Features:**
  /// - **Repository Abstraction**: Uses ConnectivityRepository for testable Firebase connectivity
  /// - **Service Integration**: Integrates with dependency injection through ServiceLocator
  /// - **Error Isolation**: Comprehensive error handling with detailed debug logging
  /// - **Feature Management**: Enables conditional Firebase-dependent feature activation
  ///
  /// **Usage Examples:**
  /// ```dart
  /// // Check Firebase availability before database operations
  /// final firebaseOnline = await ConnectivityCheck.hasFirebaseConnectivity();
  /// if (firebaseOnline) {
  ///   await syncRecipesToFirebase();
  /// } else {
  ///   // Queue operations for later sync
  ///   queuePendingOperations();
  /// }
  /// ```
  ///
  /// **Architecture:** Uses repository pattern for testable and flexible Firebase connectivity
  static Future<bool> hasFirebaseConnectivity() async {
    try {
      final connectivityRepo = ServiceLocator.get<ConnectivityRepository>();
      return await connectivityRepo.checkFirebaseConnection();
    } catch (e) {
      AppLogger.debug('Firebase connectivity test failed: $e');
      return false;
    }
  }

  /// Performs comprehensive connectivity analysis with detailed result categorization for optimal application behavior.
  ///
  /// This method executes complete connectivity validation including both internet and Firebase connectivity
  /// testing to provide detailed connectivity status information. It enables applications to make informed
  /// decisions about feature availability and appropriate user experience adaptations.
  ///
  /// Returns [ConnectivityResult] with detailed connectivity status categorization
  ///
  /// **Connectivity Analysis Process:**
  /// 1. **Internet Validation**: Tests robust internet connectivity using multiple DNS servers
  /// 2. **Firebase Validation**: Tests Firebase database connectivity through repository abstraction
  /// 3. **Result Categorization**: Provides detailed connectivity status for appropriate application responses
  /// 4. **Error Handling**: Comprehensive error handling with appropriate fallback categorization
  ///
  /// **Result Categories:**
  /// - **ConnectivityResult.full**: Complete internet and Firebase connectivity available
  /// - **ConnectivityResult.limited**: Internet available but Firebase unreachable
  /// - **ConnectivityResult.none**: No internet connectivity detected
  /// - **ConnectivityResult.unknown**: Unable to determine connectivity due to errors
  ///
  /// **Usage Examples:**
  /// ```dart
  /// // Comprehensive connectivity-based feature management
  /// final connectivity = await ConnectivityCheck.checkConnectivity();
  /// switch (connectivity) {
  ///   case ConnectivityResult.full:
  ///     enableAllFeatures();
  ///     break;
  ///   case ConnectivityResult.limited:
  ///     enableBasicFeatures();
  ///     disableFirebaseFeatures();
  ///     break;
  ///   case ConnectivityResult.none:
  ///     enableOfflineMode();
  ///     break;
  ///   case ConnectivityResult.unknown:
  ///     showConnectivityWarning();
  ///     break;
  /// }
  /// ```
  ///
  /// **Performance:** Sequential validation with comprehensive error handling and logging
  static Future<ConnectivityResult> checkConnectivity() async {
    try {
      // Check basic internet connectivity
      final hasInternet = await hasRobustInternetConnection();
      if (!hasInternet) {
        return ConnectivityResult.none;
      }

      // Check Firebase connectivity
      final hasFirebase = await hasFirebaseConnectivity();
      if (!hasFirebase) {
        return ConnectivityResult.limited;
      }

      return ConnectivityResult.full;
    } catch (e) {
      AppLogger.error('Connectivity check failed: $e');
      return ConnectivityResult.unknown;
    }
  }
}

/// Comprehensive connectivity status enumeration providing detailed connectivity categorization for optimal application behavior.
///
/// This enumeration defines the possible connectivity states returned by the connectivity validation system,
/// enabling applications to make informed decisions about feature availability and appropriate user experience
/// adaptations. Each state represents a distinct connectivity condition with specific characteristics and recommended responses.
///
/// **Connectivity State Categories:**
/// - [none] Complete absence of internet connectivity requiring offline mode activation
/// - [limited] Internet connectivity available but Firebase services unreachable
/// - [full] Complete connectivity with both internet and Firebase database access
/// - [unknown] Connectivity status cannot be determined due to validation errors
///
/// **Usage Examples:**
/// ```dart
/// final connectivity = await ConnectivityCheck.checkConnectivity();
/// switch (connectivity) {
///   case ConnectivityResult.full:
///     // Enable all online features including Firebase-dependent operations
///     enableRealTimeSync();
///     enableSocialFeatures();
///     break;
///   case ConnectivityResult.limited:
///     // Enable basic online features, disable Firebase operations
///     enableBasicNetworkFeatures();
///     disableRealTimeFeatures();
///     break;
///   case ConnectivityResult.none:
///     // Switch to complete offline mode
///     enableOfflineMode();
///     disableAllNetworkFeatures();
///     break;
///   case ConnectivityResult.unknown:
///     // Handle uncertain connectivity with conservative approach
///     showConnectivityWarning();
///     enableLimitedMode();
///     break;
/// }
/// ```
enum ConnectivityResult {
  /// Complete absence of internet connectivity requiring offline mode activation.
  ///
  /// This state indicates that no internet connection could be established through any of the tested
  /// DNS servers, requiring the application to switch to complete offline mode with local-only
  /// functionality and queued operations for later synchronization.
  none,
  
  /// Internet connectivity available but Firebase services unreachable.
  ///
  /// This state indicates that basic internet connectivity exists but Firebase database services
  /// are not accessible, enabling basic online features while disabling Firebase-dependent
  /// functionality such as real-time synchronization and social features.
  limited,
  
  /// Complete connectivity with both internet and Firebase database access.
  ///
  /// This state indicates optimal connectivity conditions with both internet and Firebase services
  /// available, enabling all application features including real-time synchronization, social
  /// interactions, and collaborative functionality.
  full,
  
  /// Connectivity status cannot be determined due to validation errors.
  ///
  /// This state indicates that connectivity validation encountered errors preventing accurate
  /// status determination, requiring conservative feature management and appropriate user
  /// communication about uncertain connectivity conditions.
  unknown,
}
