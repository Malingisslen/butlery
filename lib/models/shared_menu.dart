// lib/models/shared_menu.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/firebase/firebase_auth_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'; // För debugPrint
import 'recipe.dart'; // Import existing Recipe model


class SharedMenu {
  final String id;
  final String sharedByUserId;
  final String sharedByDisplayName;
  final List<String> sharedToUserIds;
  final DateTime sharedAt;
  final String? shareMessage;
  final String menuTitle; // e.g., "Marias veckomeny"
  final Map<String, List<Recipe>> menuSnapshot; // Complete menu copy
  final int totalRecipeCount; // For quick stats
  final List<String> categories; // ["Middag", "Lunch", etc.]
  final int viewCount;
  final int importCount;
  final List<String> viewedByUserIds;
  final List<String> importedByUserIds;
  final List<String>
      dismissedByUserIds; // 🆕 Who has dismissed it from their list
  final bool allowCollaboration; // 🆕 Kollaborationsinställning för menyer

  SharedMenu({
    required this.id,
    required this.sharedByUserId,
    required this.sharedByDisplayName,
    required this.sharedToUserIds,
    DateTime? sharedAt,
    this.shareMessage,
    required this.menuTitle,
    required this.menuSnapshot,
    List<String>? viewedByUserIds,
    List<String>? importedByUserIds,
    List<String>? dismissedByUserIds, // 🆕 Optional parameter
    this.allowCollaboration = false, // 🆕 Default: ej kollaborativ
  })  : sharedAt = sharedAt ?? DateTime.now(),
        totalRecipeCount = menuSnapshot.values.fold(
          0,
          (totalCount, recipes) => totalCount + recipes.length,
        ),
        categories = menuSnapshot.keys.toList(),
        viewCount = 0,
        importCount = 0,
        viewedByUserIds = viewedByUserIds ?? [],
        importedByUserIds = importedByUserIds ?? [],
        dismissedByUserIds = dismissedByUserIds ?? []; // 🆕 Default tom lista

  /// Factory constructor with auto-generated ID
  factory SharedMenu.create({
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    String? shareMessage,
    String? menuTitle,
    required Map<String, List<Recipe>> menuSnapshot,
    bool allowCollaboration = false, // 🆕 Kollaborationsinställning för menyer
  }) {
    final title = menuTitle ?? '${sharedByDisplayName}s veckomeny';

    return SharedMenu(
      id: const Uuid().v4(),
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      sharedAt: DateTime.now(),
      shareMessage: shareMessage,
      menuTitle: title,
      menuSnapshot: menuSnapshot,
      allowCollaboration: allowCollaboration, // 🆕 Skicka vidare parametern
    );
  }

  /// Create copy with updated stats
  SharedMenu copyWith({
    int? viewCount,
    int? importCount,
    List<String>? viewedByUserIds,
    List<String>? importedByUserIds,
    List<String>? dismissedByUserIds, // 🆕 Lägg till dismiss tracking
    bool? allowCollaboration, // 🆕 Kollaborativ uppdatering
  }) {
    return SharedMenu._internal(
      id: id,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      sharedAt: sharedAt,
      shareMessage: shareMessage,
      menuTitle: menuTitle,
      menuSnapshot: menuSnapshot,
      totalRecipeCount: totalRecipeCount,
      categories: categories,
      viewCount: viewCount ?? this.viewCount,
      importCount: importCount ?? this.importCount,
      viewedByUserIds: viewedByUserIds ?? List.from(this.viewedByUserIds),
      importedByUserIds: importedByUserIds ?? List.from(this.importedByUserIds),
      dismissedByUserIds:
          dismissedByUserIds ?? List.from(this.dismissedByUserIds), // 🆕
      allowCollaboration: allowCollaboration ?? this.allowCollaboration, // 🆕
    );
  }

