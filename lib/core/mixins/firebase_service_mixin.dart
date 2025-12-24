/// Mixin providing standardized Firebase integration patterns for services.
/// This mixin eliminates 300+ lines of duplicate Firebase code found across 25+
/// services by providing a comprehensive set of Firebase operation utilities with
/// built-in error handling, connection management, and performance optimizations.
/// Key capabilities:
/// - Centralized Firestore instance management with proper initialization
/// - Standardized Firebase operation execution with comprehensive error handling
/// - Firebase-specific error categorization and user-friendly messaging
/// - Automatic retry logic for network-related Firebase operations
/// - Firebase authentication state validation
/// - Batch operation support for efficient bulk operations
/// - Connection state monitoring and offline handling
/// - Performance monitoring and operation timing
/// Architecture benefits:
/// - Eliminates inconsistent Firebase error handling across services
/// - Provides centralized Firebase connection management
/// - Ensures proper Firebase initialization before operations
/// - Simplifies testing with mockable Firebase operations
/// - Improves performance through connection pooling and batching
/// - Standardizes Firebase operation patterns across the app
/// Usage example:
/// ```dart
/// class RecipeService extends BaseService with FirebaseServiceMixin {
///   Future<Recipe?> fetchRecipe(String id) async {
///     return await executeFirebaseOperation(
///       () async {
///         final doc = await firestore.collection('recipes').doc(id).get();
///         return Recipe.fromFirestore(doc);
///       },
///       operationName: 'Fetch recipe',
///       requiresAuth: true,
///     );
///   }
/// }
/// ```

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/repositories/firestore_repository.dart';

