import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cook_event.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';

/// Firebase implementation of the per-user cook-event log (BUT-838).
///
/// ## Schema
///
/// ```text
/// recipe_cook_events/{userId}/events/{eventId}
///   recipeId: string     — the cooked recipe's id (non-empty)
///   cookedAt: timestamp  — client cook time (clock.now() at the tap)
/// ```
///
/// The BUT-838 ticket writes the path as `recipe_cook_events/{userId}/{eventId}`,
/// which is not expressible in Firestore (paths alternate collection/document);
/// events therefore live in an `events` subcollection under the per-user
/// document. The `recipe_cook_events/{userId}` document itself is never
/// written — it exists only as a path segment, which is fine for direct
/// subcollection queries (and the rules key owner access off that segment).
///
/// Events are created atomically with the recipe's
/// `core.cookCount` bump (one WriteBatch). The `countSince`
/// aggregate needs only the automatic single-field index on `cookedAt`
/// (single range constraint, no orderBy/composite) — nothing was added to
/// firestore.indexes.json.
///
/// Deliberately NOT using `UserScopedFirebaseRepository` (the layer rule's
/// default for user-scoped data): the ticket pins the top-level
/// `recipe_cook_events/{userId}/events` tree so the GDPR cascade and rules
/// block address it directly; the mixin would route to `/users/{uid}/...`.
class FirebaseCookEventRepository extends BaseFirebaseRepository<CookEvent>
    implements CookEventRepository {
  /// Concrete recipe repository — owns the `core.cookCount` field shape, so
  /// the atomic increment is delegated to its batch-additive helper instead
  /// of duplicating the update map here.
  final FirebaseRecipeRepository _recipeRepository;

  FirebaseCookEventRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
    required FirebaseRecipeRepository recipeRepository,
  }) : _recipeRepository = recipeRepository;

  @override
  String get collectionName => FirestoreCollections.recipeCookEvents;

  /// `recipe_cook_events/{userId}/events` for an explicit user.
  CollectionReference<Map<String, dynamic>> eventsCollectionForUser(
    String userId,
  ) => firestore
      .collection(FirestoreCollections.recipeCookEvents)
      .doc(userId)
      .collection(FirestoreCollections.recipeCookEventEntries);

  @override
  CollectionReference<Map<String, dynamic>> getCollectionRef() =>
      eventsCollectionForUser(requireCurrentUserId());

  @override
  CookEvent fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      CookEvent.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(CookEvent entity) => entity.toFirestore();

  @override
  String getId(CookEvent entity) => entity.id;

  @override
  Future<bool> validateCreatePermission(String userId, CookEvent entity) async {
    return entity.userId == userId;
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    CookEvent? entity,
  ) async {
    // Collection routing already scopes reads to the caller's own events;
    // the entity check defends against a doc fetched via a foreign ref.
    return entity == null || entity.userId == userId;
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    CookEvent entity,
  ) async {
    return userId == currentUserId;
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    // Owner-only: routing scopes deletes to the caller's own subcollection.
    return currentUserId == userId;
  }

  String? _lastLoggedEventId;

  @override
  String? get lastLoggedEventId => _lastLoggedEventId;

  @override
  Future<bool> logCookEvent(
    String recipeId,
    DateTime cookedAt, {
    List<String> attendeeMemberIds = const [],
  }) async {
    if (recipeId.isEmpty) return false;

    final userId = currentUserId;
    if (userId == null) {
      AppLogger.warning('logCookEvent: no authenticated user, skipping');
      return false;
    }

    try {
      final eventRef = eventsCollectionForUser(userId).doc();
      final event = CookEvent(
        id: eventRef.id,
        userId: userId,
        recipeId: recipeId,
        cookedAt: cookedAt,
        attendeeMemberIds: attendeeMemberIds,
      );

      final canCreate = await validateCreatePermission(userId, event);
      logPermissionCheck(
        userId: userId,
        resource: '$collectionName/${eventRef.id}',
        operation: 'logCookEvent',
        granted: canCreate,
        auditRepository: auditRepository,
      );
      if (!canCreate) return false;

      // One batch: event doc + recipe counter bump. Either both land or
      // neither — the event log and core.cookCount can never drift.
      final batch = firestore.batch();
      batch.set(eventRef, toFirestore(event));
      _recipeRepository.addIncrementCookCountToBatch(
        batch,
        userId,
        recipeId,
        cookedAt,
      );
      await batch.commit();
      _lastLoggedEventId = eventRef.id;

      AppLogger.info('Cook event logged: $recipeId at $cookedAt');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to log cook event for $recipeId: $e', stackTrace);
      return false;
    }
  }

  @override
  Future<bool> updateCookEventDetails(
    String eventId, {
    int? rating,
    String? note,
    String? snapId,
  }) async {
    final userId = currentUserId;
    if (userId == null || eventId.isEmpty) return false;
    if (rating != null && (rating < 1 || rating > 5)) return false;
    // A long note is cut, not refused, so it cannot cost the rating sent with
    // it. The rules count UTF-16 code units, so cut in that unit and never
    // inside a surrogate pair.
    var trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.length > CookEvent.maxNoteLength) {
      var end = CookEvent.maxNoteLength;
      final last = trimmedNote.codeUnitAt(end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) end--;
      trimmedNote = trimmedNote.substring(0, end);
    }

    final fields = <String, dynamic>{
      'rating': ?rating,
      if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
      if (snapId != null && snapId.isNotEmpty) 'snapId': snapId,
    };
    if (fields.isEmpty) return true;

    try {
      await eventsCollectionForUser(userId).doc(eventId).update(fields);
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update cook event $eventId: $e', stackTrace);
      return false;
    }
  }

  @override
  Future<List<CookEvent>> fetchRecent({
    int limit = 30,
    DateTime? before,
  }) async {
    final userId = requireCurrentUserId();
    Query<Map<String, dynamic>> query = eventsCollectionForUser(
      userId,
    ).orderBy('cookedAt', descending: true);
    if (before != null) {
      query = query.startAfter([Timestamp.fromDate(before)]);
    }
    final snapshot = await query.limit(limit).get();
    return snapshot.docs.map(fromFirestore).toList();
  }

  /// Self-only gate shared by every per-user read: audit-logs the check,
  /// then throws unless the signed-in user IS [userId]. Centralized so the
  /// audit row and the exception can never drift apart between methods.
  Future<void> _requireSelf(String userId, String operation) async {
    final requesterId = requireCurrentUserId();
    final granted = requesterId == userId;
    logPermissionCheck(
      userId: requesterId,
      resource: '$collectionName/$userId',
      operation: operation,
      granted: granted,
      auditRepository: auditRepository,
    );
    if (!granted) {
      throw PermissionDeniedException(
        'User $requesterId cannot $operation on cook events of $userId',
        resource: collectionName,
        operation: operation,
        userId: requesterId,
      );
    }
  }

  @override
  Future<List<String>> recentAttendeeMemberIds(
    String userId, {
    int scanLimit = 20,
  }) async {
    await _requireSelf(userId, 'recentAttendeeMemberIds');

    // No server-side "has attendees" filter exists (the field is absent on
    // most events), so scan a small newest-first window and return the first
    // event that recorded attendance. Rides the automatic single-field index
    // on cookedAt — no composite.
    final snapshot = await eventsCollectionForUser(
      userId,
    ).orderBy('cookedAt', descending: true).limit(scanLimit).get();

    for (final doc in snapshot.docs) {
      final event = fromFirestore(doc);
      if (event.attendeeMemberIds.isNotEmpty) {
        return List<String>.from(event.attendeeMemberIds);
      }
    }
    return const <String>[];
  }

  @override
  Future<int> countSince(String userId, DateTime since) async {
    await _requireSelf(userId, 'countSince');

    // Server-side aggregate — counts without downloading documents. The
    // single range constraint rides Firestore's automatic single-field
    // index on cookedAt; no composite index required.
    final snapshot = await eventsCollectionForUser(userId)
        .where('cookedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  @override
  Future<List<Map<String, dynamic>>> exportCookEventsByUser(
    String userId, {
    int? limit,
  }) async {
    // GDPR Article 15/20: caller must be exporting their own events.
    await _requireSelf(userId, 'exportCookEventsByUser');

    // Newest-first so a truncated export keeps the most recent events
    // (deterministic; rides the automatic single-field index).
    Query<Map<String, dynamic>> query = eventsCollectionForUser(
      userId,
    ).orderBy('cookedAt', descending: true);
    if (limit != null) query = query.limit(limit);
    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }
}