  /// Private constructor för copyWith
  SharedMenu._internal({
    required this.id,
    required this.sharedByUserId,
    required this.sharedByDisplayName,
    required this.sharedToUserIds,
    required this.sharedAt,
    this.shareMessage,
    required this.menuTitle,
    required this.menuSnapshot,
    required this.totalRecipeCount,
    required this.categories,
    required this.viewCount,
    required this.importCount,
    required this.viewedByUserIds,
    required this.importedByUserIds,
    required this.dismissedByUserIds, // 🆕
    required this.allowCollaboration, // 🆕 LÄGG TILL DENNA RAD
  });

  /// Mark as viewed
  SharedMenu markViewedBy(String userId) {
    if (viewedByUserIds.contains(userId)) return this;

    return copyWith(
      viewCount: viewCount + 1,
      viewedByUserIds: [...viewedByUserIds, userId],
    );
  }

  /// Mark as imported
  SharedMenu markImportedBy(String userId) {
    if (importedByUserIds.contains(userId)) return this;

    return copyWith(
      importCount: importCount + 1,
      importedByUserIds: [...importedByUserIds, userId],
    );
  }

  /// 🆕 Mark as dismissed by user (ta bort från användarens lista)
  SharedMenu markDismissedBy(String userId) {
    if (dismissedByUserIds.contains(userId)) return this;

    return copyWith(
      dismissedByUserIds: [...dismissedByUserIds, userId],
    );
  }

  /// 🆕 Un-dismiss (återställ till användarens lista)
  SharedMenu undismissBy(String userId) {
    if (!dismissedByUserIds.contains(userId)) return this;

    final updatedDismissed = List<String>.from(dismissedByUserIds);
    updatedDismissed.remove(userId);

    return copyWith(
      dismissedByUserIds: updatedDismissed,
    );
  }

  /// Check permissions
  bool canBeViewedBy(String userId) {
    return sharedByUserId == userId || sharedToUserIds.contains(userId);
  }

  bool isViewedBy(String userId) => viewedByUserIds.contains(userId);
  bool isImportedBy(String userId) => importedByUserIds.contains(userId);

  /// 🆕 Check if user has dismissed (dolt från sin lista)
  bool isDismissedBy(String userId) => dismissedByUserIds.contains(userId);

  /// ✅ FIXAT: Easy isDismissed getter för current user
  bool get isDismissed {
    final currentUserId = FirebaseAuthRepository().currentUserId;
    if (currentUserId == null) return false;
    return isDismissedBy(currentUserId);
  }

  /// 🆕 Check if should be shown in user's shared list
  bool shouldBeShownTo(String userId) {
    return canBeViewedBy(userId) && !isDismissedBy(userId);
  }

  /// 🔧 ADDED: Import permission check - Löser SocialRecipeService error
  bool get allowImport {
    // Basic logic: alla menyer kan importeras om de har recept
    if (totalRecipeCount == 0) return false;

    // Du kan lägga till mer komplex logik här senare, som:
    // - Kontrollera om sharedByUserId har tillåtit import
    // - Kontrollera om menyn är för gammal
    // - Kontrollera premium features, etc.

    return true; // Som standard tillåter vi import av alla menyer med recept
  }

