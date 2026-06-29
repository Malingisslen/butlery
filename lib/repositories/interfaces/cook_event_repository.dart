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
  /// (the boolean contract `RecipeCookingService` builds its retry-safe
  /// session guard on).
  ///
  /// [attendeeMemberIds] records who was eating (the "who's eating today" pick,
  /// roster member ids). Defaults to empty — when empty the stored doc keeps its
  /// original `{recipeId, cookedAt}` shape.
  Future<bool> logCookEvent(
    String recipeId,
    DateTime cookedAt, {
    List<String> attendeeMemberIds = const [],
  });

  /// The attendee set of [userId]'s most recent cook event that recorded
  /// attendance — the "remember last time" default for the who's-eating picker.
  ///
  /// Attendance was added late and is written only when non-empty, so most
  /// historical events carry no attendee field and there is no server-side
  /// "has attendees" filter without a new index. This scans the newest
  /// [scanLimit] events and returns the first non-empty `attendeeMemberIds`;
  /// it returns an empty list when no recent event recorded attendance (the
  /// picker then falls back to everyone-selected). A convenience default, not
  /// a correctness-critical read.
  ///
  /// Owner-only — throws `PermissionDeniedException` when [userId] is not the
  /// authenticated user. Index-backed by the automatic single-field index on
  /// `cookedAt` (no composite).
  Future<List<String>> recentAttendeeMemberIds(
    String userId, {
    int scanLimit = 20,
  });

  /// Number of cook events for [userId] with `cookedAt >= since`
  /// (boundary inclusive). Owner-only — throws `PermissionDeniedException`
  /// when [userId] is not the authenticated user.
  ///
  /// Index-backed: a server-side `count()` aggregate over a single-field
  /// range on `cookedAt` — no documents are downloaded.
  Future<int> countSince(String userId, DateTime since);

  /// GDPR Article 15/20: export [userId]'s cook events as raw
  /// `{id, data}` maps for the user data export bundle.
  ///
  /// Owner-only — throws `PermissionDeniedException` when [userId] is not
  /// the authenticated user. A null [limit] fetches the whole event log.
  Future<List<Map<String, dynamic>>> exportCookEventsByUser(
    String userId, {
    int? limit,
  });
}
