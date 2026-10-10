/// BUT-2157: the kept week draft, offered as a card above an empty week. The
/// draft was never placed, so it has no days; the card lays the longest meal
/// type's dishes over Mån–Sön in draft order and says how many days that
/// fills and how long the draft is still kept.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/weekly_menu_draft.dart';
import 'package:butlery/widgets/menu/veckomeny_draft_resume_card.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

final _now = DateTime(2026, 10, 9, 9);
final _yesterdayEvening = DateTime(2026, 10, 8, 20);

const _dinners = [
  'Köttbullar',
  'Fiskgratäng',
  'Ärtsoppa',
  'Pannkakor',
  'Lasagne',
];

WeeklyMenuDraft _draft({
  Map<String, List<String>>? meals,
  Map<String, String>? names,
  DateTime? at,
}) {
  final byMealType =
      meals ??
      {
        'Middag': [for (var i = 0; i < _dinners.length; i++) 'd$i'],
      };
  return WeeklyMenuDraft(
    prompt: 'middagar',
    recipeIdsByMealType: byMealType,
    requestedByMealType: const {},
    lastModifiedAt: at ?? _yesterdayEvening,
    recipeNames:
        names ??
        {
          for (var i = 0; i < _dinners.length; i++) 'd$i': _dinners[i],
        },
  );
}

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    WeeklyMenuDraft draft, {
    VoidCallback? onRestore,
    VoidCallback? onDiscard,
    bool restoring = false,
    double? width,
    double textScale = 1.0,
  }) async {
    await withClock(Clock.fixed(_now), () async {
      Widget card = VeckomenyDraftResumeCard(
        draft: draft,
        now: _now,
        onRestore: onRestore ?? () {},
        onDiscard: onDiscard ?? () {},
        restoring: restoring,
      );
      if (width != null) {
        card = Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: card),
        );
      }
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: SingleChildScrollView(child: card),
            ),
          ),
        ),
      );
    });
  }

  const weekdays = ['Mån', 'Tis', 'Ons', 'Tors', 'Fre', 'Lör', 'Sön'];

  group('the week row', () {
    testWidgets('five dinners fill five days; the other two show a dash and '
        'the meta line counts five', (tester) async {
      await pumpCard(tester, _draft());

      for (final name in _dinners) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('–'), findsNWidgets(2));
      expect(
        find.text('5 av 7 dagar klara · finns kvar i 29 dagar'),
        findsOneWidget,
      );
    });

    testWidgets('the weekdays run Mån to Sön from left to right', (
      tester,
    ) async {
      await pumpCard(tester, _draft());

      final lefts = [
        for (final day in weekdays) tester.getTopLeft(find.text(day)).dx,
      ];

      expect(lefts, orderedEquals([...lefts]..sort()));
      expect(lefts.toSet(), hasLength(7));
    });

    testWidgets('the dishes come from the longest meal type, in draft order, '
        'whichever meal type is listed first', (tester) async {
      await pumpCard(
        tester,
        _draft(
          meals: const {
            'Lunch': ['l0', 'l1'],
            'Middag': ['d0', 'd1', 'd2'],
          },
          names: const {
            'l0': 'Sallad',
            'l1': 'Wrap',
            'd0': 'Köttbullar',
            'd1': 'Fiskgratäng',
            'd2': 'Ärtsoppa',
          },
        ),
      );

      expect(find.text('Köttbullar'), findsOneWidget);
      expect(find.text('Fiskgratäng'), findsOneWidget);
      expect(find.text('Ärtsoppa'), findsOneWidget);
      expect(find.text('Sallad'), findsNothing);
      expect(find.text('Wrap'), findsNothing);
      expect(find.textContaining('3 av 7 dagar klara'), findsOneWidget);
    });

    testWidgets('more than seven dishes show the first seven and "7 av 7"', (
      tester,
    ) async {
      final ids = [for (var i = 0; i < 9; i++) 'd$i'];
      await pumpCard(
        tester,
        _draft(
          meals: {'Middag': ids},
          names: {for (final id in ids) id: 'Rätt $id'},
        ),
      );

      for (var i = 0; i < 7; i++) {
        expect(find.text('Rätt d$i'), findsOneWidget, reason: 'day ${i + 1}');
      }
      expect(find.text('Rätt d7'), findsNothing);
      expect(find.text('Rätt d8'), findsNothing);
      expect(find.text('–'), findsNothing);
      expect(find.textContaining('7 av 7 dagar klara'), findsOneWidget);
    });

    testWidgets('a dish whose name was not kept still fills its day', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _draft(
          names: const {
            'd0': 'Köttbullar',
            'd1': 'Fiskgratäng',
            'd3': 'Pannkakor',
            'd4': 'Lasagne',
          },
        ),
      );

      expect(find.text('–'), findsNWidgets(2), reason: 'only days 6 and 7');
      expect(find.textContaining('5 av 7 dagar klara'), findsOneWidget);
      expect(find.text('Ärtsoppa'), findsNothing);
    });
  });

  group('dayNames', () {
    test('is seven long, null for a day with no dish and an empty string '
        'for a dish with no name', () {
      final names = VeckomenyDraftResumeCard.dayNames(
        _draft(
          meals: const {
            'Middag': ['a', 'b', 'c'],
          },
          names: const {'a': 'Soppa', 'c': 'Gryta'},
        ),
      );

      expect(names, ['Soppa', '', 'Gryta', null, null, null, null]);
    });
  });

  group('the title', () {
    testWidgets('names yesterday when the draft was last changed yesterday', (
      tester,
    ) async {
      await pumpCard(tester, _draft(at: _yesterdayEvening));

      expect(find.text('Påbörjad veckomeny från i går'), findsOneWidget);
    });

    testWidgets('names the time when the draft was changed today', (
      tester,
    ) async {
      await pumpCard(tester, _draft(at: DateTime(2026, 10, 9, 7, 30)));

      expect(find.textContaining('Påbörjad veckomeny från'), findsOneWidget);
      expect(find.textContaining('i går'), findsNothing);
      expect(find.textContaining('07:30'), findsOneWidget);
    });

    testWidgets('the time left follows the clock: hours on the last day', (
      tester,
    ) async {
      final at = _now
          .subtract(WeeklyMenuDraft.lifetime)
          .add(
            const Duration(hours: 5, minutes: 30),
          );
      await pumpCard(tester, _draft(at: at));

      expect(find.textContaining('finns kvar i 5 timmar'), findsOneWidget);
    });
  });

  group('the buttons', () {
    testWidgets('Återställ and Släng each call their own callback once', (
      tester,
    ) async {
      var restored = 0;
      var discarded = 0;
      await pumpCard(
        tester,
        _draft(),
        onRestore: () => restored++,
        onDiscard: () => discarded++,
      );

      await tester.tap(find.byKey(const ValueKey('veckomeny-draft-restore')));
      await tester.pump();
      expect((restored, discarded), (1, 0));

      await tester.tap(find.byKey(const ValueKey('veckomeny-draft-discard')));
      await tester.pump();
      expect((restored, discarded), (1, 1));

      expect(find.text('Återställ'), findsOneWidget);
      expect(find.text('Släng'), findsOneWidget);
    });

    testWidgets('while restoring, Släng is disabled and Återställ ignores '
        'presses', (tester) async {
      var restored = 0;
      var discarded = 0;
      await pumpCard(
        tester,
        _draft(),
        restoring: true,
        onRestore: () => restored++,
        onDiscard: () => discarded++,
      );

      final discard = tester.widget<TextButton>(
        find.byKey(const ValueKey('veckomeny-draft-discard')),
      );
      expect(discard.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('veckomeny-draft-discard')),
        warnIfMissed: false,
      );
      await tester.tap(
        find.byKey(const ValueKey('veckomeny-draft-restore')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect((restored, discarded), (0, 0));
    });
  });

  group('semantics', () {
    testWidgets('the title is the one header, each day is its own node '
        'labelled "<weekday> <dish>" or "<weekday> ingen rätt", and the card '
        'is not a header', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, _draft());

      bool isHeader(SemanticsNode n) =>
          n.getSemanticsData().flagsCollection.isHeader;

      final title = tester.getSemantics(
        find.bySemanticsLabel('Påbörjad veckomeny från i går'),
      );
      expect(isHeader(title), isTrue);

      const expected = [
        'Mån Köttbullar',
        'Tis Fiskgratäng',
        'Ons Ärtsoppa',
        'Tors Pannkakor',
        'Fre Lasagne',
        'Lör ingen rätt',
        'Sön ingen rätt',
      ];
      final days = [
        for (final label in expected)
          tester.getSemantics(find.bySemanticsLabel(label)),
      ];
      for (final node in days) {
        expect(node.label, isNot(contains('\n')), reason: node.label);
        expect(isHeader(node), isFalse, reason: node.label);
      }
      expect(find.bySemanticsLabel('Fre ingen rätt'), findsNothing);
      expect(find.bySemanticsLabel('Lör Lasagne'), findsNothing);
      expect(
        [...days.map((n) => n.label), title.label].join(),
        isNot(contains('–')),
      );

      final card = title.parent!;
      expect(isHeader(card), isFalse);
      expect(days.every((n) => identical(n.parent, card)), isTrue);
      handle.dispose();
    });
  });

  group('layout', () {
    testWidgets('at 320 dp and text scale 2.0 nothing overflows and the '
        'content is all there', (tester) async {
      await pumpCard(
        tester,
        _draft(),
        width: 320,
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      for (final name in _dinners) {
        expect(find.text(name), findsOneWidget);
      }
      for (final day in weekdays) {
        expect(find.text(day), findsOneWidget);
      }
      expect(find.text('Återställ'), findsOneWidget);
      expect(find.text('Släng'), findsOneWidget);
    });
  });
}
