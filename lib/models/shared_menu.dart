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
import 'package:butlery/core/utils/serialization_utils.dart' as utils;
import 'package:butlery/core/extensions/default_value_extensions.dart';

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

  /// Count of users actively collaborating on this content (Issue #014).
  ///
  /// Note: Actual collaborator list now stored in Firestore subcollection to eliminate
  /// 100-element array limit. Use repository.getCollaborators(menuId) for full list.
  final int _activeCollaboratorCount;

  /// Creates a new shared menu with all required metadata.
  ///
  /// Note (Issue #014): sharedToUserIds removed from model. Repository layer handles adding
  /// members to Firestore subcollection after creation.
  SharedMenu({
    required super.id,
    required super.sharedByUserId,
    required super.sharedByDisplayName,
    DateTime? sharedAt,
    super.shareMessage,
    super.viewCount = 0,
    super.engagementCount = 0,
    super.dismissalCount = 0,
    required this.menuTitle,
    required this.menuSnapshot,
    this.allowCollaboration = false,
    // Copy-on-write fields
    bool isOriginalReference = true,
    bool copyOnWriteTriggered = false,
    String? originalOwnerStaticCopyId,
    int activeCollaboratorCount = 0,
  })  : _isOriginalReference = isOriginalReference,
        _copyOnWriteTriggered = copyOnWriteTriggered,
        _originalOwnerStaticCopyId = originalOwnerStaticCopyId,
        _activeCollaboratorCount = activeCollaboratorCount,
        totalRecipeCount = menuSnapshot.values.fold(
          0,
          (totalCount, recipes) => totalCount + recipes.length,
        ),
        categories = menuSnapshot.keys.toList(),
        super(sharedAt: sharedAt ?? DateTime.now());

  /// Factory constructor for creating new shared menus with auto-generated ID.
  ///
  /// Note (Issue #014): sharedToUserIds still accepted for backward compatibility but not stored in model.
  /// Repository layer handles adding members to Firestore subcollection after creation.
  factory SharedMenu.create({
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds, // Still accept for repository layer
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
      shareMessage: shareMessage,
      menuTitle: title,
      menuSnapshot: menuSnapshot,
      allowCollaboration: allowCollaboration,
    ); // Note: sharedToUserIds NOT passed to constructor
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
    int? dismissalCount,
  }) {
    return copyWith(
      viewCount: viewCount,
      importCount: engagementCount,
      dismissalCount: dismissalCount,
    );
  }

  /// Creates a copy of this shared menu with updated values.
  ///
  /// Note (Issue #014): Array parameters removed. Status now tracked in Firestore subcollections.
  SharedMenu copyWith({
    int? viewCount,
    int? importCount,
    int? dismissalCount,
    bool? allowCollaboration,
    bool? isOriginalReference,
    bool? copyOnWriteTriggered,
    String? originalOwnerStaticCopyId,
    int? activeCollaboratorCount,
  }) {
    return SharedMenu(
      id: id,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      shareMessage: shareMessage,
      sharedAt: sharedAt,
      viewCount: viewCount ?? this.viewCount,
      engagementCount: importCount ?? engagementCount,
      dismissalCount: dismissalCount ?? this.dismissalCount,
      menuTitle: menuTitle,
      menuSnapshot: menuSnapshot,
      allowCollaboration: allowCollaboration ?? this.allowCollaboration,
      isOriginalReference: isOriginalReference ?? this.isOriginalReference,
      copyOnWriteTriggered: copyOnWriteTriggered ?? this.copyOnWriteTriggered,
      originalOwnerStaticCopyId:
          originalOwnerStaticCopyId ?? this.originalOwnerStaticCopyId,
      activeCollaboratorCount:
          activeCollaboratorCount ?? this.activeCollaboratorCount,
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
  int get activeCollaboratorCount => _activeCollaboratorCount;

  @override
  SharedMenu triggerCopyOnWrite({
    required String editingUserId,
    required String staticCopyId,
  }) {
    if (copyOnWriteTriggered || editingUserId == sharedByUserId) {
      return this;
    }

    return copyWith(
      isOriginalReference: false,
      copyOnWriteTriggered: true,
      originalOwnerStaticCopyId: staticCopyId,
      activeCollaboratorCount: 1, // First collaborator
    );
  }

  @override
  SharedMenu addActiveCollaborator(String userId) {
    if (!copyOnWriteTriggered) {
      return this;
    }

    // Increment count (actual list managed in Firestore subcollection)
    return copyWith(
      activeCollaboratorCount: activeCollaboratorCount + 1,
    );
  }

  // ===== MENU-SPECIFIC PROPERTIES =====

  // ===== TYPE-SAFE WRAPPER METHODS (REMOVED - ISSUE #014) =====
  //
  // Note: Status-checking methods (markViewedBy, markEngagedBy, etc.) removed from base class.
  // Status tracking now handled by repository layer using Firestore subcollections.
  // Use repository methods instead:
  //   - repository.addView(menuId, userId)
  //   - repository.addEngagement(menuId, userId, action: 'import')
  //   - repository.addDismissal(menuId, userId)
  //   - repository.removeDismissal(menuId, userId)

  /// Import count getter for backward compatibility.
  int get importCount => engagementCount;

  /// Creates an imported menu with proper attribution from this shared menu.
  Map<String, List<Recipe>> createImportMenu({required String newOwnerId}) {
    final importedMenu = <String, List<Recipe>>{};

    menuSnapshot.forEach((category, recipes) {
      importedMenu[category] = recipes.map((recipe) {
        final attribution =
            '\n\n📋 Importerat från ${sharedByDisplayName}s meny "$menuTitle"';
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
          recipeData['createdAt'] =
              AppTimestamp.fromDateTime(recipe.createdAt).toFirestore();
        }
        if (recipeData['updatedAt'] is DateTime) {
          recipeData['updatedAt'] =
              AppTimestamp.fromDateTime(recipe.updatedAt).toFirestore();
        }
        if (recipeData['lastCookedAt'] is DateTime &&
            recipe.lastCookedAt != null) {
          recipeData['lastCookedAt'] =
              AppTimestamp.fromDateTime(recipe.lastCookedAt!).toFirestore();
        }

        return recipeData;
      }).toList();
    }

    return {
      ...getCommonFirestoreFields(),
      ...getCopyOnWriteFirestoreFields(),
      'menuTitle': menuTitle,
      'menuSnapshot': menuData,
      'totalRecipeCount': totalRecipeCount,
      'categories': categories,
      'allowCollaboration': allowCollaboration,
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
      // 🔧 FIXED: Reconstruct menu snapshot utan MockDocumentSnapshot type cast
      final menuData =
          (data['menuSnapshot'] as Map<String, dynamic>?).orEmpty();
      final reconstructedMenu = <String, List<Recipe>>{};

      for (final entry in menuData.entries) {
        final recipeList = <Recipe>[];
        final recipes = (entry.value as List<dynamic>?).orEmpty();

        for (final recipeData in recipes) {
          try {
            // 🔧 FIXED: Skapa Recipe direkt från data istället för via mock DocumentSnapshot
            final recipeMap = recipeData as Map<String, dynamic>;
            final recipe = Recipe(
              core: RecipeCore(
                id: utils.SerializationUtils.safeString(recipeMap, 'id'),
                title: utils.SerializationUtils.safeString(recipeMap, 'title',
                    defaultValue: 'Untitled Recipe'),
                description: utils.SerializationUtils.safeString(
                    recipeMap, 'description'),
                ingredients: utils.SerializationUtils.safeStringList(
                    recipeMap, 'ingredients'),
                instructions: utils.SerializationUtils.safeStringList(
                    recipeMap, 'instructions'),
                imageUrls: utils.SerializationUtils.safeStringList(
                    recipeMap, 'imageUrls'),
                mealType: utils.SerializationUtils.safeString(
                    recipeMap, 'mealType',
                    defaultValue: 'Middag'),
                portions: utils.SerializationUtils.safeNullableInt(
                    recipeMap, 'portions'),
                timeMinutes: utils.SerializationUtils.safeNullableInt(
                    recipeMap, 'timeMinutes'),
                rating: utils.SerializationUtils.safeNullableDouble(
                    recipeMap, 'rating'),
                tags:
                    utils.SerializationUtils.safeStringList(recipeMap, 'tags'),
                sourceUrl: utils.SerializationUtils.safeNullableString(
                    recipeMap, 'sourceUrl'),
                createdAt: utils.SerializationUtils.safeDateTime(
                        recipeMap, 'createdAt')
                    .orNow(),
                updatedAt: utils.SerializationUtils.safeDateTime(
                        recipeMap, 'updatedAt')
                    .orNow(),
                lastCookedAt: utils.SerializationUtils.safeDateTime(
                    recipeMap, 'lastCookedAt'),
              ),
              type: RecipeType.shared, // Mark as shared menu recipe
            );
            recipeList.add(recipe);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ Skippar ogiltigt recept i meny: $e');
            }
            // Skip invalid recipes rather than failing entirely
            continue;
          }
        }
        reconstructedMenu[entry.key] = recipeList;
      }

      final commonFields =
          BaseSharedContentModel.parseCommonFieldsFromFirestore(data);
      final cowFields =
          CopyOnWriteSupport.parseCopyOnWriteFieldsFromFirestore(data);

      return SharedMenu(
        id: id,
        sharedByUserId: commonFields['sharedByUserId'] as String,
        sharedByDisplayName: commonFields['sharedByDisplayName'] as String,
        sharedAt: commonFields['sharedAt'] as DateTime,
        shareMessage: commonFields['shareMessage'] as String?,
        viewCount: commonFields['viewCount'] as int,
        engagementCount: commonFields['engagementCount'] as int,
        dismissalCount: commonFields['dismissalCount'] as int,
        menuTitle: utils.SerializationUtils.safeString(data, 'menuTitle',
            defaultValue: 'Delad meny'),
        menuSnapshot: reconstructedMenu,
        allowCollaboration: utils.SerializationUtils.safeBool(
            data, 'allowCollaboration',
            defaultValue: false),
        isOriginalReference: cowFields['isOriginalReference'] as bool,
        copyOnWriteTriggered: cowFields['copyOnWriteTriggered'] as bool,
        originalOwnerStaticCopyId:
            cowFields['originalOwnerStaticCopyId'] as String?,
        activeCollaboratorCount: cowFields['activeCollaboratorCount'] as int,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error parsing SharedMenu från doc $id: $e');
        debugPrint('❌ Stack trace: $stackTrace');
      }
      rethrow;
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
      ...getCommonJsonFields(),
      ...getCopyOnWriteJsonFields(),
      'menuTitle': menuTitle,
      'menuSnapshot': menuData,
      'totalRecipeCount': totalRecipeCount,
      'categories': categories,
      'allowCollaboration': allowCollaboration,
    };
  }

  factory SharedMenu.fromJson(Map<String, dynamic> json) {
    // Reconstruct menu snapshot from JSON
    final menuData = (json['menuSnapshot'] as Map<String, dynamic>?).orEmpty();
    final reconstructedMenu = <String, List<Recipe>>{};

    for (final entry in menuData.entries) {
      final recipeList = <Recipe>[];
      final recipes = (entry.value as List<dynamic>?).orEmpty();

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

    final commonFields = BaseSharedContentModel.parseCommonFieldsFromJson(json);
    final cowFields = CopyOnWriteSupport.parseCopyOnWriteFieldsFromJson(json);

    return SharedMenu(
      id: commonFields['id'] as String,
      sharedByUserId: commonFields['sharedByUserId'] as String,
      sharedByDisplayName: commonFields['sharedByDisplayName'] as String,
      sharedAt: commonFields['sharedAt'] as DateTime,
      shareMessage: commonFields['shareMessage'] as String?,
      viewCount: commonFields['viewCount'] as int,
      engagementCount: commonFields['engagementCount'] as int,
      dismissalCount: commonFields['dismissalCount'] as int,
      menuTitle: (json['menuTitle'] as String?).orDefault('Delad meny'),
      menuSnapshot: reconstructedMenu,
      allowCollaboration: (json['allowCollaboration'] as bool?).orFalse(),
      isOriginalReference: cowFields['isOriginalReference'] as bool,
      copyOnWriteTriggered: cowFields['copyOnWriteTriggered'] as bool,
      originalOwnerStaticCopyId:
          cowFields['originalOwnerStaticCopyId'] as String?,
      activeCollaboratorCount: cowFields['activeCollaboratorCount'] as int,
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
