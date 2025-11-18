/// Shared recipe model with unified base infrastructure, status tracking, and copy-on-write collaboration.
/// **Features:** Status mixins (view/import/dismiss), collaborative editing, sharing scopes, Firestore/JSON serialization.
/// ```dart
/// final sr = SharedRecipe.create(originalRecipeId: id, sharedByUserId: uid,
///   sharedByDisplayName: 'Anna', sharedToUserIds: [f1, f2], recipeSnapshot: recipe);
/// final viewed = sr.markViewedBy(userId).markImportedBy(userId);
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
import 'package:butlery/core/utils/serialization_utils.dart' as utils;

/// Enumeration defining the scope of recipe sharing for distribution categorization.
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

  /// Count of users actively collaborating on this content (Issue #014).
  /// Note: Actual collaborator list now stored in Firestore subcollection to eliminate
  /// 100-element array limit. Use repository.getCollaborators(recipeId) for full list.
  final int _activeCollaboratorCount;

  /// Creates a new shared recipe with all required metadata.
  SharedRecipe({
    required super.id,
    required super.sharedByUserId,
    required super.sharedByDisplayName,
    DateTime? sharedAt,
    super.shareMessage,
    super.viewCount = 0,
    super.engagementCount = 0,
    super.dismissalCount = 0,
    required this.originalRecipeId,
    required this.recipeSnapshot,
    this.scope = ShareScope.individual,
    this.allowImport = true,
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
        super(sharedAt: sharedAt ?? DateTime.now());

  /// Factory constructor for creating new shared recipes with auto-generated ID and intelligent defaults.
  /// Note (Issue #014): sharedToUserIds removed from model. Repository layer handles adding
  /// members to Firestore subcollection after creation.
  factory SharedRecipe.create({
    required String originalRecipeId,
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String>
        sharedToUserIds, // Still accept for scope determination
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
    int? dismissalCount,
  }) {
    return copyWith(
      viewCount: viewCount,
      importCount: engagementCount,
      dismissalCount: dismissalCount,
    );
  }

  /// Creates a copy of this shared recipe with updated values.
  /// Note (Issue #014): Array parameters removed. Status now tracked in Firestore subcollections.
  SharedRecipe copyWith({
    int? viewCount,
    int? importCount,
    int? dismissalCount,
    bool? allowCollaboration,
    bool? isOriginalReference,
    bool? copyOnWriteTriggered,
    String? originalOwnerStaticCopyId,
    int? activeCollaboratorCount,
  }) {
    return SharedRecipe(
      id: id,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedAt: sharedAt,
      shareMessage: shareMessage,
      viewCount: viewCount ?? this.viewCount,
      engagementCount: importCount ?? engagementCount,
      dismissalCount: dismissalCount ?? this.dismissalCount,
      originalRecipeId: originalRecipeId,
      recipeSnapshot: recipeSnapshot,
      scope: scope,
      allowImport: allowImport,
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
      activeCollaboratorCount: 1, // First collaborator
    );
  }

  @override
  SharedRecipe addActiveCollaborator(String userId) {
    if (!copyOnWriteTriggered) {
      return this;
    }

    // Increment count (actual list managed in Firestore subcollection)
    return copyWith(
      activeCollaboratorCount: activeCollaboratorCount + 1,
    );
  }

  // ===== TYPE-SAFE WRAPPER METHODS (REMOVED - ISSUE #014) =====
  //
  // Note: Status-checking methods (markViewedBy, markEngagedBy, etc.) removed from base class.
  // Status tracking now handled by repository layer using Firestore subcollections.
  // Use repository methods instead:
  //   - repository.addView(recipeId, userId)
  //   - repository.addEngagement(recipeId, userId, action: 'import')
  //   - repository.addDismissal(recipeId, userId)
  //   - repository.removeDismissal(recipeId, userId)

  // ===== RECIPE-SPECIFIC PROPERTIES =====

  /// Alias getter for the recipe snapshot for backward compatibility.
  Recipe get recipe => recipeSnapshot;

  /// Import count getter for backward compatibility.
  int get importCount => engagementCount;

  // ===== RECIPE-SPECIFIC METHODS =====

  /// Creates a new recipe with proper attribution for importing shared recipes.
  Recipe createImportRecipe({required String newOwnerId}) {
    final attributionText = 'Inspirerat av recept från $sharedByDisplayName';
    return recipeSnapshot.copyWith(sourceUrl: attributionText);
  }

  /// Gets the permission level for this shared recipe based on collaboration settings.
  ResourcePermission get permission {
    return allowCollaboration
        ? ResourcePermission.editor
        : ResourcePermission.viewer;
  }

  /// Determines the appropriate edit mode for the specified user.
  /// Note (Issue #014): Simplified version. For accurate membership/collaborator checks,
  /// use repository methods: isMember(recipeId, userId), isCollaborator(recipeId, userId).
  EditMode getEditModeFor(String userId) {
    if (sharedByUserId == userId) {
      return EditMode.owner;
    }

    // Note: Cannot check membership without repository query (arrays removed)
    // Assume user has access if this method is called
    if (copyOnWriteTriggered && hasActiveCollaborators) {
      return EditMode.collaborative;
    }

    return allowCollaboration
        ? EditMode.readOnlyWithFork
        : EditMode.readOnlyWithFork;
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
      final commonFields =
          BaseSharedContentModel.parseCommonFieldsFromFirestore(data);
      final cowFields =
          CopyOnWriteSupport.parseCopyOnWriteFieldsFromFirestore(data);
      final recipeData = data['recipeSnapshot'] as Map<String, dynamic>;

      final recipe = Recipe(
        core: RecipeCore(
          id: utils.SerializationUtils.safeString(recipeData, 'id'),
          title: utils.SerializationUtils.safeString(recipeData, 'title',
              defaultValue: 'Untitled Recipe'),
          description:
              utils.SerializationUtils.safeString(recipeData, 'description'),
          ingredients: utils.SerializationUtils.safeStringList(
              recipeData, 'ingredients'),
          instructions: utils.SerializationUtils.safeStringList(
              recipeData, 'instructions'),
          imageUrls:
              utils.SerializationUtils.safeStringList(recipeData, 'imageUrls'),
          mealType: utils.SerializationUtils.safeString(recipeData, 'mealType',
              defaultValue: 'Middag'),
          portions:
              utils.SerializationUtils.safeNullableInt(recipeData, 'portions'),
          timeMinutes: utils.SerializationUtils.safeNullableInt(
              recipeData, 'timeMinutes'),
          rating:
              utils.SerializationUtils.safeNullableDouble(recipeData, 'rating'),
          tags: utils.SerializationUtils.safeStringList(recipeData, 'tags'),
          sourceUrl: utils.SerializationUtils.safeNullableString(
              recipeData, 'sourceUrl'),
          createdAt:
              utils.SerializationUtils.safeDateTime(recipeData, 'createdAt') ??
                  DateTime.now(),
          updatedAt:
              utils.SerializationUtils.safeDateTime(recipeData, 'updatedAt') ??
                  DateTime.now(),
          lastCookedAt:
              utils.SerializationUtils.safeDateTime(recipeData, 'lastCookedAt'),
        ),
        type: RecipeType.shared,
      );

      return SharedRecipe(
        id: id,
        sharedByUserId: commonFields['sharedByUserId'] as String,
        sharedByDisplayName: commonFields['sharedByDisplayName'] as String,
        sharedAt: commonFields['sharedAt'] as DateTime,
        shareMessage: commonFields['shareMessage'] as String?,
        viewCount: commonFields['viewCount'] as int,
        engagementCount: commonFields['engagementCount'] as int,
        dismissalCount: commonFields['dismissalCount'] as int,
        originalRecipeId:
            utils.SerializationUtils.safeString(data, 'originalRecipeId'),
        recipeSnapshot: recipe,
        scope: utils.SerializationUtils.safeEnum(
          data,
          'scope',
          ShareScope.values,
          ShareScope.individual,
          (e) => e.name,
        ),
        allowImport: utils.SerializationUtils.safeBool(data, 'allowImport',
            defaultValue: true),
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
        debugPrint('❌ Error parsing SharedRecipe från doc $id: $e');
        debugPrint('❌ Stack trace: $stackTrace');
      }
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
      sharedAt: commonFields['sharedAt'] as DateTime,
      shareMessage: commonFields['shareMessage'] as String?,
      viewCount: commonFields['viewCount'] as int,
      engagementCount: commonFields['engagementCount'] as int,
      dismissalCount: commonFields['dismissalCount'] as int,
      originalRecipeId: json['originalRecipeId'] as String? ?? '',
      recipeSnapshot:
          Recipe.fromJson(json['recipeSnapshot'] as Map<String, dynamic>),
      scope: ShareScope.values.firstWhere(
        (s) => s.name == json['scope'],
        orElse: () => ShareScope.individual,
      ),
      allowImport: json['allowImport'] as bool? ?? true,
      allowCollaboration: json['allowCollaboration'] as bool? ?? false,
      isOriginalReference: cowFields['isOriginalReference'] as bool,
      copyOnWriteTriggered: cowFields['copyOnWriteTriggered'] as bool,
      originalOwnerStaticCopyId:
          cowFields['originalOwnerStaticCopyId'] as String?,
      activeCollaboratorCount: cowFields['activeCollaboratorCount'] as int,
    );
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the shared recipe for debugging and logging.
  /// Provides essential recipe sharing information in a readable format for development
  /// and debugging purposes with recipe title and owner name.
  /// Note (Issue #014): Recipient count removed (array no longer exists).
  @override
  String toString() {
    return 'SharedRecipe(id: $id, recipe: ${recipeSnapshot.title}, sharedBy: $sharedByDisplayName)';
  }

  /// Compares two shared recipes for equality based on unique identifier.
  /// Uses recipe sharing ID for equality comparison ensuring consistent object
  /// identity across different instances of the same shared recipe data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedRecipe && other.id == id;
  }

  /// Generates hash code based on unique shared recipe identifier.
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and recipe identification.
  @override
  int get hashCode => id.hashCode;
}
