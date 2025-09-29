/// Shared recipe model using unified base infrastructure for consistent shared content patterns.
///
/// This model extends BaseSharedContentModel and uses mixins for status management and
/// copy-on-write functionality, eliminating duplicate code while maintaining recipe-specific
/// features and collaboration capabilities.
///
/// **Key Features:**
/// - **Unified Status Management**: Uses SharedContentStatusMixin for consistent view/import/dismiss tracking
/// - **Copy-on-Write Collaboration**: Uses CopyOnWriteSupport for collaborative editing features
/// - **Recipe-Specific Logic**: Maintains sharing scopes, import attribution, and recipe permissions
/// - **Consistent Serialization**: Leverages base class patterns for Firestore and JSON operations
///
/// **Usage Examples:**
/// ```dart
/// // Create new shared recipe with collaboration
/// final sharedRecipe = SharedRecipe.create(
///   originalRecipeId: recipeId,
///   sharedByUserId: currentUserId,
///   sharedByDisplayName: 'Anna Andersson',
///   sharedToUserIds: [friend1Id, friend2Id],
///   shareMessage: 'Hoppas ni gillar det här familjerecept!',
///   allowImport: true,
///   allowCollaboration: true,
///   recipeSnapshot: originalRecipe,
/// );
/// 
/// // Status tracking (via mixins)
/// final viewedRecipe = sharedRecipe.markViewedBy(userId);
/// final importedRecipe = viewedRecipe.markImportedBy(userId);
/// ```

// lib/models/shared_recipe.dart

import 'package:butlery/models/shared_content/base_shared_content_model.dart';
import 'package:butlery/models/shared_content/shared_content_status_mixin.dart';
import 'package:butlery/models/shared_content/copy_on_write_mixin.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

/// Enumeration defining the scope of recipe sharing for distribution categorization.
///
/// Share scopes determine the distribution pattern and recipient management:
/// - [individual] - Recipe shared with a specific person for direct personal sharing
/// - [multiple] - Recipe shared with multiple specific recipients for group distribution
/// - [friends] - Recipe shared with all friends (future feature for broad social sharing)
enum ShareScope {
  individual, // Delad till specifik person
  multiple, // Delad till flera personer
  friends, // Delad till alla vänner (framtida feature)
}

