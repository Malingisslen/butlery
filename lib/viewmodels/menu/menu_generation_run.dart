import 'dart:async';

/// BUT-2157: how a call to `MenuViewModel.generateMenu` ended.
enum MenuGenerationEnd {
  /// The run finished: a menu, a no-match outcome or an error is on screen.
  completed,

  /// "Avbryt planeringen", a newer run or a closed screen ended it first.
  /// Nothing from it reaches the screen, and the week is not written.
  cancelled,

  /// It never started (an empty prompt).
  rejected,
}

/// Thrown inside a generation that was cancelled, so its remaining steps are
/// skipped. Never shown to the user.
class MenuGenerationCancelled implements Exception {
  const MenuGenerationCancelled();

  @override
  String toString() => 'MenuGenerationCancelled';
}

/// One generation or section re-roll, and the screen state to put back if it
/// is cancelled.
class MenuGenerationRun<S> {
  MenuGenerationRun._(this._owner, this.id, this.before);

  final MenuGenerationRuns<S> _owner;
  final int id;

  /// What the screen showed when the run began.
  final S before;

  final Completer<void> _cancelled = Completer<void>();

  /// False once the run was cancelled or a newer one started.
  bool get isCurrent => _owner._current == this;

  /// Passed to the generator so it stops before its next read.
  bool isCancelled() => !isCurrent;

  /// [work]'s result, or [MenuGenerationCancelled] as soon as the run is
  /// cancelled. The generation reads Firestore, and a read already in flight
  /// cannot be stopped; it finishes in the background and its result is
  /// dropped here.
  Future<T> guard<T>(Future<T> work) {
    if (!isCurrent) {
      unawaited(work.then<void>((_) {}, onError: (Object _) {}));
      return Future<T>.error(const MenuGenerationCancelled());
    }
    final result = Completer<T>();
    work.then(
      (value) {
        if (result.isCompleted) return;
        if (isCurrent) {
          result.complete(value);
        } else {
          result.completeError(const MenuGenerationCancelled());
        }
      },
      onError: (Object error, StackTrace stack) {
        if (result.isCompleted) return;
        result.completeError(
          isCurrent ? error : const MenuGenerationCancelled(),
          stack,
        );
      },
    );
    _cancelled.future.then((_) {
      if (!result.isCompleted) {
        result.completeError(const MenuGenerationCancelled());
      }
    });
    return result.future;
  }
}

/// Keeps track of the one run allowed at a time. Starting a run supersedes
/// the previous one; [cancel] ends the current one and hands back the state
/// it began from.
class MenuGenerationRuns<S> {
  MenuGenerationRun<S>? _current;
  int _nextId = 0;

  bool get isRunning => _current != null;

  MenuGenerationRun<S> start(S before) {
    final previous = _current;
    final run = MenuGenerationRun<S>._(this, ++_nextId, before);
    _current = run;
    previous?._cancelled.complete();
    return run;
  }

  /// Ends [run] if it is still the current one. True when it was, so only
  /// that run's caller clears the busy state.
  bool finish(MenuGenerationRun<S> run) {
    if (_current != run) return false;
    _current = null;
    return true;
  }

  /// Cancels the current run and returns the state it began from, or null
  /// when nothing was running.
  S? cancel() {
    final run = _current;
    if (run == null) return null;
    _current = null;
    run._cancelled.complete();
    return run.before;
  }
}
