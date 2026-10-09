/// BUT-2157: the kept week draft is offered on the week menu itself, at the
/// top of Lista and Kalender, while the week holds nothing. The draft is
/// seeded the way a previous session left it, in SharedPreferences through
/// WeeklyMenuDraftStore, and the screen finds it on opening.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/menu/weekly_menu_draft.dart';
import 'package:butlery/services/menu/weekly_menu_draft_store.dart';
import 'package:butlery/services/persistence_service.dart';

import 'veckomeny_flow_harness.dart';

const _card = ValueKey('veckomeny-draft-resume-card');
const _restore = ValueKey('veckomeny-draft-restore');
const _discard = ValueKey('veckomeny-draft-discard');

void main() {
  late VeckomenyFlowHarness h;

  Future<void> seedDraft({
    List<String> ids = const ['dinner-1', 'dinner-2', 'dinner-3'],
    String prompt = 'tre middagar',
  }) => WeeklyMenuDraftStore().save(
    flowUserId,
    WeeklyMenuDraft(
      prompt: prompt,
      recipeIdsByMealType: {'Middag': ids},
      requestedByMealType: {'middag': ids.length},
      lastModifiedAt: flowMonday.subtract(const Duration(days: 1)),
      recipeNames: {for (final id in ids) id: 'Sparad $id'},
    ),
  );

  Future<bool> hasDraft() async =>
      (await SharedPreferences.getInstance()).containsKey(
        WeeklyMenuDraftStore.keyFor(flowUserId),
      );

  // The screen reads the clock for the draft's age and expiry on every
  // rebuild, so the whole test runs on Monday morning.
  void viewTest(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(
        name,
        (tester) => withClock(Clock.fixed(flowMonday), () => body(tester)),
      );

  setUp(() async {
    h = VeckomenyFlowHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  Future<void> open(WidgetTester tester) async {
    await h.pump(tester);
    await tester.pumpAndSettle();
  }

  Future<void> tapRestore(WidgetTester tester) async {
    await tester.tap(find.byKey(_restore));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapDiscard(WidgetTester tester) async {
    await tester.tap(find.byKey(_discard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('when the card is offered', () {
    for (final mode in ['lista', 'kalender']) {
      viewTest('an empty week with a kept draft shows it in $mode, named by '
          'its dishes and age', (tester) async {
        await PersistenceService().setVeckomenyViewMode(mode);
        await seedDraft();
        await open(tester);

        expect(find.byKey(_card), findsOneWidget);
        expect(find.text('Påbörjad veckomeny från i går'), findsOneWidget);
        expect(find.text('Sparad dinner-1'), findsOneWidget);
        expect(find.text('Sparad dinner-3'), findsOneWidget);
        expect(find.textContaining('3 av 7 dagar klara'), findsOneWidget);
      });
    }

    viewTest('the card steps aside while the keyboard is up', (tester) async {
      await PersistenceService().setVeckomenyViewMode('lista');
      await seedDraft();
      await open(tester);
      expect(find.byKey(_card), findsOneWidget, reason: 'premise');

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byKey(_card), findsNothing);

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.byKey(_card), findsOneWidget);
    });

    viewTest('on a 320 x 568 phone the card fits above the prompt', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await PersistenceService().setVeckomenyViewMode('lista');
      await seedDraft();
      await open(tester);

      expect(find.byKey(_card), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsWidgets);
    });

    viewTest('no kept draft, no card', (tester) async {
      await open(tester);

      expect(find.byKey(_card), findsNothing);
    });

    viewTest('a week that already has dishes does not offer it', (
      tester,
    ) async {
      await PersistenceService().setVeckomenyViewMode('kalender');
      h.seedWeek(2);
      await seedDraft();
      await open(tester);

      expect(find.textContaining('2 rätter'), findsOneWidget);
      expect(find.byKey(_card), findsNothing);
    });

    viewTest('a generation in progress hides it, and the generated menu '
        'keeps it hidden', (tester) async {
      await PersistenceService().setVeckomenyViewMode('lista');
      await seedDraft();
      h.menu
        ..next = {
          'Middag': [flowDinner(4), flowDinner(5)],
        }
        ..hold = Completer<void>();
      await open(tester);
      expect(find.byKey(_card), findsOneWidget, reason: 'premise');

      await h.generate(tester, 'två middagar');
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.menu.generations, 1, reason: 'the run reached the service');
      expect(find.byKey(_card), findsNothing);

      h.menu.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Middag 4'), findsOneWidget);
      expect(find.byKey(_card), findsNothing);
    });

    viewTest('a discard undone after a menu appeared does not put the card '
        'over that menu', (tester) async {
      await PersistenceService().setVeckomenyViewMode('lista');
      await seedDraft();
      h.menu.next = {
        'Middag': [flowDinner(4)],
      };
      await open(tester);

      await tapDiscard(tester);
      await h.generate(tester, 'en middag');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Middag 4'), findsOneWidget, reason: 'a menu shows');
      expect(
        find.text('Ångra'),
        findsOneWidget,
        reason: 'the undo window is still open',
      );

      await tester.tap(find.text('Ångra'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Middag 4'), findsOneWidget);
      expect(find.byKey(_card), findsNothing);
    });
  });

  group('Återställ', () {
    viewTest('puts the dishes and the prompt back in Lista and says how many '
        'were dropped', (tester) async {
      await PersistenceService().setVeckomenyViewMode('kalender');
      await seedDraft(ids: ['dinner-1', 'dinner-2', 'borttagen-9']);
      await open(tester);
      expect(find.byKey(_card), findsOneWidget, reason: 'premise');

      await tapRestore(tester);

      expect(find.byKey(_card), findsNothing);
      expect(find.text('Middag 1'), findsOneWidget);
      expect(find.text('Middag 2'), findsOneWidget);
      expect(
        find.text('1 rätt passar inte längre och togs bort'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'tre middagar',
      );
      expect(
        await PersistenceService().getVeckomenyViewMode(),
        'lista',
        reason: 'the restore moves the screen from Kalender to Lista',
      );
    });

    viewTest('a draft whose dishes all still exist says nothing about '
        'dropped dishes', (tester) async {
      await seedDraft(ids: ['dinner-1', 'dinner-2']);
      await open(tester);

      await tapRestore(tester);

      expect(find.text('Middag 1'), findsOneWidget);
      expect(find.textContaining('togs bort'), findsNothing);
    });

    viewTest('a restore that cannot be done says so, keeps the draft and '
        'keeps the card', (tester) async {
      await h.tearDown();
      h = VeckomenyFlowHarness();
      await h.setUp(library: const []);
      await seedDraft();
      await open(tester);

      await tapRestore(tester);

      expect(
        find.text('Veckomenyn kunde inte återställas. Utkastet finns kvar.'),
        findsOneWidget,
      );
      expect(find.byKey(_card), findsOneWidget);
      expect(await hasDraft(), isTrue);
      expect(
        tester.widget<TextButton>(find.byKey(_discard)).onPressed,
        isNotNull,
        reason: 'the card is out of its busy state and can be tried again',
      );
    });
  });

  group('Släng', () {
    viewTest('hides the card and offers Ångra; letting the window pass '
        'deletes the draft', (tester) async {
      await seedDraft();
      await open(tester);

      await tapDiscard(tester);

      expect(find.byKey(_card), findsNothing);
      expect(find.text('Utkastet slängdes'), findsOneWidget);
      expect(find.text('Ångra'), findsOneWidget);
      expect(await hasDraft(), isTrue, reason: 'not deleted before the window');

      await tester.pump(const Duration(seconds: 8));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Utkastet slängdes'), findsNothing);
      expect(await hasDraft(), isFalse);
      expect(find.byKey(_card), findsNothing);
    });

    viewTest('Ångra brings the card back and the draft is kept', (
      tester,
    ) async {
      await seedDraft();
      await open(tester);

      await tapDiscard(tester);
      expect(find.byKey(_card), findsNothing, reason: 'premise');

      await tester.tap(find.text('Ångra'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(_card), findsOneWidget);
      expect(find.text('Sparad dinner-1'), findsOneWidget);

      await tester.pump(const Duration(seconds: 8));
      expect(await hasDraft(), isTrue);
    });
  });
}
