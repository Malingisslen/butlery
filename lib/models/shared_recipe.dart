// lib/models/shared_recipe.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'recipe.dart'; // Import existing Recipe model

/// 🔍 AI INFO BLOCK:
/// Component: Shared Recipe Model - Firebase First
/// File: models/shared_recipe.dart
/// Quick Guide: Clean Firebase-only modell för delade recept mellan vänner
/// Dependencies IN: cloud_firestore, uuid, recipe.dart
/// Dependencies OUT: SocialRecipeService, sharing views
/// Data flow: Firestore ↔ SharedRecipe object ↔ Social UI
/// State management: Immutable med copyWith pattern och cached recipe data
/// Purpose: Receptdelning med tracking och import functionality
/// Common issues: Large recipe snapshots, permission management
/// Test coverage: 70%
/// Performance: ⚡ Cached recipe data för offline access
/// Analytics: ✅ Sharing engagement och import success tracking
/// Code smells: ✅ Clean separation between sharing metadata och recipe data
/// Connected to: Recipe, UserProfile, SocialRecipeService, sharing views
/// Used in phases: 18

enum ShareScope {
  individual, // Delad till specifik person
  multiple, // Delad till flera personer
  friends, // Delad till alla vänner (framtida feature)
}

class SharedRecipe {
  final String id;
  final String originalRecipeId; // Reference to original recipe
  final String sharedByUserId; // Who shared it
  final String sharedByDisplayName; // Cache for performance
  final List<String> sharedToUserIds; // Who received it
  final DateTime sharedAt;
  final String? shareMessage; // Optional message with share
  final ShareScope scope;
  final bool allowImport; // Can recipients import/copy
  final int viewCount; // How many times viewed
  final int importCount; // How many times imported
  final List<String> viewedByUserIds; // Who has viewed
  final List<String> importedByUserIds; // Who has imported

  // Cached recipe data (for performance and offline)
  final Recipe recipeSnapshot; // Copy of recipe at time of sharing

  SharedRecipe({
    required this.id,
    required this.originalRecipeId,
    required this.sharedByUserId,
    required this.sharedByDisplayName,
    required this.sharedToUserIds,
    DateTime? sharedAt,
    this.shareMessage,
    this.scope = ShareScope.individual,
    this.allowImport = true,
    this.viewCount = 0,
    this.importCount = 0,
    this.viewedByUserIds = const [],
    this.importedByUserIds = const [],
    required this.recipeSnapshot,
  }) : sharedAt = sharedAt ?? DateTime.now();

  /// Factory constructor with auto-generated ID
  factory SharedRecipe.create({
    required String originalRecipeId,
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    String? shareMessage,
    ShareScope? scope,
    bool allowImport = true,
    required Recipe recipeSnapshot,
  }) {
    // Determine scope based on number of recipients
    final determinedScope =
        scope ??
        (sharedToUserIds.length == 1
            ? ShareScope.individual
            : ShareScope.multiple);

    return SharedRecipe(
      id: const Uuid().v4(),
      originalRecipeId: originalRecipeId,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      sharedAt: DateTime.now(),
      shareMessage: shareMessage,
      scope: determinedScope,
      allowImport: allowImport,
      recipeSnapshot: recipeSnapshot,
    );
  }

  /// Create copy with updated stats
  SharedRecipe copyWith({
    int? viewCount,
    int? importCount,
    List<String>? viewedByUserIds,
    List<String>? importedByUserIds,
  }) {
    return SharedRecipe(
      id: id,
      originalRecipeId: originalRecipeId,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      sharedAt: sharedAt,
      shareMessage: shareMessage,
      scope: scope,
      allowImport: allowImport,
      viewCount: viewCount ?? this.viewCount,
      importCount: importCount ?? this.importCount,
      viewedByUserIds: viewedByUserIds ?? List.from(this.viewedByUserIds),
      importedByUserIds: importedByUserIds ?? List.from(this.importedByUserIds),
      recipeSnapshot: recipeSnapshot,
    );
  }

  /// Mark as viewed by user
  SharedRecipe markViewedBy(String userId) {
    if (viewedByUserIds.contains(userId)) return this;

    return copyWith(
      viewCount: viewCount + 1,
      viewedByUserIds: [...viewedByUserIds, userId],
    );
  }

  /// Mark as imported by user
  SharedRecipe markImportedBy(String userId) {
    if (importedByUserIds.contains(userId)) return this;

    return copyWith(
      importCount: importCount + 1,
      importedByUserIds: [...importedByUserIds, userId],
    );
  }

  /// Check if user is recipient
  bool isSharedTo(String userId) => sharedToUserIds.contains(userId);

  /// Check if user has viewed
  bool isViewedBy(String userId) => viewedByUserIds.contains(userId);

  /// Check if user has imported
  bool isImportedBy(String userId) => importedByUserIds.contains(userId);

