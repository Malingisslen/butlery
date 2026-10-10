/// Round 8 of the press rule (BUT-2232): the photo scale and the paper rings
/// on the recipe photo (produktbeslut R8-3 = A, R8-4 = C). The saffron press
/// (R8-1) is in test/unit/theme/pressed_step_on_raised_test.dart and the
/// offline banner (R8-2) in status_indicators_simplified_test.dart.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_hero_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

import '../../infrastructure/helpers/ink_fill.dart';
import '../../test_support/semantics_announcement.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

const _photoKey = ValueKey('photo');
const _raised = Color(0xFFE6EAD9);
const _paper = Color(0xFFF5F4ED);

void main() {
  Widget photo({bool still = false}) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: Scaffold(
          body: Center(
            child: PressScale(
              onTap: () {},
              child: const SizedBox.square(key: _photoKey, dimension: 80),
            ),
          ),
        ),
      ),
    ),
  );

  double scale(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

  group('PressScale (R8-4 = C)', () {
    testWidgets('a pressed photo scales to 97 % and back on release', (
      tester,
    ) async {
      await tester.pumpWidget(photo());
      expect(scale(tester), 1);
      final gesture = await holdPress(tester, find.byKey(_photoKey));
      expect(scale(tester), 0.97);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scale(tester), 1);
    });

    testWidgets('under reduced motion a pressed photo stands still', (
      tester,
    ) async {
      await tester.pumpWidget(photo(still: true));
      final gesture = await holdPress(tester, find.byKey(_photoKey));
      expect(scale(tester), 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('hover changes neither scale nor colour, only the cursor', (
      tester,
    ) async {
      await tester.pumpWidget(photo());
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(_photoKey)));
      await tester.pumpAndSettle();
      expect(scale(tester), 1);
      final hoverFill = AppTheme.lightTheme.hoverColor;
      expect(paintsInkFill(tester, find.byKey(_photoKey), hoverFill), isFalse);
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
    });

    testWidgets('a focused photo keeps the theme\'s focus colour', (
      tester,
    ) async {
      await tester.pumpWidget(photo());
      final ink = tester.widget<InkWell>(find.byType(InkWell));
      final overlay = ink.overlayColor!;
      expect(overlay.resolve({WidgetState.pressed}), Colors.transparent);
      expect(overlay.resolve({WidgetState.hovered}), Colors.transparent);
      expect(overlay.resolve({WidgetState.focused}), isNull);
    });
  });

  group('the paper rings on the recipe photo (R8-3 = A)', () {
    Color? ring(WidgetTester tester) {
      final box = tester.widget<Container>(
        find.byKey(const ValueKey('recipe-detail-paper-ring')),
      );
      return (box.decoration! as BoxDecoration).color;
    }

    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('a pressed or hovered hero button turns its ring raised, '
          'opaque ($mode)', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Theme(
              data: theme,
              child: Center(
                child: RecipeHeroButton(
                  icon: ButleryIcons.arrowLeft,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        final button = find.byType(RecipeHeroButton);
        expect(ring(tester), _paper);
        final gesture = await holdPress(tester, button);
        expect(ring(tester), _raised);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(ring(tester), _paper);

        final mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(button));
        await tester.pumpAndSettle();
        expect(ring(tester), _raised);
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(ring(tester), _paper);

        // The ring is the press: the 48 dp box around it paints none.
        final overlay = tester
            .widget<InkWell>(find.byType(InkWell))
            .overlayColor!;
        expect(overlay.resolve({WidgetState.pressed}), Colors.transparent);
        expect(overlay.resolve({WidgetState.hovered}), Colors.transparent);
        expect(overlay.resolve({WidgetState.focused}), isNull);
      });

      testWidgets('a pressed or hovered menu button turns its ring raised '
          '($mode)', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Theme(
              data: theme,
              child: Center(
                child: RecipeHeroMenuButton<int>(
                  tooltip: 'Fler åtgärder',
                  icon: ButleryIcons.moreVertical,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 1, child: Text('Redigera')),
                  ],
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        );
        final button = find.byType(RecipeHeroMenuButton<int>);
        expect(ring(tester), _paper);
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump();
        expect(ring(tester), _raised);
        await gesture.cancel();
        await tester.pump();
        expect(ring(tester), _paper);

        final handle = tester.ensureSemantics();
        await tester.pump();
        final stop = find.descendant(
          of: find.byType(PopupMenuButton<int>),
          matching: find.byType(IconButton),
        );
        expect(announcedLines(tester, stop), ['Fler åtgärder']);
        expectActivatable(tester, stop);
        handle.dispose();

        // A real tap opens the menu and lets the ring go.
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('Redigera'), findsOneWidget);
        expect(ring(tester), _paper);
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();

        final menuStyle = tester
            .widget<PopupMenuButton<int>>(find.byType(PopupMenuButton<int>))
            .style!;
        expect(
          menuStyle.overlayColor!.resolve({WidgetState.pressed}),
          Colors.transparent,
        );
        expect(
          menuStyle.overlayColor!.resolve({WidgetState.hovered}),
          Colors.transparent,
        );

        final mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(button));
        await tester.pumpAndSettle();
        expect(ring(tester), _raised);
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(ring(tester), _paper);
      });
    }
  });
}
