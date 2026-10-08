/// BUT-2213: the recipe's revision, the top-level `rev` field, for the
/// recipe repository.
///
/// A whole recipe save raises it by one. A queued save from the offline
/// queue also says which revision it was built on, and is written only if
/// the server is still there; otherwise the server's recipe comes back as a
/// [RecipeRevisionConflictException] and nothing is written.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/parsing/sanitizers/recipe_sanitizer.dart';
import 'package:butlery/utils/text/ingredient_processor.dart';

class RecipeRevisionOperations {
  RecipeRevisionOperations({
    required this.firestore,
    required this.toFirestore,
    required this.checkOwner,
  });

  final FirebaseFirestore firestore;

  /// The repository's serializer, so every write goes through its
  /// sanitizing chokepoint (BUT-1819).
  final Map<String, dynamic> Function(Recipe recipe) toFirestore;

  /// Throws unless the signed-in user owns [existing], the server's copy.
  final Future<void> Function(Recipe existing) checkOwner;

  static const String revField = 'rev';

  /// [entity] as it is saved: sanitized, with its ingredients normalized when
  /// they need it (MODUL1 Phase 3).
  static Recipe prepare(Recipe entity) {
    final sanitized = sanitizeRecipeText(entity);
    if (!IngredientProcessor.needsNormalization(sanitized)) return sanitized;
    return sanitized.copyWith(
      ingredientsNormalized: IngredientProcessor.normalizeIngredientsForRecipe(
        sanitized.core.ingredients,
      ),
    );
  }

  /// The fields a whole save writes, raising the revision without reading
  /// it. A missing field counts as 0, so the first raise gives 1.
  Map<String, dynamic> bumped(Recipe recipe) => {
    ...toFirestore(recipe),
    revField: FieldValue.increment(1),
  };

  /// Writes [recipe] to [ref] if the server is still at [expectedRev], and
  /// returns the revision the server now has. A null [expectedRev] is
  /// written without comparing.
  ///
  /// When the server has moved on but already holds exactly what is sent (a
  /// send repeated after its answer was lost), the save counts as done and
  /// nothing is written (BUT-2162 F3-2: recipes carry no `opId`).
  Future<int> writeAtRevision(
    DocumentReference<Map<String, dynamic>> ref,
    Recipe recipe, {
    int? expectedRev,
  }) {
    final fields = toFirestore(recipe);
    return firestore.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (!snap.exists || data == null) {
        throw ResourceNotFoundException(
          'Recipe not found',
          resourceType: 'recipe',
          resourceId: ref.id,
        );
      }
      final server = Recipe.fromMap(snap.id, data);
      await checkOwner(server);
      final serverRev = server.rev ?? 0;
      if (expectedRev != null && serverRev != expectedRev) {
        if (_sameContent(fields, server)) return serverRev;
        throw RecipeRevisionConflictException(server);
      }
      tx.update(ref, {...fields, revField: serverRev + 1});
      return serverRev + 1;
    });
  }

  /// Writes [recipe] to [ref] as a new recipe and returns its revision, 0.
  /// When the document already exists (a create sent again after its answer
  /// was lost), nothing is written: the create counts as done while the
  /// server holds the same content at revision 0, and is otherwise a conflict
  /// carrying the server's recipe, so a later save from another device is
  /// neither replaced nor its revision reset.
  Future<int> createOnce(
    DocumentReference<Map<String, dynamic>> ref,
    Recipe recipe,
  ) {
    final fields = toFirestore(recipe);
    return firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (!snap.exists || data == null) {
        tx.set(ref, fields);
        return 0;
      }
      final server = Recipe.fromMap(snap.id, data);
      await checkOwner(server);
      if ((server.rev ?? 0) == 0 && _sameContent(fields, server)) return 0;
      throw RecipeRevisionConflictException(server);
    });
  }

  /// Both sides through the same serializer, so a difference in how a value
  /// is stored (a Timestamp against a DateTime) is not taken for an edit.
  bool _sameContent(Map<String, dynamic> sent, Recipe server) =>
      const DeepCollectionEquality().equals(sent, toFirestore(server));
}
