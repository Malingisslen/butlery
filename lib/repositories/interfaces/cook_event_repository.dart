import 'package:butlery/models/cook_event.dart';
import 'package:butlery/repositories/interfaces/repository.dart';

/// Per-user cook-event log (BUT-838).
///
/// Replaces the in-memory distinct-recipe proxy for `cooksLast14Days`:
/// every confirmed "mark as cooked" appends an event document, so repeat
/// cooks of the SAME recipe within a window each count (the proxy
/// collapsed them to 1, making `lifecycle_stage == habitual` unreachable
/// for repeat cookers).
abstract class CookEventRepository extends Repository<CookEvent> {
  /// Atomically appends a cook event for the current user AND bumps the
  /// recipe's denormalized `core.cookCount` / `core.lastCookedAt` in the
  /// same WriteBatch — either both land or neither does, so the event log
  /// and the counter can never drift.
  ///
  /// Returns true on commit, false on auth-missing / write failure
  /// (mirrors the old `RecipeRepository.incrementCookCount` contract that
  /// `RecipeCookingService` builds its retry-safe session guard on).
  Future<bool> logCookEvent(String recipeId, DateTime cookedAt);

  /// Number of cook events for [userId] with `cookedAt >= since`
  /// (boundary inclusive). Owner-only — throws `PermissionDeniedException`
  /// when [userId] is not the authenticated user.
  ///
  /// Index-backed: a server-side `count()` aggregate over a single-field
  /// range on `cookedAt` — no documents are downloaded.
  Future<int> countSince(String userId, DateTime since);
}
