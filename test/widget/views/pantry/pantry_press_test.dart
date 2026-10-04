// BUT-2205: a chosen pantry row's fill, and the expiry field's own fill, used
// to cover the press. Each is pressed in both modes.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/pantry/pantry_selection_manager.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/add_pantry_item_sheet.dart';
import 'package:butlery/views/pantry/pantry_item_card.dart';

import '../../../infrastructure/helpers/base_widget_test.dart';
import '../../../infrastructure/helpers/ink_fill.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

PantryItem _item(String id, String name) => PantryItem(
  id: id,
  ingredientName: name,
  quantity: 1,
  unit: 'l',
  location: PantryLocation.fridge,
  addedAt: DateTime(2026, 1, 1),
);

void main() {
  late _MockPantryViewModel vm;

  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDownAll(() async {
    await BaseWidgetTest.teardownWidget();
  });

  setUp(() {
    vm = _MockPantryViewModel();
    when(() => vm.searchResults).thenReturn(const []);
    when(() => vm.isLoading).thenReturn(false);
    when(() => vm.error).thenReturn(null);
    when(() => vm.hasError).thenReturn(false);
  });

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    final mode = theme.brightness.name;
    final modeColors = ModeColors.of(theme.brightness);

    testWidgets('pressed pantry rows show their surface\'s fill ($mode)', (
      tester,
    ) async {
      final selection = PantrySelectionManager()..enterSelectionMode('p_1');
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Theme(
            data: theme,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<PantryViewModel>.value(value: vm),
                ChangeNotifierProvider<PantrySelectionManager>.value(
                  value: selection,
                ),
              ],
              // The pantry section paints the page colour under its rows.
              child: Scaffold(
                body: ColoredBox(
                  color: theme.colorScheme.surface,
                  child: ListView(
                    children: [
                      PantryItemCard(item: _item('p_1', 'Mjölk')),
                      PantryItemCard(item: _item('p_2', 'Smör')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (final (name, fill) in [
        ('Mjölk', modeColors.pressedOnRaised),
        ('Smör', theme.colorScheme.surfaceContainerHighest),
      ]) {
        final row = find.text(name);
        expect(pressIsCovered(tester, row), isFalse);
        expect(borderIsAbovePress(tester, row), isTrue);
        final gesture = await holdPress(tester, row);
        expect(paintsInkFill(tester, row, fill), isTrue, reason: name);
        await gesture.cancel();
        await tester.pumpAndSettle();
      }
    });

    // The field paints its own fill above the ink layer, so the field itself
    // takes the pressed fill.
    testWidgets('a pressed expiry field takes the step on raised ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Theme(
            data: theme,
            child: ChangeNotifierProvider<PantryViewModel>.value(
              value: vm,
              child: const Scaffold(body: AddPantryItemSheet()),
            ),
          ),
        ),
      );
      final field = find.text('Inget utgångsdatum');
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      Color? fill() => tester
          .widget<InputDecorator>(
            find.ancestor(of: field, matching: find.byType(InputDecorator)),
          )
          .decoration
          .fillColor;

      expect(fill(), isNull);
      final gesture = await holdPress(tester, field);
      expect(fill(), modeColors.pressedOnRaised);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(fill(), isNull);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(field));
      await tester.pumpAndSettle();
      expect(fill(), modeColors.pressedOnRaised);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(fill(), isNull);

      // Only the press and hover tints are blanked: keyboard focus keeps
      // the theme's.
      final overlay = tester
          .widget<InkWell>(
            find.ancestor(of: field, matching: find.byType(InkWell)).first,
          )
          .overlayColor!;
      expect(overlay.resolve({WidgetState.focused}), isNull);
      expect(overlay.resolve({WidgetState.pressed}), Colors.transparent);
      expect(overlay.resolve({WidgetState.hovered}), Colors.transparent);
    });
  }
}