/// Shared recipe model with unified base infrastructure and recipe-specific features.
class SharedRecipe extends BaseSharedContentModel<Recipe>
    with SharedContentStatusMixin, CopyOnWriteSupport {
  // ===== RECIPE-SPECIFIC FIELDS =====
  
  /// Reference identifier to the original recipe for tracking and linking.
  final String originalRecipeId;
  
  /// Complete snapshot of the recipe at the time of sharing.
  final Recipe recipeSnapshot;
  
  /// Scope of the recipe sharing for distribution categorization.
  final ShareScope scope;
  
  /// Flag indicating whether recipients can import or copy the recipe.
  final bool allowImport;
  
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

  /// Creates a new shared recipe with all required metadata.
  SharedRecipe({
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
    required this.originalRecipeId,
    required this.recipeSnapshot,
    this.scope = ShareScope.individual,
    this.allowImport = true,
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
        super(sharedAt: sharedAt ?? DateTime.now());

  /// Factory constructor for creating new shared recipes with auto-generated ID and intelligent defaults.
  factory SharedRecipe.create({
    required String originalRecipeId,
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    String? shareMessage,
    ShareScope? scope,
    bool allowImport = true,
    bool allowCollaboration = false,
    required Recipe recipeSnapshot,
  }) {
    // Determine scope based on number of recipients
    final determinedScope = scope ??
        (sharedToUserIds.length == 1
            ? ShareScope.individual
            : ShareScope.multiple);

    return SharedRecipe(
      id: const Uuid().v4(),
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      shareMessage: shareMessage,
      originalRecipeId: originalRecipeId,
      recipeSnapshot: recipeSnapshot,
      scope: determinedScope,
      allowImport: allowImport,
      allowCollaboration: allowCollaboration,
    );
  }

  // ===== BASE CLASS IMPLEMENTATIONS =====
  
  @override
  String get contentTypeName => 'recipe';
  
  @override
  Recipe get contentSnapshot => recipeSnapshot;
  
  @override
  String getContentTitle() => recipeSnapshot.title;
  
  @override
  String getContentDescription() => recipeSnapshot.description;
  
  @override
  BaseSharedContentModel<Recipe> copyWithStatus({
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
  
  /// Creates a copy of this shared recipe with updated values.
  SharedRecipe copyWith({
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
    return SharedRecipe(
      id: id,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      sharedAt: sharedAt,
      shareMessage: shareMessage,
      viewCount: viewCount ?? this.viewCount,
      engagementCount: importCount ?? engagementCount,
      viewedByUserIds: viewedByUserIds ?? this.viewedByUserIds,
      engagedByUserIds: importedByUserIds ?? engagedByUserIds,
      dismissedByUserIds: dismissedByUserIds ?? this.dismissedByUserIds,
      originalRecipeId: originalRecipeId,
      recipeSnapshot: recipeSnapshot,
      scope: scope,
      allowImport: allowImport,
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
  SharedRecipe triggerCopyOnWrite({
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
      activeCollaboratorIds: [editingUserId],
    );
  }
  
  @override
  SharedRecipe addActiveCollaborator(String userId) {
    if (!copyOnWriteTriggered || activeCollaboratorIds.contains(userId)) {
      return this;
    }

    return copyWith(
      activeCollaboratorIds: [...activeCollaboratorIds, userId],
    );
  }

  // ===== TYPE-SAFE WRAPPER METHODS =====
  
  /// Type-safe wrapper methods that return SharedRecipe instead of BaseSharedContentModel with Recipe generic type
  /// These methods delegate to mixin implementations but provide concrete return types.
  
  @override
  SharedRecipe markViewedBy(String userId) {
    final updated = super.markViewedBy(userId);
    if (updated == this) return this;
    return copyWith(
      viewCount: updated.viewCount,
      viewedByUserIds: updated.viewedByUserIds,
    );
  }
  
  @override
  SharedRecipe markEngagedBy(String userId) {
    final updated = super.markEngagedBy(userId);
    if (updated == this) return this;
    return copyWith(
      importCount: updated.engagementCount,
      importedByUserIds: updated.engagedByUserIds,
    );
  }
  
  @override
  SharedRecipe markDismissedBy(String userId) {
    final updated = super.markDismissedBy(userId);
    if (updated == this) return this;
    return copyWith(
      dismissedByUserIds: updated.dismissedByUserIds,
    );
  }
  
  @override
  SharedRecipe undismissBy(String userId) {
    final updated = super.undismissBy(userId);
    if (updated == this) return this;
    return copyWith(
      dismissedByUserIds: updated.dismissedByUserIds,
    );
  }

  // ===== RECIPE-SPECIFIC PROPERTIES =====
  
  /// Alias getter for the recipe snapshot for backward compatibility.
  Recipe get recipe => recipeSnapshot;
  
  /// Checks if the specified user is a recipient of this shared recipe.
  bool isSharedTo(String userId) => sharedToUserIds.contains(userId);
  
  /// Import count getter for backward compatibility.
  int get importCount => engagementCount;
  
  /// Imported by user IDs getter for backward compatibility.
  List<String> get importedByUserIds => engagedByUserIds;
  
  /// Backward compatibility methods with old terminology.
  @override
  SharedRecipe markImportedBy(String userId) => markEngagedBy(userId);
  @override
  bool isImportedBy(String userId) => isEngagedBy(userId);


  // ===== RECIPE-SPECIFIC METHODS =====

  /// Creates a new recipe with proper attribution for importing shared recipes.
  Recipe createImportRecipe({required String newOwnerId}) {
    final attributionText = 'Inspirerat av recept från $sharedByDisplayName';
    return recipeSnapshot.copyWith(sourceUrl: attributionText);
  }

  /// Gets the permission level for this shared recipe based on collaboration settings.
  ResourcePermission get permission {
    return allowCollaboration ? ResourcePermission.editor : ResourcePermission.viewer;
  }

  /// Determines the appropriate edit mode for the specified user.
  EditMode getEditModeFor(String userId) {
    if (sharedByUserId == userId) {
      return EditMode.owner;
    }

    if (!sharedToUserIds.contains(userId)) {
      return EditMode.noAccess;
    }

    if (copyOnWriteTriggered && activeCollaboratorIds.contains(userId)) {
      return EditMode.collaborative;
    }

    return allowCollaboration ? EditMode.readOnlyWithFork : EditMode.readOnlyWithFork;
  }

  // ===== SERIALIZATION =====

  /// Converts the shared recipe to Firestore-compatible format for persistence.
  Map<String, dynamic> toFirestore() {
    return {
      ...getCommonFirestoreFields(),
      ...getCopyOnWriteFirestoreFields(),
      'originalRecipeId': originalRecipeId,
      'scope': scope.name,
      'allowImport': allowImport,
      'allowCollaboration': allowCollaboration,
      'recipeSnapshot': recipeSnapshot.toFirestore(),
    };
  }

  /// Creates a shared recipe instance from Firestore repository data.
  factory SharedRecipe.fromMap(String id, Map<String, dynamic> data) {
    try {
      final commonFields = BaseSharedContentModel.parseCommonFieldsFromFirestore(data);
      final cowFields = CopyOnWriteSupport.parseCopyOnWriteFieldsFromFirestore(data);
      final recipeData = data['recipeSnapshot'] as Map<String, dynamic>;

      final recipe = Recipe(
        core: RecipeCore(
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
          createdAt: BaseSharedContentModel.parseTimestamp(recipeData['createdAt']) ?? DateTime.now(),
          updatedAt: BaseSharedContentModel.parseTimestamp(recipeData['updatedAt']) ?? DateTime.now(),
          lastCookedAt: BaseSharedContentModel.parseTimestamp(recipeData['lastCookedAt']),
        ),
        type: RecipeType.shared,
      );

      return SharedRecipe(
        id: id,
        sharedByUserId: commonFields['sharedByUserId'] as String,
        sharedByDisplayName: commonFields['sharedByDisplayName'] as String,
        sharedToUserIds: commonFields['sharedToUserIds'] as List<String>,
        sharedAt: commonFields['sharedAt'] as DateTime,
        shareMessage: commonFields['shareMessage'] as String?,
        viewCount: commonFields['viewCount'] as int,
        engagementCount: commonFields['engagementCount'] as int,
        viewedByUserIds: commonFields['viewedByUserIds'] as List<String>,
        engagedByUserIds: commonFields['engagedByUserIds'] as List<String>,
        dismissedByUserIds: commonFields['dismissedByUserIds'] as List<String>,
        originalRecipeId: data['originalRecipeId'] as String? ?? '',
        recipeSnapshot: recipe,
        scope: ShareScope.values.firstWhere(
          (s) => s.name == data['scope'],
          orElse: () => ShareScope.individual,
        ),
        allowImport: data['allowImport'] as bool? ?? true,
        allowCollaboration: data['allowCollaboration'] as bool? ?? false,
        isOriginalReference: cowFields['isOriginalReference'] as bool,
        copyOnWriteTriggered: cowFields['copyOnWriteTriggered'] as bool,
        originalOwnerStaticCopyId: cowFields['originalOwnerStaticCopyId'] as String?,
        activeCollaboratorIds: cowFields['activeCollaboratorIds'] as List<String>,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing SharedRecipe från doc $id: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Converts the shared recipe to JSON format for caching and client-side storage.
  Map<String, dynamic> toJson() {
    return {
      ...getCommonJsonFields(),
      ...getCopyOnWriteJsonFields(),
      'originalRecipeId': originalRecipeId,
      'scope': scope.name,
      'allowImport': allowImport,
      'allowCollaboration': allowCollaboration,
      'recipeSnapshot': recipeSnapshot.toJson(),
    };
  }

  /// Creates a shared recipe instance from JSON data for caching and deserialization.
  factory SharedRecipe.fromJson(Map<String, dynamic> json) {
    final commonFields = BaseSharedContentModel.parseCommonFieldsFromJson(json);
    final cowFields = CopyOnWriteSupport.parseCopyOnWriteFieldsFromJson(json);
    
    return SharedRecipe(
      id: commonFields['id'] as String,
      sharedByUserId: commonFields['sharedByUserId'] as String,
      sharedByDisplayName: commonFields['sharedByDisplayName'] as String,
      sharedToUserIds: commonFields['sharedToUserIds'] as List<String>,
      sharedAt: commonFields['sharedAt'] as DateTime,
      shareMessage: commonFields['shareMessage'] as String?,
      viewCount: commonFields['viewCount'] as int,
      engagementCount: commonFields['engagementCount'] as int,
      viewedByUserIds: commonFields['viewedByUserIds'] as List<String>,
      engagedByUserIds: commonFields['engagedByUserIds'] as List<String>,
      dismissedByUserIds: commonFields['dismissedByUserIds'] as List<String>,
      originalRecipeId: json['originalRecipeId'] as String? ?? '',
      recipeSnapshot: Recipe.fromJson(json['recipeSnapshot'] as Map<String, dynamic>),
      scope: ShareScope.values.firstWhere(
        (s) => s.name == json['scope'],
        orElse: () => ShareScope.individual,
      ),
      allowImport: json['allowImport'] as bool? ?? true,
      allowCollaboration: json['allowCollaboration'] as bool? ?? false,
      isOriginalReference: cowFields['isOriginalReference'] as bool,
      copyOnWriteTriggered: cowFields['copyOnWriteTriggered'] as bool,
      originalOwnerStaticCopyId: cowFields['originalOwnerStaticCopyId'] as String?,
      activeCollaboratorIds: cowFields['activeCollaboratorIds'] as List<String>,
    );
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the shared recipe for debugging and logging.
  ///
  /// Provides essential recipe sharing information in a readable format for development
  /// and debugging purposes with recipe title, owner name, and recipient count.
  @override
  String toString() {
    return 'SharedRecipe(id: $id, recipe: ${recipeSnapshot.title}, sharedBy: $sharedByDisplayName, recipients: ${sharedToUserIds.length})';
  }

  /// Compares two shared recipes for equality based on unique identifier.
  ///
  /// Uses recipe sharing ID for equality comparison ensuring consistent object
  /// identity across different instances of the same shared recipe data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedRecipe && other.id == id;
  }

  /// Generates hash code based on unique shared recipe identifier.
  ///
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and recipe identification.
  @override
  int get hashCode => id.hashCode;
}
