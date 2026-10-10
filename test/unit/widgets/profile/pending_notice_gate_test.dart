// The Art. 12(4) notice on the signed-out screen.
//
// A notice left by an EARLIER process must open collapsed, and one written by
// THIS process must open expanded. Collapsing is Malin's 2026-09-12 option (b):
// dropping `startCollapsed` at the call site would reverse a decided privacy
// control with every other suite green. The dialog's two modes are pinned
// elsewhere; what is pinned here is which mode this caller asks for, and which
// event it logs.
//
// The write lands after the deletion's own sign-out has put this screen up, so
// the gate has to react to a write that arrives after it is mounted, and to one
// that arrives while its first read is in flight.
//
// The other behaviours witnessed only here, each an edit that would ship
// silently: `clear()` placed AFTER the awaited dialog rather than before it
// (the record must survive a notice torn down unread), and the empty-store
// early return.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/app/auth/pending_notice_gate.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/services/analytics_service.dart';

class _RecordingAnalytics implements AnalyticsService {
  final List<String> events = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add(name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Holds the FIRST read open after it has taken its answer, so a write can land
/// while the gate is mid-attempt. The held read still returns what it saw
/// before the write.
class _GatedReadStore extends PendingRetentionNoticeStore {
  final Completer<void> readEntered = Completer<void>();
  final Completer<void> release = Completer<void>();
  bool _held = false;

  @override
  Future<PendingRetentionNotice?> read({DateTime? now}) async {
    final result = await super.read(now: now);
    if (!_held) {
      _held = true;
      readEntered.complete();
      await release.future;
    }
    return result;
  }
}

class _CountingListenable implements Listenable {
  _CountingListenable(this._inner);

  final Listenable _inner;
  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    _inner.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    _inner.removeListener(listener);
  }
}

class _CountingStore extends PendingRetentionNoticeStore {
  late final _CountingListenable counting = _CountingListenable(super.writes);

  @override
  Listenable get writes => counting;
}

class _TestModule implements DIModule {
  _TestModule(this.store, this.analytics);

  final PendingRetentionNoticeStore store;
  final _RecordingAnalytics analytics;

  @override
  String get name => 'PendingNoticeGateTestModule';

  @override
  List<Type> get dependencies => const [];

  @override
  List<Type> get provides => const [
    PendingRetentionNoticeStore,
    AnalyticsService,
  ];

  @override
  Future<void> configure(GetIt container) async {
    container.registerSingleton<PendingRetentionNoticeStore>(store);
    container.registerSingleton<AnalyticsService>(analytics);
  }

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Far enough out that no case here goes red on a date rather than on a
/// commit. The gate calls read() with no injectable clock, so a near-future
/// literal would be a time bomb (BUT-1905).
final _farFuture = DateTime.utc(2999, 3, 11);

const _collapsedText =
    'Ett meddelande om ett raderat konto på den här enheten.';
const _expandedTitle = 'Ditt konto är raderat';

late PendingRetentionNoticeStore store;
late List<String> loggedEvents;

Future<void> _setUpLocator([PendingRetentionNoticeStore? diStore]) async {
  store = diStore ?? PendingRetentionNoticeStore();
  final analytics = _RecordingAnalytics();
  loggedEvents = analytics.events;
  final container = DIContainer();
  await container.reset();
  container.registerModule(_TestModule(store, analytics));
  await container.initialize();
  ServiceLocator.initialize(container);
}

/// Preferences are shared, so a separate instance is a record left behind by a
/// process that has since exited: the DI store's `writtenInThisProcess` stays
/// false.
Future<void> _writtenByEarlierProcess({
  bool reviewKept = true,
  bool ownReportKept = false,
  DateTime? holdUntil,
  DateTime? now,
}) => PendingRetentionNoticeStore().write(
  holdUntil: holdUntil ?? _farFuture,
  provisional: false,
  reviewKept: reviewKept,
  ownReportKept: ownReportKept,
  now: now,
);

Widget _host() {
  return MaterialApp(
    locale: const Locale('sv'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const PendingNoticeGate(
      child: Scaffold(body: Text('inloggning')),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // The gate's re-entrancy guard is process-wide, and a case that leaves a
    // notice open would silence every case after it.
    PendingNoticeGate.resetForTesting();
    await _setUpLocator();
  });

  tearDown(() => DIContainer().reset());

  testWidgets('an unread notice comes back, and it comes back COLLAPSED', (
    tester,
  ) async {
    await _writtenByEarlierProcess();

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text(_collapsedText), findsOneWidget);
    expect(find.text(_expandedTitle), findsNothing);
    expect(find.textContaining('granskning'), findsNothing);
  });

  testWidgets('it expands to the full Art. 12(4) notice', (tester) async {
    await _writtenByEarlierProcess();

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visa mer'));
    await tester.pumpAndSettle();

    expect(find.text(_expandedTitle), findsOneWidget);
    expect(find.textContaining('11 mars 2999'), findsOneWidget);
    expect(find.textContaining('IMY'), findsOneWidget);
  });

  testWidgets('a kept report the person FILED comes back as that, collapsed', (
    tester,
  ) async {
    await _writtenByEarlierProcess(reviewKept: false, ownReportKept: true);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    // Collapsed first: nothing about a report shows to whoever holds the device.
    expect(find.textContaining('du har gjort'), findsNothing);

    await tester.tap(find.text('Visa mer'));
    await tester.pumpAndSettle();

    expect(find.textContaining('anmälningar du har gjort'), findsOneWidget);
    expect(
      find.textContaining('granskning av innehåll som anmälts'),
      findsNothing,
      reason: 'only a filed report was kept, not a review of their content',
    );
  });

  testWidgets('the record survives until the notice is actually closed', (
    tester,
  ) async {
    // `clear()` sits after the awaited dialog. Moved above it, a notice torn
    // down unread would never come back — which is the whole reason the record
    // exists.
    await _writtenByEarlierProcess();

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(
      await store.read(),
      isNotNull,
      reason: 'still on disk while the notice is up and unread',
    );

    await tester.tap(find.text('Stäng'));
    await tester.pumpAndSettle();

    expect(await store.read(), isNull);
  });

  testWidgets('an empty store draws nothing', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(loggedEvents, isEmpty);
  });

