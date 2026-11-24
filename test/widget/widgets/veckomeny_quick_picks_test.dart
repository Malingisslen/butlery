// BUT-2498: quick picks on an empty week.

import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/menu_constraint_parser.dart';
import 'package:butlery/widgets/menu/veckomeny_quick_picks.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
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
    Future<List<MenuWishFill>> pump(
      WidgetTester tester, {
      DateTime? now,
      String? activeSourceId,
    }) async {
      final picks = <MenuWishFill>[];
      await withClock(Clock.fixed(now ?? DateTime(2026, 11, 25)), () async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: VeckomenyQuickPicks(
              activeSourceId: activeSourceId,
              onPick: picks.add,
            ),
          ),
        );
      });
      return picks;
    }

    testWidgets('shows the heading and both chips, and none for one pan', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('FÄRDIGA ÖNSKEMÅL'), findsOneWidget);
      expect(find.text('Snabb vecka'), findsOneWidget);
      expect(find.text('Använd det jag har hemma'), findsOneWidget);
      expect(find.textContaining('panna'), findsNothing);
    });

    testWidgets('Snabb vecka hands over fast dinners, without pantry focus', (
      tester,
    ) async {
      final picks = await pump(tester);
      await tester.tap(find.text('Snabb vecka'));
      expect(picks, [
        const MenuWishFill(
          text: '5 middagar snabba',
          pantryFocus: false,
          sourceId: VeckomenyQuickPicks.fastSourceId,
        ),
      ]);
    });

    testWidgets('on a Sunday both chips ask for one dinner, in the singular', (
      tester,
    ) async {
      final picks = await pump(tester, now: DateTime(2026, 11, 29));
      await tester.tap(find.text('Snabb vecka'));
      await tester.tap(find.text('Använd det jag har hemma'));
      expect(picks.map((p) => (p.text, p.pantryFocus)), [
        ('1 middag snabba', false),
        ('1 middag', true),
      ]);
    });

    testWidgets('the pantry chip sets the pantry focus', (tester) async {
      final picks = await pump(tester);
      await tester.tap(find.text('Använd det jag har hemma'));
      expect(picks.single.text, '5 middagar');
      expect(picks.single.pantryFocus, isTrue);
      expect(picks.single.sourceId, VeckomenyQuickPicks.pantrySourceId);
    });

    testWidgets('only the chip named by activeSourceId is selected', (
      tester,
    ) async {
      await pump(tester, activeSourceId: VeckomenyQuickPicks.pantrySourceId);
      bool selected(String label) => tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, label))
          .selected;
      expect(selected('Använd det jag har hemma'), isTrue);
      expect(selected('Snabb vecka'), isFalse);
    });

    testWidgets('a chip is a selectable button for a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, activeSourceId: VeckomenyQuickPicks.fastSourceId);
      expect(
        tester.getSemantics(find.widgetWithText(FilterChip, 'Snabb vecka')),
        matchesSemantics(
          label: 'Snabb vecka',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
