// The second delivery: the Art. 12(4) notice re-shown on the sign-in screen
// when the one-shot dialog never reached anyone.
//
// `startCollapsed: true` at the call site is what carries Malin's 2026-09-12
// option (b), and dropping that one argument would reverse a decided privacy
// control with every other suite green. The dialog's two modes are pinned
// elsewhere; what is pinned here is which mode this caller asks for.
//
// The other behaviours witnessed only here, each an edit that would ship
// silently: `clear()` placed AFTER the awaited dialog rather than before it
// (the record must survive a notice torn down unread), the empty-store early
// return, and the arbitration against the live dialog — without which the gate
// stacks a second notice on a working one and counts it as a recovery,
// corrupting the one number that says whether this mechanism is worth keeping.

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

/// A store whose read() claims the run mid-flight, staging the one interleaving
/// the gate's post-read re-check exists for: the gate passes its first check,
/// and the handler claims delivery while the read is still in the air.
class _ClaimsDuringReadStore extends PendingRetentionNoticeStore {
  @override
  Future<PendingRetentionNotice?> read({DateTime? now}) async {
    final notice = await super.read(now: now);
    markDeliveredLive();
    return notice;
  }
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

late PendingRetentionNoticeStore store;
late List<String> loggedEvents;

Future<void> _setUpLocator() async {
  store = PendingRetentionNoticeStore();
  final analytics = _RecordingAnalytics();
  loggedEvents = analytics.events;
  final container = DIContainer();
  await container.reset();
  container.registerModule(_TestModule(store, analytics));
  await container.initialize();
  ServiceLocator.initialize(container);
}

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
    // The call-site half of Malin's option (b). The dialog can collapse; this
    // asserts that this caller asks it to.
    await store.write(holdUntil: _farFuture, provisional: false);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(
      find.text('Ett meddelande om ett raderat konto på den här enheten.'),
      findsOneWidget,
    );
    expect(find.text('Ditt konto är raderat'), findsNothing);
    expect(find.textContaining('granskning'), findsNothing);
  });

  testWidgets('it expands to the full Art. 12(4) notice', (tester) async {
    await store.write(holdUntil: _farFuture, provisional: false);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visa mer'));
    await tester.pumpAndSettle();

    expect(find.text('Ditt konto är raderat'), findsOneWidget);
    expect(find.textContaining('11 mars 2999'), findsOneWidget);
    expect(find.textContaining('IMY'), findsOneWidget);
  });

  testWidgets('the record survives until the notice is actually closed', (
    tester,
  ) async {
    // `clear()` sits after the awaited dialog. Moved above it, a notice torn
    // down unread would never come back — which is the whole reason the record
    // exists.
    await store.write(holdUntil: _farFuture, provisional: false);

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

  testWidgets('a claim that lands DURING the read still wins', (tester) async {
    // Without the re-check after the read, the gate draws a second notice on a
    // working one and logs a recovery for a delivery that happened — the same
    // corruption of the one meaningful counter that the first check prevents,
    // surviving in the window the first check cannot see.
    store = _ClaimsDuringReadStore();
    final container = DIContainer();
    await container.reset();
    container.registerModule(_TestModule(store, _RecordingAnalytics()));
    await container.initialize();
    ServiceLocator.initialize(container);
    loggedEvents =
        (ServiceLocator.get<AnalyticsService>() as _RecordingAnalytics).events;
    await store.write(holdUntil: _farFuture, provisional: false);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(loggedEvents, isEmpty);
  });

  testWidgets('an empty store draws nothing', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(loggedEvents, isEmpty);
  });

  testWidgets('an expired record draws nothing', (tester) async {
    await store.write(
      holdUntil: DateTime.utc(2026, 1, 1),
      provisional: false,
      now: DateTime.utc(2025, 12, 1),
    );

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a recovered notice is counted as recovered, then as closed', (
    tester,
  ) async {
    await store.write(holdUntil: _farFuture, provisional: false);

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
    'the live dialog wins: a claimed run draws nothing and counts nothing',
    (tester) async {
      // The arbiter. The record is still on disk while the live dialog is up —
      // it is cleared only once the person closes it — and the deletion's own
      // sign-out rebuilds this branch, so without the claim the gate would
      // stack a second notice on a working one AND log a recovery on the one
      // run where nothing needed recovering. That would make the number which
      // decides whether this mechanism is worth keeping read near-100%.
      await store.write(
        holdUntil: _farFuture,
        provisional: false,
      );
      store.markDeliveredLive();

      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(loggedEvents, isEmpty);
      expect(
        await store.read(),
        isNotNull,
        reason: 'the live dialog owns clearing it; the gate must not',
      );
    },
  );
}
