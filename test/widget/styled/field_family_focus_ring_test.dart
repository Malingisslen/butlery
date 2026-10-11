// The composer and the row field show focus with the canonical ring 3 px
// outside the box, ink on light and paper on dark, read back from rendered
// pixels as in butlery_control_focus_test.dart.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/styled/butlery_composer_field.dart';
import 'package:butlery/widgets/styled/butlery_row_field.dart';

final _boundaryKey = GlobalKey();

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget body) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(40),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 300, child: body),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<Color> _pixel(WidgetTester tester, Offset at) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    return (data!, width);
  });
  final (ByteData data, int width) = bytes!;
  final i = (at.dy.floor() * width + at.dx.floor()) * 4;
  return Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
}

/// The middle of the ring's stroke above the box.
Offset _aboveTop(Rect r) =>
    Offset(r.center.dx, r.top - ButleryFocusRing.inflate);

Rect _box(WidgetTester tester) => tester.getRect(find.byType(InputDecorator));

Future<void> _tabInto(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
}

void main() {
  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final ring = AppModeColors.focusRing(theme.colorScheme.brightness);

    group('field family focus ring, $mode', () {
      testWidgets('the composer: no ring at rest, the ring at focus', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          const ButleryComposerField(hintText: 'Skriv ett meddelande'),
        );
        expect(await _pixel(tester, _aboveTop(_box(tester))), isNot(ring));

        await _tabInto(tester);
        expect(await _pixel(tester, _aboveTop(_box(tester))), ring);
      });

      testWidgets('the composer ring follows the box as it grows', (
        tester,
      ) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await _pump(
          tester,
          theme,
          ButleryComposerField(hintText: 'x', controller: controller),
        );
        await _tabInto(tester);
        controller.text = 'a\nb\nc\nd';
        await tester.pumpAndSettle();

        final box = _box(tester);
        final belowBottom = Offset(
          box.center.dx,
          box.bottom + ButleryFocusRing.inflate,
        );
        expect(await _pixel(tester, belowBottom), ring);
      });

      testWidgets('the row field: no ring at rest, the ring at focus', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          const ButleryFieldRow(
            children: [Expanded(child: ButleryRowField(hintText: 'Steg 1'))],
          ),
        );
        expect(await _pixel(tester, _aboveTop(_box(tester))), isNot(ring));

        await _tabInto(tester);
        expect(await _pixel(tester, _aboveTop(_box(tester))), ring);
      });
    });
  }
}
