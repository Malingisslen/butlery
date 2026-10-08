/// A chip takes the pressed fill of the surface it rests on (B83-1 = A;
/// BUT-2205, produktbeslut R7-1 = B, R7-2 = B; Malin 2026-10-04: chips follow
/// the same rule as rows). Chips have no colour setting of their own for the
/// press, so PressFill sets it for them.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
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
    var found = false;
    for (final ink in tester.allRenderObjects.where(
      (o) => o.runtimeType.toString() == '_RenderInkFeatures',
    )) {
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
    }
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

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final raised = theme.colorScheme.surfaceContainerHighest;

    testWidgets('a pressed popup menu row fills to raised ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          theme,
          PressFill(
            surface: PressSurface.base,
            child: PopupMenuButton<int>(
              itemBuilder: (_) => const [
                PopupMenuItem(value: 1, child: Text('Byt namn')),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.startGesture(tester.getCenter(find.text('Byt namn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fills(tester, raised), isTrue);
    });

    testWidgets('a pressed dropdown row fills to raised ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          theme,
          PressFill(
            surface: PressSurface.base,
            child: DropdownButton<int>(
              value: 1,
              onChanged: (_) {},
              items: const [
                DropdownMenuItem(value: 1, child: Text('Gram')),
                DropdownMenuItem(value: 2, child: Text('Liter')),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Gram'));
      await tester.pumpAndSettle();
      await tester.startGesture(tester.getCenter(find.text('Liter').last));
      // A row inside a scrollable menu starts its highlight after the
      // press timeout, so let that timer fire before the fade runs.
      await tester.pump();
      await tester.pump(kPressTimeout);
      await tester.pump(const Duration(milliseconds: 300));
      expect(fills(tester, raised), isTrue);
    });
  }

  // What the text field's own painters draw. The dark step is also the dark
  // page colour, so the search stays inside the field.
  bool fieldFills(WidgetTester tester, Color color) {
    var found = false;
    final painters = find.descendant(
      of: find.byType(TextField),
      matching: find.byType(CustomPaint),
    );
    for (final painter in tester.renderObjectList<RenderCustomPaint>(
      painters,
    )) {
      expect(
        painter,
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
    }
    return found;
  }

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final modeColors = ModeColors.of(theme.brightness);

    testWidgets('a pressed menu row that is a ListTile fills to the step on '
        'raised ($mode)', (tester) async {
      await tester.pumpWidget(
        app(
          theme,
          PressFill(
            surface: PressSurface.raised,
            child: PopupMenuButton<int>(
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 1,
                  child: ListTile(title: Text('Ta bort')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.startGesture(tester.getCenter(find.text('Ta bort')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fills(tester, modeColors.pressedOnRaised), isTrue);
    });

    testWidgets('a hovered filled field takes the step on raised ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          theme,
          const SizedBox(
            width: 240,
            child: TextField(decoration: InputDecoration(hintText: 'Sök')),
          ),
        ),
      );
      final fill = theme.colorScheme.surfaceContainerHighest;
      expect(fieldFills(tester, fill), isTrue);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(TextField)));
      await tester.pumpAndSettle();
      expect(fieldFills(tester, fill), isFalse);
      expect(fieldFills(tester, modeColors.pressedOnRaised), isTrue);
    });
  }

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final modeColors = ModeColors.of(theme.brightness);
    for (final (surface, fill) in [
      (PressSurface.base, theme.colorScheme.surfaceContainerHighest),
      (PressSurface.ink, modeColors.pressedOnInk),
    ]) {
      testWidgets(
        'a pressed InkWell on ${surface.name} takes its fill ($mode)',
        (
          tester,
        ) async {
          await tester.pumpWidget(
            app(
              theme,
              PressFill(
                surface: surface,
                child: InkWell(
                  onTap: () {},
                  child: const SizedBox(
                    width: 200,
                    height: 48,
                    child: Text('Vegetariskt'),
                  ),
                ),
              ),
            ),
          );
          await press(tester);
          expect(fills(tester, fill), isTrue);
        },
      );
    }
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
          child: PressFill(
            surface: PressSurface.base,
            child: Icon(ButleryIcons.plus),
          ),
        ),
      ),
    );
    final icon = find.byIcon(ButleryIcons.plus);
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
