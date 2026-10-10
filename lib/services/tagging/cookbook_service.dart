import 'dart:typed_data';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/recipe_personal_tag.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';

/// Cookbooks are personal tags with a `cookbook` map (BUT-1325). This
/// service owns the writes that are cookbook-only: the map itself, the own
/// cover photo, and tagging several recipes from inside a book.
///
/// The recipe and upload services live in the Content module, which is
/// configured after Tagging, so they are resolved on first use rather than
/// at construction.
class CookbookService extends BaseService {
  CookbookService({
    required PersonalTagService tagService,
    UnifiedRecipeService? recipeService,
    ImageUploadService? uploadService,
    StorageService? storageService,
    PermissionService? permissionService,
  }) : _tags = tagService,
       _recipeServiceOverride = recipeService,
       _uploadServiceOverride = uploadService,
       _storageServiceOverride = storageService,
       _permissionServiceOverride = permissionService;

  final PersonalTagService _tags;
  final UnifiedRecipeService? _recipeServiceOverride;
  final ImageUploadService? _uploadServiceOverride;
  final StorageService? _storageServiceOverride;
  final PermissionService? _permissionServiceOverride;

  UnifiedRecipeService get _recipes =>
      _recipeServiceOverride ?? ServiceLocator.get<UnifiedRecipeService>();
  ImageUploadService get _uploads =>
      _uploadServiceOverride ?? ServiceLocator.get<ImageUploadService>();
  StorageService get _storage =>
      _storageServiceOverride ?? ServiceLocator.get<StorageService>();
  PermissionService get _permissions =>
      _permissionServiceOverride ?? ServiceLocator.get<PermissionService>();

  @override
  String get serviceName => 'CookbookService';

  List<Recipe> get libraryRecipes => _recipes.recipes;

  /// Fires whenever the library changes, so a book can re-order its recipes.
  Stream<void> get libraryChanges => _recipes.stateStream;

  Stream<List<PersonalTag>> watchTags() => _tags.watchTags();

  /// Writes [details] as [tag]'s cookbook. When the cover's own photo was
  /// replaced or dropped, the old file is deleted afterwards; a failed delete
  /// only leaves a file under the user's own folder, which account deletion
  /// removes.
  Future<bool> save(PersonalTag tag, CookbookDetails details) async {
    if (!isValid(details)) return false;
    final saved = await _tags.updateCookbook(tag.id, details);
    if (saved) await _deleteReplacedPhoto(tag.cookbook, details);
    return saved;
  }

  /// The tag and its recipes stay exactly as they were.
  Future<bool> remove(PersonalTag tag) async {
    final saved = await _tags.updateCookbook(tag.id, null);
    if (saved) await _deleteReplacedPhoto(tag.cookbook, null);
    return saved;
  }

  static bool isValid(CookbookDetails details) =>
      details.description.length <= CookbookDetails.maxDescriptionLength &&
      (details.recipeOrder?.length ?? 0) <= CookbookDetails.maxOrderedRecipes &&
      details.recipeNotes.length <= CookbookDetails.maxOrderedRecipes &&
      details.recipeNotes.values.every(
        (n) => n.length <= CookbookDetails.maxNoteLength,
      );

  /// Uploads an own cover photo and returns its URL, or null when the upload
  /// failed (offline included; the upload service classifies the cause).
  Future<String?> uploadCoverPhoto(Uint8List bytes, String fileName) async {
    final userId = _permissions.currentUserId;
    if (userId == null) return null;
    final result = await _uploads.uploadImageFromBytes(
      bytes: bytes,
      userId: userId,
      fileName: fileName,
    );
    return result.success ? result.url : null;
  }

  /// Puts [tag] on every recipe in [recipes] that lacks it, then, if the
  /// book has its own order, appends them to it so they land last. Returns
  /// how many recipes were tagged, or null when the book's order could not
  /// be saved (the tagged recipes still show, among the unlisted ones).
  Future<int?> addRecipes(PersonalTag tag, List<Recipe> recipes) async {
    final cookbook = tag.cookbook;
    if (cookbook == null) return null;

    final added = <String>[];
    for (final recipe in recipes) {
      final ids = recipe.core.personalTagIds ?? const <String>[];
      if (ids.contains(tag.id)) continue;
      final updated = Recipe(
        core: recipe.core.copyWith(
          personalTagIds: [...ids, tag.id],
          personalTags: [
            ...?recipe.core.personalTags,
            RecipePersonalTag.manual(tagId: tag.id, name: tag.name),
          ],
        ),
        type: recipe.type,
        socialData: recipe.socialData,
        realtimeData: recipe.realtimeData,
        offlineData: recipe.offlineData,
        rev: recipe.rev,
      );
      final ok = await executeServiceOperation<bool>(
        () => _recipes.updateRecipe(updated),
        operationName: 'Add recipe to cookbook',
        defaultValue: false,
      );
      if (ok ?? false) added.add(recipe.id);
    }

    final order = cookbook.recipeOrder;
    if (order == null || added.isEmpty) return added.length;
    final saved = await save(
      tag,
      cookbook.copyWith(recipeOrder: [...order, ...added]),
    );
    if (!saved) {
      AppLogger.warning('Cookbook ${tag.id}: recipes tagged, order not saved');
      return null;
    }
    return added.length;
  }

  Future<void> _deleteReplacedPhoto(
    CookbookDetails? before,
    CookbookDetails? after,
  ) async {
    final old = before?.cover;
    if (old == null || old.kind != CookbookCoverKind.photo) return;
    final oldUrl = old.imageUrl;
    if (oldUrl == null) return;
    final next = after?.cover;
    if (next?.kind == CookbookCoverKind.photo && next?.imageUrl == oldUrl) {
      return;
    }
    await executeServiceOperation<bool>(
      () => _storage.deleteImage(oldUrl),
      operationName: 'Delete old cookbook cover',
      defaultValue: false,
    );
  }
}
