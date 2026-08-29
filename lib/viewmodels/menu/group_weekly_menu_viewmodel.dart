/// ViewModel backing the group weekly menu view (BUT-1971).
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/operations/realtime_group_menu/realtime_group_menu_module.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Why an edit did not happen. Rendered as a passing notice by the widget,
/// which owns the wording — a ViewModel that carries Swedish strings bypasses
/// l10n and shows Swedish in an English build.
/// [undoFailed] is deliberately its own value rather than
/// `saveFailed && canUndoRemoval`: `_edit` sets `saveFailed` before it clears
/// the undo state, so that pair is also true for an unrelated edit whose
/// compute throws — and the retry it earns would put back a dish the user
/// removed earlier instead of redoing what they just tried.
enum GroupMenuEditProblem {
  none,
  notAnEditor,
  saveFailed,
  undoUnavailable,
  undoFailed,
}

/// Why the screen cannot show the week.
///
/// The two are deliberately NOT one nullable string: a refusal and an outage
/// need different screens, and the whole product condition on BUT-1971 is that
/// a refusal must NOT offer a retry button. Collapsing them is how a user gets
/// taught that buttons do nothing.
enum GroupMenuFailure { none, permissionDenied, transient }

class GroupWeeklyMenuViewModel extends BaseViewModel {
  final GroupWeeklyMenuPlanService _service;
  final RealtimeGroupMenuModule _realtime;
  final UserService _userService;
  final String groupId;
  final String currentUserId;

  GroupWeeklyMenuViewModel({
    required GroupWeeklyMenuPlanService service,
    required RealtimeGroupMenuModule realtime,
    required UserService userService,
    required this.groupId,
    required this.currentUserId,
  }) : _service = service,
       _realtime = realtime,
       _userService = userService;

  GroupWeeklyMenuPlan? _plan;
  DateTime _weekStart = IsoWeekUtils.weekStartOf(DateTime.now());
  GroupMenuFailure _failure = GroupMenuFailure.none;
  StreamSubscription<GroupWeeklyMenuPlan?>? _subscription;

  /// An edit that was refused or failed. The view surfaces this as a transient
  /// notice and calls [clearEditNotice].
  GroupMenuEditProblem _editNotice = GroupMenuEditProblem.none;

  /// The dish the last removal took, so the snackbar's "Ångra" can put back
  /// exactly that — never a snapshot of the whole week.
  WeeklyMenuPlanEntry? _undoEntry;

  /// The document the restore would write to.
  String? _undoDocId;

  /// Counts published edits, so a removal can tell whether its own edit was the
  /// last one before it armed the undo.
  int _editSeq = 0;

  GroupWeeklyMenuPlan? get plan => _plan;
  DateTime get weekStart => _weekStart;
  GroupMenuFailure get failure => _failure;
  GroupMenuEditProblem get editNotice => _editNotice;

  /// True when the week loaded and holds nothing. Distinct from a failed read,
  /// which leaves [plan] null with a non-none [failure].
  bool get isEmptyWeek =>
      _failure == GroupMenuFailure.none && (_plan?.entries.isEmpty ?? true);

  bool get canEdit => _plan?.canEdit(currentUserId) ?? false;

  List<GroupMenuParticipant> get participants =>
      _plan?.participants ?? const [];

  final Map<String, String> _displayNames = {};

  /// Ids we have already asked about. A profile that is absent or unreadable
  /// never lands in [_displayNames], so without this the same miss is re-fetched
  /// on every snapshot of a live-synced screen.
  final Set<String> _nameLookupsAttempted = {};

  /// Display name for [userId], or null while it is still being resolved or if
  /// the profile could not be read. The face row falls back to a neutral mark
  /// rather than showing a raw uid.
  String? displayNameFor(String userId) => _displayNames[userId];

  /// Resolve participant names for the face row. Failures are swallowed on
  /// purpose: a name we cannot read must not take the week off the screen.
  Future<void> _resolveNames(GroupWeeklyMenuPlan plan) async {
    final missing = plan.participantUserIds
        .where((id) => !_nameLookupsAttempted.contains(id))
        .toList();
    if (missing.isEmpty) return;
    _nameLookupsAttempted.addAll(missing);
    try {
      final profiles = await _userService.getUserProfiles(missing);
      if (isDisposed) return;
      for (final profile in profiles) {
        _displayNames[profile.uid] = profile.displayName;
      }
      notifyListeners();
    } catch (e) {
      AppLogger.warning('Could not resolve group menu participant names: $e');
    }
  }