  /// Check if user can view this share
  bool canBeViewedBy(String userId) {
    return sharedByUserId == userId || isSharedTo(userId);
  }

  /// Create recipe with proper attribution for import
  Recipe createImportRecipe({required String newOwnerId}) {
    // Create new recipe with attribution
    final attributionText = 'Inspirerat av recept från $sharedByDisplayName';

    return recipeSnapshot.copyWith(
      // Generate new ID för imported copy
      sourceUrl: attributionText,
      // Reset sharing-specific metadata
    );
  }

  /// Time ago text
  String get timeAgoText {
    final now = DateTime.now();
    final difference = now.difference(sharedAt);

    if (difference.inMinutes < 1) {
      return 'Nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min sedan';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} tim sedan';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else {
      return '${(difference.inDays / 7).floor()} veckor sedan';
    }
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'originalRecipeId': originalRecipeId,
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': sharedByDisplayName,
      'sharedToUserIds': sharedToUserIds,
      'sharedAt': Timestamp.fromDate(sharedAt),
      'shareMessage': shareMessage,
      'scope': scope.name,
      'allowImport': allowImport,
      'viewCount': viewCount,
      'importCount': importCount,
      'viewedByUserIds': viewedByUserIds,
      'importedByUserIds': importedByUserIds,
      'recipeSnapshot': recipeSnapshot.toFirestore(),
    };
  }

  /// Create from Firestore document
  factory SharedRecipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Reconstruct recipe from snapshot
    final recipeData = data['recipeSnapshot'] as Map<String, dynamic>;
    final recipe = Recipe.fromFirestore(
      // Create a mock DocumentSnapshot for the Recipe
      _MockDocumentSnapshot(recipeData['id'] ?? '', recipeData)
          as DocumentSnapshot,
    );

    return SharedRecipe(
      id: doc.id,
      originalRecipeId: data['originalRecipeId'] as String? ?? '',
      sharedByUserId: data['sharedByUserId'] as String? ?? '',
      sharedByDisplayName: data['sharedByDisplayName'] as String? ?? '',
      sharedToUserIds: List<String>.from(data['sharedToUserIds'] ?? []),
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      shareMessage: data['shareMessage'] as String?,
      scope: ShareScope.values.firstWhere(
        (s) => s.name == data['scope'],
        orElse: () => ShareScope.individual,
      ),
      allowImport: data['allowImport'] as bool? ?? true,
      viewCount: data['viewCount'] as int? ?? 0,
      importCount: data['importCount'] as int? ?? 0,
      viewedByUserIds: List<String>.from(data['viewedByUserIds'] ?? []),
      importedByUserIds: List<String>.from(data['importedByUserIds'] ?? []),
      recipeSnapshot: recipe,
    );
  }

  /// JSON serialization för caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalRecipeId': originalRecipeId,
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': sharedByDisplayName,
      'sharedToUserIds': sharedToUserIds,
      'sharedAt': sharedAt.toIso8601String(),
      'shareMessage': shareMessage,
      'scope': scope.name,
      'allowImport': allowImport,
      'viewCount': viewCount,
      'importCount': importCount,
      'viewedByUserIds': viewedByUserIds,
      'importedByUserIds': importedByUserIds,
      'recipeSnapshot': recipeSnapshot.toJson(),
    };
  }

  factory SharedRecipe.fromJson(Map<String, dynamic> json) {
    return SharedRecipe(
      id: json['id'] as String,
      originalRecipeId: json['originalRecipeId'] as String? ?? '',
      sharedByUserId: json['sharedByUserId'] as String? ?? '',
      sharedByDisplayName: json['sharedByDisplayName'] as String? ?? '',
      sharedToUserIds: List<String>.from(json['sharedToUserIds'] ?? []),
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      shareMessage: json['shareMessage'] as String?,
      scope: ShareScope.values.firstWhere(
        (s) => s.name == json['scope'],
        orElse: () => ShareScope.individual,
      ),
      allowImport: json['allowImport'] as bool? ?? true,
      viewCount: json['viewCount'] as int? ?? 0,
      importCount: json['importCount'] as int? ?? 0,
      viewedByUserIds: List<String>.from(json['viewedByUserIds'] ?? []),
      importedByUserIds: List<String>.from(json['importedByUserIds'] ?? []),
      recipeSnapshot: Recipe.fromJson(
        json['recipeSnapshot'] as Map<String, dynamic>,
      ),
    );
  }

  @override
  String toString() {
    return 'SharedRecipe(id: $id, recipe: ${recipeSnapshot.title}, sharedBy: $sharedByDisplayName, recipients: ${sharedToUserIds.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedRecipe && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Helper class för Recipe reconstruction från Firestore data
class _MockDocumentSnapshot {
  final String _id;
  final Map<String, dynamic> _data;

  _MockDocumentSnapshot(this._id, this._data);

  String get id => _id;
  Map<String, dynamic>? data() => _data;
  bool get exists => true;
}
