import 'package:butlery/models/tagging/ingredient_change_request.dart';

/// Admin-only proposals to change an ingredient row. Access is enforced by
/// Firestore rules (`ingredient_change_requests`: read, create and withdraw
/// need an `admins/{uid}` document).
abstract class IngredientChangeRequestRepository {
  /// Most proposals in one [createBatch], so a batch stays one atomic write.
  static const int maxBatchSize = 50;

  /// Saves [entity] under a new id and the current user as creator. Returns
  /// the saved request.
  Future<IngredientChangeRequest> create(IngredientChangeRequest entity);

  /// Saves all [entities] in one write batch: all or nothing. Throws
  /// [ArgumentError] above [maxBatchSize].
  Future<void> createBatch(List<IngredientChangeRequest> entities);

  /// Upper bound on [watchPending]; a full page means more are waiting.
  static const int maxPending = 500;

  /// Pending proposals, at most [maxPending], unordered; the caller sorts.
  Stream<List<IngredientChangeRequest>> watchPending();

  Future<void> withdraw(String id);
}
