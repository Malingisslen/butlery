/// Shared menu model using unified base infrastructure for consistent shared content patterns.
///
/// This model extends BaseSharedContentModel and uses mixins for status management and
/// copy-on-write functionality, eliminating duplicate code while maintaining menu-specific
/// features and collaboration capabilities.
///
/// **Key Features:**
/// - **Unified Status Management**: Uses SharedContentStatusMixin for consistent view/import/dismiss tracking
/// - **Copy-on-Write Collaboration**: Uses CopyOnWriteSupport for collaborative editing features  
/// - **Menu-Specific Logic**: Maintains menu snapshots, categories, and import attribution
/// - **Consistent Serialization**: Leverages base class patterns for Firestore and JSON operations
///
/// **Usage Examples:**
/// ```dart
/// // Create new shared menu with collaboration
/// final sharedMenu = SharedMenu.create(
///   sharedByUserId: currentUserId,
///   sharedByDisplayName: 'Anna Andersson',
///   sharedToUserIds: [friend1Id, friend2Id],
///   shareMessage: 'Min veckomeny för nästa vecka!',
///   menuTitle: 'Annas veckomeny v.45',
///   menuSnapshot: menuData,
///   allowCollaboration: true,
/// );
/// 
/// // Status tracking (via mixins)
/// final viewedMenu = sharedMenu.markViewedBy(userId);
/// final importedMenu = viewedMenu.markImportedBy(userId);
/// ```

// lib/models/shared_menu.dart

import 'package:butlery/models/shared_content/base_shared_content_model.dart';
import 'package:butlery/models/shared_content/shared_content_status_mixin.dart';
import 'package:butlery/models/shared_content/copy_on_write_mixin.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/types/app_timestamp.dart';

