// BUT-2205: placement cells and tray cards whose own fill, or the column's,
// used to cover the press. Each is pressed in both modes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart';
import 'package:butlery/views/menu_placement/placement_widgets.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/ink_fill.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/semantics_announcement.dart';

class _MockVm extends Mock implements MenuPlacementViewModel {}

void main() {
  late _MockVm vm;

  setUp(() {
    final now = DateTime.utc(2026, 4, 13);
    final item = MenuPlacementItem(
      mealType: 'lunch',
      slot: MealSlot.lunch,
      recipe: RecipeFactory.build(id: 'r1', title: 'Pannkakor'),
    );
    vm = _MockVm();
    when(() => vm.plan).thenReturn(
      WeeklyMenuPlan(
        id: 'u1_2026-W16',
        userId: 'u1',
        weekStartDate: now,
        entries: const [
          WeeklyMenuPlanEntry(
            id: 'cell',
            day: DayOfWeek.mon,
            slot: MealSlot.lunch,
            recipeId: 'r2',
            recipeTitle: 'Köttbullar',
          ),
          WeeklyMenuPlanEntry(
            id: 'chip',
            day: DayOfWeek.mon,
            slot: MealSlot.ovrigt,
            recipeId: 'r3',
            recipeTitle: 'Smoothie',
          ),
          WeeklyMenuPlanEntry(
            id: 'earlier',
            day: DayOfWeek.wed,
            slot: MealSlot.ovrigt,
            recipeId: 'r4',
            recipeTitle: 'Gröt',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );
    when(() => vm.selectedItem).thenReturn(item);
    when(() => vm.isEligible(any(), any())).thenReturn(false);
    when(() => vm.isEligible(DayOfWeek.tue, MealSlot.ovrigt)).thenReturn(true);
    when(() => vm.isSessionEntry(any())).thenReturn(true);
    when(() => vm.isSessionEntry('earlier')).thenReturn(false);
    when(() => vm.items).thenReturn([item, item]);
    when(() => vm.selectedIndex).thenReturn(1);
  });

  setUpAll(() {
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.lunch);
  });

  Future<void> pump(WidgetTester tester, ThemeData theme, Widget child) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Theme(
          data: theme,
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
  }

  Future<void> expectPressFill(
    WidgetTester tester,
    Finder target,
    Color fill, {
    bool bordered = true,
  }) async {
    expect(pressIsCovered(tester, target), isFalse);
    if (bordered) expect(borderIsAbovePress(tester, target), isTrue);
    final gesture = await holdPress(tester, target);
    expect(paintsInkFill(tester, target, fill), isTrue);
    await gesture.cancel();
    await tester.pumpAndSettle();
  }

  testWidgets('a free cell, a placed dish and a tray card are each named once '
      'and can be activated', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      AppTheme.lightTheme,
      Column(
        children: [
          PlacementGrid(vm: vm),
          SizedBox(height: 80, child: PlacementTrayCard(vm: vm, index: 0)),
        ],
      ),
    );

    for (final label in [
      RegExp(r'^Placera på'),
      RegExp(r'^Ta bort från rutan'),
      RegExp(r'^Välj'),
    ]) {
      final node = find.bySemanticsLabel(label).first;
      expectActivatable(tester, node);
      expectNothingAnnouncedTwice(tester, node);
    }
    handle.dispose();
  });

  testWidgets('a free cell announces its action only, not the "placera här" '
      'text drawn in it', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, AppTheme.lightTheme, PlacementGrid(vm: vm));

    final cell = find.bySemanticsLabel(RegExp(r'^Placera på')).first;
    expectActivatable(tester, cell);
    final lines = announcedLines(tester, cell);
    expect(lines, hasLength(1), reason: '$lines');
    expect(lines.single, startsWith('Placera på'));
    expect(
      lines.map((l) => l.toLowerCase()),
      isNot(contains('placera här')),
      reason: '$lines',
    );
    handle.dispose();
  });

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    final mode = theme.brightness.name;
    final modeColors = ModeColors.of(theme.brightness);

    testWidgets('pressed grid cells show their surface\'s fill ($mode)', (
      tester,
    ) async {
      await pump(tester, theme, PlacementGrid(vm: vm));
      // The free cell sits in the övrigt column's fill and draws its dashed
      // outline as a foreground, not a border.
      await expectPressFill(
        tester,
        find.text('placera här'),
        theme.colorScheme.surfaceContainerHighest,
        bordered: false,
      );
      await expectPressFill(
        tester,
        find.text('köttbullar'),
        modeColors.pressedOnRaised,
      );
      await expectPressFill(
        tester,
        find.text('smoothie'),
        theme.colorScheme.surfaceContainerHighest,
      );
      // A dish from before this session is not pressable, but its fill still
      // needs a layer above the column's.
      expect(pressIsCovered(tester, find.text('gröt')), isFalse);
    });

    testWidgets('pressed tray cards show their surface\'s fill ($mode)', (
      tester,
    ) async {
      await pump(
        tester,
        theme,
        // The tray paints surface.raised under its cards.
        ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: SizedBox(
            height: 80,
            child: Row(
              children: [
                PlacementTrayCard(vm: vm, index: 0),
                PlacementTrayCard(vm: vm, index: 1),
              ],
            ),
          ),
        ),
      );
      await expectPressFill(
        tester,
        find.text('Pannkakor').at(0),
        modeColors.pressedOnRaised,
      );
      // The chosen card is ink and has no border.
      await expectPressFill(
        tester,
        find.text('Pannkakor').at(1),
        modeColors.pressedOnInk,
        bordered: false,
      );
    });
  }
}
