import 'package:butlery/models/shared_content/base_shared_content_model.dart';
import 'package:butlery/models/shared_content/shared_content_status_mixin.dart';
import 'package:butlery/models/shared_content/copy_on_write_mixin.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart' as utils;
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Shared menu model with copy-on-write collaboration support.
class SharedMenu extends BaseSharedContentModel<Map<String, List<Recipe>>>
    with SharedContentStatusMixin, CopyOnWriteSupport {
  final String menuTitle;
  final Map<String, List<Recipe>> menuSnapshot;
  final int totalRecipeCount;
  final List<String> categories;
  final bool allowCollaboration;
  final String? realtimeMenuId;
  final bool _isOriginalReference;
  final bool _copyOnWriteTriggered;
  final String? _originalOwnerStaticCopyId;
  final int _activeCollaboratorCount;

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
    this.realtimeMenuId,
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

  factory SharedMenu.create({
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    String? shareMessage,
    String? menuTitle,
    required Map<String, List<Recipe>> menuSnapshot,
    bool allowCollaboration = false,
    String? realtimeMenuId,
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
      realtimeMenuId: realtimeMenuId,
    );
  }

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

  SharedMenu copyWith({
    int? viewCount,
    int? importCount,
    int? dismissalCount,
    bool? allowCollaboration,
    String? realtimeMenuId,
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
      realtimeMenuId: realtimeMenuId ?? this.realtimeMenuId,
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
      activeCollaboratorCount: 1,
    );
  }

  @override
  SharedMenu addActiveCollaborator(String userId) {
    if (!copyOnWriteTriggered) {
      return this;
    }
    return copyWith(activeCollaboratorCount: activeCollaboratorCount + 1);
  }

  int get importCount => engagementCount;

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

  bool get allowImport => totalRecipeCount > 0;

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

  @override
  double get conversionRate {
    if (viewCount == 0) return 0.0;
    return (importCount / viewCount) * 100.0;
  }

  bool get hasContent => totalRecipeCount > 0;

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

  Map<String, dynamic> toFirestore() {
    final menuData = <String, dynamic>{};
    for (final entry in menuSnapshot.entries) {
      menuData[entry.key] = entry.value.map((recipe) {
        final recipeData = recipe.core.toFirestore();

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
      if (realtimeMenuId != null) 'realtimeMenuId': realtimeMenuId,
    };
  }

  factory SharedMenu.fromFirestore(Map<String, dynamic> data, String id) {
    return SharedMenu.fromMap(id, data);
  }

  factory SharedMenu.fromMap(String id, Map<String, dynamic> data) {
    try {
      final menuData =
          (data['menuSnapshot'] as Map<String, dynamic>?).orEmpty();
      final reconstructedMenu = <String, List<Recipe>>{};

      for (final entry in menuData.entries) {
        final recipeList = <Recipe>[];
        final recipes = (entry.value as List<dynamic>?).orEmpty();

        for (final recipeData in recipes) {
          try {
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
              type: RecipeType.shared,
            );
            recipeList.add(recipe);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ Skippar ogiltigt recept i meny: $e');
            }
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
        realtimeMenuId:
            utils.SerializationUtils.safeNullableString(data, 'realtimeMenuId'),
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

  Map<String, dynamic> toJson() {
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
      if (realtimeMenuId != null) 'realtimeMenuId': realtimeMenuId,
    };
  }

  factory SharedMenu.fromJson(Map<String, dynamic> json) {
    final menuData = (json['menuSnapshot'] as Map<String, dynamic>?).orEmpty();
    final reconstructedMenu = <String, List<Recipe>>{};

    for (final entry in menuData.entries) {
      final recipeList = <Recipe>[];
      final recipes = (entry.value as List<dynamic>?).orEmpty();

      for (final recipeData in recipes) {
        try {
          recipeList.add(Recipe.fromJson(recipeData as Map<String, dynamic>));
        } catch (e) {
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
      realtimeMenuId: json['realtimeMenuId'] as String?,
      isOriginalReference: cowFields['isOriginalReference'] as bool,
      copyOnWriteTriggered: cowFields['copyOnWriteTriggered'] as bool,
      originalOwnerStaticCopyId:
          cowFields['originalOwnerStaticCopyId'] as String?,
      activeCollaboratorCount: cowFields['activeCollaboratorCount'] as int,
    );
  }

  @override
  String toString() {
    return 'SharedMenu(id: $id, title: $menuTitle, sharedBy: $sharedByDisplayName, recipes: $totalRecipeCount, CoW: ${copyOnWriteTriggered ? 'collaborative' : 'original'})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedMenu && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
