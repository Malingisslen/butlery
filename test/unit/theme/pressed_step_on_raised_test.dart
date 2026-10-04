/// A row that rests on surface.raised turns one step darker when pressed or
/// hovered (BUT-2205, produktbeslut R7-1 = B). Every ListTile paints a raised
/// tile, so the app theme's press and hover fill is that step. A disabled row
/// is never pressed.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/image/components/edit_actions_panel.dart';

import '../../infrastructure/helpers/ink_fill.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Widget app(ThemeData theme, Widget child) => MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Center(child: SizedBox(width: 300, child: child)),
    ),
  );

  Widget tile({required bool enabled}) =>
      ListTile(title: const Text('Mjölk'), onTap: () {}, enabled: enabled);

  final row = find.text('Mjölk');

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final modeColors = ModeColors.of(theme.brightness);
    final step = modeColors.pressedOnRaised;
    // The hover the app had before BUT-2205: it set none, so Flutter's.
    final flutterHover = ThemeData(brightness: theme.brightness).hoverColor;

    testWidgets('a pressed ListTile fills with the step on raised ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(app(theme, tile(enabled: true)));
      final gesture = await holdPress(tester, row);
      expect(paintsInkFill(tester, row, step), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a hovered ListTile fills with the step on raised ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(app(theme, tile(enabled: true)));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(row));
      await tester.pumpAndSettle();
      expect(paintsInkFill(tester, row, step), isTrue);
    });

    // The tile keeps a live onTap, so only `enabled` stands between a press
    // and the fill.
    testWidgets('a disabled ListTile is never pressed ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(app(theme, tile(enabled: false)));
      final gesture = await holdPress(tester, row);
      expect(paintsInkFill(tester, row, step), isFalse);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    // The first attempt at BUT-2205 changed only the theme, and a pressed
    // chosen chip turned paper on the step on raised. A chosen chip rests on
    // ink, so it keeps paper text on the step on ink.
    testWidgets('a pressed chosen chip keeps paper on the step on ink '
        '($mode)', (tester) async {
      await tester.pumpWidget(
        app(
          theme,
          Center(
            child: PressFill(
              surface: PressSurface.ink,
              child: FilterChip(
                label: const Text('Vegansk'),
                selected: true,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      final label = find.text('Vegansk');
      final gesture = await holdPress(tester, label);
      expect(paintsInkFill(tester, label, modeColors.pressedOnInk), isTrue);
      // In dark mode the two steps are the same colour.
      if (theme.brightness == Brightness.light) {
        expect(paintsInkFill(tester, label, step), isFalse);
      }
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.text.style?.color, theme.colorScheme.onPrimary);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    // The bottom tab rests on ink, so its hover is the step on ink, not the
    // theme's step on raised.
    testWidgets('a hovered bottom tab takes the step on ink ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Theme(
            data: theme,
            child: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: ButleryBottomNavigation(
                currentIndex: 0,
                items: const [
                  AdaptiveNavigationItem(
                    label: 'Recept',
                    icon: Icons.grid_view,
                    activeIcon: Icons.grid_view,
                    route: '/',
                  ),
                  AdaptiveNavigationItem(
                    label: 'Meny',
                    icon: ButleryIcons.calendar,
                    activeIcon: ButleryIcons.calendar,
                    route: '/veckomeny',
                  ),
                ],
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      final tab = find.text('Meny');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(tab));
      await tester.pumpAndSettle();
      expect(paintsInkFill(tester, tab, modeColors.pressedOnInk), isTrue);
      if (theme.brightness == Brightness.light) {
        expect(paintsInkFill(tester, tab, step), isFalse);
      }
    });

    // The surfaces the design session decides (BUT-2232) keep the press and
    // hover they had before BUT-2205.
    testWidgets('a surface left to the design session keeps its old press '
        'and hover ($mode)', (tester) async {
      await tester.pumpWidget(
        app(
          theme,
          Center(
            child: Material(
              color: theme.colorScheme.secondary,
              child: PressUnchanged(
                child: InkWell(
                  onTap: () {},
                  child: const SizedBox(
                    width: 80,
                    height: 80,
                    child: Center(child: Text('Lägg till')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final target = find.text('Lägg till');
      final gesture = await holdPress(tester, target);
      expect(
        paintsInkFill(tester, target, AppColors.rust.withValues(alpha: 0.12)),
        isTrue,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(target));
      await tester.pumpAndSettle();
      expect(paintsInkFill(tester, target, flutterHover), isTrue);
    });

    // In dark mode the step on raised is the add button's glyph colour, so
    // the glyph would vanish under it.
    testWidgets('a hovered add button keeps its old hover ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Theme(
            data: theme,
            child: Center(child: ButleryAddButton(onPressed: () {})),
          ),
        ),
      );
      final button = find.byType(ButleryAddButton);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(button));
      await tester.pumpAndSettle();
      final glyph = find.descendant(
        of: button,
        matching: find.byWidgetPredicate((w) => w is Icon),
      );
      expect(paintsInkFill(tester, glyph, flutterHover), isTrue);
      // In dark mode the glyph is the step's colour too.
      if (theme.brightness == Brightness.light) {
        expect(paintsInkFill(tester, glyph, step), isFalse);
      }
    });

    // A FloatingActionButton rests on ink.
    testWidgets('a pressed floating action button takes the step on ink '
        '($mode)', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Theme(
            data: theme,
            child: Center(
              child: FloatingActionButtonWidget.message(
                onPressed: () {},
                semanticLabel: 'Ny konversation',
              ),
            ),
          ),
        ),
      );
      final glyph = find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byWidgetPredicate((w) => w is Icon),
      );
      final gesture = await holdPress(tester, glyph);
      expect(paintsInkFill(tester, glyph, modeColors.pressedOnInk), isTrue);
      if (theme.brightness == Brightness.light) {
        expect(paintsInkFill(tester, glyph, step), isFalse);
      }
      await gesture.up();
      await tester.pumpAndSettle();
    });
  }

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    // The image actions rest on surface.raised, but the destructive one rests
    // on the error colour and keeps its old press (BUT-2232).
    testWidgets('the image actions press by their surface ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Theme(
            data: theme,
            child: Stack(
              children: [
                EditActionsPanel(onAddImage: () {}, onRemoveImage: () {}),
              ],
            ),
          ),
        ),
      );
      Finder icon(IconData data) =>
          find.byWidgetPredicate((w) => w is Icon && w.icon == data);
      final old = AppColors.rust.withValues(alpha: 0.12);
      final step = ModeColors.of(theme.brightness).pressedOnRaised;

      final add = icon(ButleryIcons.camera);
      var gesture = await holdPress(tester, add);
      expect(paintsInkFill(tester, add, step), isTrue);
      expect(paintsInkFill(tester, add, old), isFalse);
      await gesture.up();
      await tester.pumpAndSettle();

      final remove = icon(ButleryIcons.trash2);
      gesture = await holdPress(tester, remove);
      expect(paintsInkFill(tester, remove, old), isTrue);
      expect(paintsInkFill(tester, remove, step), isFalse);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  }

  test('the step is a different colour from the raised tile it sits on', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      expect(
        ModeColors.of(theme.brightness).pressedOnRaised,
        isNot(theme.colorScheme.surfaceContainerHighest),
      );
    }
  });
}
