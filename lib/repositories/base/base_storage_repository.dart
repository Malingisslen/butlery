/// Base repository for Firebase Storage operations with security validation.
/// This abstract base class provides unified patterns for repositories that handle
/// file storage operations - uploads, downloads, deletions, and directory management.
/// Architecture Integration:
/// - Uses PermissionValidationMixin for security enforcement
/// - Integrates with AuthRepository for user authentication
/// - Integrates with FirebaseAuditRepository for GDPR Article 30 compliance
/// - Provides injectable FirebaseStorage instance for testability
/// Key Features:
/// - Path-based security validation (users can only access their own directories)
/// - Comprehensive audit logging for all storage operations
/// - Recursive directory deletion for GDPR compliance (right to erasure)
/// - Unified error handling and permission checks
/// - Support for both file uploads and deletions
/// **Usage Example:**
/// ```dart
/// class FirebaseStorageRepository extends BaseStorageRepository {
///   FirebaseStorageRepository({
///     super.storage,
///     required super.authRepository,
///     super.auditRepository,
///   });
///   // Image-specific operations (compression, thumbnails, etc.)
///   Future<String?> uploadImage(File imageFile, String userId, String path) async {
///     await validatePathPermission(userId, path, 'upload');
///     // ... image-specific logic
///   }
/// }
/// ```
/// **Architectural Decision:**
/// This base class exists separately from BaseFirebaseRepository because:
/// - Storage operates on binary files, not Firestore documents
/// - Uses firebase_storage SDK instead of cloud_firestore
/// - Different data model: Buckets → Paths → Files (vs Collections → Documents)
/// - Different operations: Upload/Download/Delete files (vs CRUD on documents)
/// See: docs/architecture/FIREBASE_STORAGE_REPOSITORY_EXCLUSION.md

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/mixins/permission_validation_mixin.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';

/// Base class for Firebase Storage repositories.
/// This class consolidates common storage operation patterns and security validation:
/// - Unified permission validation for path-based access control
/// - Unified audit logging for GDPR Article 30 compliance
/// - Unified recursive directory deletion for right to erasure
/// - Unified file listing and metadata operations
/// Pattern Usage:
/// 1. File Operations: upload, delete, getDownloadURL (implemented by subclasses)
/// 2. Directory Operations: deleteDirectory, listFiles (provided by base class)
/// 3. Security Validation: validatePathPermission, extractUserIdFromPath
/// 4. Audit Logging: All operations logged for GDPR compliance
abstract class BaseStorageRepository with PermissionValidationMixin {
  // Lazy so constructing a BaseStorageRepository subclass doesn't require
  // Firebase.initializeApp(); FirebaseStorage.instance is only resolved on
  // first actual storage access. Tests that never touch storage can still
  // wire up a service that uses this repository.
  final FirebaseStorage? _storageOverride;
  FirebaseStorage? _resolvedStorage;
  final AuthRepository _authRepository;
  final FirebaseAuditRepository? _auditRepository;

  BaseStorageRepository({
    FirebaseStorage? storage,
    required AuthRepository authRepository,
    FirebaseAuditRepository? auditRepository,
  }) : _storageOverride = storage,
       _authRepository = authRepository,
       _auditRepository = auditRepository;

  /// Protected access to FirebaseStorage instance for subclasses
  @protected
  FirebaseStorage get storage =>
      _storageOverride ?? (_resolvedStorage ??= FirebaseStorage.instance);

  /// Protected access to AuthRepository instance for subclasses
  @protected
  AuthRepository get authRepository => _authRepository;

  /// Protected access to audit repository for explicit logging
  @protected
  FirebaseAuditRepository? get auditRepository => _auditRepository;

  /// Get current authenticated user ID
  @protected
  String? get currentUserId => _authRepository.currentUser?.uid;

  /// Get storage reference for a path
  /// This is the primary method for accessing Firebase Storage references.
  /// **Usage:** Subclasses use this to get references for upload/download operations
  @protected
  Reference getReference(String path) {
    return storage.ref(path);
  }

