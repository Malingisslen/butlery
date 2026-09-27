// P4-U19: "Väntar på synk" (produktregler.md:189-192; Skarmar v12 del 4
// #synkko, light and dark).

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/sync/sync_queue_row.dart';
import 'package:butlery/views/sync/sync_queue_view.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/helpers/base_widget_test.dart';
import 'fake_sync_queue_source.dart';

final _sv = AppLocalizationsSv();
final _now = DateTime(2026, 9, 27, 12);

QueuedChange _change(
  String id, {
  QueuedChangeKind kind = QueuedChangeKind.recipe,
  QueuedOperation op = QueuedOperation.update,
  Duration age = const Duration(minutes: 2),
  String? subject = 'Citronrisotto',
  bool needsUser = false,
  QueuedChangeReason reason = QueuedChangeReason.unknown,
  bool waits = false,
}) => QueuedChange(
  kind: kind,
  id: id,
  operation: op,
  queuedAt: _now.subtract(age),
  subject: subject,
  needsUser: needsUser,
  reason: reason,
  waitsOnEarlier: waits,
);

Widget _app(ThemeData theme, {String? backTo}) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: theme,
  home: SyncQueueView(backTo: backTo),
);

void main() {
  late FakeSyncQueueSource source;
  late FakeOfflineService offline;

  setUpAll(() async => BaseWidgetTest.setupWidget());

  setUp(() async {
    offline = FakeOfflineService();
    await registerOffline(offline);
    source = FakeSyncQueueSource();
    SyncQueueSource.debugOverride = source;
  });

  tearDown(() async {
    SyncQueueSource.debugOverride = null;
    await BaseWidgetTest.teardownWidget();
  });

  Future<void> pump(WidgetTester tester, ThemeData theme) async {
    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(_app(theme, backTo: _sv.moreTitle));
      await tester.pump();
    });
  }

  for (final mode in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    group('${mode.key} mode', () {
      testWidgets('permanent failures first, then the queue, with count, '
          'what and age', (tester) async {
        source.set([
          _change('q1', age: const Duration(minutes: 9)),
          _change(
            'f1',
            needsUser: true,
            reason: QueuedChangeReason.notFound,
            subject: 'Grillmarinad',
          ),
          _change(
            'q2',
            kind: QueuedChangeKind.image,
            op: QueuedOperation.upload,
            age: const Duration(hours: 1, minutes: 30),
            waits: true,
          ),
        ]);
        await pump(tester, mode.value);

        expect(find.text(_sv.syncQueueTitle), findsOneWidget);
        // "antal poster": the total in the bar.
        expect(
          tester.widget<Text>(find.byKey(SyncQueueView.countKey)).data,
          '3',
        );
        final needsYou = find.text(
          _sv.syncQueueNeedsYouHeader(1).toUpperCase(),
        );
        final queued = find.text(_sv.syncQueueQueuedHeader(2).toUpperCase());
        expect(needsYou, findsOneWidget);
        expect(queued, findsOneWidget);
        expect(
          tester.getTopLeft(needsYou).dy,
          lessThan(tester.getTopLeft(queued).dy),
        );
        // "vad de rör" and the cause in words.
        expect(
          find.text(_sv.syncQueueRecipeUpdated('Grillmarinad')),
          findsOneWidget,
        );
        expect(find.text(_sv.syncQueueReasonNotFound), findsOneWidget);
        expect(find.text(_sv.syncQueueImageFor('Citronrisotto')), findsOne);
        expect(find.text(_sv.syncQueueWaitsOnEarlier), findsOneWidget);
        // "ålder" (content-style-guide.md:31-32).
        expect(find.text(_sv.syncQueueAgeMinutes(9)), findsOneWidget);
        expect(find.text(_sv.syncQueueAgeHoursMinutes(1, 30)), findsOneWidget);
      });

      testWidgets('the failure card is edged in text.danger', (tester) async {
        source.set([_change('f1', needsUser: true)]);
        await pump(tester, mode.value);
        final danger = mode.value.colorScheme.error;
        // #9C3B23 light, #DE9078 dark (tokens.json semantic text.danger).
        expect(
          danger,
          mode.key == 'light'
              ? const Color(0xFF9C3B23)
              : const Color(0xFFDE9078),
        );
        final card = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(SyncQueueNeedsYouCard),
                matching: find.byType(Container),
              )
              .first,
        );
        final border = (card.decoration! as BoxDecoration).border! as Border;
        expect(border.top.color, danger);
        expect(
          tester
              .widget<Text>(find.text(_sv.syncQueueReasonUnknown))
              .style!
              .color,
          danger,
        );
      });
    });
  }

  testWidgets('Försök igen and Släng act on that change, by identity', (
    tester,
  ) async {
    final a = _change('a', needsUser: true);
    final b = _change('b', needsUser: true, subject: 'Pannbiffar');
    source.set([a, b]);
    await pump(tester, AppTheme.lightTheme);

    await tester.tap(find.byKey(SyncQueueNeedsYouCard.retryKey(b)));
    await tester.pump();
    await tester.tap(find.byKey(SyncQueueNeedsYouCard.discardKey(a)));
    await tester.pump();

    expect(source.retried, [b]);
    expect(source.discarded, [a]);
  });

  testWidgets('the actions are named after the change they act on', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final a = _change('a', needsUser: true, subject: 'Pannbiffar');
    source.set([a]);
    await pump(tester, AppTheme.lightTheme);
    final what = _sv.syncQueueRecipeUpdated('Pannbiffar');
    expect(find.bySemanticsLabel(_sv.syncQueueRetryA11y(what)), findsOneWidget);
    expect(
      find.bySemanticsLabel(_sv.syncQueueDiscardA11y(what)),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('Försök synka nu sends the queue; offline it is off', (
    tester,
  ) async {
    source.set([_change('q1')]);
    await pump(tester, AppTheme.lightTheme);
    await tester.tap(find.byKey(SyncQueueView.syncNowKey));
    await tester.pump();
    expect(source.syncs, 1);

    source.online = false;
    offline.setOnline(false);
    await pump(tester, AppTheme.lightTheme);
    await tester.pumpWidget(const SizedBox());
    await pump(tester, AppTheme.lightTheme);
    final button = tester.widget<ButtonStyleButton>(
      find.byKey(SyncQueueView.syncNowKey),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('nothing waiting says so, with no count and no button', (
    tester,
  ) async {
    await pump(tester, AppTheme.lightTheme);
    expect(find.byKey(SyncQueueView.emptyKey), findsOneWidget);
    expect(find.text(_sv.syncQueueEmpty), findsOneWidget);
    expect(find.byKey(SyncQueueView.countKey), findsNothing);
    expect(find.byKey(SyncQueueView.syncNowKey), findsNothing);
  });

  testWidgets('the list follows the queue live', (tester) async {
    await pump(tester, AppTheme.lightTheme);
    expect(find.byKey(SyncQueueView.emptyKey), findsOneWidget);
    source.set([_change('q1')]);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(SyncQueueView.emptyKey), findsNothing);
    expect(find.byType(SyncQueueRow), findsOneWidget);
  });

  testWidgets('Back names Mer when opened from Mer', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        home: const SizedBox(),
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => SyncQueueView(backTo: _sv.moreTitle),
          ),
        );
    await tester.pumpAndSettle();
    expect(
      find.byTooltip(_sv.commonBackTo(_sv.moreTitle)),
      findsOneWidget,
    );
    handle.dispose();
  });

  group('age in words (content-style-guide.md:31-35)', () {
    String age(Duration d) => withClock(
      Clock.fixed(_now),
      () => describeQueuedAge(_sv, _change('x', age: d)),
    );

    test('under a minute is "nu"', () {
      expect(age(const Duration(seconds: 20)), 'nu');
    });
    test('minutes', () => expect(age(const Duration(minutes: 14)), '14 min'));
    test('whole hours', () => expect(age(const Duration(hours: 2)), '2 h'));
    test('hours and minutes', () {
      expect(age(const Duration(hours: 1, minutes: 30)), '1 h 30 min');
    });
    test('days', () => expect(age(const Duration(days: 2)), '2 dygn'));
  });

  test('a recipe with no known title is "Ett recept"', () {
    expect(
      describeQueuedChange(
        _sv,
        _change('x', op: QueuedOperation.create, subject: null),
      ),
      _sv.syncQueueRecipeCreated(_sv.syncQueueUnnamedRecipe),
    );
  });
}
