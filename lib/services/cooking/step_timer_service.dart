import 'dart:async';

import 'package:clock/clock.dart';

import 'package:butlery/core/base/base_service.dart';

/// BUT-406: In-memory step timer for cooking mode.
///
/// Single active timer per service instance. Local-only — no Firestore/RTDB.
/// The timer is driven by the wall clock via `package:clock` so tests can
/// advance time with `withClock(FakeClock(...))` + `fakeAsync`.
///
/// Backgrounding: when the app is suspended Dart may pause `Timer.periodic`,
/// but the target end-time is stored as an absolute `DateTime`. On resume
/// the next tick reconciles against `clock.now()`, so short backgroundings
/// don't drift.
class StepTimerService extends BaseService {
  @override
  String get serviceName => 'StepTimerService';

  /// Stream of remaining time. Emits on every tick (1Hz) and on every state
  /// transition (start/pause/resume/reset/expire). Terminates when the
  /// service is disposed.
  Stream<Duration> get remaining => _remainingController.stream;

  /// Whether a timer is currently counting down (not paused, not idle).
  bool get isRunning => _state == _TimerState.running;

  /// Whether a timer exists but is currently paused.
  bool get isPaused => _state == _TimerState.paused;

  /// Current remaining duration. Never negative; zero when expired or idle.
  Duration get currentRemaining => _computeRemaining();

  final StreamController<Duration> _remainingController =
      StreamController<Duration>.broadcast();

  _TimerState _state = _TimerState.idle;

  /// Absolute wall-clock time at which the running timer expires. `null`
  /// when the timer is idle or paused.
  DateTime? _endAt;

  /// Cached remaining while paused. `null` when the timer is running or idle.
  Duration? _pausedRemaining;

  Timer? _ticker;

  /// Last `inSeconds` value we emitted — the ticker fires at sub-second
  /// cadence under `fakeAsync`, so skip emissions that wouldn't change
  /// the `mm:ss` rendering downstream.
  int? _lastEmittedSeconds;

  /// Starts a new countdown of [duration]. Any existing timer is reset
  /// first — callers that want to guard against this should check
  /// [isRunning]/[isPaused] beforehand. Throws [ArgumentError] if
  /// [duration] is not positive.
  void start(Duration duration) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(
        duration,
        'duration',
        'Timer duration must be positive',
      );
    }

    _cancelTicker();
    _endAt = clock.now().add(duration);
    _pausedRemaining = null;
    _state = _TimerState.running;
    _emit(duration);
    _startTicker();
  }

  /// Pauses a running timer. No-op when idle or already paused.
  void pause() {
    if (_state != _TimerState.running) return;
    _pausedRemaining = _computeRemaining();
    _endAt = null;
    _cancelTicker();
    _state = _TimerState.paused;
    _emit(_pausedRemaining ?? Duration.zero);
  }

  /// Resumes a paused timer from the previously captured remaining. No-op
  /// when idle or already running. If the paused remaining is zero, the
  /// timer transitions straight to expired.
  void resume() {
    if (_state != _TimerState.paused) return;
    final remaining = _pausedRemaining ?? Duration.zero;
    if (remaining <= Duration.zero) {
      _expire();
      return;
    }
    _endAt = clock.now().add(remaining);
    _pausedRemaining = null;
    _state = _TimerState.running;
    _emit(remaining);
    _startTicker();
  }

  /// Clears the current timer and emits zero. Safe to call from any state.
  void reset() {
    _cancelTicker();
    _endAt = null;
    _pausedRemaining = null;
    _state = _TimerState.idle;
    _emit(Duration.zero);
  }

  @override
  Future<void> onDispose() async {
    _cancelTicker();
    if (!_remainingController.isClosed) {
      await _remainingController.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = _computeRemaining();
      if (remaining <= Duration.zero) {
        _expire(emitZero: true);
        return;
      }
      // Skip emission if the `mm:ss` rendering wouldn't change — avoids
      // per-tick widget churn under fakeAsync and sub-second ticker drift.
      if (_lastEmittedSeconds == remaining.inSeconds) return;
      _emit(remaining);
    });
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Transitions to expired. Emits zero unless the caller has already
  /// emitted it this tick (only the ticker path does so today — callers
  /// from `resume()` on a paused-to-zero timer still need the emit).
  void _expire({bool emitZero = true}) {
    _cancelTicker();
    _endAt = null;
    _pausedRemaining = null;
    _state = _TimerState.expired;
    if (emitZero) _emit(Duration.zero);
  }

  Duration _computeRemaining() {
    switch (_state) {
      case _TimerState.running:
        final endAt = _endAt;
        if (endAt == null) return Duration.zero;
        final diff = endAt.difference(clock.now());
        return diff.isNegative ? Duration.zero : diff;
      case _TimerState.paused:
        return _pausedRemaining ?? Duration.zero;
      case _TimerState.idle:
      case _TimerState.expired:
        return Duration.zero;
    }
  }

  void _emit(Duration remaining) {
    if (_remainingController.isClosed) return;
    _lastEmittedSeconds = remaining.inSeconds;
    _remainingController.add(remaining);
  }
}

enum _TimerState { idle, running, paused, expired }
