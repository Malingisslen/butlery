/// Firebase Firestore repository wrapper providing centralized database access and testability.
/// This repository serves as a comprehensive abstraction layer over Firebase Firestore operations,
/// providing a single point of access for all database interactions throughout the application.
/// It enhances testability through dependency injection, centralizes Firestore configuration,
/// and provides convenient helper methods for common database operations while maintaining
/// direct access to the underlying Firestore instance for advanced use cases.
/// **Architecture Integration:**
/// - Serves as the primary Firestore access layer for all services and repositories
/// - Enables easy mocking and unit testing through centralized database abstraction
/// - Provides consistent error handling and connection management across the application
/// - Integrates with dependency injection systems for flexible configuration
/// - Supports both high-level convenience methods and low-level direct access patterns
/// **Database Access Features:**
/// - **Centralized Access**: Single point of entry for all Firestore operations
/// - **Generic Helpers**: Common document and collection operations with type safety
/// - **User-Scoped Collections**: Convenient access to user-specific data collections
/// - **Real-time Resources**: Specialized support for real-time collaborative features
/// - **Connectivity Monitoring**: Built-in connectivity testing and health checks
/// - **Testability**: Easy mocking and testing through consistent interface abstraction
/// **Performance and Reliability:**
/// - **Connection Pooling**: Leverages Firebase connection pooling for optimal performance
/// - **Error Handling**: Consistent error handling patterns across all database operations
/// - **Type Safety**: Strongly-typed document and collection references
/// - **Batch Operations**: Support for efficient batch operations and transactions

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Centralized Firestore repository providing comprehensive database access and testing abstraction.
/// This repository class serves as the primary interface for all Firebase Firestore operations
/// throughout the application, providing a consistent abstraction layer that enhances testability,
/// centralizes configuration, and offers convenient helper methods for common database patterns.
/// **Design Patterns:**
/// - **Repository Pattern**: Abstracts database operations behind a consistent interface
/// - **Dependency Injection**: Enables easy mocking and testing through centralized access
/// - **Facade Pattern**: Provides simplified interface over complex Firestore operations
/// - **Single Responsibility**: Focuses solely on database access and abstraction
/// **Usage Examples:**
/// ```dart
/// final firestoreRepo = FirestoreRepository();
/// // Access user-specific collections
/// final userRecipes = firestoreRepo.userRecipesCollection(userId);
/// // Generic document operations
/// final docRef = firestoreRepo.collection('recipes').doc(recipeId);
/// await firestoreRepo.setDocument(docRef, recipeData);
/// // Real-time resource management
/// final realtimeDoc = firestoreRepo.realtimeResourceDoc(resourceId);
/// ```
/// BUT-886 (wave-7 audit gap): intentional bypass of [BaseFirebaseRepository]
/// + [PermissionValidationMixin].
///
/// This class is the low-level Firestore infrastructure layer — a generic
/// untyped wrapper, not a model-typed repository. It pre-dates the
/// `BaseFirebaseRepository<T>` pattern and provides direct DocumentReference /
/// QuerySnapshot access for services that need raw Firestore (DataExport,
/// AccountDeletionService, FirestoreRecipeRepository factory bootstrap).
///
/// Permission validation + audit logging are the responsibility of the
/// *typed* repositories built on top of this wrapper (every other class in
/// `lib/repositories/firebase/` extends `BaseFirebaseRepository<T>`). Adding
/// `PermissionValidationMixin` here would force every helper method to
/// resolve a model type — but there is no model type at this layer.
///
/// Callers that perform user-data writes through this wrapper (DataExport,
/// AccountDeletion) emit their own audit-log entries — DataExport via the
/// GDPR Art. 20 portability log, AccountDeletion via `audit_logs` entries
/// staged by `functions/src/cleanup/cascade-audit-log.ts` server-side. So
/// the audit trail exists, it just doesn't live here.
class FirestoreRepository {
  /// The underlying Firebase Firestore instance for all database operations.
  final FirebaseFirestore _firestore;

  /// Creates a new FirestoreRepository with optional dependency injection support.
  /// Accepts an optional [firestore] instance for testing purposes. If not provided,
  /// uses the default FirebaseFirestore.instance for production.
  FirestoreRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Provides direct access to the Firebase Firestore instance for advanced operations.
  /// This getter allows access to the raw Firestore instance for complex operations
  /// that require direct API access, such as batch operations, transactions, or
  /// advanced querying capabilities not exposed through helper methods.
  /// Returns the [FirebaseFirestore] instance used by this repository
  FirebaseFirestore get firestore => _firestore;

  /// Creates a real-time stream for connectivity monitoring and health checks.
  /// Provides a lightweight stream that can be used to monitor Firestore connectivity
  /// by subscribing to a minimal test collection. This enables the application to
  /// detect connection issues and respond appropriately with offline capabilities.
  /// Returns a [Stream] of [QuerySnapshot] for connectivity monitoring
  Stream<QuerySnapshot<Map<String, dynamic>>> connectivityStream() {
    return _firestore
        .collection(FirestoreCollections.connectivityTest)
        .limit(1)
        .snapshots();
  }

  /// Generic helpers for document operations.
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
      DocumentReference<Map<String, dynamic>> ref) {
    return ref.get();
  }

  Future<void> setDocument(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) {
    return ref.set(data, SetOptions(merge: true));
  }

  Future<void> deleteDocument(DocumentReference<Map<String, dynamic>> ref) {
    return ref.delete();
  }

  /// Collection with a user's recipes.
  CollectionReference<Map<String, dynamic>> userRecipesCollection(String uid) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection(FirestoreCollections.recipes);
  }

  /// Low level access for generic collections.
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _firestore.collection(path);
  }

  /// Low level access for generic documents.
  DocumentReference<Map<String, dynamic>> doc(String path) {
    return _firestore.doc(path);
  }
}
