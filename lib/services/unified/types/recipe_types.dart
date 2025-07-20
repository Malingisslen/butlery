/// 🔍 AI INFO BLOCK:
/// Component: Recipe Service Types - Shared types for unified recipe service
/// File: lib/services/unified/types/recipe_types.dart
/// Quick Guide: Common types and enums used across recipe service interfaces
/// Dependencies IN: None - base types
/// Dependencies OUT: Used by all recipe operation interfaces
/// Data flow: Shared types across feature interfaces
/// State management: Static types only
/// Purpose: Avoid duplication of types across feature interfaces
/// Common issues: None - simple type definitions
/// Test coverage: Types tested through usage in operations
/// Performance: No performance impact - compile-time types
/// Analytics: No analytics needed for types
/// Code smells: None - simple type definitions
/// Connected to: All recipe operation interfaces
/// Used in phases: Phase 5 - Service Consolidation

// Import ResourcePermission from unified recipe model
import '../../../models/permissions/resource_permission.dart';

/// Result class for recipe operations
class RecipeOperationResult {
  final bool isSuccess;
  final String? message;
  final List<String>? warnings;
  
  const RecipeOperationResult._({
    required this.isSuccess,
    this.message,
    this.warnings,
  });
  
  factory RecipeOperationResult.success([String? message, List<String>? warnings]) =>
      RecipeOperationResult._(
        isSuccess: true, 
        message: message,
        warnings: warnings,
      );
  
  factory RecipeOperationResult.failure(String message) =>
      RecipeOperationResult._(isSuccess: false, message: message);
      
  bool get isFailure => !isSuccess;
  bool get hasWarnings => warnings != null && warnings!.isNotEmpty;
}

/// Import strategy types for recipe import operations
enum ImportSourceType {
  archive,
  text,
  url,
  photo,
  file,
}

/// Social recipe sharing data
class SharedRecipeData {
  final String id;
  final String title;
  final String description;
  final String ownerId;
  final String ownerDisplayName;
  final DateTime sharedAt;
  final Map<String, ResourcePermission> permissions;
  final bool allowGuestViewing;
  final bool allowMemberInvites;

  const SharedRecipeData({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerId,
    required this.ownerDisplayName,
    required this.sharedAt,
    required this.permissions,
    this.allowGuestViewing = false,
    this.allowMemberInvites = true,
  });
}

/// Real-time editing session info
class RealtimeEditSession {
  final String recipeId;
  final String userId;
  final String userDisplayName;
  final DateTime startedAt;
  final bool isActive;

  const RealtimeEditSession({
    required this.recipeId,
    required this.userId,
    required this.userDisplayName,
    required this.startedAt,
    this.isActive = true,
  });
}

/// Recipe comment data
class RecipeCommentData {
  final String id;
  final String recipeId;
  final String userId;
  final String userDisplayName;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const RecipeCommentData({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.userDisplayName,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
  });
}

/// Import operation result
class ImportResult {
  final bool isSuccess;
  final String? recipeId;
  final String? error;
  final ImportSourceType sourceType;
  final Map<String, dynamic>? metadata;

  const ImportResult({
    required this.isSuccess,
    this.recipeId,
    this.error,
    required this.sourceType,
    this.metadata,
  });

  factory ImportResult.success({
    required String recipeId,
    required ImportSourceType sourceType,
    Map<String, dynamic>? metadata,
  }) {
    return ImportResult(
      isSuccess: true,
      recipeId: recipeId,
      sourceType: sourceType,
      metadata: metadata,
    );
  }

  factory ImportResult.failure({
    required String error,
    required ImportSourceType sourceType,
    Map<String, dynamic>? metadata,
  }) {
    return ImportResult(
      isSuccess: false,
      error: error,
      sourceType: sourceType,
      metadata: metadata,
    );
  }
}

/// Export format options
enum ExportFormat {
  json,
  csv,
  pdf,
  plainText,
}

/// Export operation result
class ExportResult {
  final bool isSuccess;
  final String? filePath;
  final String? error;
  final ExportFormat format;
  final int recipeCount;
  final Map<String, dynamic>? metadata;

  const ExportResult({
    required this.isSuccess,
    this.filePath,
    this.error,
    required this.format,
    this.recipeCount = 0,
    this.metadata,
  });

  factory ExportResult.success({
    required String filePath,
    required ExportFormat format,
    required int recipeCount,
    Map<String, dynamic>? metadata,
  }) {
    return ExportResult(
      isSuccess: true,
      filePath: filePath,
      format: format,
      recipeCount: recipeCount,
      metadata: metadata,
    );
  }

  factory ExportResult.failure({
    required String error,
    required ExportFormat format,
    Map<String, dynamic>? metadata,
  }) {
    return ExportResult(
      isSuccess: false,
      error: error,
      format: format,
      metadata: metadata,
    );
  }
}