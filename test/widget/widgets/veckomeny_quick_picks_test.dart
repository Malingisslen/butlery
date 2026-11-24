// BUT-2498: quick picks on an empty week.

import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/menu_constraint_parser.dart';
import 'package:butlery/widgets/menu/veckomeny_quick_picks.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('dinnersLeftThisWeek', () {
    test('Monday asks for seven, today included', () {
      expect(
        VeckomenyQuickPicks.dinnersLeftThisWeek(DateTime(2026, 11, 23)),
        7,
      );
    });
    test('Sunday asks for one', () {
      expect(
        VeckomenyQuickPicks.dinnersLeftThisWeek(DateTime(2026, 11, 29)),
        1,
      );
    });
  });

  group('the prompt a quick pick sends', () {
    test('"5 middagar snabba" is five dinners of 30 minutes at most', () async {
      final lexicon = await const CodeLexiconProvider().load();
      final parsed = MenuConstraintParser.parse('5 middagar snabba', lexicon);
      final slot = parsed.slotRequests.single;
      expect(slot.mealType, 'middag');
      expect(slot.totalCount, 5);
      expect(slot.subRequests.single.maxTimeMinutes, 30);
    });
  });

  test(
    '"1 middag snabba", asked on a Sunday, is one dinner of 30 minutes',
    () async {
      final lexicon = await const CodeLexiconProvider().load();
      final slot = MenuConstraintParser.parse(
        '1 middag snabba',
        lexicon,
      ).slotRequests.single;
      expect(slot.totalCount, 1);
      expect(slot.subRequests.single.maxTimeMinutes, 30);
    },
  );

  group('VeckomenyQuickPicks', () {
    Future<List<(String, bool)>> pump(WidgetTester tester) async {
      final picks = <(String, bool)>[];
      await withClock(Clock.fixed(DateTime(2026, 11, 25)), () async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: VeckomenyQuickPicks(
              onPick: (prompt, {required pantryFocus}) =>
                  picks.add((prompt, pantryFocus)),
            ),
          ),
        );
      });
      return picks;
    }

    testWidgets('shows both picks, and no pick for one pan', (tester) async {
      await pump(tester);
      expect(find.text('Snabb vecka'), findsOneWidget);
      expect(find.text('Använd det jag har hemma'), findsOneWidget);
      expect(find.textContaining('panna'), findsNothing);
    });

    testWidgets('Snabb vecka asks for fast dinners, without pantry focus', (
      tester,
    ) async {
      final picks = await pump(tester);
      await tester.tap(find.text('Snabb vecka'));
      expect(picks, [('5 middagar snabba', false)]);
    });

    testWidgets('on a Sunday both picks ask for one dinner, in the singular', (
      tester,
    ) async {
      final picks = <(String, bool)>[];
      await withClock(Clock.fixed(DateTime(2026, 11, 29)), () async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: VeckomenyQuickPicks(
              onPick: (prompt, {required pantryFocus}) =>
                  picks.add((prompt, pantryFocus)),
            ),
          ),
        );
      });
      await tester.tap(find.text('Snabb vecka'));
      await tester.tap(find.text('Använd det jag har hemma'));
      expect(picks, [('1 middag snabba', false), ('1 middag', true)]);
    });

    testWidgets('the pantry pick sets the pantry focus', (tester) async {
      final picks = await pump(tester);
      await tester.tap(find.text('Använd det jag har hemma'));
      expect(picks, [('5 middagar', true)]);
    });
  });
}
