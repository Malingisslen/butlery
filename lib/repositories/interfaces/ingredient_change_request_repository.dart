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

  /// Upper bound on [watchOpen]; a full page means more are waiting.
  static const int maxPending = 500;

  /// Most `applied` proposals [watchApplied] returns.
  static const int maxApplied = 30;

  /// Most `rejected` proposals [watchRejected] returns.
  static const int maxRejected = 20;

  /// Proposals still in the queue (`pending`, `inReview`, `conflict`), at
  /// most [maxPending], unordered; the caller sorts.
  Stream<List<IngredientChangeRequest>> watchOpen();

  /// The newest `applied` proposals by `appliedAt`, at most [maxApplied].
  /// Needs the composite index on status and appliedAt.
  Stream<List<IngredientChangeRequest>> watchApplied();

  /// Some `rejected` proposals, at most [maxRejected], unordered: they are
  /// rare, so an order would not pay for an index.
  Stream<List<IngredientChangeRequest>> watchRejected();

  /// Allowed from `pending`, `conflict` and `inReview`.
  Future<void> withdraw(String id);
}
