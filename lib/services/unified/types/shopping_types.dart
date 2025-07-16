/// 🔍 AI INFO BLOCK:
/// Component: Shopping Service Types - Shared types for unified shopping service
/// File: lib/services/unified/types/shopping_types.dart
/// Quick Guide: Common types and enums used across shopping service interfaces
/// Dependencies IN: None - base types
/// Dependencies OUT: Used by all shopping operation interfaces
/// Data flow: Shared types across feature interfaces
/// State management: Static types only
/// Purpose: Avoid duplication of types across feature interfaces
/// Common issues: None - simple type definitions
/// Test coverage: Types tested through usage in operations
/// Performance: No performance impact - compile-time types
/// Analytics: No analytics needed for types
/// Code smells: None - simple type definitions
/// Connected to: All shopping operation interfaces
/// Used in phases: Phase 5 - Service Consolidation

// Shared types for shopping operations

/// Result class for shopping operations
class ShoppingOperationResult {
  final bool isSuccess;
  final String? message;
  final List<String>? warnings;
  
  const ShoppingOperationResult._({
    required this.isSuccess,
    this.message,
    this.warnings,
  });
  
  factory ShoppingOperationResult.success([String? message, List<String>? warnings]) =>
      ShoppingOperationResult._(
        isSuccess: true, 
        message: message,
        warnings: warnings,
      );
  
  factory ShoppingOperationResult.failure(String message) =>
      ShoppingOperationResult._(isSuccess: false, message: message);
      
  bool get isFailure => !isSuccess;
  bool get hasWarnings => warnings != null && warnings!.isNotEmpty;
}

/// Import strategy types for shopping list import operations
enum ImportSourceType {
  text,
  csv,
  json,
  template,
  recipe,
  photo,
}

/// Export format options
enum ExportFormat {
  text,
  json,
  csv,
  minimal,
}

/// Import operation result
class ImportResult {
  final bool isSuccess;
  final String? listId;
  final String? error;
  final ImportSourceType sourceType;
  final int itemCount;
  final Map<String, dynamic>? metadata;

  const ImportResult({
    required this.isSuccess,
    this.listId,
    this.error,
    required this.sourceType,
    this.itemCount = 0,
    this.metadata,
  });

  factory ImportResult.success({
    required String listId,
    required ImportSourceType sourceType,
    required int itemCount,
    Map<String, dynamic>? metadata,
  }) {
    return ImportResult(
      isSuccess: true,
      listId: listId,
      sourceType: sourceType,
      itemCount: itemCount,
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

/// Export operation result
class ExportResult {
  final bool isSuccess;
  final String? content;
  final String? error;
  final ExportFormat format;
  final int itemCount;
  final Map<String, dynamic>? metadata;

  const ExportResult({
    required this.isSuccess,
    this.content,
    this.error,
    required this.format,
    this.itemCount = 0,
    this.metadata,
  });

  factory ExportResult.success({
    required String content,
    required ExportFormat format,
    required int itemCount,
    Map<String, dynamic>? metadata,
  }) {
    return ExportResult(
      isSuccess: true,
      content: content,
      format: format,
      itemCount: itemCount,
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

/// Shopping list activity data
class ShoppingListActivity {
  final String id;
  final String listId;
  final String userId;
  final String userDisplayName;
  final String action;
  final String? itemName;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const ShoppingListActivity({
    required this.id,
    required this.listId,
    required this.userId,
    required this.userDisplayName,
    required this.action,
    this.itemName,
    required this.timestamp,
    this.metadata,
  });
}

/// Shopping list statistics
class ShoppingListStats {
  final String listId;
  final String listName;
  final int totalItems;
  final int boughtItems;
  final int remainingItems;
  final double completionPercentage;
  final double? estimatedTotal;
  final Map<String, int> categoryBreakdown;
  final Map<String, int>? memberActivity;
  final DateTime lastUpdated;

  const ShoppingListStats({
    required this.listId,
    required this.listName,
    required this.totalItems,
    required this.boughtItems,
    required this.remainingItems,
    required this.completionPercentage,
    this.estimatedTotal,
    required this.categoryBreakdown,
    this.memberActivity,
    required this.lastUpdated,
  });
}

/// Share operation result
class ShareResult {
  final bool isSuccess;
  final String? shareId;
  final String? shareUrl;
  final String? error;
  final Map<String, dynamic>? metadata;

  const ShareResult({
    required this.isSuccess,
    this.shareId,
    this.shareUrl,
    this.error,
    this.metadata,
  });

  factory ShareResult.success({
    String? shareId,
    String? shareUrl,
    Map<String, dynamic>? metadata,
  }) {
    return ShareResult(
      isSuccess: true,
      shareId: shareId,
      shareUrl: shareUrl,
      metadata: metadata,
    );
  }

  factory ShareResult.failure({
    required String error,
    Map<String, dynamic>? metadata,
  }) {
    return ShareResult(
      isSuccess: false,
      error: error,
      metadata: metadata,
    );
  }
}

/// Template data for shopping lists
class ShoppingTemplate {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final String createdByDisplayName;
  final DateTime createdAt;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? metadata;

  const ShoppingTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.createdByDisplayName,
    required this.createdAt,
    required this.items,
    this.metadata,
  });
}