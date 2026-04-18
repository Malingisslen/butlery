/// Realtime watcher for [GroupWeeklyMenuPlan] docs.
///
/// Mirrors the collaborative-recipe realtime pattern but scoped to the
/// group-plan collection. Emits updates whenever any editor writes to the
/// shared plan doc so all group members see entry changes live.
///
/// Scope note: this module is content sync ONLY. Presence tracking (who's
/// looking at the plan right now) is intentionally out of scope — adding
/// it would duplicate the collaborative-shopping presence work. Separate
/// ticket if/when we need it.
library;

import 'dart:async';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';

/// Live-sync watcher for a group's weekly menu plan document.
///
/// Thin wrapper over the repository's document-stream so the UI layer
/// doesn't need to know about Firestore types. The caller owns the
/// returned subscription; the module delegates parsing + error handling
/// to the repo and exposes the stream as-is.
class RealtimeGroupMenuModule {
  final GroupWeeklyMenuPlanRepository _repository;

  RealtimeGroupMenuModule({
    required GroupWeeklyMenuPlanRepository repository,
  }) : _repository = repository;

  /// Watch the plan document for [groupId] + the ISO week containing [date].
  ///
  /// Emits `null` when the doc does not exist yet (callers render an empty
  /// plan state) and a parsed `GroupWeeklyMenuPlan` on every subsequent
  /// change. Errors on the underlying snapshot stream are logged in the
  /// repo and forwarded so the caller can surface a retry affordance.
  Stream<GroupWeeklyMenuPlan?> watchPlan({
    required String groupId,
    required DateTime date,
  }) {
    return _repository.watchForWeek(groupId: groupId, date: date);
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