  /// Get menu summary for preview
  String get menuSummary {
    final parts = <String>[];
    for (final entry in menuSnapshot.entries) {
      final categoryName = entry.key.toLowerCase();
      final count = entry.value.length;
      if (count > 0) {
        parts.add('$count $categoryName');
      }
    }
    return parts.join(', ');
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
    // Convert menu snapshot to Firestore format - UTAN serverTimestamp i nested data
    final menuData = <String, dynamic>{};
    for (final entry in menuSnapshot.entries) {
      menuData[entry.key] = entry.value.map((recipe) {
        // Få recipe data och säkerställ att inga FieldValue.serverTimestamp() finns i nested objects
        final recipeData = recipe.toFirestore(isNested: true);

        // Ersätt eventuella serverTimestamp med DateTime.now() för nested objects
        if (recipeData['createdAt'] is FieldValue) {
          recipeData['createdAt'] = Timestamp.fromDate(recipe.createdAt);
        }
        if (recipeData['updatedAt'] is FieldValue) {
          recipeData['updatedAt'] = Timestamp.fromDate(recipe.updatedAt);
        }
        if (recipeData['lastCookedAt'] is FieldValue) {
          recipeData['lastCookedAt'] = recipe.lastCookedAt != null
              ? Timestamp.fromDate(recipe.lastCookedAt!)
              : null;
        }

        return recipeData;
      }).toList();
    }

    return {
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': sharedByDisplayName,
      'sharedToUserIds': sharedToUserIds,
      'sharedAt': Timestamp.fromDate(sharedAt),
      'shareMessage': shareMessage,
      'menuTitle': menuTitle,
      'menuSnapshot': menuData,
      'totalRecipeCount': totalRecipeCount,
      'categories': categories,
      'viewCount': viewCount,
      'importCount': importCount,
      'viewedByUserIds': viewedByUserIds,
      'importedByUserIds': importedByUserIds,
      'dismissedByUserIds': dismissedByUserIds, // 🆕 Spara dismiss data
      'allowCollaboration': allowCollaboration, // 🆕 LÄGG TILL DENNA RAD
    };
  }