/// Shared menu model with unified base infrastructure and menu-specific features.
class SharedMenu extends BaseSharedContentModel<Map<String, List<Recipe>>>
    with SharedContentStatusMixin, CopyOnWriteSupport {
  // ===== MENU-SPECIFIC FIELDS =====
  
  /// Title of the shared menu for identification and display.
  final String menuTitle;
  
  /// Complete snapshot of the menu with all recipes organized by category.
  final Map<String, List<Recipe>> menuSnapshot;
  
  /// Cached total recipe count for quick statistics and UI display.
  final int totalRecipeCount;
  
  /// List of category names present in the menu snapshot.
  final List<String> categories;
  
  /// Flag indicating whether collaborative editing is allowed.
  final bool allowCollaboration;

  // ===== COPY-ON-WRITE FIELDS =====
  
  /// Flag indicating whether this is an original reference or collaborative version.
  final bool _isOriginalReference;
  
  /// Flag indicating whether copy-on-write has been triggered for this content.
  final bool _copyOnWriteTriggered;
  
  /// ID of the static copy created for the original owner when CoW is triggered.
  final String? _originalOwnerStaticCopyId;
  
  /// List of user IDs actively collaborating on this content.
  final List<String> _activeCollaboratorIds;

  /// Creates a new shared menu with all required metadata.
  SharedMenu({
    required super.id,
    required super.sharedByUserId,
    required super.sharedByDisplayName,
    required super.sharedToUserIds,
    DateTime? sharedAt,
    super.shareMessage,
    super.viewCount = 0,
    super.engagementCount = 0,
    super.viewedByUserIds = const [],
    super.engagedByUserIds = const [],
    super.dismissedByUserIds = const [],
    required this.menuTitle,
    required this.menuSnapshot,
    this.allowCollaboration = false,
    // Copy-on-write fields
    bool isOriginalReference = true,
    bool copyOnWriteTriggered = false,
    String? originalOwnerStaticCopyId,
    List<String> activeCollaboratorIds = const [],
  })  : _isOriginalReference = isOriginalReference,
        _copyOnWriteTriggered = copyOnWriteTriggered,
        _originalOwnerStaticCopyId = originalOwnerStaticCopyId,
        _activeCollaboratorIds = activeCollaboratorIds,
        totalRecipeCount = menuSnapshot.values.fold(
          0,
          (totalCount, recipes) => totalCount + recipes.length,
        ),
        categories = menuSnapshot.keys.toList(),
        super(sharedAt: sharedAt ?? DateTime.now());

  /// Factory constructor for creating new shared menus with auto-generated ID.
  factory SharedMenu.create({
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    String? shareMessage,
    String? menuTitle,
    required Map<String, List<Recipe>> menuSnapshot,
    bool allowCollaboration = false,
  }) {
    final title = menuTitle ?? '${sharedByDisplayName}s veckomeny';

    return SharedMenu(
      id: const Uuid().v4(),
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      shareMessage: shareMessage,
      menuTitle: title,
      menuSnapshot: menuSnapshot,
      allowCollaboration: allowCollaboration,
    );
  }

  // ===== BASE CLASS IMPLEMENTATIONS =====
  
  @override
  String get contentTypeName => 'menu';
  
  @override
  Map<String, List<Recipe>> get contentSnapshot => menuSnapshot;
  
  @override
  String getContentTitle() => menuTitle;
  
  @override
  String getContentDescription() => menuSummary;
  
  @override
  BaseSharedContentModel<Map<String, List<Recipe>>> copyWithStatus({
    int? viewCount,
    int? engagementCount,
    List<String>? viewedByUserIds,
    List<String>? engagedByUserIds,
    List<String>? dismissedByUserIds,
  }) {
    return copyWith(
      viewCount: viewCount,
      importCount: engagementCount,
      viewedByUserIds: viewedByUserIds,
      importedByUserIds: engagedByUserIds,
      dismissedByUserIds: dismissedByUserIds,
    );
  }
  
  /// Creates a copy of this shared menu with updated values.
  SharedMenu copyWith({
    int? viewCount,
    int? importCount,
    List<String>? viewedByUserIds,
    List<String>? importedByUserIds,
    List<String>? dismissedByUserIds,
    bool? allowCollaboration,
    bool? isOriginalReference,
    bool? copyOnWriteTriggered,
    String? originalOwnerStaticCopyId,
    List<String>? activeCollaboratorIds,
  }) {
    return SharedMenu(
      id: id,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      shareMessage: shareMessage,
      sharedAt: sharedAt,
      viewCount: viewCount ?? this.viewCount,
      engagementCount: importCount ?? engagementCount,
      viewedByUserIds: viewedByUserIds ?? this.viewedByUserIds,
      engagedByUserIds: importedByUserIds ?? engagedByUserIds,
      dismissedByUserIds: dismissedByUserIds ?? this.dismissedByUserIds,
      menuTitle: menuTitle,
      menuSnapshot: menuSnapshot,
      allowCollaboration: allowCollaboration ?? this.allowCollaboration,
      isOriginalReference: isOriginalReference ?? this.isOriginalReference,
      copyOnWriteTriggered: copyOnWriteTriggered ?? this.copyOnWriteTriggered,
      originalOwnerStaticCopyId: originalOwnerStaticCopyId ?? this.originalOwnerStaticCopyId,
      activeCollaboratorIds: activeCollaboratorIds ?? this.activeCollaboratorIds,
    );
  }

  // ===== COPY-ON-WRITE IMPLEMENTATIONS =====
  
  /// Copy-on-write getter implementations from CopyOnWriteSupport mixin.
  @override
  bool get isOriginalReference => _isOriginalReference;
  
  @override
  bool get copyOnWriteTriggered => _copyOnWriteTriggered;
  
  @override
  String? get originalOwnerStaticCopyId => _originalOwnerStaticCopyId;
  
  @override
  List<String> get activeCollaboratorIds => _activeCollaboratorIds;
  
  
  @override
  SharedMenu triggerCopyOnWrite({
    required String editingUserId,
    required String staticCopyId,
  }) {
    return copyWith(
      isOriginalReference: false,
      copyOnWriteTriggered: true,
      originalOwnerStaticCopyId: staticCopyId,
      activeCollaboratorIds: [editingUserId],
    );
  }
  
  @override
  SharedMenu addActiveCollaborator(String userId) {
    if (activeCollaboratorIds.contains(userId)) {
      return this;
    }

    return copyWith(
      activeCollaboratorIds: [...activeCollaboratorIds, userId],
    );
  }



  // ===== MENU-SPECIFIC PROPERTIES =====
  
  // ===== TYPE-SAFE WRAPPER METHODS =====
  
  /// Type-safe wrapper methods that return SharedMenu instead of BaseSharedContentModel with Map generic type
  /// These methods delegate to mixin implementations but provide concrete return types.
  
  @override
  SharedMenu markViewedBy(String userId) {
    final updated = super.markViewedBy(userId);
    if (updated == this) return this;
    return copyWith(
      viewCount: updated.viewCount,
      viewedByUserIds: updated.viewedByUserIds,
    );
  }
  
  @override
  SharedMenu markEngagedBy(String userId) {
    final updated = super.markEngagedBy(userId);
    if (updated == this) return this;
    return copyWith(
      importCount: updated.engagementCount,
      importedByUserIds: updated.engagedByUserIds,
    );
  }
  
  @override
  SharedMenu markDismissedBy(String userId) {
    final updated = super.markDismissedBy(userId);
    if (updated == this) return this;
    return copyWith(
      dismissedByUserIds: updated.dismissedByUserIds,
    );
  }
  
  @override
  SharedMenu undismissBy(String userId) {
    final updated = super.undismissBy(userId);
    if (updated == this) return this;
    return copyWith(
      dismissedByUserIds: updated.dismissedByUserIds,
    );
  }

  /// Import count getter for backward compatibility.
  int get importCount => engagementCount;
  
  /// Imported by user IDs getter for backward compatibility.
  List<String> get importedByUserIds => engagedByUserIds;
  
  /// Backward compatibility methods with old terminology.
  @override
  SharedMenu markImportedBy(String userId) => markEngagedBy(userId);
  @override
  bool isImportedBy(String userId) => isEngagedBy(userId);
  
  /// Creates an imported menu with proper attribution from this shared menu.
  Map<String, List<Recipe>> createImportMenu({required String newOwnerId}) {
    final importedMenu = <String, List<Recipe>>{};
    
    menuSnapshot.forEach((category, recipes) {
      importedMenu[category] = recipes.map((recipe) {
        final attribution = '\n\n📋 Importerat från ${sharedByDisplayName}s meny "$menuTitle"';
        final newDescription = recipe.description.isNotEmpty
            ? '${recipe.description}$attribution'
            : 'Importerat recept$attribution';
        
        return recipe.copyWith(
          description: newDescription,
          lastCookedAt: null,
        );
      }).toList();
    });
    
    return importedMenu;
  }

  /// Checks if the menu can be imported by users.
  bool get allowImport {
    return totalRecipeCount > 0;
  }

  /// Gets a localized Swedish summary of the menu contents for preview display.
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

  /// Gets user-friendly Swedish text for how long ago the menu was shared.
  ///
  /// Provides localized time-ago display optimized for Swedish users with natural
  /// language formatting for improved user experience and temporal context.
  ///
  /// Returns Swedish time format: 'Nu', '5 min sedan', '2 tim sedan', '3 dagar sedan', '2 veckor sedan'.
  @override
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

  /// Analytics and statistics methods for menu engagement insights.

  /// Gets the conversion rate from views to imports as a percentage.
  ///
  /// Provides menu effectiveness metrics by calculating the percentage of
  /// viewers who imported the menu for performance analysis.
  ///
  /// Returns conversion rate as a percentage (0.0 to 100.0).
  @override
  double get conversionRate {
    if (viewCount == 0) return 0.0;
    return (importCount / viewCount) * 100.0;
  }
  
  /// Gets the total number of unique users who have interacted with the menu.
  ///
  /// Provides engagement reach metrics by counting all users who have viewed,
  /// imported, or dismissed the menu for comprehensive interaction analysis.
  @override
  int get totalInteractions {
    final allInteractors = <String>{
      ...viewedByUserIds,
      ...importedByUserIds,
      ...dismissedByUserIds,
    };
    return allInteractors.length;
  }
  
  /// Checks if the menu has any recipe content available for sharing.
  ///
  /// Provides validation for menu sharing eligibility based on content availability.
  ///
  /// Returns true if the menu contains at least one recipe in any category.
  bool get hasContent => totalRecipeCount > 0;
  
  /// Gets the most popular category based on recipe count.
  ///
  /// Provides menu analysis by identifying the category with the most recipes
  /// for content optimization and user preference insights.
  ///
  /// Returns the category name with the highest recipe count, or null if empty.
  String? get mostPopularCategory {
    if (menuSnapshot.isEmpty) return null;
    
    String? topCategory;
    int maxCount = 0;
    
    for (final entry in menuSnapshot.entries) {
      if (entry.value.length > maxCount) {
        maxCount = entry.value.length;
        topCategory = entry.key;
      }
    }
    
    return topCategory;
  }

  /// Data persistence and serialization methods for Firestore and caching integration.

  /// Converts the shared menu to Firestore-compatible format for persistence.
  ///
  /// Transforms all menu data including complete recipe snapshots into Firestore format
  /// with proper timestamp handling and nested object serialization for database efficiency.
  ///
  /// Returns a map containing all shared menu data formatted for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    // Convert menu snapshot to Firestore format - UTAN serverTimestamp i nested data
    final menuData = <String, dynamic>{};
    for (final entry in menuSnapshot.entries) {
      menuData[entry.key] = entry.value.map((recipe) {
        // Få recipe data och säkerställ att inga FieldValue.serverTimestamp() finns i nested objects
        final recipeData = recipe.toFirestore();

        // Ersätt eventuella serverTimestamp med DateTime.now() för nested objects
        if (recipeData['createdAt'] is DateTime) {
          recipeData['createdAt'] = AppTimestamp.fromDateTime(recipe.createdAt).toFirestore();
        }
        if (recipeData['updatedAt'] is DateTime) {
          recipeData['updatedAt'] = AppTimestamp.fromDateTime(recipe.updatedAt).toFirestore();
        }
        if (recipeData['lastCookedAt'] is DateTime && recipe.lastCookedAt != null) {
          recipeData['lastCookedAt'] = AppTimestamp.fromDateTime(recipe.lastCookedAt!).toFirestore();
        }

        return recipeData;
      }).toList();
    }

    return {
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': sharedByDisplayName,
      'sharedToUserIds': sharedToUserIds,
      'sharedAt': AppTimestamp.fromDateTime(sharedAt).toFirestore(),
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
      'isOriginalReference': isOriginalReference, // CoW: Original reference status
      'copyOnWriteTriggered': copyOnWriteTriggered, // CoW: Trigger status
      'originalOwnerStaticCopyId': originalOwnerStaticCopyId, // CoW: Static copy ID
      'activeCollaboratorIds': activeCollaboratorIds, // CoW: Active collaborators
    };
  }

  /// Creates a shared menu instance from Firestore repository data with robust error handling.
  ///
  /// Transforms Firestore document data into a complete [SharedMenu] instance with proper
  /// type conversion, recipe reconstruction, and comprehensive error handling for robust data recovery.
  ///
  /// [id] Document identifier from Firestore
  /// [data] Raw document data from Firestore with all menu fields
  ///
  /// Returns a new [SharedMenu] instance with all data properly parsed and validated.
  /// Factory constructor to create SharedMenu from Firestore document.
  ///
  /// This is a convenience method that delegates to fromMap for compatibility
  /// with services expecting a fromFirestore method.
  factory SharedMenu.fromFirestore(Map<String, dynamic> data, String id) {
    return SharedMenu.fromMap(id, data);
  }
  
  factory SharedMenu.fromMap(String id, Map<String, dynamic> data) {
    try {
      debugPrint('🔍 Parsing SharedMenu från doc ID: $id');

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
              core: RecipeCore(
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
              ),
              type: RecipeType.shared, // Mark as shared menu recipe
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

      return SharedMenu(
        id: id,
        sharedByUserId: data['sharedByUserId'] as String? ?? '',
        sharedByDisplayName: data['sharedByDisplayName'] as String? ?? '',
        sharedToUserIds: List<String>.from(data['sharedToUserIds'] ?? []),
        sharedAt: _parseTimestamp(data['sharedAt']) ?? DateTime.now(),
        shareMessage: data['shareMessage'] as String?,
        menuTitle: data['menuTitle'] as String? ?? 'Delad meny',
        menuSnapshot: reconstructedMenu,
        viewCount: data['viewCount'] as int? ?? 0,
        engagementCount: data['importCount'] as int? ?? 0,
        viewedByUserIds: List<String>.from(data['viewedByUserIds'] ?? []),
        engagedByUserIds: List<String>.from(data['importedByUserIds'] ?? []),
        dismissedByUserIds: List<String>.from(data['dismissedByUserIds'] ?? []),
        allowCollaboration: data['allowCollaboration'] as bool? ?? false,
        isOriginalReference: data['isOriginalReference'] as bool? ?? true,
        copyOnWriteTriggered: data['copyOnWriteTriggered'] as bool? ?? false,
        originalOwnerStaticCopyId: data['originalOwnerStaticCopyId'] as String?,
        activeCollaboratorIds: List<String>.from(data['activeCollaboratorIds'] ?? []),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing SharedMenu från doc $id: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 🔧 ADDED: Helper method för robust timestamp parsing
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is Map) {
        // Handle raw timestamp data from Firestore
        final seconds = timestamp['seconds'] as int?;
        final nanoseconds = timestamp['nanoseconds'] as int? ?? 0;
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + nanoseconds ~/ 1000000);
        }
      } else if (timestamp is int) {
        // Handle milliseconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        // Handle ISO string format
        return DateTime.parse(timestamp);
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
      'isOriginalReference': isOriginalReference, // CoW: JSON support
      'copyOnWriteTriggered': copyOnWriteTriggered, // CoW: JSON support
      'originalOwnerStaticCopyId': originalOwnerStaticCopyId, // CoW: JSON support
      'activeCollaboratorIds': activeCollaboratorIds, // CoW: JSON support
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

    return SharedMenu(
      id: json['id'] as String,
      sharedByUserId: json['sharedByUserId'] as String? ?? '',
      sharedByDisplayName: json['sharedByDisplayName'] as String? ?? '',
      sharedToUserIds: List<String>.from(json['sharedToUserIds'] ?? []),
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      shareMessage: json['shareMessage'] as String?,
      menuTitle: json['menuTitle'] as String? ?? 'Delad meny',
      menuSnapshot: reconstructedMenu,
      viewCount: json['viewCount'] as int? ?? 0,
      engagementCount: json['importCount'] as int? ?? 0,
      viewedByUserIds: List<String>.from(json['viewedByUserIds'] ?? []),
      engagedByUserIds: List<String>.from(json['importedByUserIds'] ?? []),
      dismissedByUserIds: List<String>.from(json['dismissedByUserIds'] ?? []),
      allowCollaboration: json['allowCollaboration'] as bool? ?? false,
      isOriginalReference: json['isOriginalReference'] as bool? ?? true,
      copyOnWriteTriggered: json['copyOnWriteTriggered'] as bool? ?? false,
      originalOwnerStaticCopyId: json['originalOwnerStaticCopyId'] as String?,
      activeCollaboratorIds: List<String>.from(json['activeCollaboratorIds'] ?? []),
    );
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the shared menu for debugging and logging.
  ///
  /// Provides essential menu information in a readable format for development
  /// and debugging purposes with menu title, owner, and recipe count.
  @override
  String toString() {
    return 'SharedMenu(id: $id, title: $menuTitle, sharedBy: $sharedByDisplayName, recipes: $totalRecipeCount, CoW: ${copyOnWriteTriggered ? 'collaborative' : 'original'})';
  }

  /// Compares two shared menus for equality based on unique identifier.
  ///
  /// Uses menu ID for equality comparison ensuring consistent object
  /// identity across different instances of the same menu data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedMenu && other.id == id;
  }

  /// Generates hash code based on unique menu identifier.
  ///
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and menu identification.
  @override
  int get hashCode => id.hashCode;
}
