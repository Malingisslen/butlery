// P4-U19, PQ-04 = B: the top bar's queue counter. Nothing while the queue
// drains by itself; a saffron counter only when something needs the user;
// tapping it opens "Väntar på synk" (produktregler.md:190;
// flows-roles-budget.md:111).

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/sync/sync_queue_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../views/sync/fake_sync_queue_source.dart';

final _sv = AppLocalizationsSv();

QueuedChange _c(String id, {bool needsUser = false}) => QueuedChange(
  kind: QueuedChangeKind.recipe,
  id: id,
  operation: QueuedOperation.update,
  queuedAt: DateTime(2026),
  needsUser: needsUser,
);

class _Pushes extends NavigatorObserver {
  final List<String?> names = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name);
}

Widget _app(PreferredSizeWidget bar, {ThemeData? theme, _Pushes? pushes}) =>
    MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme ?? AppTheme.lightTheme,
      navigatorObservers: [?pushes],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('queue')),
      ),
      home: Scaffold(appBar: bar),
    );

void main() {
  late FakeSyncQueueSource source;

  setUp(() {
    source = FakeSyncQueueSource();
    SyncQueueSource.debugOverride = source;
  });

  tearDown(() => SyncQueueSource.debugOverride = null);

  testWidgets('an empty queue: no counter and no actions row', (tester) async {
    await tester.pumpWidget(_app(const ButleryTopBar.rot(title: 'Hem')));
    await tester.pump();
    expect(find.byKey(SyncQueueIndicator.buttonKey), findsNothing);
    expect(find.byKey(const ValueKey('butleryTopBar.actions')), findsNothing);
  });

  testWidgets('a queue that drains by itself shows nothing', (tester) async {
    source.set([_c('a'), _c('b')]);
    await tester.pumpWidget(_app(const ButleryTopBar.rot(title: 'Hem')));
    await tester.pump();
    expect(find.byKey(SyncQueueIndicator.buttonKey), findsNothing);
  });

  for (final mode in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    testWidgets('${mode.key}: a permanent failure shows the saffron count', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      source.set([_c('a'), _c('b', needsUser: true)]);
      await tester.pumpWidget(
        _app(const ButleryTopBar.rot(title: 'Hem'), theme: mode.value),
      );
      await tester.pump();

      expect(find.byKey(SyncQueueIndicator.buttonKey), findsOneWidget);
      final badge = tester.widget<Badge>(find.byType(Badge));
      // action.primary behind text.onActionPrimary in both modes.
      expect(badge.backgroundColor, const Color(0xFFCE7C1E));
      expect(badge.textColor, const Color(0xFF17251D));
      expect(find.text('1'), findsOneWidget);
      expect(
        find.bySemanticsLabel(_sv.syncQueueIndicatorA11y(1)),
        findsOneWidget,
      );
      handle.dispose();
    });
  }

  testWidgets('the counter comes and goes with the queue', (tester) async {
    await tester.pumpWidget(_app(const ButleryTopBar.rot(title: 'Hem')));
    await tester.pump();
    source.set([_c('b', needsUser: true)]);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(SyncQueueIndicator.buttonKey), findsOneWidget);
    source.set(const []);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(SyncQueueIndicator.buttonKey), findsNothing);
  });

  testWidgets('tapping it opens Väntar på synk', (tester) async {
    final pushes = _Pushes();
    source.set([_c('b', needsUser: true)]);
    await tester.pumpWidget(
      _app(const ButleryTopBar.rot(title: 'Hem'), pushes: pushes),
    );
    await tester.pump();
    pushes.names.clear();
    await tester.tap(find.byKey(SyncQueueIndicator.buttonKey));
    await tester.pumpAndSettle();
    expect(pushes.names, [Routes.syncQueue]);
  });

  testWidgets('it sits before the bar\'s own actions', (tester) async {
    source.set([_c('b', needsUser: true)]);
    await tester.pumpWidget(
      _app(
        const ButleryTopBar.rot(
          title: 'Hem',
          actions: [Icon(Icons.search, key: ValueKey('own'))],
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getCenter(find.byKey(SyncQueueIndicator.buttonKey)).dx,
      lessThan(tester.getCenter(find.byKey(const ValueKey('own'))).dx),
    );
  });

  testWidgets('a subpage bar never shows it', (tester) async {
    source.set([_c('b', needsUser: true)]);
    await tester.pumpWidget(_app(const ButleryTopBar.undersida(title: 'X')));
    await tester.pump();
    expect(find.byKey(SyncQueueIndicator.buttonKey), findsNothing);
  });
}
