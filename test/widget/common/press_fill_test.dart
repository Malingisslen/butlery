/// A chip takes the pressed fill of the surface it rests on (B83-1 = A;
/// BUT-2205, produktbeslut R7-1 = B, R7-2 = B; Malin 2026-10-04: chips follow
/// the same rule as rows). Chips have no colour setting of their own for the
/// press, so PressFill sets it for them.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/press_fill.dart';

void main() {
  Widget app(ThemeData theme, Widget child) => MaterialApp(
    theme: theme,
    home: Scaffold(body: Center(child: child)),
  );

  Widget chip({required bool selected, required PressSurface surface}) =>
      PressFill(
        surface: surface,
        child: FilterChip(
          label: const Text('Vegetariskt'),
          selected: selected,
          onSelected: (_) {},
        ),
      );

  // A press paints more than one rect, so record every rect drawn on the
  // chip's ink layer.
  bool fills(WidgetTester tester, Color color) {
    final ink = tester.allRenderObjects.lastWhere(
      (o) => o.runtimeType.toString() == '_RenderInkFeatures',
    );
    var found = false;
    expect(
      ink,
      paints..everything((method, args) {
        if ((method == #drawRect ||
                method == #drawRRect ||
                method == #drawPath) &&
            args.last is Paint &&
            (args.last as Paint).color.toARGB32() == color.toARGB32()) {
          found = true;
        }
        return true;
      }),
    );
    return found;
  }

  Future<void> press(WidgetTester tester) async {
    await tester.startGesture(tester.getCenter(find.text('Vegetariskt')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final modeColors = ModeColors.of(theme.brightness);

    testWidgets('an unselected chip on base fills to raised ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(theme, chip(selected: false, surface: PressSurface.base)),
      );
      await press(tester);
      expect(fills(tester, theme.colorScheme.surfaceContainerHighest), isTrue);
    });

    testWidgets('a selected ink chip fills to the step on ink ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(theme, chip(selected: true, surface: PressSurface.ink)),
      );
      await press(tester);
      expect(fills(tester, modeColors.pressedOnInk), isTrue);
    });

    testWidgets('a chip on raised fills to the step on raised ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(theme, chip(selected: true, surface: PressSurface.raised)),
      );
      await press(tester);
      expect(fills(tester, modeColors.pressedOnRaised), isTrue);
    });

    testWidgets('hover takes the same fill as the press ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          theme,
          PressFill(
            surface: PressSurface.base,
            child: ActionChip(
              label: const Text('Vegetariskt'),
              onPressed: () {},
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Vegetariskt')));
      await tester.pumpAndSettle();
      expect(fills(tester, theme.colorScheme.surfaceContainerHighest), isTrue);
    });
  }

  testWidgets('the icon colour around it reaches the chip unchanged', (
    tester,
  ) async {
    const appBarIcon = Color(0xFFF5F4ED);
    await tester.pumpWidget(
      app(
        AppTheme.lightTheme,
        const IconTheme(
          data: IconThemeData(color: appBarIcon),
          child: PressFill(surface: PressSurface.base, child: Icon(Icons.add)),
        ),
      ),
    );
    final icon = find.byIcon(Icons.add);
    expect(IconTheme.of(tester.element(icon)).color, appBarIcon);
  });

  test('neither step fill equals surface.raised, in either mode', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final m = ModeColors.of(theme.brightness);
      final raised = theme.colorScheme.surfaceContainerHighest;
      expect(m.pressedOnRaised, isNot(raised));
      expect(m.pressedOnInk, isNot(raised));
    }
  });
}
