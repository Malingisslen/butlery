/// Intent-Test Sprint Batch 11 — `ApplicationBootstrap` startup orchestrator.
///
/// These tests pin the load-bearing contracts of the app's bootstrap singleton:
/// - Stages execute in **priority order** (a 2-line refactor that swaps the
///   sort comparator must fail these tests).
/// - Non-optional stage failures **propagate as `BootstrapException`** with
///   the original error preserved as `cause`.
/// - Optional stage failures are **swallowed**, so the app can degrade.
/// - `registerStage` after init **throws**, except for hot-restart-style
///   re-registration of an already-known stage type (idempotency).
/// - The `initialized` Future **completes on success** and **completeErrors
///   on failure** — UI splash widgets depend on this.
/// - `reset()` clears every observable bit (`isInitialized`, `isInitializing`,
///   `status['stages_count']`, the in-flight completer).
///
/// `ApplicationBootstrap` and `DIContainer` are both true singletons (private
/// `_internal` constructors). We therefore call `reset()` in both `setUp` and
/// `tearDown` and never assume a fresh instance between tests.
///
/// Bootstrap collaborators avoided: real DI modules (Firebase-heavy) — the
/// static `initialize(...)` path is exercised with **zero modules + fake
/// stages**, which is enough to walk the full code path without booting
/// Firebase. Validation is skipped automatically because no user scope is
/// active (production code path at `_validateInitialization`).
library;

import 'dart:async';

import 'package:butlery/core/bootstrap/application_bootstrap.dart';
import 'package:butlery/core/bootstrap/stages/bootstrap_stage.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Test stage that records the order it was executed in via a shared list.
class _RecordingStage implements BootstrapStage {
  _RecordingStage(
    this.name, {
    required this.priority,
    required this.executionLog,
    this.isOptional = false,
    this.validateResult = true,
    this.executeThrows,
  });

  @override
  final String name;
  @override
  final int priority;
  @override
  final bool isOptional;

  final List<String> executionLog;
  final bool validateResult;
  final Object? executeThrows;
  int executeCount = 0;
  int validateCount = 0;

  @override
  List<Type> get requiredModules => const [];

  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  Future<void> execute() async {
    executeCount++;
    executionLog.add(name);
    if (executeThrows != null) {
      throw executeThrows!;
    }
  }

  @override
  Future<bool> validate() async {
    validateCount++;
    return validateResult;
  }
}

/// A stage with an unrealistically short timeout for timeout-enforcement tests.
class _SlowStage implements BootstrapStage {
  _SlowStage(this.name, {required this.delay, required this.timeout});

  @override
  final String name;
  @override
  final Duration timeout;
  final Duration delay;

  @override
  List<Type> get requiredModules => const [];

  @override
  int get priority => 100;

  @override
  bool get isOptional => false;

  @override
  Future<void> execute() async {
    await Future<void>.delayed(delay);
  }

  @override
  Future<bool> validate() async => true;
}

Future<void> _fullReset() async {
  await ApplicationBootstrap().reset();
  ServiceLocator.reset();
  await GetIt.instance.reset();
}

