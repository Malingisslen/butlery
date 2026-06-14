import 'dart:async';

import 'package:clock/clock.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/services/notifications/local_timer_notification_service.dart';

/// Lifecycle state of a single step timer.
enum StepTimerState { idle, running, paused, expired }

/// Immutable snapshot of one labelled timer, surfaced via
/// [StepTimerService.timers]. `remaining` is computed against the wall clock at
/// snapshot time, so consumers re-render from the latest emission rather than
/// recomputing themselves.
class StepTimerEntry {
  const StepTimerEntry({
    required this.id,
    required this.label,
    required this.state,
    required this.remaining,
    required this.total,
  });

  final String id;

  /// Human label (e.g. the parsed step phrase). Empty when the caller didn't
  /// supply one.
  final String label;

  final StepTimerState state;

  /// Remaining time at snapshot. Never negative; zero when expired/idle.
  final Duration remaining;

  /// The duration the timer was started with — lets the UI render progress.
  final Duration total;

  bool get isRunning => state == StepTimerState.running;
  bool get isPaused => state == StepTimerState.paused;
  bool get isExpired => state == StepTimerState.expired;

  @override
  bool operator ==(Object other) =>
      other is StepTimerEntry &&
      other.id == id &&
      other.label == label &&
      other.state == state &&
      other.remaining == remaining &&
      other.total == total;

  @override
  int get hashCode => Object.hash(id, label, state, remaining, total);
}

/// BUT-406 / BUT-1242: In-memory step timers for cooking mode.
///
/// Originally a single active timer (BUT-406); BUT-1242 generalised it to a map
/// of `id -> timer` so several labelled timers can run concurrently (e.g. "koka
/// pasta 10 min" + "stek lök 5 min"), with a [timers] snapshot stream powering a
/// cooking-mode active-timers overview, and an OS-level local notification
/// scheduled per running timer so expiry is alerted even when backgrounded.
///
/// Local-only — no Firestore/RTDB. Timers are driven by the wall clock via
/// `package:clock` so tests advance time with `withClock(Clock(...))` +
/// `fakeAsync`.
///
/// Backgrounding: when the app is suspended Dart pauses `Timer.periodic`, but
/// each timer stores an absolute `DateTime` end-time. On resume the next tick
/// reconciles against `clock.now()`, so short backgroundings don't drift; the
/// scheduled local notification covers longer backgroundings where the periodic
/// tick wouldn't fire in time.
///
/// Backward compatibility: the original single-timer API ([start], [pause],
/// [resume], [reset], [remaining], [isRunning], [isPaused], [currentRemaining])
/// is preserved — it operates on a reserved [defaultTimerId] entry. New callers
/// use the id-keyed variants ([startTimer], [pauseTimer], [resumeTimer],
/// [resetTimer]) and observe [timers].
class StepTimerService extends BaseService {
  StepTimerService({LocalTimerNotificationService? notifications})
      : _notifications = notifications;

  @override
  String get serviceName => 'StepTimerService';

  /// Reserved id for the legacy single-timer API.
  static const String defaultTimerId = '_default';

  final LocalTimerNotificationService? _notifications;

  final Map<String, _Timer> _timers = {};

  final StreamController<Duration> _remainingController =
      StreamController<Duration>.broadcast();
  final StreamController<List<StepTimerEntry>> _timersController =
      StreamController<List<StepTimerEntry>>.broadcast();

  /// Stream of the default timer's remaining time (legacy single-timer API).
  /// Emits on every tick (1Hz) and on every default-timer state transition.
  Stream<Duration> get remaining => _remainingController.stream;

  /// Stream of all timer snapshots, sorted by remaining ascending (soonest to
  /// expire first). Emits whenever any timer ticks or changes state. Idle/expired
  /// default-timer churn from the legacy API is included so the overview stays
  /// consistent.
  Stream<List<StepTimerEntry>> get timers => _timersController.stream;

  /// Current snapshot of all timers (sorted soonest-first).
  List<StepTimerEntry> get currentTimers => _snapshot();