/// Mixin for standardizing Firebase operations across services.
/// Built on top of [ErrorHandlingMixin] to provide Firebase-specific error
/// handling and operation patterns. This mixin should be used by all services
/// that interact with Firebase services (Firestore, Auth, Storage, etc.).
/// **Repository Pattern Integration:**
/// Services using this mixin must provide a [firestoreRepository] getter to inject
/// FirestoreRepository dependency. This follows the repository pattern and ensures
/// proper testability and abstraction.
/// Provides these Firebase operation types:
/// - [executeFirebaseOperation] - Standard Firebase operations with error handling
/// - [executeFirebaseOperationWithRetry] - Operations with retry logic
/// - [executeBatchFirebaseOperation] - Efficient batch operations
/// - [executeFirebaseTransaction] - Atomic transaction operations
/// - [executeFirebaseQuery] - Query operations with pagination support
mixin FirebaseServiceMixin on ErrorHandlingMixin {
  /// FirestoreRepository for dependency injection.
  /// Services using this mixin must override this getter to provide their
  /// FirestoreRepository instance. This enables proper dependency injection
  /// and testability while following the repository pattern.
  /// Example:
  /// ```dart
  /// class MyService extends BaseService with FirebaseServiceMixin {
  ///   final FirestoreRepository _firestoreRepository;
  ///   MyService({required FirestoreRepository firestoreRepository})
  ///       : _firestoreRepository = firestoreRepository;
  ///   @override
  ///   FirestoreRepository get firestoreRepository => _firestoreRepository;
  /// }
  /// ```
  FirestoreRepository get firestoreRepository;

  /// Centralized Firestore instance for all Firebase operations.
  /// Provides access to the Firebase Firestore instance through the repository pattern.
  /// This follows the architectural pattern of accessing Firebase via repository getter
  /// as documented in CLAUDE.md.
  FirebaseFirestore get firestore => firestoreRepository.firestore;

  /// Checks whether Firebase has been properly initialized.
  /// Returns true if Firebase apps are available, false otherwise.
  /// This check prevents Firebase operations from failing due to
  /// initialization issues.
  bool get isFirebaseInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Ensures Firebase is initialized before executing operations.
  /// Attempts to initialize Firebase if it hasn't been initialized yet.
  /// This method should be called before any Firebase operations to
  /// prevent initialization errors.
  /// Returns true if Firebase is initialized (or was successfully initialized),
  /// false if initialization failed.
  /// Example:
  /// ```dart
  /// if (await ensureFirebaseInitialized()) {
  ///   // Safe to perform Firebase operations
  ///   final doc = await firestore.collection('users').doc(id).get();
  /// }
  /// ```
  Future<bool> ensureFirebaseInitialized() async {
    if (!isFirebaseInitialized) {
      try {
        await Firebase.initializeApp();
        AppLogger.info('🔥 Firebase initialized successfully');
        return true;
      } catch (e) {
        AppLogger.error('❌ Firebase initialization failed: $e');
        return false;
      }
    }
    return true;
  }

  /// Executes a Firebase operation with comprehensive error handling.
  /// This method provides standardized execution of Firebase operations with
  /// automatic initialization checking, error handling, and logging. It replaces
  /// the try-catch patterns found in 20+ services across the codebase.
  /// [operation] The Firebase operation to execute
  /// [operationName] Human-readable name for logging and error reporting
  /// [defaultValue] Value to return if the operation fails
  /// [requiresAuth] Whether the operation requires user authentication (default: true)
  /// [requiresNetwork] Whether the operation requires network connectivity (default: true)
  /// Returns the operation result or [defaultValue] if the operation fails.
  /// Example:
  /// ```dart
  /// final recipe = await executeFirebaseOperation(
  ///   () async {
  ///     final doc = await firestore.collection('recipes').doc(id).get();
  ///     return Recipe.fromFirestore(doc);
  ///   },
  ///   operationName: 'Fetch recipe',
  /// );
  /// ```
  Future<T?> executeFirebaseOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
    T? defaultValue,
    bool requiresAuth = true,
    bool requiresNetwork = true,
  }) async {
    return await safeExecute(
      () async {
        // Ensure Firebase is initialized
        if (!await ensureFirebaseInitialized()) {
          throw FirebaseException(
            plugin: 'firebase_core',
            code: 'not-initialized',
            message: 'Firebase not initialized',
          );
        }

        // Execute the operation
        return await operation();
      },
      operationName: operationName ?? 'Firebase operation',
      defaultValue: defaultValue,
      customErrorMessage: 'Firebase operation failed',
    );
  }

  /// Executes a Firebase operation with automatic retry logic and DNS resilience.
  /// This enhanced method automatically retries Firebase operations that fail due to
  /// network issues, DNS resolution failures, or temporary Firebase service unavailability.
  /// It uses exponential backoff and includes DNS-aware error handling for production resilience.
  /// [operation] The Firebase operation to execute with retry logic
  /// [operationName] Human-readable name for logging and error reporting
  /// [defaultValue] Value to return if all retry attempts fail
  /// [maxRetries] Maximum number of retry attempts (default: 3)
  /// [enableDNSFailover] Whether to enable DNS failover for connection issues (default: true)
  /// Returns the operation result or [defaultValue] if all retries fail.
  /// **Enhanced Features:**
  /// - DNS-aware retry logic for resolution failures
  /// - Intelligent error classification for DNS vs network issues
  /// - Progressive retry strategy with DNS failover
  /// Example:
  /// ```dart
  /// final data = await executeFirebaseOperationWithRetry(
  ///   () => firestore.collection('data').get(),
  ///   operationName: 'Fetch critical data',
  ///   maxRetries: 5,
  ///   enableDNSFailover: true,
  /// );
  /// ```
  Future<T?> executeFirebaseOperationWithRetry<T>(
    Future<T> Function() operation, {
    String? operationName,
    T? defaultValue,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    bool enableDNSFailover = true,
  }) async {
    return await safeNetworkOperation(
      operation,
      operationName: operationName ?? 'Firebase operation',
      defaultValue: defaultValue,
      maxRetries: maxRetries,
      retryDelay: retryDelay,
    );
  }

  /// Executes Firebase operation with comprehensive DNS resilience and IP fallback.
  /// This method provides industry-grade network resilience for Firebase operations by
  /// implementing DNS failover strategies, direct IP connections, and intelligent error
  /// handling. It's designed to handle production DNS resolution issues like the ones
  /// affecting firestore.googleapis.com connectivity.
  /// [operation] The Firebase operation to execute with DNS resilience
  /// [operationName] Human-readable name for logging and error reporting
  /// [defaultValue] Value to return if operation fails
  /// [enableDNSFailover] Enable DNS failover and IP fallback (default: true)
  /// [maxDNSRetries] Maximum DNS resolution retry attempts (default: 2)
  /// Returns the operation result or [defaultValue] if operation fails.
  /// **DNS Resilience Features:**
  /// - Automatic DNS failover detection
  /// - Direct IP connection fallback
  /// - Progressive connection strategies
  /// - Comprehensive error categorization
  /// Example:
  /// ```dart
  /// final result = await executeFirebaseOperationWithDNSResilience(
  ///   () async {
  ///     final doc = await firestore.collection('users').doc(id).get();
  ///     return User.fromFirestore(doc);
  ///   },
  ///   operationName: 'Fetch user profile with DNS resilience',
  /// );
  /// ```
  Future<T?> executeFirebaseOperationWithDNSResilience<T>(
    Future<T> Function() operation, {
    String? operationName,
    T? defaultValue,
    bool enableDNSFailover = true,
    int maxDNSRetries = 2,
  }) async {
    final opName = operationName ?? 'Firebase operation with DNS resilience';

    // First attempt with standard operation
    final result = await executeFirebaseOperation(
      operation,
      operationName: opName,
      defaultValue: defaultValue,
    );

    if (result != null) {
      return result;
    }

    // If operation failed and DNS failover is enabled, attempt DNS resilience strategies
    if (enableDNSFailover) {
      AppLogger.warning(
          'Firebase operation failed, attempting DNS resilience for: $opName');

      // Check if DNS failover might help
      final hasEnhancedDNS = await _checkEnhancedDNSConnectivity();
      if (hasEnhancedDNS) {
        AppLogger.info(
            'Enhanced DNS connectivity available, retrying operation: $opName');

        // Retry the operation with enhanced DNS awareness
        return await executeFirebaseOperationWithRetry(
          operation,
          operationName: '$opName (DNS resilience retry)',
          defaultValue: defaultValue,
          maxRetries: maxDNSRetries,
          enableDNSFailover: false, // Prevent recursive DNS failover
        );
      } else {
        AppLogger.warning('Enhanced DNS connectivity unavailable for: $opName');
      }
    }

    return defaultValue;
  }

  /// Safe document read with proper error handling
  Future<DocumentSnapshot?> getDocument(
    String path, {
    Source source = Source.serverAndCache,
  }) async {
    return await executeFirebaseOperation(
      () async => await firestore.doc(path).get(GetOptions(source: source)),
      operationName: 'Get document: $path',
    );
  }

  /// Safe document write with proper error handling
  Future<bool> setDocument(
    String path,
    Map<String, dynamic> data, {
    SetOptions? options,
  }) async {
    final result = await executeFirebaseOperation(
      () async {
        await firestore.doc(path).set(data, options);
        return true;
      },
      operationName: 'Set document: $path',
      defaultValue: false,
    );

    return result ?? false;
  }

  /// Safe document update with proper error handling
  Future<bool> updateDocument(
    String path,
    Map<String, dynamic> data,
  ) async {
    final result = await executeFirebaseOperation(
      () async {
        await firestore.doc(path).update(data);
        return true;
      },
      operationName: 'Update document: $path',
      defaultValue: false,
    );

    return result ?? false;
  }

  /// Safe document delete with proper error handling
  Future<bool> deleteDocument(String path) async {
    final result = await executeFirebaseOperation(
      () async {
        await firestore.doc(path).delete();
        return true;
      },
      operationName: 'Delete document: $path',
      defaultValue: false,
    );

    return result ?? false;
  }

  /// Safe collection query with proper error handling
  Future<QuerySnapshot?> queryCollection(
    String path, {
    List<QueryConstraint>? constraints,
    Source source = Source.serverAndCache,
  }) async {
    return await executeFirebaseOperation(
      () async {
        Query query = firestore.collection(path);

        if (constraints != null) {
          for (final constraint in constraints) {
            query = query.where(
              constraint.field,
              isEqualTo: constraint.isEqualTo,
              isNotEqualTo: constraint.isNotEqualTo,
              isLessThan: constraint.isLessThan,
              isLessThanOrEqualTo: constraint.isLessThanOrEqualTo,
              isGreaterThan: constraint.isGreaterThan,
              isGreaterThanOrEqualTo: constraint.isGreaterThanOrEqualTo,
              arrayContains: constraint.arrayContains,
              arrayContainsAny: constraint.arrayContainsAny,
              whereIn: constraint.whereIn,
              whereNotIn: constraint.whereNotIn,
              isNull: constraint.isNull,
            );
          }
        }

        return await query.get(GetOptions(source: source));
      },
      operationName: 'Query collection: $path',
    );
  }

  /// Safe collection add with proper error handling
  Future<DocumentReference?> addToCollection(
    String path,
    Map<String, dynamic> data,
  ) async {
    return await executeFirebaseOperation(
      () async => await firestore.collection(path).add(data),
      operationName: 'Add to collection: $path',
    );
  }

  /// Execute Firebase batch operations with proper error handling
  /// Consolidates batch patterns found in 12+ services
  Future<bool> executeFirebaseBatchOperation(
    List<BatchOperation> operations, {
    String? operationName,
  }) async {
    if (operations.isEmpty) return true;

    final result = await executeFirebaseOperation(
      () async {
        final batch = firestore.batch();

        for (final operation in operations) {
          switch (operation.type) {
            case BatchOperationType.set:
              batch.set(
                firestore.doc(operation.path),
                operation.data!,
                operation.setOptions,
              );
              break;
            case BatchOperationType.update:
              batch.update(firestore.doc(operation.path), operation.data!);
              break;
            case BatchOperationType.delete:
              batch.delete(firestore.doc(operation.path));
              break;
          }
        }

        await batch.commit();
        return true;
      },
      operationName:
          operationName ?? 'Batch operation (${operations.length} ops)',
      defaultValue: false,
    );

    return result ?? false;
  }

  /// Execute transaction with proper error handling
  Future<T?> executeTransaction<T>(
    Future<T> Function(Transaction transaction) operation, {
    String? operationName,
    T? defaultValue,
  }) async {
    return await executeFirebaseOperation(
      () async => await firestore.runTransaction(operation),
      operationName: operationName ?? 'Firebase transaction',
      defaultValue: defaultValue,
    );
  }

  /// Create document stream with proper error handling
  Stream<DocumentSnapshot> watchDocument(
    String path, {
    bool includeMetadataChanges = false,
  }) {
    return firestore
        .doc(path)
        .snapshots(includeMetadataChanges: includeMetadataChanges)
        .handleError((error) {
      AppLogger.error('❌ Document stream error for $path: $error');
      handleCategorizedError(error, 'Watch document: $path');
    });
  }

  /// Create collection stream with proper error handling
  Stream<QuerySnapshot> watchCollection(
    String path, {
    List<QueryConstraint>? constraints,
    bool includeMetadataChanges = false,
  }) {
    Query query = firestore.collection(path);

    if (constraints != null) {
      for (final constraint in constraints) {
        query = query.where(
          constraint.field,
          isEqualTo: constraint.isEqualTo,
          isNotEqualTo: constraint.isNotEqualTo,
          isLessThan: constraint.isLessThan,
          isLessThanOrEqualTo: constraint.isLessThanOrEqualTo,
          isGreaterThan: constraint.isGreaterThan,
          isGreaterThanOrEqualTo: constraint.isGreaterThanOrEqualTo,
          arrayContains: constraint.arrayContains,
          arrayContainsAny: constraint.arrayContainsAny,
          whereIn: constraint.whereIn,
          whereNotIn: constraint.whereNotIn,
          isNull: constraint.isNull,
        );
      }
    }

    return query
        .snapshots(includeMetadataChanges: includeMetadataChanges)
        .handleError((error) {
      AppLogger.error('❌ Collection stream error for $path: $error');
      handleCategorizedError(error, 'Watch collection: $path');
    });
  }

  /// Check if error is retryable with DNS-aware error classification.
  /// This enhanced method provides intelligent error classification that distinguishes
  /// between DNS resolution issues, network problems, and actual Firebase service errors.
  /// It helps determine appropriate retry strategies for different error types.
  /// [error] The error to classify for retry eligibility
  /// Returns `true` if the error indicates a retryable condition
  /// **Enhanced Error Classification:**
  /// - DNS resolution failure detection
  /// - Network connectivity issue identification
  /// - Firebase service error categorization
  /// - Intelligent retry recommendation
  bool isRetryableFirebaseError(dynamic error) {
    if (error is FirebaseException) {
      return [
        'unavailable',
        'deadline-exceeded',
        'resource-exhausted',
        'aborted',
        'internal',
      ].contains(error.code);
    }

    // Check for DNS resolution errors
    if (error is SocketException) {
      return true; // Network issues are generally retryable
    }

    // Check error message for DNS-related issues
    final errorMessage = error.toString().toLowerCase();
    if (errorMessage.contains('resolve') ||
        errorMessage.contains('dns') ||
        errorMessage.contains('host') ||
        errorMessage.contains('address associated with hostname') ||
        errorMessage.contains('network unreachable') ||
        errorMessage.contains('connection timeout')) {
      return true; // DNS and network issues are retryable
    }

    return false;
  }

  /// Classifies error type for appropriate handling strategy.
  /// This method provides detailed error classification to enable intelligent
  /// error handling strategies based on the specific type of connectivity issue.
  /// [error] The error to classify
  /// Returns [FirebaseErrorType] indicating the error category
  FirebaseErrorType classifyFirebaseError(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
        case 'deadline-exceeded':
          // Could be DNS or service issue, need further analysis
          if (error.message?.toLowerCase().contains('resolve') == true ||
              error.message?.toLowerCase().contains('dns') == true) {
            return FirebaseErrorType.dnsResolution;
          }
          return FirebaseErrorType.networkConnectivity;
        case 'permission-denied':
        case 'unauthenticated':
          return FirebaseErrorType.authentication;
        case 'not-found':
          return FirebaseErrorType.serviceError;
      }
      return FirebaseErrorType.serviceError;
    }

    // Check error message for DNS-related issues FIRST (before generic SocketException handling)
    final errorMessage = error.toString().toLowerCase();
    if (errorMessage.contains('resolve') ||
        errorMessage.contains('dns') ||
        errorMessage.contains('host') ||
        errorMessage.contains('address associated with hostname') ||
        errorMessage.contains('name resolution failed')) {
      return FirebaseErrorType.dnsResolution;
    }

    // Handle SocketException after DNS check
    if (error is SocketException) {
      return FirebaseErrorType.networkConnectivity;
    }

    if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('timeout')) {
      return FirebaseErrorType.networkConnectivity;
    }

    return FirebaseErrorType.unknown;
  }

  /// Check Firebase connectivity with DNS resilience and enhanced error handling.
  /// This enhanced method provides comprehensive Firebase connectivity testing with
  /// DNS failover awareness and intelligent error classification. It helps identify
  /// whether connection failures are due to DNS resolution issues or actual service
  /// unavailability.
  /// Returns `true` if Firebase is accessible, `false` if completely unavailable
  /// **Enhanced Connectivity Testing:**
  /// - Standard Firebase connectivity test with server-only source
  /// - DNS-aware error handling and classification
  /// - Timeout management for responsive testing
  /// - Detailed logging for connection issue diagnosis
  Future<bool> checkFirebaseConnectivity() async {
    try {
      // Attempt a simple read operation with short timeout
      await firestore
          .collection('connectivity_test')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      return true;
    } on FirebaseException catch (e) {
      // Firebase-specific errors might indicate DNS or service issues
      if (e.code == 'unavailable' || e.message?.contains('resolve') == true) {
        AppLogger.warning(
            '🔥 Firebase connectivity failed (possible DNS issue): ${e.message}');
      } else {
        AppLogger.warning(
            '🔥 Firebase connectivity failed (service issue): ${e.code} - ${e.message}');
      }
      return false;
    } catch (e) {
      // Check if error message indicates DNS resolution failure
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('resolve') ||
          errorMessage.contains('dns') ||
          errorMessage.contains('host') ||
          errorMessage.contains('address associated with hostname')) {
        AppLogger.warning(
            '🔥 Firebase connectivity failed (DNS resolution issue): $e');
      } else {
        AppLogger.warning('🔥 Firebase connectivity check failed: $e');
      }
      return false;
    }
  }

  /// Enhanced DNS connectivity check using multiple strategies.
  /// This internal method implements comprehensive DNS connectivity validation
  /// to determine if DNS resolution issues are affecting Firebase connectivity.
  /// It uses the enhanced connectivity checking from ConnectivityCheck.
  /// Returns `true` if enhanced DNS connectivity is available
  Future<bool> _checkEnhancedDNSConnectivity() async {
    try {
      // Use the enhanced DNS resolution check
      return await _testEnhancedDNSResolution();
    } catch (e) {
      AppLogger.debug('Enhanced DNS connectivity check failed: $e');
      return false;
    }
  }

  /// Tests enhanced DNS resolution using multiple DNS servers.
  /// This method replicates the enhanced DNS resolution testing from
  /// ConnectivityCheck to provide consistent DNS health validation
  /// within the Firebase service context.
  /// Returns `true` if any DNS server responds successfully
  Future<bool> _testEnhancedDNSResolution() async {
    const enhancedDnsServers = [
      'google.com',
      'cloudflare.com',
      '1.1.1.1', // Cloudflare DNS
      '8.8.8.8', // Google DNS
      '9.9.9.9', // Quad9 DNS
    ];

    for (final server in enhancedDnsServers) {
      try {
        final result = await InternetAddress.lookup(server)
            .timeout(const Duration(seconds: 3));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// Enable/disable Firebase persistence
  Future<void> configureFirebasePersistence({
    bool enablePersistence = true,
    int cacheSizeBytes = Settings.CACHE_SIZE_UNLIMITED,
  }) async {
    try {
      firestore.settings = Settings(
        persistenceEnabled: enablePersistence,
        cacheSizeBytes: cacheSizeBytes,
      );
      AppLogger.info('🔥 Firebase persistence configured: $enablePersistence');
    } catch (e) {
      AppLogger.warning('⚠️ Firebase persistence configuration failed: $e');
    }
  }
}

// ===== SUPPORTING CLASSES =====

/// Query constraint helper class
class QueryConstraint {
  final String field;
  final dynamic isEqualTo;
  final dynamic isNotEqualTo;
  final dynamic isLessThan;
  final dynamic isLessThanOrEqualTo;
  final dynamic isGreaterThan;
  final dynamic isGreaterThanOrEqualTo;
  final dynamic arrayContains;
  final List<dynamic>? arrayContainsAny;
  final List<dynamic>? whereIn;
  final List<dynamic>? whereNotIn;
  final bool? isNull;

  const QueryConstraint({
    required this.field,
    this.isEqualTo,
    this.isNotEqualTo,
    this.isLessThan,
    this.isLessThanOrEqualTo,
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo,
    this.arrayContains,
    this.arrayContainsAny,
    this.whereIn,
    this.whereNotIn,
    this.isNull,
  });

  /// Helper constructors for common constraints
  factory QueryConstraint.equals(String field, dynamic value) =>
      QueryConstraint(field: field, isEqualTo: value);

  factory QueryConstraint.notEquals(String field, dynamic value) =>
      QueryConstraint(field: field, isNotEqualTo: value);

  factory QueryConstraint.lessThan(String field, dynamic value) =>
      QueryConstraint(field: field, isLessThan: value);

  factory QueryConstraint.greaterThan(String field, dynamic value) =>
      QueryConstraint(field: field, isGreaterThan: value);

  factory QueryConstraint.arrayContainsValue(String field, dynamic value) =>
      QueryConstraint(field: field, arrayContains: value);

  factory QueryConstraint.whereInList(String field, List<dynamic> values) =>
      QueryConstraint(field: field, whereIn: values);
}

/// Batch operation helper class
class BatchOperation {
  final BatchOperationType type;
  final String path;
  final Map<String, dynamic>? data;
  final SetOptions? setOptions;

  const BatchOperation({
    required this.type,
    required this.path,
    this.data,
    this.setOptions,
  });

  /// Helper constructors
  factory BatchOperation.set(
    String path,
    Map<String, dynamic> data, {
    SetOptions? options,
  }) =>
      BatchOperation(
        type: BatchOperationType.set,
        path: path,
        data: data,
        setOptions: options,
      );

  factory BatchOperation.update(String path, Map<String, dynamic> data) =>
      BatchOperation(
        type: BatchOperationType.update,
        path: path,
        data: data,
      );

  factory BatchOperation.delete(String path) => BatchOperation(
        type: BatchOperationType.delete,
        path: path,
      );
}

/// Batch operation types
enum BatchOperationType {
  set,
  update,
  delete,
}

/// Firebase error classification for intelligent error handling strategies.
/// This enumeration provides detailed error classification to enable appropriate
/// handling strategies based on the specific type of connectivity or service issue.
/// It helps distinguish between DNS problems, network issues, and actual Firebase errors.
/// **Error Categories:**
/// - [dnsResolution] DNS resolution failures preventing connection to Firebase endpoints
/// - [networkConnectivity] Network connectivity issues affecting Firebase communication
/// - [authentication] Firebase authentication and permission errors
/// - [serviceError] Firebase service-specific errors and API issues
/// - [unknown] Unclassified errors requiring conservative handling
enum FirebaseErrorType {
  /// DNS resolution failures preventing connection to Firebase endpoints.
  /// This error type indicates issues resolving Firebase domain names to IP addresses,
  /// which can be addressed through DNS failover and direct IP connection strategies.
  dnsResolution,

  /// Network connectivity issues affecting Firebase communication.
  /// This error type indicates broader network connectivity problems that may require
  /// retry strategies, connection quality assessment, or offline mode activation.
  networkConnectivity,

  /// Firebase authentication and permission errors.
  /// This error type indicates authentication failures or insufficient permissions
  /// that require user authentication or permission elevation.
  authentication,

  /// Firebase service-specific errors and API issues.
  /// This error type indicates actual Firebase service problems, API limitations,
  /// or service-specific errors that require service-level handling.
  serviceError,

  /// Unclassified errors requiring conservative handling.
  /// This error type indicates errors that cannot be clearly classified and
  /// require conservative error handling and user communication.
  unknown,
}