void main() {
  setUp(() async {
    await _fullReset();
  });

  tearDown(() async {
    await _fullReset();
  });

  group('singleton & initial state', () {
    /// Proves: `ApplicationBootstrap()` is a process-wide singleton — both
    /// calls share state. A future refactor that drops the `_internal`
    /// pattern must update bootstrap callers in the same change.
    test('factory returns the same instance every call', () {
      final a = ApplicationBootstrap();
      final b = ApplicationBootstrap();
      expect(identical(a, b), isTrue);
    });

    /// Proves: after a fresh reset, the bootstrap reports neither initialized
    /// nor in-progress, and the status map mirrors that.
    test('after reset, isInitialized and isInitializing are both false', () {
      final bootstrap = ApplicationBootstrap();
      expect(bootstrap.isInitialized, isFalse);
      expect(bootstrap.isInitializing, isFalse);
      expect(bootstrap.status['initialized'], isFalse);
      expect(bootstrap.status['initializing'], isFalse);
      expect(bootstrap.status['stages_count'], 0);
      expect(bootstrap.status['modules_count'], 0);
    });
  });

  group('registerStage / registerStages', () {
    /// Proves: registerStage records the stage so `status['stages_count']`
    /// increments. If someone refactored `_stages.add(...)` away, this fails.
    test('registerStage adds the stage to the internal list', () {
      final bootstrap = ApplicationBootstrap();
      bootstrap.registerStage(
        _RecordingStage('A', priority: 1, executionLog: []),
      );
      expect(bootstrap.status['stages_count'], 1);

      bootstrap.registerStage(
        _RecordingStage('B', priority: 2, executionLog: []),
      );
      expect(bootstrap.status['stages_count'], 2);
    });

    /// Proves: registerStages walks the list and registers each one (not just
    /// the first or last). A `for` loop with the wrong bound would fail this.
    test('registerStages adds every stage in the list', () {
      final bootstrap = ApplicationBootstrap();
      bootstrap.registerStages([
        _RecordingStage('A', priority: 1, executionLog: []),
        _RecordingStage('B', priority: 2, executionLog: []),
        _RecordingStage('C', priority: 3, executionLog: []),
      ]);
      expect(bootstrap.status['stages_count'], 3);
    });

    /// Proves: once initialization finished, registering a *new* stage type
    /// throws — the registry is closed for change. The error must be
    /// `BootstrapException` with the stage name and operation populated so
    /// crash reports identify the culprit.
    test(
      'registerStage throws after initialization for a new stage type',
      () async {
        final log = <String>[];
        await ApplicationBootstrap.initialize(
          stages: [_RecordingStage('Init', priority: 1, executionLog: log)],
        );
        final bootstrap = ApplicationBootstrap();
        expect(bootstrap.isInitialized, isTrue);

        // _UnknownStage is a runtimeType not seen before, so the idempotency
        // shortcut shouldn't apply.
        expect(
          () => bootstrap.registerStage(
            _SlowStage(
              'Late',
              delay: Duration.zero,
              timeout: const Duration(seconds: 1),
            ),
          ),
          throwsA(
            isA<BootstrapException>()
                .having((e) => e.stage, 'stage', 'Late')
                .having((e) => e.operation, 'operation', 'registration'),
          ),
        );
      },
    );

    /// Proves: hot-restart idempotency — re-registering a stage of a type
    /// already in `_stagesByType` is a silent no-op (does NOT throw, does
    /// NOT double-count). This is load-bearing: hot restart re-runs main(),
    /// which re-registers the same stage instances.
    test(
      'registerStage of a known stage type after init is a silent no-op',
      () async {
        final log = <String>[];
        await ApplicationBootstrap.initialize(
          stages: [_RecordingStage('Init', priority: 1, executionLog: log)],
        );
        final bootstrap = ApplicationBootstrap();
        final countBefore = bootstrap.status['stages_count'] as int;

        // Same runtimeType (_RecordingStage) as the one already registered:
        // production short-circuits before throwing.
        expect(
          () => bootstrap.registerStage(
            _RecordingStage('Init2', priority: 5, executionLog: log),
          ),
          returnsNormally,
        );

        // Critically: must NOT double-count. The whole point of the
        // hot-restart guard is to skip silently.
        expect(bootstrap.status['stages_count'], countBefore);
      },
    );
  });

  group('initialize() — happy path', () {
    /// Proves: a successful initialize flips `isInitialized` to true, clears
    /// `isInitializing`, and records the stage count in `status`. The
    /// passed-in stage must have been executed exactly once.
    test('executes the stage and flips isInitialized to true', () async {
      final log = <String>[];
      final stage = _RecordingStage('Only', priority: 1, executionLog: log);

      await ApplicationBootstrap.initialize(stages: [stage]);

      final bootstrap = ApplicationBootstrap();
      expect(bootstrap.isInitialized, isTrue);
      expect(bootstrap.isInitializing, isFalse);
      expect(stage.executeCount, 1);
      expect(stage.validateCount, 1);
      expect(log, ['Only']);
      expect(bootstrap.status['initialized'], isTrue);
    });

    /// Proves: **stages run in priority order, lowest priority first** — this
    /// is the load-bearing ordering contract. If someone reverses the
    /// `compareTo` direction or removes the sort, this test breaks.
    /// Registration order is deliberately reversed from priority order so a
    /// no-sort implementation would produce `['C','B','A']`.
    test('stages execute in ascending priority order, regardless of '
        'registration order', () async {
      final log = <String>[];
      await ApplicationBootstrap.initialize(
        stages: [
          _RecordingStage('C', priority: 30, executionLog: log),
          _RecordingStage('A', priority: 10, executionLog: log),
          _RecordingStage('B', priority: 20, executionLog: log),
        ],
      );

      expect(
        log,
        ['A', 'B', 'C'],
        reason:
            'Lower priority numbers must execute first. '
            'A bug that drops or reverses the sort would surface here.',
      );
    });

    /// Proves: empty stages list does NOT throw — the bootstrap warns and
    /// returns cleanly. (A naive `_stages.first` would crash here.)
    test('initialize with empty stages completes without throwing', () async {
      await expectLater(
        ApplicationBootstrap.initialize(stages: const []),
        completes,
      );
      expect(ApplicationBootstrap().isInitialized, isTrue);
    });

    /// Proves: the `initialized` Future is the public way to await readiness
    /// from UI code. On successful init it must complete (not hang, not
    /// completeError). This is what `ApplicationReadyBuilder` listens to.
    test('initialized future completes on successful initialization', () async {
      final bootstrap = ApplicationBootstrap();
      final log = <String>[];
      // Subscribe BEFORE initialize so the completer is created at the
      // right time (matches real ApplicationReadyBuilder lifecycle).
      final readyFuture = bootstrap.initialized;

      await ApplicationBootstrap.initialize(
        stages: [_RecordingStage('S', priority: 1, executionLog: log)],
      );

      await expectLater(readyFuture, completes);
    });

    /// Proves: when already initialized, `initialized` returns an immediately
    /// completed future (no completer needed) — a refactor that always
    /// allocates a completer would still pass, but a refactor that forgets
    /// the early-return would hang.
    test(
      'initialized future resolves immediately when already initialized',
      () async {
        await ApplicationBootstrap.initialize(stages: const []);
        // Should NOT hang; should complete in microtask.
        await ApplicationBootstrap().initialized.timeout(
          const Duration(milliseconds: 100),
        );
      },
    );
  });

  group('initialize() — failure paths', () {
    /// Proves: a thrown exception inside a **non-optional** stage is wrapped
    /// in `BootstrapException` with `stage` = the stage name, `operation` =
    /// 'execution', and `cause` preserving the original error. Crashlytics
    /// needs the original cause; a bug that dropped `e` would fail this.
    test(
      'non-optional stage throw is wrapped as BootstrapException with cause',
      () async {
        final original = StateError('disk full');
        final stage = _RecordingStage(
          'Critical',
          priority: 1,
          executionLog: <String>[],
          executeThrows: original,
        );

        await expectLater(
          ApplicationBootstrap.initialize(stages: [stage]),
          throwsA(
            isA<BootstrapException>()
                .having((e) => e.stage, 'stage', 'Critical')
                .having((e) => e.operation, 'operation', 'execution')
                .having((e) => e.cause, 'cause preserved', same(original)),
          ),
        );

        expect(ApplicationBootstrap().isInitialized, isFalse);
        expect(
          ApplicationBootstrap().isInitializing,
          isFalse,
          reason:
              'After a failure the in-progress flag must be cleared, '
              'otherwise the next initialize() call sees a phantom in-progress '
              'state and throws "already in progress".',
        );
      },
    );

    /// Proves: an **optional** stage that throws is logged and skipped — the
    /// bootstrap continues. This is the degraded-mode contract: optional
    /// stages can fail without bringing down the app.
    test('optional stage throw is swallowed; bootstrap finishes', () async {
      final log = <String>[];
      final failing = _RecordingStage(
        'Optional',
        priority: 1,
        executionLog: log,
        isOptional: true,
        executeThrows: StateError('flaky service'),
      );
      final survivor = _RecordingStage(
        'Survivor',
        priority: 2,
        executionLog: log,
      );

      await ApplicationBootstrap.initialize(stages: [failing, survivor]);

      expect(ApplicationBootstrap().isInitialized, isTrue);
      // Survivor must have run; optional failure must not cancel later
      // stages.
      expect(log, contains('Survivor'));
      expect(survivor.executeCount, 1);
    });

    /// Proves: validate()==false on a non-optional stage halts startup. The
    /// production code re-wraps the inner validation throw as an outer
    /// `BootstrapException(operation: 'execution')` with the inner
    /// `BootstrapException(operation: 'validation')` as `cause`. We pin BOTH
    /// layers so a refactor that loses the 'validation' inner — making it
    /// impossible to distinguish a validate-failure from an execute-throw in
    /// Crashlytics — would fail this test.
    test(
      'non-optional stage with failing validate() throws BootstrapException',
      () async {
        final stage = _RecordingStage(
          'BadValidate',
          priority: 1,
          executionLog: <String>[],
          validateResult: false,
        );

        await expectLater(
          ApplicationBootstrap.initialize(stages: [stage]),
          throwsA(
            isA<BootstrapException>()
                .having((e) => e.stage, 'stage', 'BadValidate')
                .having((e) => e.operation, 'operation', 'execution')
                .having(
                  (e) => e.cause,
                  'inner cause is a validation BootstrapException',
                  isA<BootstrapException>().having(
                    (c) => c.operation,
                    'operation',
                    'validation',
                  ),
                ),
          ),
        );
      },
    );

    /// Proves: validate()==false on an OPTIONAL stage is swallowed (no
    /// throw, no later-stage cancellation). Distinct from the throw-path.
    test('optional stage with failing validate() is swallowed', () async {
      final log = <String>[];
      await ApplicationBootstrap.initialize(
        stages: [
          _RecordingStage(
            'Opt',
            priority: 1,
            executionLog: log,
            isOptional: true,
            validateResult: false,
          ),
          _RecordingStage('After', priority: 2, executionLog: log),
        ],
      );

      expect(ApplicationBootstrap().isInitialized, isTrue);
      expect(log, ['Opt', 'After']);
    });

    /// Proves: stage timeout is enforced via `stage.timeout` (not a hardcoded
    /// constant). A stage whose `execute()` exceeds its declared timeout
    /// must surface as `BootstrapException` (which wraps the
    /// `TimeoutException`). This pins BUT-1059-adjacent reliability: long
    /// startup tasks can't silently hang the splash.
    test(
      'stage that exceeds its declared timeout fails initialization',
      () async {
        final slow = _SlowStage(
          'SlowStage',
          delay: const Duration(milliseconds: 200),
          timeout: const Duration(milliseconds: 20),
        );

        await expectLater(
          ApplicationBootstrap.initialize(stages: [slow]),
          throwsA(
            isA<BootstrapException>()
                .having((e) => e.stage, 'stage', 'SlowStage')
                .having((e) => e.operation, 'operation', 'execution')
                .having(
                  (e) => e.cause,
                  'cause is TimeoutException',
                  isA<TimeoutException>(),
                ),
          ),
        );
      },
    );

    /// Proves: when initialization fails, the `initialized` Future
    /// completeErrors so UI splash widgets can react (not hang forever).
    test('initialized future completes with error if init fails', () async {
      final bootstrap = ApplicationBootstrap();
      final readyFuture = bootstrap.initialized;

      // Fire-and-forget the failing initialize; catch the rethrow so the
      // test framework doesn't see an uncaught async error.
      // ignore: unawaited_futures
      ApplicationBootstrap.initialize(
        stages: [
          _RecordingStage(
            'WillFail',
            priority: 1,
            executionLog: <String>[],
            executeThrows: StateError('boom'),
          ),
        ],
      ).catchError((Object _) {});

      await expectLater(readyFuture, throwsA(isA<BootstrapException>()));
    });
  });

  group('reset() and hot-restart semantics', () {
    /// Proves: after a successful init then reset(), every public observable
    /// returns to a virgin state. A reset() that forgets to clear `_stages`
    /// would fail this — and that bug would silently double-execute every
    /// stage on the next init.
    test(
      'reset() clears stages, init flags, and the in-flight completer',
      () async {
        final log = <String>[];
        await ApplicationBootstrap.initialize(
          stages: [_RecordingStage('S', priority: 1, executionLog: log)],
        );
        expect(ApplicationBootstrap().status['stages_count'], 1);

        await ApplicationBootstrap().reset();

        final s = ApplicationBootstrap().status;
        expect(s['stages_count'], 0);
        expect(s['initialized'], isFalse);
        expect(s['initializing'], isFalse);

        // The completer cleared correctly: a fresh `initialized` future
        // must NOT be the already-resolved one from before, and it must
        // not have leaked into a completed state.
        final freshFuture = ApplicationBootstrap().initialized;
        // It should still be pending (no init done yet after reset).
        var resolved = false;
        // ignore: unawaited_futures
        freshFuture
            .then<void>((_) {
              resolved = true;
            })
            .onError((_, __) {
              // Swallow — the future is intentionally never completed in this test.
            });
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          resolved,
          isFalse,
          reason:
              'After reset(), the new initialized future must NOT be '
              'pre-completed (it should track the next init() cycle).',
        );
      },
    );

    /// Proves: hot restart — calling `initialize(...)` again after a
    /// successful init detects the already-initialized state, calls
    /// `reset()`, and re-runs cleanly. The stages from the SECOND call
    /// must be the ones that ran (i.e. reset cleared the first batch).
    test(
      'static initialize() during hot restart re-runs with new stages',
      () async {
        final log1 = <String>[];
        await ApplicationBootstrap.initialize(
          stages: [_RecordingStage('First', priority: 1, executionLog: log1)],
        );

        final log2 = <String>[];
        await ApplicationBootstrap.initialize(
          stages: [_RecordingStage('Second', priority: 1, executionLog: log2)],
        );

        expect(log2, [
          'Second',
        ], reason: 'Hot-restart cycle must re-run with the new stage list.');
        // After reset+re-init there should be exactly one stage registered,
        // not two (otherwise reset() didn't clear).
        expect(ApplicationBootstrap().status['stages_count'], 1);
      },
    );
  });

  group('status map contract', () {
    /// Proves: `status` exposes the documented keys with the documented
    /// runtime types. ApplicationProvider debug widgets read these — a
    /// rename that drops a key would break debug UI silently.
    test('status returns the documented keys with correct types', () async {
      final log = <String>[];
      await ApplicationBootstrap.initialize(
        stages: [_RecordingStage('S', priority: 1, executionLog: log)],
      );

      final s = ApplicationBootstrap().status;
      expect(
        s.keys,
        containsAll(<String>[
          'initialized',
          'initializing',
          'modules_count',
          'stages_count',
          'di_initialized',
        ]),
      );
      expect(s['initialized'], isA<bool>());
      expect(s['initializing'], isA<bool>());
      expect(s['stages_count'], isA<int>());
      expect(s['modules_count'], isA<int>());
      expect(s['di_initialized'], isA<bool>());
    });
  });

  group('ServiceLocator wiring', () {
    /// Proves: `initialize()` wires the ServiceLocator BEFORE running stages.
    /// If a stage's `execute()` calls `ServiceLocator.get<T>()`, it must
    /// already be initialized. A refactor that delayed `ServiceLocator.initialize`
    /// until after stages would break the documented invariant.
    test('ServiceLocator is initialized before any stage executes', () async {
      var locatorWasReadyWhenStageRan = false;
      final probeStage = _RecordingStage(
        'Probe',
        priority: 1,
        executionLog: <String>[],
      );
      // Wrap via a custom stage whose execute() checks the ServiceLocator.
      final checker = _ServiceLocatorChecker(
        onExecute: () {
          locatorWasReadyWhenStageRan = ServiceLocator.isInitialized;
        },
      );

      await ApplicationBootstrap.initialize(stages: [checker, probeStage]);

      expect(
        locatorWasReadyWhenStageRan,
        isTrue,
        reason:
            'Stages must be able to rely on ServiceLocator being '
            'wired before execute() runs.',
      );
    });
  });
}

/// Stage whose only job is to record what the ServiceLocator looked like at
/// execute() time — used for the ordering invariant test.
class _ServiceLocatorChecker implements BootstrapStage {
  _ServiceLocatorChecker({required this.onExecute});

  final void Function() onExecute;

  @override
  String get name => 'LocatorChecker';

  @override
  List<Type> get requiredModules => const [];

  @override
  Duration get timeout => const Duration(seconds: 2);

  @override
  int get priority => 0;

  @override
  bool get isOptional => false;

  @override
  Future<void> execute() async {
    onExecute();
  }

  @override
  Future<bool> validate() async => true;
}