  /// Entries for [day] in `MealSlot` declaration order — lunch, middag, övrigt.
  List<WeeklyMenuPlanEntry> entriesFor(DayOfWeek day) {
    final entries = _plan?.entries.where((e) => e.day == day).toList() ?? [];
    entries.sort((a, b) => a.slot.index.compareTo(b.slot.index));
    return entries;
  }

  Future<void> loadWeek(DateTime date) async {
    final requested = IsoWeekUtils.weekStartOf(date);
    _weekStart = requested;
    _failure = GroupMenuFailure.none;
    clearError();
    setLoading(true);

    final read = await _service.readWeek(groupId: groupId, date: requested);

    if (isDisposed) return;
    // Two quick arrow taps can resolve out of order. Without this the older
    // read writes its week's meals under the newer week's header.
    if (_weekStart != requested) return;
    setLoading(false);

    if (read.readFailed) {
      // `readWeek` answers every failure the same way, so the type that would
      // separate a refusal from an outage is already gone by here. The stream
      // below carries the typed error and is what upgrades this to
      // `permissionDenied`.
      _plan = null;
      _failure = GroupMenuFailure.transient;
      notifyListeners();
    } else {
      _plan = read.plan;
      notifyListeners();
      final loaded = read.plan;
      if (loaded != null) unawaited(_resolveNames(loaded));
    }

    _subscribe();
  }

  Future<void> goToPreviousWeek() =>
      loadWeek(_weekStart.subtract(const Duration(days: 7)));

