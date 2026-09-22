/// Proves the focus ring renders unclipped 3 px outside the control inside a
/// Card, a ListView and a ClipRRect (decision D3), in both modes, only for
/// keyboard focus on buttons, on every focus for text entry, and without
/// changing focus traversal.
///
/// The ring is read back from rendered pixels, not from the widget tree.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';

final _boundaryKey = GlobalKey();

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(40),
            child: Align(alignment: Alignment.topLeft, child: body),
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

/// The middle of the ring's stroke on the left side, and above the top edge.
List<Offset> _ringPoints(Rect r) => [
  Offset(r.left - ButleryFocusRing.inflate, r.center.dy),
  Offset(r.center.dx, r.top - ButleryFocusRing.inflate),
];

Widget _button(FocusNode node) => SizedBox(
  width: 160,
  child: ElevatedButton(
    focusNode: node,
    onPressed: () {},
    child: const Text('Spara'),
  ),
);

void main() {
  late FocusNode node;

  setUp(() {
    node = FocusNode();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    node.dispose();
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  final containers = <String, Widget Function(Widget)>{
    'Card': (child) => Card(margin: EdgeInsets.zero, child: child),
    'ListView': (child) => SizedBox(
      width: 160,
      height: 120,
      child: ListView(padding: EdgeInsets.zero, children: [child]),
    ),
    'ClipRRect': (child) => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: child,
    ),
  };

  for (final entry in containers.entries) {
    testWidgets('keyboard focus ring is unclipped inside ${entry.key}', (
      tester,
    ) async {
      await _pump(tester, entry.value(_button(node)));
      final rect = tester.getRect(find.byType(ElevatedButton));

      for (final p in _ringPoints(rect)) {
        expect(await _pixel(tester, p), AppColors.cream, reason: 'at rest');
      }

      node.requestFocus();
      await tester.pumpAndSettle();

      for (final p in _ringPoints(rect)) {
        expect(
          await _pixel(tester, p),
          AppColors.focusRing,
          reason: '${entry.key}: ring at $p',
        );
      }
      // The 3 px gap between the button and the ring stays empty.
      expect(
        await _pixel(tester, Offset(rect.left - 1.5, rect.center.dy)),
        AppColors.cream,
      );
    });
  }

  testWidgets('the ring is paper in dark mode', (tester) async {
    await _pump(tester, _button(node), theme: AppTheme.darkTheme);
    node.requestFocus();
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(ElevatedButton));
    for (final p in _ringPoints(rect)) {
      expect(await _pixel(tester, p), AppColorsDark.focusRing);
    }
  });

  testWidgets('a button focused by touch shows no ring', (tester) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await _pump(tester, _button(node));
    node.requestFocus();
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(ElevatedButton));
    for (final p in _ringPoints(rect)) {
      expect(await _pixel(tester, p), AppColors.cream);
    }
  });

  testWidgets('the ring appears when input switches to the keyboard', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await _pump(tester, _button(node));
    node.requestFocus();
    await tester.pumpAndSettle();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(ElevatedButton));
    expect(await _pixel(tester, _ringPoints(rect).first), AppColors.focusRing);
  });

  testWidgets('the search box shows the ring on every focus', (tester) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await _pump(
      tester,
      SizedBox(
        width: 240,
        child: ButlerySearchBox(focusNode: node, hintText: 'Sök'),
      ),
    );
    node.requestFocus();
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(ButlerySearchBox));
    for (final p in _ringPoints(rect)) {
      expect(await _pixel(tester, p), AppColors.focusRing);
    }
  });

  testWidgets('the ring observes focus and adds no focus stop', (
    tester,
  ) async {
    final second = FocusNode();
    addTearDown(second.dispose);
    await _pump(
      tester,
      Column(
        children: [
          ButleryFocusRing(
            child: TextButton(
              focusNode: node,
              onPressed: () {},
              child: const Text('A'),
            ),
          ),
          TextButton(
            focusNode: second,
            onPressed: () {},
            child: const Text('B'),
          ),
        ],
      ),
    );
    node.requestFocus();
    await tester.pumpAndSettle();
    node.nextFocus();
    await tester.pumpAndSettle();
    expect(second.hasPrimaryFocus, isTrue);
  });

  group('theme focus expressions', () {
    for (final t in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final ring = t.brightness == Brightness.dark
          ? AppColorsDark.focusRing
          : AppColors.focusRing;

      test('${t.brightness}: no themed button tints or thickens at focus', () {
        const focused = {WidgetState.focused};
        for (final style in [
          t.elevatedButtonTheme.style!,
          t.filledButtonTheme.style!,
          t.outlinedButtonTheme.style!,
          t.textButtonTheme.style!,
          t.iconButtonTheme.style!,
        ]) {
          expect(style.overlayColor!.resolve(focused), Colors.transparent);
          expect(style.backgroundBuilder, isNotNull);
          expect(
            style.side?.resolve(focused),
            style.side?.resolve(<WidgetState>{}),
          );
        }
      });

      test('${t.brightness}: fields focus in the ring colour, 2 px', () {
        final border =
            t.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
        expect(border.borderSide.color, ring);
        expect(border.borderSide.width, 2);
      });
    }
  });
}