  /// 🔧 FIXED: Create from Firestore document - No more type cast errors!
  factory SharedMenu.fromFirestore(dynamic doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;

      debugPrint('🔍 Parsing SharedMenu från doc ID: ${doc.id}');

      // 🔧 FIXED: Reconstruct menu snapshot utan MockDocumentSnapshot type cast
      final menuData = data['menuSnapshot'] as Map<String, dynamic>? ?? {};
      final reconstructedMenu = <String, List<Recipe>>{};

      for (final entry in menuData.entries) {
        final recipeList = <Recipe>[];
        final recipes = entry.value as List<dynamic>? ?? [];

        for (final recipeData in recipes) {
          try {
            // 🔧 FIXED: Skapa Recipe direkt från data istället för via mock DocumentSnapshot
            final recipeMap = recipeData as Map<String, dynamic>;
            final recipe = Recipe(
              id: recipeMap['id'] as String? ?? '',
              title: recipeMap['title'] as String? ?? 'Untitled Recipe',
              description: recipeMap['description'] as String? ?? '',
              ingredients: List<String>.from(recipeMap['ingredients'] ?? []),
              instructions: List<String>.from(recipeMap['instructions'] ?? []),
              imageUrls: List<String>.from(recipeMap['imageUrls'] ?? []),
              mealType: recipeMap['mealType'] as String? ?? 'Middag',
              portions: recipeMap['portions'] as int?,
              timeMinutes: recipeMap['timeMinutes'] as int?,
              rating: (recipeMap['rating'] as num?)?.toDouble(),
              tags: List<String>.from(recipeMap['tags'] ?? []),
              sourceUrl: recipeMap['sourceUrl'] as String?,
              createdAt:
                  _parseTimestamp(recipeMap['createdAt']) ?? DateTime.now(),
              updatedAt:
                  _parseTimestamp(recipeMap['updatedAt']) ?? DateTime.now(),
              lastCookedAt: _parseTimestamp(recipeMap['lastCookedAt']),
            );
            recipeList.add(recipe);
          } catch (e) {
            debugPrint('⚠️ Skippar ogiltigt recept i meny: $e');
            // Skip invalid recipes rather than failing entirely
            continue;
          }
        }
        reconstructedMenu[entry.key] = recipeList;
      }

      return SharedMenu._internal(
        id: doc.id,
        sharedByUserId: data['sharedByUserId'] as String? ?? '',
        sharedByDisplayName: data['sharedByDisplayName'] as String? ?? '',
        sharedToUserIds: List<String>.from(data['sharedToUserIds'] ?? []),
        sharedAt: _parseTimestamp(data['sharedAt']) ?? DateTime.now(),
        shareMessage: data['shareMessage'] as String?,
        menuTitle: data['menuTitle'] as String? ?? 'Delad meny',
        menuSnapshot: reconstructedMenu,
        totalRecipeCount: data['totalRecipeCount'] as int? ?? 0,
        categories: List<String>.from(data['categories'] ?? []),
        viewCount: data['viewCount'] as int? ?? 0,
        importCount: data['importCount'] as int? ?? 0,
        viewedByUserIds: List<String>.from(data['viewedByUserIds'] ?? []),
        importedByUserIds: List<String>.from(data['importedByUserIds'] ?? []),
        dismissedByUserIds: List<String>.from(
            data['dismissedByUserIds'] ?? []), // 🆕 Läs dismiss data
        allowCollaboration: data['allowCollaboration'] as bool? ??
            false, // 🆕 LÄGG TILL DENNA RAD
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing SharedMenu från doc ${doc.id}: $e');
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
    // Convert menu snapshot to JSON format
    final menuData = <String, dynamic>{};
    for (final entry in menuSnapshot.entries) {
      menuData[entry.key] =
          entry.value.map((recipe) => recipe.toJson()).toList();
    }

    return {
      'id': id,
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': sharedByDisplayName,
      'sharedToUserIds': sharedToUserIds,
      'sharedAt': sharedAt.toIso8601String(),
      'shareMessage': shareMessage,
      'menuTitle': menuTitle,
      'menuSnapshot': menuData,
      'totalRecipeCount': totalRecipeCount,
      'categories': categories,
      'viewCount': viewCount,
      'importCount': importCount,
      'viewedByUserIds': viewedByUserIds,
      'importedByUserIds': importedByUserIds,
      'dismissedByUserIds': dismissedByUserIds, // 🆕 JSON support för dismiss
      'allowCollaboration':
          allowCollaboration, // 🆕 JSON support för collaboration
    };
  }

  factory SharedMenu.fromJson(Map<String, dynamic> json) {
    // Reconstruct menu snapshot from JSON
    final menuData = json['menuSnapshot'] as Map<String, dynamic>? ?? {};
    final reconstructedMenu = <String, List<Recipe>>{};

    for (final entry in menuData.entries) {
      final recipeList = <Recipe>[];
      final recipes = entry.value as List<dynamic>? ?? [];

      for (final recipeData in recipes) {
        try {
          recipeList.add(Recipe.fromJson(recipeData as Map<String, dynamic>));
        } catch (e) {
          // Skip invalid recipes
          continue;
        }
      }
      reconstructedMenu[entry.key] = recipeList;
    }

    return SharedMenu._internal(
      id: json['id'] as String,
      sharedByUserId: json['sharedByUserId'] as String? ?? '',
      sharedByDisplayName: json['sharedByDisplayName'] as String? ?? '',
      sharedToUserIds: List<String>.from(json['sharedToUserIds'] ?? []),
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      shareMessage: json['shareMessage'] as String?,
      menuTitle: json['menuTitle'] as String? ?? 'Delad meny',
      menuSnapshot: reconstructedMenu,
      totalRecipeCount: json['totalRecipeCount'] as int? ?? 0,
      categories: List<String>.from(json['categories'] ?? []),
      viewCount: json['viewCount'] as int? ?? 0,
      importCount: json['importCount'] as int? ?? 0,
      viewedByUserIds: List<String>.from(json['viewedByUserIds'] ?? []),
      importedByUserIds: List<String>.from(json['importedByUserIds'] ?? []),
      dismissedByUserIds: List<String>.from(
          json['dismissedByUserIds'] ?? []), // 🆕 JSON parse för dismiss
      allowCollaboration: json['allowCollaboration'] as bool? ??
          false, // 🆕 JSON parse för collaboration
    );
  }

  @override
  String toString() {
    return 'SharedMenu(id: $id, title: $menuTitle, sharedBy: $sharedByDisplayName, recipes: $totalRecipeCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedMenu && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