  Future<void> goToNextWeek() =>
      loadWeek(_weekStart.add(const Duration(days: 7)));

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _realtime.subscribe(
      groupId: groupId,
      date: _weekStart,
      onUpdate: (incoming) {
        if (isDisposed) return;
        _plan = incoming;
        _failure = GroupMenuFailure.none;
        notifyListeners();
        if (incoming != null) unawaited(_resolveNames(incoming));
      },
      onError: (error) {
        if (isDisposed) return;
        _failure = _classify(error);
        // A refusal invalidates what is on screen; an outage does not. The
        // transient screen carries a retry, the refusal does not.
        if (_failure == GroupMenuFailure.permissionDenied) _plan = null;
        notifyListeners();
      },
    );
  }

  GroupMenuFailure _classify(Object error) {
    if (error is PermissionDeniedException) {
      return GroupMenuFailure.permissionDenied;
    }
    if (error is FirebaseException && error.code == 'permission-denied') {
      return GroupMenuFailure.permissionDenied;
    }
    return GroupMenuFailure.transient;
  }

  void clearEditNotice() {
    if (_editNotice == GroupMenuEditProblem.none) return;
    _editNotice = GroupMenuEditProblem.none;
    notifyListeners();
  }

  /// Compares the DOCUMENT ID, which is what `save` writes to — not
  /// `weekStartDate`, which only derives it.
  bool get canUndoRemoval =>
      _undoEntry != null &&
      _undoDocId == GroupWeeklyMenuPlan.docIdFor(groupId, _weekStart);

  Future<bool> removeEntry(String entryId) async {
    final before = _plan;
    final forWeek = _weekStart;
    final forDoc = before?.id;
    final seqBefore = _editSeq;
    WeeklyMenuPlanEntry? removed;
    for (final entry in before?.entries ?? const <WeeklyMenuPlanEntry>[]) {
      if (entry.id == entryId) {
        removed = entry;
        break;
      }
    }
    final ok = await _edit(
      (current) => _service.removeEntry(
        plan: current,
        actorId: currentUserId,
        entryId: entryId,
      ),
    );
    // Arm only if this removal is still the newest thing that happened: the
    // week has not changed and no later edit published while we were saving.
    // `isNewest` is false when a later edit published while this save was in
    // flight. Such a straggler must not touch the undo state at all: clearing
    // unconditionally let an old removal wipe a newer, legitimate undo.
    final isNewest = _editSeq == seqBefore + 1;
    final armed = ok && removed != null && _weekStart == forWeek && isNewest;
    if (armed) {
      _undoEntry = removed;
      _undoDocId = forDoc;
    } else if (isNewest || removed == null) {
      // `removed == null` is a tap on a row a snapshot had already taken away.
      // It advances nothing, so without this the PREVIOUS removal's undo stays
      // armed and the snackbar this tap raises would restore a different dish.
      _undoEntry = null;
      _undoDocId = null;
    }
    return ok;
  }

  Future<bool> moveEntry({
    required String entryId,
    required DayOfWeek toDay,
    required MealSlot toSlot,
  }) {
    return _edit(
      (current) => _service.moveEntry(
        plan: current,
        actorId: currentUserId,
        entryId: entryId,
        toDay: toDay,
        toSlot: toSlot,
      ),
    );
  }

  /// Put back the dish the last removal took.
  ///
  /// Refuses when the screen has moved to another week, and when a peer has
  /// meanwhile filled the slot it came from: on a lunch or middag their entry
  /// is the live truth, and appending beside it would break the single-
  /// occupancy rule the service enforces everywhere else.
  Future<bool> undoLastRemoval() async {
    final entry = _undoEntry;
    final forDoc = _undoDocId;
    final forWeek = _weekStart;
    final current = _plan;
    final slotTaken =
        entry != null &&
        !entry.slot.isMulti &&
        (current?.entries.any(
              (e) => e.day == entry.day && e.slot == entry.slot,
            ) ??
            false);

    // `current == null` is a week whose read failed under an armed undo. It
    // reaches `_edit`, which returns false without a notice, so without this
    // arm the dish would be consumed below and lost in silence.
    if (entry == null || current == null || !canUndoRemoval || slotTaken) {
      _editNotice = GroupMenuEditProblem.undoUnavailable;
      notifyListeners();
      return false;
    }

    final seqBefore = _editSeq;
    _undoEntry = null;
    _undoDocId = null;
    final ok = await _edit((plan) {
      if (plan.entries.any((e) => e.id == entry.id)) return plan;
      return plan.copyWith(entries: [...plan.entries, entry]);
    });

    // A refused undo rolls the week back to WITHOUT the dish, so at this point
    // nothing holds it — not `_plan`, not this field, and the snackbar that
    // offered it is gone. Re-arm, but only when nothing newer published and the
    // dish did not arrive by another route meanwhile.
    //
    // `seqBefore` and `seqBefore + 1` are both "nothing newer published": the
    // closure above can return before `_edit` publishes anything, and a
    // computation that never reached the screen must not consume the dish.
    if (!ok &&
        _weekStart == forWeek &&
        (_editSeq == seqBefore || _editSeq == seqBefore + 1) &&
        !(_plan?.entries.any((e) => e.id == entry.id) ?? false)) {
      _undoEntry = entry;
      _undoDocId = forDoc;
      // The only point that knows both halves: the undo's save failed AND the
      // dish is reachable again. A refusal keeps `notAnEditor` — retrying a
      // deterministic denial is the one thing this screen must never offer.
      if (_editNotice == GroupMenuEditProblem.saveFailed) {
        _editNotice = GroupMenuEditProblem.undoFailed;
      }
      notifyListeners();
    }
    return ok;
  }

  /// Compute the edit, put it on screen, then persist.
  Future<bool> _edit(
    GroupWeeklyMenuPlan Function(GroupWeeklyMenuPlan current) mutate,
  ) async {
    if (isDisposed) return false;
    final current = _plan;
    if (current == null) return false;

    final GroupWeeklyMenuPlan updated;
    try {
      updated = mutate(current);
    } on PermissionDeniedException {
      _editNotice = GroupMenuEditProblem.notAnEditor;
      notifyListeners();
      return false;
    } catch (e) {
      AppLogger.error('Group menu edit failed to compute', e);
      _editNotice = GroupMenuEditProblem.saveFailed;
      notifyListeners();
      return false;
    }

    if (identical(updated, current)) return true;

    _undoEntry = null;
    _undoDocId = null;
    _editSeq++;
    // Published before the save is awaited, so a second tap computes from the
    // new base.
    _plan = updated;
    _editNotice = GroupMenuEditProblem.none;
    notifyListeners();

    try {
      await _service.save(plan: updated, actorId: currentUserId);
      return true;
    } catch (e) {
      AppLogger.error('Group menu save failed', e);
      if (isDisposed) return false;
      // Roll back only what is still on screen: another member's snapshot, or
      // a later edit of our own, may have superseded this one while the
      // refusal was in flight.
      if (identical(_plan, updated)) {
        _plan = current;
      }
      _editNotice = e is PermissionDeniedException
          ? GroupMenuEditProblem.notAnEditor
          : GroupMenuEditProblem.saveFailed;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