  // ── Legacy single-timer API (operates on [defaultTimerId]) ────────────────

  bool get isRunning =>
      _timers[defaultTimerId]?.state == StepTimerState.running;
  bool get isPaused => _timers[defaultTimerId]?.state == StepTimerState.paused;
  Duration get currentRemaining =>
      _timers[defaultTimerId]?.computeRemaining() ?? Duration.zero;

  void start(Duration duration) =>
      startTimer(id: defaultTimerId, duration: duration);
  void pause() => pauseTimer(defaultTimerId);
  void resume() => resumeTimer(defaultTimerId);
  void reset() => resetTimer(defaultTimerId);

  // ── Per-id accessors (for a widget bound to one timer) ────────────────────

  /// Remaining time for [id] as a stream, derived from the shared snapshot
  /// stream. Emits the entry's current remaining on every change; emits
  /// [Duration.zero] when the timer doesn't exist (idle/reset/expired-removed).
  Stream<Duration> remainingFor(String id) =>
      timers.map((list) => _remainingOf(list, id));

  bool isRunningFor(String id) => _timers[id]?.state == StepTimerState.running;
  bool isPausedFor(String id) => _timers[id]?.state == StepTimerState.paused;
  Duration currentRemainingFor(String id) =>
      _timers[id]?.computeRemaining() ?? Duration.zero;

  Duration _remainingOf(List<StepTimerEntry> list, String id) {
    for (final e in list) {
      if (e.id == id) return e.remaining;
    }
    return Duration.zero;
  }

  // ── Multi-timer API ───────────────────────────────────────────────────────