  testWidgets('an expired record draws nothing', (tester) async {
    await _writtenByEarlierProcess(
      holdUntil: DateTime.utc(2026, 1, 1),
      now: DateTime.utc(2025, 12, 1),
    );

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a recovered notice is counted as recovered, then as closed', (
    tester,
  ) async {
    await _writtenByEarlierProcess();

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(loggedEvents, ['retention_notice_recovered']);

    await tester.tap(find.text('Stäng'));
    await tester.pumpAndSettle();

    expect(loggedEvents, [
      'retention_notice_recovered',
      'retention_notice_closed',
    ]);
  });

  testWidgets(
    'a notice written AFTER the gate is mounted opens expanded, shown then closed',
    (tester) async {
      // The BUT-950 path: the deletion's own sign-out has already put this
      // screen up, and the gate has already found the store empty.
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await store.write(holdUntil: _farFuture, provisional: false);
      await tester.pumpAndSettle();

      expect(find.text(_expandedTitle), findsOneWidget);
      expect(find.text(_collapsedText), findsNothing);
      expect(loggedEvents, ['retention_notice_shown']);

      await tester.tap(find.text('Stäng'));
      await tester.pumpAndSettle();

      expect(loggedEvents, [
        'retention_notice_shown',
        'retention_notice_closed',
      ]);
      expect(await store.read(), isNull);
    },
  );

  testWidgets('a notice written BEFORE the gate is mounted opens expanded', (
    tester,
  ) async {
    await store.write(holdUntil: _farFuture, provisional: false);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text(_expandedTitle), findsOneWidget);
    expect(find.text(_collapsedText), findsNothing);
    expect(loggedEvents, ['retention_notice_shown']);
  });

  testWidgets('a write that lands DURING the first read is drawn once', (
    tester,
  ) async {
    final gated = _GatedReadStore();
    await _setUpLocator(gated);

    await tester.pumpWidget(_host());
    await tester.pump();
    expect(
      gated.readEntered.isCompleted,
      isTrue,
      reason: 'premise: the first read has taken its (empty) answer and waits',
    );

    await gated.write(holdUntil: _farFuture, provisional: false);
    gated.release.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(_expandedTitle), findsOneWidget);
    expect(loggedEvents, ['retention_notice_shown']);
  });

  testWidgets(
    'after the gate is gone a write draws nothing and throws nothing',
    (
      tester,
    ) async {
      final counting = _CountingStore();
      await _setUpLocator(counting);

      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      expect(counting.counting.listeners, 1);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(
        counting.counting.listeners,
        0,
        reason: 'a listener left on a process-wide store outlives its gate',
      );

      await counting.write(holdUntil: _farFuture, provisional: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(loggedEvents, isEmpty);
    },
  );
}
