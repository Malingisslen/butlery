/// Realtime watcher for [GroupWeeklyMenuPlan] docs (BUT-405 / BUT-211 pattern).
///
/// Mirrors [RealtimeWatchingModule] but scoped to the group-plan collection.
/// Emits updates whenever any editor writes to the shared plan doc so all
/// group members see entry changes live — same mental model as the
/// collaborative recipe editing from BUT-211.
///
/// Scope note: B3 is content sync ONLY. Presence tracking (who's looking
/// at the plan right now) is intentionally out of scope — adding it would
/// duplicate the shopping-presence work from BUT-238 and push this past
/// the sprint boundary. Separate ticket if/when we need it.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';

/// Live-sync watcher for a group's weekly menu plan document.
///
/// This is a thin wrapper over `DocumentReference.snapshots()` so the UI
/// layer doesn't need to know about Firestore types. The module owns
/// subscription lifecycle and parses snapshots into `GroupWeeklyMenuPlan`
/// instances (tolerating missing docs by emitting null).
class RealtimeGroupMenuModule {
  final FirebaseFirestore _firestore;

  RealtimeGroupMenuModule({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Watch the plan document for [groupId] + the ISO week containing [date].
  ///
  /// Emits `null` when the doc does not exist yet (callers render an empty
  /// plan state) and a parsed `GroupWeeklyMenuPlan` on every subsequent
  /// change. Errors on the underlying snapshot stream are logged and
  /// forwarded so the caller can surface a retry affordance.
  Stream<GroupWeeklyMenuPlan?> watchPlan({
    required String groupId,
    required DateTime date,
  }) {
    final docId = GroupWeeklyMenuPlan.docIdFor(groupId, date);
    final docRef = _firestore
        .collection(FirestoreCollections.groupWeeklyMenuPlans)
        .doc(docId);

    return docRef.snapshots().map<GroupWeeklyMenuPlan?>((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      try {
        return GroupWeeklyMenuPlan.fromMap(snapshot.id, data);
      } catch (e) {
        AppLogger.warning('Failed to parse group menu plan ${snapshot.id}: $e');
        return null;
      }
    }).handleError((Object error) {
      AppLogger.error(
          'Realtime group menu plan stream error ($groupId / $docId)', error);
      throw error;
    });
  }

  /// Subscribe with a callback-style API for UI layers that don't want to
  /// manage a stream directly. Returns the subscription so the caller can
  /// cancel when the view is disposed.
  StreamSubscription<GroupWeeklyMenuPlan?> subscribe({
    required String groupId,
    required DateTime date,
    required void Function(GroupWeeklyMenuPlan?) onUpdate,
    void Function(Object)? onError,
  }) {
    return watchPlan(groupId: groupId, date: date).listen(
      onUpdate,
      onError: onError ??
          (error) {
            AppLogger.error(
                'Group menu plan subscription error ($groupId)', error);
          },
    );
  }
}
