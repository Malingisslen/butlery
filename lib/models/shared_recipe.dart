import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/shared_content/base_shared_content_model.dart';
import 'package:butlery/models/shared_content/shared_content_status_mixin.dart';
import 'package:butlery/models/shared_content/copy_on_write_mixin.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/serialization_utils.dart' as utils;
import 'package:butlery/core/extensions/default_value_extensions.dart';

enum ShareScope {
  individual,
  multiple,
  friends,
}

/// Shared recipe model with copy-on-write collaboration support.
///
/// V2 optimization (FIRE-CRITICAL-003): Uses denormalized metadata for list display
/// instead of embedding full recipe. Full recipe fetched on-demand for detail views.
class SharedRecipe extends BaseSharedContentModel<Recipe>
    with SharedContentStatusMixin, CopyOnWriteSupport {
  final String originalRecipeId;

  /// Denormalized metadata for efficient list display (V2)
  final String recipeTitle;
  final String? recipeImageUrl;
  final int? recipePortions;
  final int? recipeTimeMinutes;
  final String? recipeDescription;

  /// Full recipe snapshot - deprecated, kept for backward compatibility.
  /// New shares only store denormalized fields; full recipe fetched on-demand.
  final Recipe? _recipeSnapshot;

  final ShareScope scope;
  final bool allowImport;
  final bool allowCollaboration;
  final bool _isOriginalReference;
  final bool _copyOnWriteTriggered;
  final String? _originalOwnerStaticCopyId;
  final int _activeCollaboratorCount;

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
    // V2 denormalized metadata
    required this.recipeTitle,
    this.recipeImageUrl,
    this.recipePortions,
    this.recipeTimeMinutes,
    this.recipeDescription,
    // Deprecated: full snapshot (backward compatibility)
    Recipe? recipeSnapshot,
    this.scope = ShareScope.individual,
    this.allowImport = true,
    this.allowCollaboration = false,
    // Copy-on-write fields
    bool isOriginalReference = true,
    bool copyOnWriteTriggered = false,
    String? originalOwnerStaticCopyId,
    int activeCollaboratorCount = 0,
  })  : _recipeSnapshot = recipeSnapshot,
        _isOriginalReference = isOriginalReference,
        _copyOnWriteTriggered = copyOnWriteTriggered,
        _originalOwnerStaticCopyId = originalOwnerStaticCopyId,
        _activeCollaboratorCount = activeCollaboratorCount,
        super(sharedAt: sharedAt ?? DateTime.now());

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
      // V2: Store denormalized metadata for efficient list display
      recipeTitle: recipeSnapshot.title,
      recipeImageUrl: recipeSnapshot.imageUrls.isNotEmpty
          ? recipeSnapshot.imageUrls.first
          : null,
      recipePortions: recipeSnapshot.portions,
      recipeTimeMinutes: recipeSnapshot.timeMinutes,
      recipeDescription: recipeSnapshot.description,
      // Keep snapshot for backward compatibility during transition
      recipeSnapshot: recipeSnapshot,
      scope: determinedScope,
      allowImport: allowImport,
      allowCollaboration: allowCollaboration,
    );
  }

  @override
  String get contentTypeName => 'recipe';

  /// Returns the full recipe snapshot if available (backward compatibility).
  /// For new V2 shares, this may be null - use denormalized fields for display.
  Recipe? get recipeSnapshot => _recipeSnapshot;

  /// Backward compatibility getter for recipe.
  Recipe? get recipe => _recipeSnapshot;

  /// Whether full recipe snapshot is available (V1 shares have it, V2 may not).
  bool get hasFullSnapshot => _recipeSnapshot != null;

  @override
  Recipe get contentSnapshot {
    // Return snapshot if available, otherwise create minimal recipe from metadata
    return _recipeSnapshot ??
        Recipe(
          core: RecipeCore(
            id: originalRecipeId,
            title: recipeTitle,
            description: recipeDescription.orEmpty(),
            ingredients: const [],
            instructions: const [],
            imageUrls: recipeImageUrl != null ? [recipeImageUrl!] : const [],
            mealType: 'Middag',
            portions: recipePortions,
            timeMinutes: recipeTimeMinutes,
            createdAt: sharedAt,
            updatedAt: sharedAt,
          ),
          type: RecipeType.shared,
        );
  }

  @override
  String getContentTitle() => recipeTitle;

  @override
  String getContentDescription() => recipeDescription.orEmpty();

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
      // V2 denormalized fields
      recipeTitle: recipeTitle,
      recipeImageUrl: recipeImageUrl,
      recipePortions: recipePortions,
      recipeTimeMinutes: recipeTimeMinutes,
      recipeDescription: recipeDescription,
      recipeSnapshot: _recipeSnapshot,
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
      activeCollaboratorCount: 1,
    );
  }

  @override
  SharedRecipe addActiveCollaborator(String userId) {
    if (!copyOnWriteTriggered) {
      return this;
    }
    return copyWith(activeCollaboratorCount: activeCollaboratorCount + 1);
  }

  int get importCount => engagementCount;

  /// Creates a recipe for import. Requires full snapshot to be available.
  /// For V2 shares without snapshot, caller must fetch full recipe first.
  Recipe? createImportRecipe({required String newOwnerId}) {
    if (_recipeSnapshot == null) return null;
    final attributionText =
        AppLocale.current.sharedRecipeAttributionText(sharedByDisplayName);
    // Clear sender's personalTagIds — UUIDs are meaningless in recipient's account
    return _recipeSnapshot.copyWith(
      sourceUrl: attributionText,
      personalTagIds: [],
    );
  }

  ResourcePermission get permission {
    return allowCollaboration
        ? ResourcePermission.editor
        : ResourcePermission.viewer;
  }

  EditMode getEditModeFor(String userId) {
    if (sharedByUserId == userId) {
      return EditMode.owner;
    }

    if (copyOnWriteTriggered && hasActiveCollaborators) {
      return EditMode.collaborative;
    }

    return allowCollaboration
        ? EditMode.readOnlyWithFork
        : EditMode.readOnlyWithFork;
  }

  Map<String, dynamic> toFirestore() {
    return {
      ...getCommonFirestoreFields(),
      ...getCopyOnWriteFirestoreFields(),
      'originalRecipeId': originalRecipeId,
      'scope': scope.name,
      'allowImport': allowImport,
      'allowCollaboration': allowCollaboration,
      // V2 denormalized metadata for efficient list display
      'recipeTitle': recipeTitle,
      if (recipeImageUrl != null) 'recipeImageUrl': recipeImageUrl,
      if (recipePortions != null) 'recipePortions': recipePortions,
      if (recipeTimeMinutes != null) 'recipeTimeMinutes': recipeTimeMinutes,
      if (recipeDescription != null) 'recipeDescription': recipeDescription,
      // Keep snapshot for backward compatibility during transition
      if (_recipeSnapshot != null)
        'recipeSnapshot': _recipeSnapshot.toFirestore(),
    };
  }

  factory SharedRecipe.fromMap(String id, Map<String, dynamic> data) {
    try {
      final commonFields =
          BaseSharedContentModel.parseCommonFieldsFromFirestore(data);
      final cowFields =
          CopyOnWriteSupport.parseCopyOnWriteFieldsFromFirestore(data);

      // V1 backward compatibility: parse full snapshot if present
      final recipeData = data['recipeSnapshot'] as Map<String, dynamic>?;
      Recipe? recipe;
      String recipeTitle;
      String? recipeImageUrl;
      int? recipePortions;
      int? recipeTimeMinutes;
      String? recipeDescription;

      if (recipeData != null) {
        // V1 format: full snapshot present
        recipe = Recipe(
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
            imageUrls: utils.SerializationUtils.safeStringList(
                recipeData, 'imageUrls'),
            mealType: utils.SerializationUtils.safeString(
                recipeData, 'mealType',
                defaultValue: 'Middag'),
            portions: utils.SerializationUtils.safeNullableInt(
                recipeData, 'portions'),
            timeMinutes: utils.SerializationUtils.safeNullableInt(
                recipeData, 'timeMinutes'),
            rating: utils.SerializationUtils.safeNullableDouble(
                recipeData, 'rating'),
            personalTagIds: utils.SerializationUtils.safeStringList(
                recipeData, 'personalTagIds'),
            sourceUrl: utils.SerializationUtils.safeNullableString(
                recipeData, 'sourceUrl'),
            createdAt: utils.SerializationUtils.safeDateTime(
                    recipeData, 'createdAt') ??
                DateTime.now(),
            updatedAt: utils.SerializationUtils.safeDateTime(
                    recipeData, 'updatedAt') ??
                DateTime.now(),
            lastCookedAt: utils.SerializationUtils.safeDateTime(
                recipeData, 'lastCookedAt'),
          ),
          type: RecipeType.shared,
        );
        // Extract denormalized fields from snapshot for consistency
        recipeTitle = recipe.title;
        final imageUrls = recipe.imageUrls;
        recipeImageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
        recipePortions = recipe.portions;
        recipeTimeMinutes = recipe.timeMinutes;
        recipeDescription = recipe.description;
      } else {
        // V2 format: denormalized fields only
        recipeTitle = utils.SerializationUtils.safeString(data, 'recipeTitle',
            defaultValue: 'Untitled Recipe');
        recipeImageUrl =
            utils.SerializationUtils.safeNullableString(data, 'recipeImageUrl');
        recipePortions =
            utils.SerializationUtils.safeNullableInt(data, 'recipePortions');
        recipeTimeMinutes =
            utils.SerializationUtils.safeNullableInt(data, 'recipeTimeMinutes');
        recipeDescription = utils.SerializationUtils.safeNullableString(
            data, 'recipeDescription');
      }

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
        // V2 denormalized fields
        recipeTitle: recipeTitle,
        recipeImageUrl: recipeImageUrl,
        recipePortions: recipePortions,
        recipeTimeMinutes: recipeTimeMinutes,
        recipeDescription: recipeDescription,
        // V1 backward compatibility: full snapshot
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
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      ...getCommonJsonFields(),
      ...getCopyOnWriteJsonFields(),
      'originalRecipeId': originalRecipeId,
      'scope': scope.name,
      'allowImport': allowImport,
      'allowCollaboration': allowCollaboration,
      // V2 denormalized metadata
      'recipeTitle': recipeTitle,
      if (recipeImageUrl != null) 'recipeImageUrl': recipeImageUrl,
      if (recipePortions != null) 'recipePortions': recipePortions,
      if (recipeTimeMinutes != null) 'recipeTimeMinutes': recipeTimeMinutes,
      if (recipeDescription != null) 'recipeDescription': recipeDescription,
      // V1 backward compatibility
      if (_recipeSnapshot != null) 'recipeSnapshot': _recipeSnapshot.toJson(),
    };
  }

  factory SharedRecipe.fromJson(Map<String, dynamic> json) {
    final commonFields = BaseSharedContentModel.parseCommonFieldsFromJson(json);
    final cowFields = CopyOnWriteSupport.parseCopyOnWriteFieldsFromJson(json);

    // V1 backward compatibility: parse snapshot if present
    final snapshotData = json['recipeSnapshot'] as Map<String, dynamic>?;
    Recipe? recipe;
    String recipeTitle;
    String? recipeImageUrl;
    int? recipePortions;
    int? recipeTimeMinutes;
    String? recipeDescription;

    if (snapshotData != null) {
      recipe = Recipe.fromJson(snapshotData);
      recipeTitle = recipe.title;
      recipeImageUrl =
          recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null;
      recipePortions = recipe.portions;
      recipeTimeMinutes = recipe.timeMinutes;
      recipeDescription = recipe.description;
    } else {
      recipeTitle = json['recipeTitle'] as String? ?? 'Untitled Recipe';
      recipeImageUrl = json['recipeImageUrl'] as String?;
      recipePortions = json['recipePortions'] as int?;
      recipeTimeMinutes = json['recipeTimeMinutes'] as int?;
      recipeDescription = json['recipeDescription'] as String?;
    }

    return SharedRecipe(
      id: commonFields['id'] as String,
      sharedByUserId: commonFields['sharedByUserId'] as String,
      sharedByDisplayName: commonFields['sharedByDisplayName'] as String,
      sharedAt: commonFields['sharedAt'] as DateTime,
      shareMessage: commonFields['shareMessage'] as String?,
      viewCount: commonFields['viewCount'] as int,
      engagementCount: commonFields['engagementCount'] as int,
      dismissalCount: commonFields['dismissalCount'] as int,
      originalRecipeId: (json['originalRecipeId'] as String?).orEmpty(),
      recipeTitle: recipeTitle,
      recipeImageUrl: recipeImageUrl,
      recipePortions: recipePortions,
      recipeTimeMinutes: recipeTimeMinutes,
      recipeDescription: recipeDescription,
      recipeSnapshot: recipe,
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

  @override
  String toString() {
    return 'SharedRecipe(id: $id, recipe: $recipeTitle, sharedBy: $sharedByDisplayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedRecipe && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