  /// Starts (or restarts) the timer identified by [id] with [duration].
  /// Throws [ArgumentError] if [duration] is not positive. An existing timer
  /// with the same id is replaced. Schedules a backgrounded-expiry notification.
  void startTimer({
    required String id,
    required Duration duration,
    String label = '',
  }) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(
        duration,
        'duration',
        'Timer duration must be positive',
      );
    }

    final existing = _timers[id];
    existing?.cancelTicker();

    final timer = _Timer(
      id: id,
      label: existing?.label.isNotEmpty == true && label.isEmpty
          ? existing!.label
          : label,
      total: duration,
      endAt: clock.now().add(duration),
      state: StepTimerState.running,
      onTick: () => _onTick(id),
    );
    _timers[id] = timer;
    timer.startTicker();

    _scheduleNotification(timer);
    _emit(id);
  }

  /// Pauses the running timer [id]. No-op when idle/paused/missing. Cancels the
  /// pending notification (a paused timer must not fire a phantom alert).
  void pauseTimer(String id) {
    final timer = _timers[id];
    if (timer == null || timer.state != StepTimerState.running) return;
    timer.pausedRemaining = timer.computeRemaining();
    timer.endAt = null;
    timer.cancelTicker();
    timer.state = StepTimerState.paused;
    _cancelNotification(id);
    _emit(id);
  }

  /// Resumes the paused timer [id] from its captured remaining. No-op when
  /// idle/running/missing. Zero remaining → expires immediately.
  void resumeTimer(String id) {
    final timer = _timers[id];
    if (timer == null || timer.state != StepTimerState.paused) return;
    final remaining = timer.pausedRemaining ?? Duration.zero;
    if (remaining <= Duration.zero) {
      _expire(id);
      return;
    }
    timer.endAt = clock.now().add(remaining);
    timer.pausedRemaining = null;
    timer.state = StepTimerState.running;
    timer.startTicker();
    _scheduleNotification(timer);
    _emit(id);
  }

  /// Clears the timer [id] (back to idle) and cancels any pending notification.
  /// Safe from any state. The default timer stays in the map (idle) so the
  /// legacy `remaining` stream keeps emitting zero; named timers are removed
  /// from the map so they leave the overview.
  void resetTimer(String id) {
    final timer = _timers[id];
    _cancelNotification(id);
    if (id == defaultTimerId) {
      timer?.cancelTicker();
      if (timer != null) {
        timer.endAt = null;
        timer.pausedRemaining = null;
        timer.state = StepTimerState.idle;
      }
      _emit(id);
      return;
    }
    timer?.cancelTicker();
    _timers.remove(id);
    _emitAll();
  }

  @override
  Future<void> onDispose() async {
    for (final t in _timers.values) {
      t.cancelTicker();
    }
    _timers.clear();
    if (!_remainingController.isClosed) await _remainingController.close();
    if (!_timersController.isClosed) await _timersController.close();
  }

  void _onTick(String id) {
    final timer = _timers[id];
    if (timer == null) return;
    final remaining = timer.computeRemaining();
    if (remaining <= Duration.zero) {
      _expire(id);
      return;
    }
    // Skip emission if the mm:ss rendering wouldn't change — avoids per-tick
    // widget churn under fakeAsync and sub-second ticker drift.
    if (timer.lastEmittedSeconds == remaining.inSeconds) return;
    _emit(id);
  }

  void _expire(String id) {
    final timer = _timers[id];
    if (timer == null) return;
    timer.cancelTicker();
    timer.endAt = null;
    timer.pausedRemaining = null;
    timer.state = StepTimerState.expired;
    // The OS notification (if any) has already fired by expiry; cancel defends
    // against the foreground case where the periodic tick beat the schedule.
    _cancelNotification(id);
    _emit(id);
  }

  void _scheduleNotification(_Timer timer) {
    final notifications = _notifications;
    if (notifications == null) return;
    final remaining = timer.computeRemaining();
    if (remaining <= Duration.zero) return;
    // Fire-and-forget: notification scheduling must never block the timer.
    unawaited(notifications.schedule(
      timerId: timer.id,
      duration: remaining,
      label: timer.label.isEmpty ? null : timer.label,
    ));
  }

  void _cancelNotification(String id) {
    final notifications = _notifications;
    if (notifications == null) return;
    unawaited(notifications.cancel(id));
  }

  /// Emits the default-timer remaining (legacy stream) when [id] is the default,
  /// and always re-emits the full snapshot.
  void _emit(String id) {
    final timer = _timers[id];
    if (timer != null) {
      timer.lastEmittedSeconds = timer.computeRemaining().inSeconds;
    }
    if (id == defaultTimerId && !_remainingController.isClosed) {
      _remainingController.add(timer?.computeRemaining() ?? Duration.zero);
    }
    _emitAll();
  }

  void _emitAll() {
    if (_timersController.isClosed) return;
    _timersController.add(_snapshot());
  }

  List<StepTimerEntry> _snapshot() {
    final entries = _timers.values
        .map((t) => StepTimerEntry(
              id: t.id,
              label: t.label,
              state: t.state,
              remaining: t.computeRemaining(),
              total: t.total,
            ))
        .toList()
      ..sort((a, b) => a.remaining.compareTo(b.remaining));
    return entries;
  }
}

/// Mutable per-timer bookkeeping. Private — only [StepTimerService] mutates it;
/// consumers see immutable [StepTimerEntry] snapshots.
class _Timer {
  _Timer({
    required this.id,
    required this.label,
    required this.total,
    required this.endAt,
    required this.state,
    required this.onTick,
  });

  final String id;
  final String label;
  final Duration total;
  final void Function() onTick;

  /// Absolute expiry instant while running; null while paused/idle.
  DateTime? endAt;

  /// Cached remaining while paused; null while running/idle.
  Duration? pausedRemaining;

  StepTimerState state;
  Timer? ticker;
  int? lastEmittedSeconds;

  void startTicker() {
    cancelTicker();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => onTick());
  }

  void cancelTicker() {
    ticker?.cancel();
    ticker = null;
  }

  Duration computeRemaining() {
    switch (state) {
      case StepTimerState.running:
        final e = endAt;
        if (e == null) return Duration.zero;
        final diff = e.difference(clock.now());
        return diff.isNegative ? Duration.zero : diff;
      case StepTimerState.paused:
        return pausedRemaining ?? Duration.zero;
      case StepTimerState.idle:
      case StepTimerState.expired:
        return Duration.zero;
    }
  }
}
