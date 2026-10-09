// PQ-17: the Mer tab (Skarmar v12 del 2 #mer), and "Mer → Väntar på synk"
// (produktregler.md:190). Every row opens its own view, identified by route.
// The queue row is there only while something waits, and carries a saffron
// count only when something needs the user (PQ-04 = B).

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/more/more_view.dart';
import 'package:butlery/widgets/common/sync/sync_queue_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sync/fake_sync_queue_source.dart';

final _sv = AppLocalizationsSv();

class _Pushes extends NavigatorObserver {
  final List<RouteSettings> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings);
  }
}

Widget _app(ThemeData theme, _Pushes pushes) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: theme,
  navigatorObservers: [pushes],
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => const Scaffold(body: Text('pushed')),
  ),
  home: const MoreView(avatar: SizedBox.square(dimension: 40)),
);

/// The drawn rows, in order, with the queue row under App & konto.
final _rows = <String, String>{
  Routes.friends: _sv.socialFriendsAndGroups,
  Routes.messages: _sv.messagingTitle,
  Routes.settingsFamily: _sv.moreFamily,
  Routes.shared: _sv.profileSharedWithMe,
  Routes.settingsPersonalTags: _sv.morePersonalTags,
  Routes.collectionStats: _sv.moreCollectionStats,
  Routes.notifications: _sv.moreNotifications,
  Routes.syncQueue: _sv.syncQueueTitle,
  Routes.settings: _sv.commonSettings,
};

void main() {
  late FakeSyncQueueSource source;

  setUp(() {
    source = FakeSyncQueueSource();
    SyncQueueSource.debugOverride = source;
    // One change draining, so every drawn row, the queue's included, is up.
    source.set([
      QueuedChange(
        kind: QueuedChangeKind.recipe,
        id: 'draining',
        operation: QueuedOperation.update,
        queuedAt: DateTime(2026),
      ),
    ]);
  });

  tearDown(() => SyncQueueSource.debugOverride = null);

  Future<void> tall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final mode in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    testWidgets('${mode.key}: the drawn sections and rows, in order', (
      tester,
    ) async {
      await tall(tester);
      await tester.pumpWidget(_app(mode.value, _Pushes()));
      await tester.pump();

      expect(find.text(_sv.moreTitle), findsOneWidget);
      for (final heading in [
        _sv.moreSectionTogether,
        _sv.moreSectionKitchen,
        _sv.moreSectionAppAccount,
      ]) {
        final text = tester.widget<Text>(find.text(heading.toUpperCase()));
        // text.success: #3F6B4F light, #8FB89A dark (tokens.json semantic).
        expect(
          text.style!.color,
          mode.key == 'light'
              ? const Color(0xFF3F6B4F)
              : const Color(0xFF8FB89A),
        );
      }
      var lastY = -1.0;
      for (final entry in _rows.entries) {
        final row = find.byKey(MoreView.rowKey(entry.key));
        expect(row, findsOneWidget, reason: entry.key);
        expect(
          find.descendant(of: row, matching: find.text(entry.value)),
          findsOneWidget,
        );
        final y = tester.getTopLeft(row).dy;
        expect(y, greaterThan(lastY), reason: entry.key);
        lastY = y;
      }
    });
  }

  for (final entry in _rows.entries) {
    testWidgets('the row "${entry.value}" opens ${entry.key}', (tester) async {
      await tall(tester);
      final pushes = _Pushes();
      await tester.pumpWidget(_app(AppTheme.lightTheme, pushes));
      await tester.pump();
      pushes.pushed.clear();

      await tester.tap(find.byKey(MoreView.rowKey(entry.key)));
      await tester.pumpAndSettle();
      expect(pushes.pushed.map((s) => s.name), [entry.key]);
    });
  }

  testWidgets('the queue view is told that Back leads to Mer', (tester) async {
    await tall(tester);
    final pushes = _Pushes();
    await tester.pumpWidget(_app(AppTheme.lightTheme, pushes));
    await tester.pump();
    pushes.pushed.clear();
    await tester.tap(find.byKey(MoreView.rowKey(Routes.syncQueue)));
    await tester.pumpAndSettle();
    expect(pushes.pushed.single.arguments, _sv.moreTitle);
  });

  testWidgets('no queue row while nothing waits', (tester) async {
    await tall(tester);
    source.set(const []);
    await tester.pumpWidget(_app(AppTheme.lightTheme, _Pushes()));
    await tester.pump();
    expect(find.byKey(MoreView.rowKey(Routes.syncQueue)), findsNothing);
    expect(find.byKey(MoreView.rowKey(Routes.settings)), findsOneWidget);

    source.set([
      QueuedChange(
        kind: QueuedChangeKind.recipe,
        id: 'a',
        operation: QueuedOperation.update,
        queuedAt: DateTime(2026),
      ),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(MoreView.rowKey(Routes.syncQueue)), findsOneWidget);
  });

  testWidgets('each heading is its own node and holds no row', (tester) async {
    await tall(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(AppTheme.lightTheme, _Pushes()));
    await tester.pump();

    final headings = find.semantics
        .byFlag(SemanticsFlag.isHeader)
        .evaluate()
        .toList();
    final labels = headings.map((n) => n.getSemanticsData().label).toList();
    expect(
      labels,
      unorderedEquals([
        _sv.moreTitle,
        _sv.moreSectionTogether.toUpperCase(),
        _sv.moreSectionKitchen.toUpperCase(),
        _sv.moreSectionAppAccount.toUpperCase(),
      ]),
    );
    for (final heading in headings) {
      expect(heading.childrenCount, 0, reason: heading.label);
    }
    handle.dispose();
  });

  testWidgets('the queue row counts only what needs the user', (tester) async {
    await tall(tester);
    source.set([
      QueuedChange(
        kind: QueuedChangeKind.recipe,
        id: 'a',
        operation: QueuedOperation.update,
        queuedAt: DateTime(2026),
      ),
    ]);
    await tester.pumpWidget(_app(AppTheme.lightTheme, _Pushes()));
    await tester.pump();
    // Only draining: nothing (PQ-04 = B).
    expect(find.byType(SaffronCount), findsNothing);

    source.set([
      QueuedChange(
        kind: QueuedChangeKind.recipe,
        id: 'a',
        operation: QueuedOperation.update,
        queuedAt: DateTime(2026),
        needsUser: true,
      ),
      QueuedChange(
        kind: QueuedChangeKind.image,
        id: 'b',
        operation: QueuedOperation.upload,
        queuedAt: DateTime(2026),
        needsUser: true,
      ),
    ]);
    await tester.pump();
    await tester.pump();
    final count = find.descendant(
      of: find.byKey(MoreView.rowKey(Routes.syncQueue)),
      matching: find.byType(SaffronCount),
    );
    expect(count, findsOneWidget);
    expect(find.descendant(of: count, matching: find.text('2')), findsOne);
  });
}