  /// Get download URL for a file at the specified path
  /// **Security:** Should be called after validatePathPermission check
  /// **Returns:** Download URL string, or null if file doesn't exist
  @protected
  Future<String?> getDownloadURL(String path) async {
    try {
      final ref = getReference(path);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        AppLogger.warning('File not found at path: $path');
        return null;
      }
      AppLogger.error('Failed to get download URL for path: $path', e);
      throw RepositoryException('Failed to get download URL: ${e.message}');
    }
  }

  /// Get metadata for a file at the specified path
  /// **Security:** Should be called after validatePathPermission check
  /// **Returns:** FullMetadata object, or null if file doesn't exist
  @protected
  Future<FullMetadata?> getMetadata(String path) async {
    try {
      final ref = getReference(path);
      return await ref.getMetadata();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        AppLogger.warning('File not found at path: $path');
        return null;
      }
      AppLogger.error('Failed to get metadata for path: $path', e);
      throw RepositoryException('Failed to get metadata: ${e.message}');
    }
  }

  /// List all files in a directory
  /// **Security:** Should be called after validatePathPermission check
  /// **Returns:** ListResult containing files and subdirectories
  @protected
  Future<ListResult> listFiles(String path) async {
    try {
      final ref = getReference(path);
      return await ref.listAll();
    } on FirebaseException catch (e) {
      AppLogger.error('Failed to list files at path: $path', e);
      throw RepositoryException('Failed to list files: ${e.message}');
    }
  }

  /// Recursively delete all files in a directory and its subdirectories
  /// **Use Case:** GDPR Article 17 - Right to Erasure
  /// **Security:** Should be called after validatePathPermission check
  /// **Warning:** This is a destructive operation that cannot be undone
  @protected
  Future<void> deleteDirectory(String path, {bool logAudit = true}) async {
    try {
      final ref = getReference(path);
      await _deleteDirectoryRecursive(ref, logAudit: logAudit);

      if (logAudit) {
        AppLogger.success('Successfully deleted directory: $path');
      }
    } on FirebaseException catch (e) {
      AppLogger.error('Failed to delete directory: $path', e);
      throw RepositoryException('Failed to delete directory: ${e.message}');
    }
  }

  /// Helper method for recursive directory deletion
  Future<void> _deleteDirectoryRecursive(
    Reference dirRef, {
    bool logAudit = true,
  }) async {
    try {
      final result = await dirRef.listAll();

      // Delete all files in this directory
      for (final fileRef in result.items) {
        try {
          await fileRef.delete();

          if (logAudit) {
            await logPermissionCheck(
              userId: currentUserId ?? 'system',
              resource: 'storage/${fileRef.fullPath}',
              operation: 'delete',
              granted: true,
              details: 'File deleted during directory deletion',
              auditRepository: _auditRepository,
            );
            AppLogger.debug('Deleted storage file: ${fileRef.fullPath}');
          }
        } catch (e) {
          AppLogger.warning('Failed to delete file ${fileRef.fullPath}: $e');
          // Continue deleting other files even if one fails
        }
      }

      // Recursively delete all subdirectories
      for (final prefix in result.prefixes) {
        await _deleteDirectoryRecursive(prefix, logAudit: logAudit);
      }
    } catch (e) {
      AppLogger.warning('Failed to delete directory ${dirRef.fullPath}: $e');
      // Don't throw - allow partial deletion to complete
    }
  }

  /// Delete a single file at the specified path
  /// **Security:** Should be called after validatePathPermission check
  @protected
  Future<void> deleteFile(String path, {bool logAudit = true}) async {
    try {
      final ref = getReference(path);
      await ref.delete();

      if (logAudit) {
        await logPermissionCheck(
          userId: currentUserId ?? 'system',
          resource: 'storage/$path',
          operation: 'delete',
          granted: true,
          auditRepository: _auditRepository,
        );
        AppLogger.success('Deleted file: $path');
      }
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        AppLogger.warning('File not found for deletion: $path');
        return; // Not an error - file already doesn't exist
      }
      AppLogger.error('Failed to delete file: $path', e);
      throw RepositoryException('Failed to delete file: ${e.message}');
    }
  }

  /// Validate that a user has permission to access a storage path
  /// **Security Rule:** Users can only access paths in their own directory (users/{userId}/...)
  /// **Parameters:**
  /// - [userId]: The user ID that should own this path
  /// - [path]: The storage path to validate
  /// - [operation]: The operation being performed (upload, delete, etc.)
  /// **Throws:** PermissionDeniedException if validation fails
  @protected
  Future<void> validatePathPermission(
    String userId,
    String path,
    String operation,
  ) async {
    final currentUser = currentUserId;

    // Check authentication
    if (currentUser == null) {
      await logPermissionCheck(
        userId: 'anonymous',
        resource: 'storage/$path',
        operation: operation,
        granted: false,
        details: 'User not authenticated',
        auditRepository: _auditRepository,
      );
      throw PermissionDeniedException(
        'User must be authenticated to perform storage operations',
        resource: 'storage/$path',
        operation: operation,
      );
    }

    // Validate user is accessing their own path
    if (userId != currentUser) {
      await logPermissionCheck(
        userId: currentUser,
        resource: 'storage/$path',
        operation: operation,
        granted: false,
        details: 'User attempted to access another user\'s directory',
        auditRepository: _auditRepository,
      );
      throw PermissionDeniedException(
        'Users can only access files in their own directory',
        resource: 'storage/$path',
        operation: operation,
        userId: currentUser,
      );
    }

    // Validate path starts with users/{userId}/
    if (!path.startsWith('users/$userId/')) {
      await logPermissionCheck(
        userId: currentUser,
        resource: 'storage/$path',
        operation: operation,
        granted: false,
        details: 'Invalid path format - must start with users/{userId}/',
        auditRepository: _auditRepository,
      );
      throw PermissionDeniedException(
        'Invalid storage path - must be in user directory',
        resource: 'storage/$path',
        operation: operation,
        userId: currentUser,
      );
    }

    // Log successful permission check
    await logPermissionCheck(
      userId: currentUser,
      resource: 'storage/$path',
      operation: operation,
      granted: true,
      auditRepository: _auditRepository,
    );
  }

  /// Extract user ID from a storage path or URL
  /// **Supported formats:**
  /// - Path: users/{userId}/recipes/abc123.jpg
  /// - URL: https://...firebase...com/...%2Fusers%2F{userId}%2F...
  /// **Returns:** User ID if found, null otherwise
  @protected
  String? extractUserIdFromPath(String pathOrUrl) {
    try {
      // Decode URL encoding if present
      final decoded = Uri.decodeComponent(pathOrUrl);

      // Match pattern: users/{userId}/
      final regex = RegExp(r'users/([^/]+)/');
      final match = regex.firstMatch(decoded);

      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }

      return null;
    } catch (e) {
      AppLogger.warning('Failed to extract user ID from path: $pathOrUrl');
      return null;
    }
  }
}
