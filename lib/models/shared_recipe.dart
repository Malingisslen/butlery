// lib/models/shared_recipe.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/firebase/firebase_auth_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'; // För debugPrint
import 'recipe.dart'; // Import existing Recipe model
import 'permissions/edit_mode.dart';


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
  final bool allowCollaboration; // 🆕 Can recipients edit collaboratively
  final int viewCount; // How many times viewed
  final int importCount; // How many times imported
  final List<String> viewedByUserIds; // Who has viewed
  final List<String> importedByUserIds; // Who has imported
  final List<String>
      dismissedByUserIds; // 🆕 Who has dismissed it from their list

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
    this.allowCollaboration = false, // 🆕 Default: ej kollaborativ
    this.viewCount = 0,
    this.importCount = 0,
    this.viewedByUserIds = const [],
    this.importedByUserIds = const [],
    this.dismissedByUserIds = const [], // 🆕 Default tom lista
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
    bool allowCollaboration = false, // ✅ NY: Kollaborationsinställning
    required Recipe recipeSnapshot,
  }) {
    // Determine scope based on number of recipients
    final determinedScope = scope ??
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
      allowCollaboration:
          allowCollaboration, // ✅ UPPDATERAT: Skicka vidare parametern
      recipeSnapshot: recipeSnapshot,
    );
  }

  /// Create copy with updated stats
  SharedRecipe copyWith({
    int? viewCount,
    int? importCount,
    List<String>? viewedByUserIds,
    List<String>? importedByUserIds,
    List<String>? dismissedByUserIds, // 🆕 Lägg till dismiss tracking
    bool? allowCollaboration, // 🆕
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
      allowCollaboration: allowCollaboration ?? this.allowCollaboration, // 🆕
      viewCount: viewCount ?? this.viewCount,
      importCount: importCount ?? this.importCount,
      viewedByUserIds: viewedByUserIds ?? List.from(this.viewedByUserIds),
      importedByUserIds: importedByUserIds ?? List.from(this.importedByUserIds),
      dismissedByUserIds:
          dismissedByUserIds ?? List.from(this.dismissedByUserIds), // 🆕
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

  /// 🆕 Mark as dismissed by user (ta bort från användarens lista)
  SharedRecipe markDismissedBy(String userId) {
    if (dismissedByUserIds.contains(userId)) return this;

    return copyWith(
      dismissedByUserIds: [...dismissedByUserIds, userId],
    );
  }

  /// 🆕 Un-dismiss (återställ till användarens lista)
  SharedRecipe undismissBy(String userId) {
    if (!dismissedByUserIds.contains(userId)) return this;

    final updatedDismissed = List<String>.from(dismissedByUserIds);
    updatedDismissed.remove(userId);

    return copyWith(
      dismissedByUserIds: updatedDismissed,
    );
  }

  /// Check if user is recipient
  bool isSharedTo(String userId) => sharedToUserIds.contains(userId);

  /// Check if user has viewed
  bool isViewedBy(String userId) => viewedByUserIds.contains(userId);

  /// Check if user has imported
  bool isImportedBy(String userId) => importedByUserIds.contains(userId);

  /// 🆕 Check if user has dismissed (dolt från sin lista)
  bool isDismissedBy(String userId) => dismissedByUserIds.contains(userId);

  /// ✅ FIXAT: Easy isDismissed getter för current user
  bool get isDismissed {
    final currentUserId = FirebaseAuthRepository().currentUserId;
    if (currentUserId == null) return false;
    return isDismissedBy(currentUserId);
  }

  /// Check if user can view this share
  bool canBeViewedBy(String userId) {
    return sharedByUserId == userId || isSharedTo(userId);
  }

  /// 🆕 Kontrollera om användaren kan redigera receptet
  bool canBeEditedBy(String userId) {
    // Ägaren kan alltid redigera
    if (sharedByUserId == userId) return true;

    // Deltagare kan bara redigera om collaboration är tillåtet
    if (allowCollaboration && sharedToUserIds.contains(userId)) {
      return true;
    }

    return false;
  }

  /// 🆕 Kontrollera om "Spara min kopia" ska visas
  bool shouldShowForkOption(String userId) {
    // Visa alltid för mottagare (oavsett collaborative eller inte)
    return isSharedTo(userId) && sharedByUserId != userId;
  }

  /// 🆕 Check if should be shown in user's shared list
  bool shouldBeShownTo(String userId) {
    return canBeViewedBy(userId) && !isDismissedBy(userId);
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

  /// 🆕 Bestäm redigeringsläge för användaren
  EditMode getEditModeFor(String userId) {
    if (sharedByUserId == userId) {
      return EditMode.owner; // Ägaren redigerar alltid original
    }

    if (allowCollaboration && sharedToUserIds.contains(userId)) {
      return EditMode.collaborative; // Kollaborativ redigering
    }

    if (sharedToUserIds.contains(userId)) {
      return EditMode.readOnlyWithFork; // Bara läsning + fork
    }

    return EditMode.noAccess;
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
      'allowCollaboration': allowCollaboration, // 🆕
      'viewCount': viewCount,
      'importCount': importCount,
      'viewedByUserIds': viewedByUserIds,
      'importedByUserIds': importedByUserIds,
      'dismissedByUserIds': dismissedByUserIds, // 🆕 Spara dismiss data
      'recipeSnapshot': recipeSnapshot.toFirestore(
          isNested: true), // 🔧 FIXED: isNested = true
    };
  }

  /// 🔧 FIXED: Create from Firestore document - No more type cast errors!
  factory SharedRecipe.fromFirestore(dynamic doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;

      debugPrint('🔍 Parsing SharedRecipe från doc ID: ${doc.id}');

      // 🔧 FIXED: Hantera recipe snapshot utan type cast
      final recipeData = data['recipeSnapshot'] as Map<String, dynamic>;

      // Skapa Recipe direkt från data istället för att använda mock DocumentSnapshot
      final recipe = Recipe(
        id: recipeData['id'] as String? ?? '',
        title: recipeData['title'] as String? ?? 'Untitled Recipe',
        description: recipeData['description'] as String? ?? '',
        ingredients: List<String>.from(recipeData['ingredients'] ?? []),
        instructions: List<String>.from(recipeData['instructions'] ?? []),
        imageUrls: List<String>.from(recipeData['imageUrls'] ?? []),
        mealType: recipeData['mealType'] as String? ?? 'Middag',
        portions: recipeData['portions'] as int?,
        timeMinutes: recipeData['timeMinutes'] as int?,
        rating: (recipeData['rating'] as num?)?.toDouble(),
        tags: List<String>.from(recipeData['tags'] ?? []),
        sourceUrl: recipeData['sourceUrl'] as String?,
        createdAt: _parseTimestamp(recipeData['createdAt']) ?? DateTime.now(),
        updatedAt: _parseTimestamp(recipeData['updatedAt']) ?? DateTime.now(),
        lastCookedAt: _parseTimestamp(recipeData['lastCookedAt']),
      );

      return SharedRecipe(
        id: doc.id,
        originalRecipeId: data['originalRecipeId'] as String? ?? '',
        sharedByUserId: data['sharedByUserId'] as String? ?? '',
        sharedByDisplayName: data['sharedByDisplayName'] as String? ?? '',
        sharedToUserIds: List<String>.from(data['sharedToUserIds'] ?? []),
        sharedAt: _parseTimestamp(data['sharedAt']) ?? DateTime.now(),
        shareMessage: data['shareMessage'] as String?,
        scope: ShareScope.values.firstWhere(
          (s) => s.name == data['scope'],
          orElse: () => ShareScope.individual,
        ),
        allowImport: data['allowImport'] as bool? ?? true,
        allowCollaboration: data['allowCollaboration'] as bool? ?? false, // 🆕
        viewCount: data['viewCount'] as int? ?? 0,
        importCount: data['importCount'] as int? ?? 0,
        viewedByUserIds: List<String>.from(data['viewedByUserIds'] ?? []),
        importedByUserIds: List<String>.from(data['importedByUserIds'] ?? []),
        dismissedByUserIds: List<String>.from(
            data['dismissedByUserIds'] ?? []), // 🆕 Läs dismiss data
        recipeSnapshot: recipe,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing SharedRecipe från doc ${doc.id}: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 🔧 ADDED: Helper method för robust timestamp parsing
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp.toString().contains('Timestamp')) {
        // Handle mock timestamps från debug output
        final timestampObj = timestamp as dynamic;
        final seconds = timestampObj.seconds as int;
        final nanoseconds = timestampObj.nanoseconds as int? ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + nanoseconds ~/ 1000000);
      } else if (timestamp is Map) {
        // Handle raw timestamp data
        final seconds = timestamp['seconds'] as int?;
        final nanoseconds = timestamp['nanoseconds'] as int? ?? 0;
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + nanoseconds ~/ 1000000);
        }
      }

      debugPrint('⚠️ Unknown timestamp format: ${timestamp.runtimeType}');
      return DateTime.now();
    } catch (e) {
      debugPrint('❌ Error parsing timestamp: $e');
      return DateTime.now();
    }
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
      'allowCollaboration': allowCollaboration, // 🆕
      'viewCount': viewCount,
      'importCount': importCount,
      'viewedByUserIds': viewedByUserIds,
      'importedByUserIds': importedByUserIds,
      'dismissedByUserIds': dismissedByUserIds, // 🆕 JSON support för dismiss
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
      dismissedByUserIds: List<String>.from(
          json['dismissedByUserIds'] ?? []), // 🆕 JSON parse för dismiss
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
