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
    // Class 1 (produktregler.md:132): gone from the list at once, thrown
    // away only when the 7 s Ångra window closes.
    expect(find.byKey(SyncQueueNeedsYouCard.discardKey(a)), findsNothing);
    expect(find.text(_sv.syncQueueDiscarded), findsOneWidget);
    expect(source.discarded, isEmpty);

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(source.discarded, [a]);
  });

  testWidgets('Ångra within the window keeps the change', (tester) async {
    final a = _change('a', needsUser: true);
    source.set([a]);
    await pump(tester, AppTheme.lightTheme);

    await tester.tap(find.byKey(SyncQueueNeedsYouCard.discardKey(a)));
    await tester.pump();
    expect(find.byKey(SyncQueueNeedsYouCard.discardKey(a)), findsNothing);

    await tester.pumpAndSettle();
    await tester.tap(find.text(_sv.commonUndo));
    await tester.pumpAndSettle();
    expect(find.byKey(SyncQueueNeedsYouCard.discardKey(a)), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(source.discarded, isEmpty);
  });

  testWidgets('a failed action says so and keeps the change', (tester) async {
    final a = _change('a', needsUser: true);
    source
      ..set([a])
      ..failWith = StateError('database closed');
    await pump(tester, AppTheme.lightTheme);

    await tester.tap(find.byKey(SyncQueueNeedsYouCard.retryKey(a)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining(_sv.syncQueueRetryFailed),
      findsOneWidget,
    );
    expect(find.textContaining(_sv.syncQueueChangeKept), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(SyncQueueNeedsYouCard.discardKey(a)));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The discard failed: the card is back and the cause is shown.
    expect(find.byKey(SyncQueueNeedsYouCard.discardKey(a)), findsOneWidget);
    expect(
      find.textContaining(_sv.syncQueueDiscardFailed),
      findsOneWidget,
    );
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

  // ── P6-U08b ────────────────────────────────────────────────────────────

  group('nästa försök (#synkko; produktregler.md:188)', () {
    for (final mode in {
      'light': AppTheme.lightTheme,
      'dark': AppTheme.darkTheme,
    }.entries) {
      testWidgets('${mode.key}: a failed change says when it is sent again, '
          'counting down, in text.secondary', (tester) async {
        final now = clock.now();
        source.set([
          QueuedChange(
            kind: QueuedChangeKind.recipe,
            id: 'q1',
            operation: QueuedOperation.update,
            queuedAt: now.subtract(const Duration(minutes: 2)),
            subject: 'Citronrisotto',
            nextAttemptAt: now.add(const Duration(seconds: 8)),
          ),
        ]);
        await tester.pumpWidget(_app(mode.value));
        await tester.pump();

        final line = find.text(_sv.syncQueueNextAttemptSeconds(8));
        expect(line, findsOneWidget);
        // text.secondary: #627061 light, #93A48D dark (tokens.json semantic).
        // Interpretation: #synkko's slot for this line is #627061 light but
        // #C9D3C4 dark (Skarmar v12 del 4:64); the token decides the dark
        // value.
        expect(
          tester.widget<Text>(line).style!.color,
          mode.value.colorScheme.onSurfaceVariant,
        );
        expect(
          mode.value.colorScheme.onSurfaceVariant,
          mode.key == 'light'
              ? const Color(0xFF627061)
              : const Color(0xFF93A48D),
        );

        await tester.pump(const Duration(seconds: 1));
        expect(find.text(_sv.syncQueueNextAttemptSeconds(7)), findsOneWidget);

        await tester.pump(const Duration(seconds: 8));
        expect(
          find.textContaining('nästa försök'),
          findsNothing,
          reason: 'the time has come; the line goes',
        );
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('a minute or more is written in minutes', (tester) async {
      final now = clock.now();
      source.set([
        QueuedChange(
          kind: QueuedChangeKind.recipe,
          id: 'q1',
          operation: QueuedOperation.update,
          queuedAt: now,
          nextAttemptAt: now.add(const Duration(minutes: 9, seconds: 30)),
        ),
      ]);
      await tester.pumpWidget(_app(AppTheme.lightTheme));
      await tester.pump();
      expect(find.text(_sv.syncQueueNextAttemptMinutes(10)), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('offline the line is still shown, as #synkko draws it under '
        'the offline banner (Skarmar v12 del 4:245, :271)', (tester) async {
      final now = clock.now();
      source
        ..online = false
        ..set([
          QueuedChange(
            kind: QueuedChangeKind.recipe,
            id: 'q1',
            operation: QueuedOperation.update,
            queuedAt: now,
            nextAttemptAt: now.add(const Duration(seconds: 8)),
          ),
        ]);
      await tester.pumpWidget(_app(AppTheme.lightTheme));
      await tester.pump();
      expect(find.text(_sv.syncQueueNextAttemptSeconds(8)), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the actions of a failure (produktregler.md:188; #synkko)', () {
    testWidgets('a changed recipe: Försök igen, Spara som kopia, Släng', (
      tester,
    ) async {
      final c = _change(
        'u',
        needsUser: true,
        reason: QueuedChangeReason.notFound,
      );
      source.set([c]);
      await pump(tester, AppTheme.lightTheme);
      expect(find.byKey(SyncQueueNeedsYouCard.retryKey(c)), findsOneWidget);
      expect(find.byKey(SyncQueueNeedsYouCard.copyKey(c)), findsOneWidget);
      expect(find.byKey(SyncQueueNeedsYouCard.discardKey(c)), findsOneWidget);
      expect(find.byKey(SyncQueueNeedsYouCard.smallerKey(c)), findsNothing);
    });

    testWidgets('a new recipe the server never had: Försök igen, Spara som '
        'kopia and Släng (Q6-11 = B)', (tester) async {
      final c = _change(
        'n',
        op: QueuedOperation.create,
        needsUser: true,
        reason: QueuedChangeReason.permissionDenied,
      );
      source.set([c]);
      await pump(tester, AppTheme.lightTheme);
      expect(find.byKey(SyncQueueNeedsYouCard.retryKey(c)), findsOneWidget);
      expect(find.byKey(SyncQueueNeedsYouCard.copyKey(c)), findsOneWidget);
      expect(find.byKey(SyncQueueNeedsYouCard.discardKey(c)), findsOneWidget);
    });

    // Q6-11 = B (produktbeslut 2026-09-27b): the recipe exists only on this
    // phone, so Släng first says so; confirmed, it is class 1 like every
    // Släng (produktregler.md:132, 7 s Ångra).
    testWidgets('Släng on a phone-only recipe asks first, and Avbryt keeps '
        'it', (tester) async {
      final c = _change(
        'n',
        op: QueuedOperation.create,
        needsUser: true,
        subject: 'Mormors kålpudding',
      );
      source.set([c]);
      await pump(tester, AppTheme.lightTheme);

      await tester.tap(find.byKey(SyncQueueNeedsYouCard.discardKey(c)));
      await tester.pumpAndSettle();
      expect(find.text(_sv.syncQueueDiscardPhoneOnlyTitle), findsOneWidget);
      expect(
        find.text(_sv.syncQueueDiscardPhoneOnlyBody('Mormors kålpudding')),
        findsOneWidget,
      );

      await tester.tap(find.text(_sv.commonCancel));
      await tester.pumpAndSettle();
      expect(find.byKey(SyncQueueNeedsYouCard.discardKey(c)), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(source.discarded, isEmpty);
    });

    testWidgets('confirmed, the phone-only recipe goes with 7 s Ångra', (
      tester,
    ) async {
      final c = _change('n', op: QueuedOperation.create, needsUser: true);
      source.set([c]);
      await pump(tester, AppTheme.lightTheme);

      await tester.tap(find.byKey(SyncQueueNeedsYouCard.discardKey(c)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.syncQueueDiscardPhoneOnlyConfirm));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(SyncQueueNeedsYouCard.discardKey(c)), findsNothing);
      expect(find.text(_sv.syncQueueRecipeDiscarded), findsOneWidget);
      expect(source.discarded, isEmpty, reason: 'Ångra is still open');

      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(source.discarded, [c]);
    });

    testWidgets('a changed recipe is discarded without asking', (
      tester,
    ) async {
      final c = _change('u', needsUser: true);
      source.set([c]);
      await pump(tester, AppTheme.lightTheme);
      await tester.tap(find.byKey(SyncQueueNeedsYouCard.discardKey(c)));
      await tester.pump();
      expect(find.text(_sv.syncQueueDiscardPhoneOnlyTitle), findsNothing);
      expect(find.text(_sv.syncQueueDiscarded), findsOneWidget);
    });

    testWidgets('a too-large image: Försök mindre and Släng, as drawn', (
      tester,
    ) async {
      final c = _change(
        'i',
        kind: QueuedChangeKind.image,
        op: QueuedOperation.upload,
        needsUser: true,
        reason: QueuedChangeReason.tooLarge,
      );
      source.set([c]);
      await pump(tester, AppTheme.lightTheme);
      expect(find.byKey(SyncQueueNeedsYouCard.smallerKey(c)), findsOneWidget);
      expect(find.byKey(SyncQueueNeedsYouCard.discardKey(c)), findsOneWidget);
      expect(find.byKey(SyncQueueNeedsYouCard.retryKey(c)), findsNothing);
      expect(find.byKey(SyncQueueNeedsYouCard.copyKey(c)), findsNothing);
      expect(find.text(_sv.syncQueueTrySmaller), findsOneWidget);
    });

    testWidgets('a deleted recipe has nothing to copy', (tester) async {
      final c = _change(
        'd',
        op: QueuedOperation.delete,
        needsUser: true,
        reason: QueuedChangeReason.permissionDenied,
      );
      source.set([c]);
      await pump(tester, AppTheme.lightTheme);
      expect(find.byKey(SyncQueueNeedsYouCard.copyKey(c)), findsNothing);
      expect(find.byKey(SyncQueueNeedsYouCard.discardKey(c)), findsOneWidget);
    });

    testWidgets('24 h of failures says so in words', (tester) async {
      source.set([
        _change(
          'x',
          needsUser: true,
          reason: QueuedChangeReason.retriesExhausted,
        ),
      ]);
      await pump(tester, AppTheme.lightTheme);
      expect(find.text(_sv.syncQueueReasonExpired), findsOneWidget);
    });

    testWidgets('Spara som kopia and Försök mindre act on that change, by '
        'identity', (tester) async {
      final b = _change('b', needsUser: true, subject: 'Pannbiffar');
      final img = _change(
        'i',
        kind: QueuedChangeKind.image,
        op: QueuedOperation.upload,
        needsUser: true,
        reason: QueuedChangeReason.tooLarge,
        // Oldest, so its card comes first and is built.
        age: const Duration(hours: 1),
      );
      source.set([b, img]);
      await pump(tester, AppTheme.lightTheme);

      await tester.tap(find.byKey(SyncQueueNeedsYouCard.copyKey(b)));
      await tester.pump();
      await tester.tap(find.byKey(SyncQueueNeedsYouCard.smallerKey(img)));
      await tester.pump();

      expect(source.copied, [b]);
      expect(source.shrunk, [img]);
      // Q6-14 = C: the copy's title says it is the copy.
      expect(source.copyTitleOfCitronrisotto, 'Citronrisotto (kopia)');
    });

    testWidgets('a failed copy says so and keeps the change', (tester) async {
      final a = _change('a', needsUser: true);
      source
        ..set([a])
        ..failWith = StateError('no device copy');
      await pump(tester, AppTheme.lightTheme);

      await tester.tap(find.byKey(SyncQueueNeedsYouCard.copyKey(a)));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining(_sv.syncQueueCopyFailed), findsOneWidget);
      expect(find.textContaining(_sv.syncQueueChangeKept), findsOneWidget);
      expect(find.byKey(SyncQueueNeedsYouCard.copyKey(a)), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('the new actions are named after the change', (tester) async {
      final handle = tester.ensureSemantics();
      final a = _change('a', needsUser: true, subject: 'Pannbiffar');
      final img = _change(
        'i',
        kind: QueuedChangeKind.image,
        op: QueuedOperation.upload,
        subject: 'Sommarens grillmarinad',
        needsUser: true,
        reason: QueuedChangeReason.tooLarge,
      );
      source.set([a, img]);
      await pump(tester, AppTheme.lightTheme);
      expect(
        find.bySemanticsLabel(
          _sv.syncQueueSaveAsCopyA11y(_sv.syncQueueRecipeUpdated('Pannbiffar')),
        ),
        findsOneWidget,
      );
      // #synkko data-a11y-name "Försök mindre — Bild till Sommarens
      // grillmarinad".
      expect(
        find.bySemanticsLabel(
          'Försök mindre — Bild till Sommarens grillmarinad',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
