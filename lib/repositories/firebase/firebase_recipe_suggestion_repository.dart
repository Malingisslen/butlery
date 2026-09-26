/// Firebase implementation of [RecipeSuggestionRepository] (P5-U27b).
///
/// Stores at the top-level `recipe_suggestions/{autoId}`. Two people read a
/// row, so it cannot live under one user's path: the suggester (`suggesterId`)
/// and the recipe's owner (`ownerId`). Every query here filters on the
/// signed-in user's own id in one of those two fields, which is also what the
/// read rule in firestore.rules requires, so a query can never ask for rows
/// the rule would refuse. The rule additionally lets only the suggester create
/// a row, only for a recipe the owner shared with them, and only the owner
/// change its status; nobody deletes one (TTL and the account deletion
/// cascade do).
///
/// The queries use equality filters only, which Firestore serves from
/// single-field indexes; the ordering is done here so no composite index is
/// needed.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_suggestion_repository.dart';

class FirebaseRecipeSuggestionRepository
    extends BaseFirebaseRepository<RecipeSuggestion>
    implements RecipeSuggestionRepository {
  FirebaseRecipeSuggestionRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get collectionName => FirestoreCollections.recipeSuggestions;

  @override
  RecipeSuggestion fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final parsed = RecipeSuggestion.fromFirestore(doc.id, doc.data() ?? {});
    if (parsed == null) {
      throw FormatException('Not a readable recipe suggestion: ${doc.id}');
    }
    return parsed;
  }

  @override
  Map<String, dynamic> toFirestore(RecipeSuggestion entity) =>
      entity.toFirestore();

  @override
  String getId(RecipeSuggestion entity) => entity.id;

  /// Only as oneself, and never to one's own recipe: an owner edits their
  /// recipe directly.
  @override
  Future<bool> validateCreatePermission(
    String userId,
    RecipeSuggestion entity,
  ) async =>
      userId == requireCurrentUserId() &&
      entity.suggesterId == userId &&
      entity.ownerId != userId;

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    RecipeSuggestion? entity,
  ) async =>
      entity != null &&
      (entity.suggesterId == userId || entity.ownerId == userId);

  /// Only the owner's decision changes a row; see [decide].
  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    RecipeSuggestion entity,
  ) async => entity.ownerId == userId;

  /// Nobody deletes a suggestion from the app: TTL removes it after 7 days
  /// and the account deletion cascade removes it with either account.
  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async => false;

  CollectionReference<Map<String, dynamic>> get _rows =>
      firestore.collection(FirestoreCollections.recipeSuggestions);

  @override
  Future<RecipeSuggestion> suggest(RecipeSuggestion suggestion) async {
    final uid = requireCurrentUserId();
    if (!await validateCreatePermission(uid, suggestion)) {
      throw PermissionDeniedException(
        'A suggestion can only be made as oneself, to someone else\'s recipe',
      );
    }
    final ref = _rows.doc();
    await ref.set(suggestion.toFirestore());
    return suggestion.withId(ref.id);
  }

  @override
  Stream<List<RecipeSuggestion>> watchMine(String recipeId) =>
      _watch('suggesterId', recipeId);

  @override
  Stream<List<RecipeSuggestion>> watchToMe(String recipeId) =>
      _watch('ownerId', recipeId);

  Stream<List<RecipeSuggestion>> _watch(String party, String recipeId) {
    final uid = requireCurrentUserId();
    return _rows
        .where(party, isEqualTo: uid)
        .where('recipeId', isEqualTo: recipeId)
        .snapshots()
        .map((snap) {
          final rows = [
            for (final doc in snap.docs)
              ?RecipeSuggestion.fromFirestore(doc.id, doc.data()),
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rows;
        });
  }

  @override
  Future<void> decide(
    String suggestionId,
    RecipeSuggestionStatus status,
  ) async {
    if (status == RecipeSuggestionStatus.pending) {
      throw ArgumentError.value(status, 'status', 'a decision is not pending');
    }
    final uid = requireCurrentUserId();
    final ref = _rows.doc(suggestionId);
    final snap = await ref.get();
    final row = snap.exists
        ? RecipeSuggestion.fromFirestore(snap.id, snap.data() ?? {})
        : null;
    if (row == null || row.ownerId != uid) {
      throw PermissionDeniedException(
        'Only the recipe\'s owner decides a suggestion',
      );
    }
    await ref.update({
      'status': status.name,
      'decidedAt': FieldValue.serverTimestamp(),
    });
  }
}
