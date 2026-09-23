/// BUT-1163: widget tests for [ConflictDiffView] — the conflict-recovery screen.
///
/// This is the only place the user can *recover* from a silent last-write-wins
/// loss: when their version lost, the screen offers "Behåll min version" which
/// re-persists their local snapshot through the permission-checked update path.
/// The banner test (`conflict_banner_test.dart`) stubs navigation away, so the
/// view's own behaviour — keep-bar visibility, the re-apply call, success/error
/// toasts, and the empty-vs-diff body — was entirely untested before this file.
///
/// Intent per block:
///  - keep-bar appears only when the local side LOST (remoteWon), never when it
///    won — showing a "keep mine" button after winning would be nonsense.
///  - tapping keep re-persists the *local* snapshot (not the remote) and pops —
///    the whole point of the feature; a regression here silently keeps the
///    version the user was trying to overwrite.
///  - missing service / failing update surface an error toast and DON'T pop, so
///    the user isn't told "saved" when nothing was.
///  - identical snapshots render the no-changes state; differing fields render
///    both values.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/views/realtime/conflict_diff_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockRealtimeSyncService extends Mock implements RealtimeSyncService {}

/// A resource whose serialized form is fully controllable. We override
/// `toFirestore()` directly (a concrete body) so this is a Fake, not a Mock —
/// per the Mock-vs-Fake rule a `when()` stub on a method with a real body would
/// silently no-op.
class _FakeResource extends Fake implements RealtimeResource {
  _FakeResource(this._map);
  final Map<String, dynamic> _map;

  @override
  Map<String, dynamic> toFirestore() => _map;
}

ConflictEvent _event({
  required ConflictResolutionStrategy strategy,
  Map<String, dynamic>? local,
  Map<String, dynamic>? remote,
  ConflictEntity entity = ConflictEntity.recipeOwn,
}) {
  final localRes = _FakeResource(local ?? {'title': 'Min soppa'});
  final remoteRes = _FakeResource(remote ?? {'title': 'Deras gryta'});
  return ConflictEvent(
    collectionPath: 'recipes',
    docId: 'doc-1',
    localValue: localRes,
    remoteValue: remoteRes,
    chosenStrategy: strategy,
    entity: entity,
    occurredAt: DateTime(2026, 6, 13),
  );
}

