/// Firebase implementation of [TrashRepository] (BUT-907).
///
/// Stores at `users/{uid}/trash/{recipeId}`. Owner-only, like
/// `overwritten_versions`: the uid is in the path, so every permission check
/// is "is the caller that user". The rules block in firestore.rules forbids
/// updates, so a copy is only ever restored or deleted.
///
/// Moving a recipe to the trash and restoring it each write both documents
/// at once, so a recipe is never gone without its copy and never both live
/// and in the trash.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe/recipe_serialization.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/trash_item.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/modules/recipe_legacy_validator.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';
import 'package:butlery/services/parsing/sanitizers/recipe_sanitizer.dart';

class FirebaseTrashRepository extends BaseFirebaseRepository<TrashItem>
    with UserScopedFirebaseRepository<TrashItem>
    implements TrashRepository {
  FirebaseTrashRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  }) {
    _legacyValidator = RecipeLegacyValidator(
      firestore: firestore,
      getUserRecipeDoc: (userId, recipeId) =>
          _recipes(userId).doc(recipeId).get(),
      validateOwnership: validateOwnership,
    );
  }

  /// The most writes one Firestore batch takes.
  static const int batchLimit = 500;

  /// The recipe repository's delete check, so a recipe goes to the trash
  /// only when it could have been deleted (firebase_recipe_repository.dart).
  late final RecipeLegacyValidator _legacyValidator;

  @override
  String get collectionName => FirestoreCollections.userTrash;

  @override
  TrashItem fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final parsed = TrashItem.fromFirestore(doc.id, doc.data() ?? {});
    if (parsed == null) {
      throw FormatException('Not a restorable trash item: ${doc.id}');
    }
    return parsed;
  }

  @override
  Map<String, dynamic> toFirestore(TrashItem entity) => entity.toFirestore();

  @override
  String getId(TrashItem entity) => entity.id;

  @override
  Future<bool> validateCreatePermission(String userId, TrashItem entity) async {
    final createdBy = entity.recipe.createdBy;
    return userId == requireCurrentUserId() &&
        entity.ownerId == userId &&
        entity.sourceId == entity.id &&
        (createdBy == null || createdBy.isEmpty || createdBy == userId);
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    TrashItem? entity,
  ) async =>
      userId == requireCurrentUserId() &&
      (entity == null || entity.ownerId == userId);

  /// A trash row is never changed; it is restored or deleted.
  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    TrashItem entity,
  ) async => false;

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async => userId == requireCurrentUserId();

  CollectionReference<Map<String, dynamic>> _trash(String uid) =>
      getCollectionForUser(uid);

  CollectionReference<Map<String, dynamic>> _recipes(String uid) => firestore
      .collection(FirestoreCollections.users)
      .doc(uid)
      .collection(FirestoreCollections.recipes);

  Query<Map<String, dynamic>> _newestFirst(String uid) => _trash(
    uid,
  ).orderBy('deletedAt', descending: true).limit(TrashRepository.listLimit);

  static List<TrashItem> _parse(QuerySnapshot<Map<String, dynamic>> snap) => [
    for (final doc in snap.docs) ?TrashItem.fromFirestore(doc.id, doc.data()),
  ];

  Future<void> _require(
    bool allowed,
    String uid,
    String resource,
    String operation,
  ) async {
    await logPermissionCheck(
      userId: uid,
      resource: 'TrashItem/$resource',
      operation: operation,
      granted: allowed,
      auditRepository: auditRepository,
    );
    if (!allowed) {
      throw PermissionDeniedException(
        'User may not $operation trash item $resource',
        resource: 'trash',
        operation: operation,
        userId: uid,
      );
    }
  }

  @override
  Stream<List<TrashItem>> watchTrash() {
    final uid = requireCurrentUserId();
    return _newestFirst(uid).snapshots().map(_parse);
  }

  @override
  Future<List<TrashItem>> listTrash() async {
    final uid = requireCurrentUserId();
    return _parse(await _newestFirst(uid).get());
  }

  @override
  Future<void> moveRecipeToTrash(Recipe recipe) async {
    final uid = requireCurrentUserId();
    final isLegacy = _legacyValidator.isLegacyRecipe(recipe);
    final canDelete = await _legacyValidator.validateDeletionWithLegacySupport(
      recipe,
      uid,
      recipe.id,
      isLegacy,
      (r) => (r.socialData?.ownerId ?? r.createdBy).orEmpty(),
    );
    await _require(canDelete, uid, recipe.id, 'delete');

    final item = TrashItem.fromRecipe(recipe, ownerId: uid);
    await _require(
      await validateCreatePermission(uid, item),
      uid,
      item.id,
      'create',
    );
    if (isLegacy) await _legacyValidator.logLegacyDeletion(recipe, uid);

    final batch = firestore.batch()
      ..set(_trash(uid).doc(item.id), item.toFirestore())
      ..delete(_recipes(uid).doc(recipe.id));
    await batch.commit();
  }

  @override
  Future<Recipe> restoreRecipe(TrashItem item, {TagResult? tagResult}) async {
    final uid = requireCurrentUserId();
    await _require(item.ownerId == uid, uid, item.id, 'restore');
    if (!item.isKeptAt(clock.now())) throw TrashItemExpiredException(item.id);

    final trashRef = _trash(uid).doc(item.id);
    final recipeRef = _recipes(uid).doc(item.sourceId);
    // A transaction rather than a batch: it is written only while the copy
    // is still there and the recipe is not, so a second restore from a stale
    // screen can neither replace a recipe edited since nor reset its `rev`.
    return firestore.runTransaction((tx) async {
      final trashSnap = await tx.get(trashRef);
      final stored = trashSnap.exists
          ? TrashItem.fromFirestore(trashSnap.id, trashSnap.data() ?? {})
          : null;
      if (stored == null) throw TrashItemGoneException(item.id);
      if (stored.ownerId != uid) {
        throw PermissionDeniedException(
          'User may not restore trash item ${item.id}',
          resource: 'trash',
          operation: 'restore',
          userId: uid,
        );
      }
      if (!stored.isKeptAt(clock.now())) {
        throw TrashItemExpiredException(item.id);
      }
      if ((await tx.get(recipeRef)).exists) {
        throw TrashItemGoneException(item.id);
      }
      final restored = restoredRecipe(stored, tagResult: tagResult);
      tx
        ..set(recipeRef, {
          ...RecipeSerialization.toFirestore(restored),
          'rev': restored.rev,
        })
        ..delete(trashRef);
      return restored;
    });
  }

  /// [item]'s recipe as a restore writes it: sanitized as every recipe write
  /// is (BUT-1819), with [tagResult] when given, one revision on from the
  /// one it was deleted at (BUT-2213), so a queued edit built on the deleted
  /// copy meets a conflict rather than writing over the restore unasked.
  static Recipe restoredRecipe(TrashItem item, {TagResult? tagResult}) {
    final kept = item.recipe;
    final recipe = sanitizeRecipeText(
      tagResult == null
          ? kept
          : Recipe(
              core: kept.core.copyWith(tagResult: tagResult),
              type: kept.type,
            ),
    );
    return Recipe(
      core: recipe.core,
      type: RecipeType.personal,
      rev: (kept.rev ?? 0) + 1,
    );
  }

  @override
  Future<void> deleteForever(List<String> ids) async {
    final uid = requireCurrentUserId();
    for (final id in ids) {
      await _require(
        id.isNotEmpty && await validateDeletePermission(uid, id),
        uid,
        id,
        'delete',
      );
    }
    final trash = _trash(uid);
    for (var start = 0; start < ids.length; start += batchLimit) {
      final end = (start + batchLimit).clamp(0, ids.length);
      final batch = firestore.batch();
      for (final id in ids.sublist(start, end)) {
        batch.delete(trash.doc(id));
      }
      await batch.commit();
    }
  }

  @override
  Future<int> emptyTrash() async {
    final uid = requireCurrentUserId();
    await _require(
      await validateDeletePermission(uid, '*'),
      uid,
      '*',
      'delete',
    );
    final page = _trash(uid).limit(batchLimit);
    var deleted = 0;
    while (true) {
      final snap = await page.get();
      if (snap.docs.isEmpty) break;
      final batch = firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;
      if (snap.docs.length < batchLimit) break;
    }
    return deleted;
  }
}
