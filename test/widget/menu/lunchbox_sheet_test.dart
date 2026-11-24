/// BUT-2486 del 3: the lunchbox sheet answers with the box the user built —
/// leftovers that follow the week's own middag, Monday's leftovers from last
/// Sunday with the dish picked by hand, a prep-day dish, a suggestion — and
/// with who takes one and how many boxes, or with "Ingen matlåda".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/menu/calendar/lunchbox_sheet.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

HouseholdRosterMember _member(String id, String name) =>
    HouseholdRosterMember.fromUser(userId: id, displayName: name);

void main() {
  final sv = AppLocalizationsSv();

  /// Opens the sheet for [day] and returns a getter for its answer.
  Future<LunchboxSheetResult? Function()> open(
    WidgetTester tester, {
    DayOfWeek day = DayOfWeek.tue,
    Lunchbox? current,
    String? currentTitle,
    String? leftoversTitle = 'Linsgryta',
    List<Recipe> suggestions = const [],
    List<HouseholdRosterMember> roster = const [],
    Recipe? picked,
    List<int>? pickCount,
  }) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    LunchboxSheetResult? result;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showLunchboxSheet(
                context,
                day: day,
                dayName: 'tisdag',
                current: current,
                currentTitle: currentTitle,
                leftoversTitle: leftoversTitle,
                suggestions: suggestions,
                roster: roster,
                pickRecipe: (_) async {
                  pickCount?.add(1);
                  return picked;
                },
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('lunchbox-save')));
    await tester.pumpAndSettle();
  }

  Lunchbox saved(LunchboxSheetResult? Function() result) =>
      (result() as LunchboxSheetSave).box;

  testWidgets(
    'leftovers on Tuesday follow Monday\'s middag and store no dish',
    (tester) async {
      final result = await open(tester);

      expect(find.text(sv.lunchboxSheetTitle('tisdag')), findsOneWidget);
      expect(find.text(sv.lunchboxLeftoversFrom('Linsgryta')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lunchbox-source-leftovers')));
      await tester.pump();
      await save(tester);

      final box = saved(result);
      expect(box.source, LunchboxSource.leftovers);
      expect(box.fromDay, DayOfWeek.mon);
      expect(box.fromPreviousWeek, isFalse);
      expect(box.recipeId, isNull);
      expect(box.followsMiddag, isTrue);
      expect(box.portions, 1);
      expect(box.takerIds, isEmpty);
    },
  );

  testWidgets('with no middag the day before, leftovers cannot be chosen and '
      'nothing can be saved', (tester) async {
    final result = await open(tester, leftoversTitle: null);

    expect(find.text(sv.lunchboxLeftoversNone), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lunchbox-source-leftovers')));
    await tester.pump();
    await save(tester);

    expect(result(), isNull);
    expect(find.text(sv.lunchboxSave), findsOneWidget);
  });

  testWidgets('Monday\'s leftovers come from last Sunday: the dish is picked '
      'by hand and stored on the box', (tester) async {
    final picks = <int>[];
    final result = await open(
      tester,
      day: DayOfWeek.mon,
      leftoversTitle: null,
      picked: RecipeFactory.build(id: 'chili', title: 'Chili'),
      pickCount: picks,
    );

    expect(find.text(sv.lunchboxLeftoversPreviousWeek), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lunchbox-source-leftovers')));
    await tester.pumpAndSettle();
    await save(tester);

    expect(picks, hasLength(1));
    final box = saved(result);
    expect(box.source, LunchboxSource.leftovers);
    expect(box.fromPreviousWeek, isTrue);
    expect(box.recipeId, 'chili');
    expect(box.recipeTitle, 'Chili');
    expect(box.followsMiddag, isFalse);
  });

  testWidgets('a prep-day box stores the dish picked for it', (tester) async {
    final result = await open(
      tester,
      picked: RecipeFactory.build(id: 'chili', title: 'Chili'),
    );

    await tester.tap(find.byKey(const ValueKey('lunchbox-source-prepday')));
    await tester.pumpAndSettle();
    expect(find.text('Chili'), findsOneWidget);
    await save(tester);

    final box = saved(result);
    expect(box.source, LunchboxSource.prepDay);
    expect(box.recipeId, 'chili');
    expect(box.fromDay, isNull);
  });

  testWidgets('a suggestion is saved with its dish', (tester) async {
    final result = await open(
      tester,
      suggestions: [RecipeFactory.build(id: 'soup', title: 'Soppa med bröd')],
    );

    expect(
      find.text('Soppa med bröd · ${sv.lunchboxSuitsSubtitle}'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('lunchbox-suggestion-soup')));
    await tester.pump();
    await save(tester);

    final box = saved(result);
    expect(box.source, LunchboxSource.suggestion);
    expect(box.recipeId, 'soup');
    expect(box.recipeTitle, 'Soppa med bröd');
  });

  testWidgets('without suitable recipes the sheet says so', (tester) async {
    await open(tester);

    expect(find.text(sv.lunchboxNoSuggestions), findsOneWidget);
  });

  testWidgets('ticked takers are saved, and the number of boxes follows them '
      'until it is set by hand', (tester) async {
    final result = await open(
      tester,
      roster: [
        _member('a', 'Malin'),
        _member('b', 'Sambon'),
        _member('c', 'Barnen'),
      ],
    );

    expect(find.text(sv.lunchboxTakersHeading.toUpperCase()), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lunchbox-source-leftovers')));
    await tester.tap(find.byKey(const ValueKey('lunchbox-taker-b')));
    await tester.tap(find.byKey(const ValueKey('lunchbox-taker-a')));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lunchbox-portions-plus')));
    await tester.tap(find.byKey(const ValueKey('lunchbox-taker-c')));
    await tester.pump();
    await save(tester);

    final box = saved(result);
    expect(box.takerIds, ['a', 'b', 'c']);
    expect(box.portions, 3);
  });

  testWidgets('a solo account is not asked who takes the box', (tester) async {
    await open(tester, roster: [_member('a', 'Malin')]);

    expect(find.byKey(const ValueKey('lunchbox-taker-a')), findsNothing);
  });

  testWidgets('an existing box opens as it is and offers "Ingen matlåda"', (
    tester,
  ) async {
    final result = await open(
      tester,
      current: const Lunchbox(
        source: LunchboxSource.prepDay,
        recipeId: 'chili',
        recipeTitle: 'Chili',
        portions: 3,
      ),
      currentTitle: 'Chili',
    );

    expect(find.text('Chili'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lunchbox-remove')));
    await tester.pumpAndSettle();

    expect(result(), isA<LunchboxSheetRemove>());
  });

  testWidgets('a new box offers no "Ingen matlåda"', (tester) async {
    await open(tester);

    expect(find.byKey(const ValueKey('lunchbox-remove')), findsNothing);
  });
}