void main() {
  late _MockRealtimeSyncService service;

  setUpAll(() {
    registerFallbackValue(_FakeResource(const {}));
  });

  setUp(() async {
    await GetIt.instance.reset();
    service = _MockRealtimeSyncService();
    GetIt.instance.registerSingleton<RealtimeSyncService>(service);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  // Captures live l10n so assertions never hardcode copy that can drift.
  late String keepMine;
  late String noChanges;
  late String localLabel;
  late String remoteLabel;
  late String emptyValue;

  Widget harness(ConflictEvent event) {
    return createLocalizedTestApp(
      wrapInScaffold: false,
      child: Builder(
        builder: (context) {
          keepMine = context.l10n.conflictDiffKeepMine;
          noChanges = context.l10n.conflictDiffNoChanges;
          localLabel = context.l10n.conflictDiffLocalLabel;
          remoteLabel = context.l10n.conflictDiffRemoteLabel;
          emptyValue = context.l10n.conflictDiffEmptyValue;
          return ConflictDiffView(event: event);
        },
      ),
    );
  }

  testWidgets('shows the "keep my version" bar only when the local side lost', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(_event(strategy: ConflictResolutionStrategy.remoteWon)),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, keepMine),
      findsOneWidget,
      reason: 'remoteWon means the user lost — they must be offered recovery',
    );
  });

  testWidgets('hides the keep bar when the local side won', (tester) async {
    await tester.pumpWidget(
      harness(_event(strategy: ConflictResolutionStrategy.localWon)),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, keepMine),
      findsNothing,
      reason: 'localWon means nothing was lost — no recovery button',
    );
  });

  testWidgets(
    'keep re-persists the LOCAL snapshot via updateResource and pops the route',
    (tester) async {
      final event = _event(
        strategy: ConflictResolutionStrategy.remoteWon,
        local: {'title': 'Min version'},
        remote: {'title': 'Deras version'},
      );
      when(
        () => service.recoverLocalVersion<RealtimeResource>(any()),
      ).thenAnswer((_) async {});

      // Push the view as a real route so we can assert it pops on success.
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              keepMine = context.l10n.conflictDiffKeepMine;
              return ElevatedButton(
                onPressed: () => ConflictDiffView.show(context, event),
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, keepMine), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, keepMine));
      await tester.pumpAndSettle();

      final captured =
          verify(
                () =>
                    service.recoverLocalVersion<RealtimeResource>(captureAny()),
              ).captured.single
              as RealtimeResource;
      expect(
        captured.toFirestore()['title'],
        'Min version',
        reason:
            'must re-apply the local value the user was overwriting with, '
            'not the remote one that won',
      );

      // Route popped: the diff view is gone, the launcher button is back.
      expect(find.widgetWithText(FilledButton, keepMine), findsNothing);
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets(
    'shows an error toast and does NOT pop when the service is absent',
    (tester) async {
      // Remove the service so ServiceLocator.tryGet returns null.
      await GetIt.instance.reset();
      prod.ServiceLocator.initialize(DIContainer());

      final event = _event(strategy: ConflictResolutionStrategy.remoteWon);
      late String keepFailed;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              keepMine = context.l10n.conflictDiffKeepMine;
              keepFailed = context.l10n.conflictDiffKeepFailed;
              return ConflictDiffView(event: event);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, keepMine));
      await tester.pumpAndSettle();

      expect(find.text(keepFailed), findsOneWidget);
      // Bar is still present (we didn't pop) and re-enabled for a retry.
      expect(find.widgetWithText(FilledButton, keepMine), findsOneWidget);
    },
  );

  testWidgets(
    'shows an error toast and stays open when updateResource throws',
    (tester) async {
      when(
        () => service.recoverLocalVersion<RealtimeResource>(any()),
      ).thenThrow(
        SyncError(type: SyncErrorType.firestoreError, message: 'boom'),
      );

      final event = _event(strategy: ConflictResolutionStrategy.remoteWon);
      late String keepFailed;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              keepMine = context.l10n.conflictDiffKeepMine;
              keepFailed = context.l10n.conflictDiffKeepFailed;
              return ConflictDiffView(event: event);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, keepMine));
      await tester.pumpAndSettle();

      expect(
        find.text(keepFailed),
        findsOneWidget,
        reason: 'a failed re-apply must not silently look successful',
      );
      // Re-enabled so the user can retry, not stuck on the spinner.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, keepMine))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('renders the no-changes empty state for identical snapshots', (
    tester,
  ) async {
    final event = _event(
      strategy: ConflictResolutionStrategy.localWon,
      local: {'title': 'Soppa'},
      remote: {'title': 'Soppa'},
    );
    await tester.pumpWidget(harness(event));
    await tester.pumpAndSettle();

    expect(find.text(noChanges), findsOneWidget);
  });

  testWidgets('renders both local and remote values for a differing field', (
    tester,
  ) async {
    final event = _event(
      strategy: ConflictResolutionStrategy.remoteWon,
      local: {'title': 'Min titel'},
      remote: {'title': 'Deras titel'},
    );
    await tester.pumpWidget(harness(event));
    await tester.pumpAndSettle();

    expect(find.text(localLabel), findsOneWidget);
    expect(find.text(remoteLabel), findsOneWidget);
    expect(find.text('Min titel'), findsOneWidget);
    expect(find.text('Deras titel'), findsOneWidget);
  });

  testWidgets(
    'shows the empty-value placeholder for a field present on one side only',
    (tester) async {
      final event = _event(
        strategy: ConflictResolutionStrategy.remoteWon,
        local: {'subtitle': ''},
        remote: {'subtitle': 'Vegetarisk'},
      );
      await tester.pumpWidget(harness(event));
      await tester.pumpAndSettle();

      expect(
        find.text(emptyValue),
        findsOneWidget,
        reason:
            'an empty local value must render the (tomt) placeholder, '
            'not a blank box the user can\'t interpret',
      );
      expect(find.text('Vegetarisk'), findsOneWidget);
    },
  );

  // PQ-02 = A (2026-09-23): the choice goes both ways, for the owner's recipe
  // and for someone else's shared recipe alike (produktregler.md:102;
  // Skarmar v12 del 3 #konflikt :1199 draws "Behåll min version" and
  // "Använd Eriks version").
  group('the choice goes both ways (PQ-02 = A)', () {
    late String useTheirs;
    late String usedTheirs;
    late String useTheirsFailed;
    late String useTheirsKept;

    Future<void> openView(WidgetTester tester, ConflictEvent event) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              keepMine = context.l10n.conflictDiffKeepMine;
              useTheirs = context.l10n.conflictDiffUseTheirs;
              usedTheirs = context.l10n.conflictDiffUsedTheirs;
              useTheirsFailed = context.l10n.conflictDiffUseTheirsFailed;
              useTheirsKept = context.l10n.conflictDiffUseTheirsKept;
              return ElevatedButton(
                onPressed: () => ConflictDiffView.show(context, event),
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    final useTheirsKey = find.byKey(const ValueKey('conflictDiff.useTheirs'));
    final keepMineKey = find.byKey(const ValueKey('conflictDiff.keepMine'));

    for (final entity in [
      ConflictEntity.recipeOwn,
      ConflictEntity.recipeShared,
    ]) {
      testWidgets('${entity.name}: my version won -> "Använd deras version" '
          'writes THEIR snapshot back and closes', (tester) async {
        when(
          () => service.recoverLocalVersion<RealtimeResource>(any()),
        ).thenAnswer((_) async {});
        await openView(
          tester,
          _event(
            strategy: ConflictResolutionStrategy.localWon,
            local: {'title': 'Min version'},
            remote: {'title': 'Deras version'},
            entity: entity,
          ),
        );

        expect(useTheirs, 'Använd deras version');
        expect(find.widgetWithText(OutlinedButton, useTheirs), findsOneWidget);
        expect(keepMineKey, findsNothing);

        await tester.tap(useTheirsKey);
        await tester.pumpAndSettle();

        final captured =
            verify(
                  () => service.recoverLocalVersion<RealtimeResource>(
                    captureAny(),
                  ),
                ).captured.single
                as RealtimeResource;
        expect(
          captured.toFirestore()['title'],
          'Deras version',
          reason: 'using theirs must write the remote snapshot, not mine',
        );
        expect(useTheirsKey, findsNothing);
        expect(find.text('open'), findsOneWidget);
        expect(find.text(usedTheirs), findsOneWidget);
      });

      testWidgets('${entity.name}: my version lost -> "Behåll min version" '
          'writes MY snapshot back; no "Använd deras"', (tester) async {
        when(
          () => service.recoverLocalVersion<RealtimeResource>(any()),
        ).thenAnswer((_) async {});
        await openView(
          tester,
          _event(
            strategy: ConflictResolutionStrategy.remoteWon,
            local: {'title': 'Min version'},
            remote: {'title': 'Deras version'},
            entity: entity,
          ),
        );

        expect(useTheirsKey, findsNothing);
        await tester.tap(keepMineKey);
        await tester.pumpAndSettle();

        final captured =
            verify(
                  () => service.recoverLocalVersion<RealtimeResource>(
                    captureAny(),
                  ),
                ).captured.single
                as RealtimeResource;
        expect(captured.toFirestore()['title'], 'Min version');
        expect(find.text('open'), findsOneWidget);
      });
    }

    testWidgets('a failed "Använd deras" stays open and says mine still '
        'applies, with a retry', (tester) async {
      when(
        () => service.recoverLocalVersion<RealtimeResource>(any()),
      ).thenThrow(SyncError(type: SyncErrorType.firestoreError, message: 'x'));
      await openView(
        tester,
        _event(strategy: ConflictResolutionStrategy.localWon),
      );

      await tester.tap(useTheirsKey);
      await tester.pumpAndSettle();

      expect(find.text('$useTheirsFailed $useTheirsKept'), findsOneWidget);
      expect(find.text('Försök igen'), findsOneWidget);
      // Still open and usable again: nothing was lost and nothing claimed.
      expect(
        tester.widget<OutlinedButton>(useTheirsKey).onPressed,
        isNotNull,
      );
    });

    testWidgets('identical snapshots offer no "Använd deras"', (tester) async {
      await openView(
        tester,
        _event(
          strategy: ConflictResolutionStrategy.localWon,
          local: {'title': 'Soppa'},
          remote: {'title': 'Soppa'},
        ),
      );

      expect(useTheirsKey, findsNothing);
    });
  });
}
