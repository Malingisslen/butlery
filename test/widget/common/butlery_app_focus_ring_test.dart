/// BUT-2148: the app-level focus ring marks a focused control that draws no
/// ring of its own, and stays away where a control rings itself.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/keyboard/app_keyboard_layer.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_app_focus_ring.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';

Future<void> _pump(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: ButleryAppFocusRing.builder,
      home: Scaffold(body: Center(child: body)),
    ),
  );
}

/// The app-level ring's painter, or null when it draws nothing.
CustomPainter? _appRing(WidgetTester tester) => tester
    .renderObject<RenderCustomPaint>(
      find
          .descendant(
            of: find.byType(ButleryAppFocusRing),
            matching: find.byType(CustomPaint),
          )
          .first,
    )
    .foregroundPainter;

Future<void> _tab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('a focused InkWell without its own ring gets the ring', (
    tester,
  ) async {
    await _pump(
      tester,
      InkWell(onTap: () {}, child: const SizedBox(width: 120, height: 48)),
    );
    expect(_appRing(tester), isNull);
    await _tab(tester);
    expect(_appRing(tester), isNotNull);
  });

  testWidgets('a control in ButleryControlFocus keeps only its own ring', (
    tester,
  ) async {
    await _pump(
      tester,
      ButleryControlFocus(child: Checkbox(value: false, onChanged: (_) {})),
    );
    await _tab(tester);
    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(
      tester
          .getSemantics(find.byType(Checkbox))
          .getSemanticsData()
          .flagsCollection
          .isFocused,
      ui.Tristate.isTrue,
    );
    handle.dispose();
    expect(_appRing(tester), isNull);
  });

  testWidgets('a themed button keeps only its own ring', (tester) async {
    await _pump(
      tester,
      FilledButton(onPressed: () {}, child: const Text('Ok')),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    // Frame by frame: the button's ring shows a frame after its focus, and
    // the app ring must not fill that frame.
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump();
      expect(_appRing(tester), isNull, reason: 'frame $frame');
    }
    expect(ButleryFocusRing.showing.value, 1);
  });

  testWidgets('a text field is ringed around its input box', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        width: 300,
        child: TextField(
          decoration: InputDecoration(
            labelText: 'Namn',
            helperText: 'Hjälp',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
    await _tab(tester);
    // The helper line is part of the field but outside its input box: the
    // ring ends above it.
    final field = tester.getRect(find.byType(TextField));
    final helper = tester.getRect(find.text('Hjälp'));
    final ring = _appRing(tester);
    expect(ring, isNotNull);
    final canvas = _RectCanvas();
    ring!.paint(canvas, Size.zero);
    final drawn = canvas.rects;
    expect(drawn, hasLength(1));
    final inner = drawn.single.deflate(ButleryFocusRing.inflate);
    expect(inner.top, field.top);
    expect(inner.left, field.left);
    expect(inner.right, field.right);
    expect(inner.bottom, lessThan(helper.top));
    expect(inner.bottom, greaterThan(field.top + 40));
  });

  testWidgets('the app keyboard layer is not ringed when it holds focus', (
    tester,
  ) async {
    late BuildContext inside;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => ButleryAppFocusRing(
          child: AppKeyboardLayer(
            child: Builder(
              builder: (context) {
                inside = context;
                return child!;
              },
            ),
          ),
        ),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    final layer = Focus.of(inside);
    layer.requestFocus();
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(layer));
    expect(_appRing(tester), isNull);
  });

  testWidgets('touch focus draws no ring', (tester) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    final node = FocusNode();
    addTearDown(node.dispose);
    await _pump(
      tester,
      InkWell(
        focusNode: node,
        onTap: () {},
        child: const SizedBox(width: 120, height: 48),
      ),
    );
    node.requestFocus();
    await tester.pumpAndSettle();
    expect(node.hasPrimaryFocus, isTrue);
    expect(_appRing(tester), isNull);
  });

  testWidgets('a focus node that skips traversal is not ringed', (
    tester,
  ) async {
    final node = FocusNode(skipTraversal: true);
    addTearDown(node.dispose);
    await _pump(
      tester,
      Focus(focusNode: node, child: const SizedBox(width: 200, height: 200)),
    );
    node.requestFocus();
    await tester.pumpAndSettle();
    expect(node.hasPrimaryFocus, isTrue);
    expect(_appRing(tester), isNull);
  });
}

/// Records the rectangles a painter draws.
class _RectCanvas extends Fake implements Canvas {
  final List<Rect> rects = [];

  @override
  void drawRect(Rect rect, Paint paint) => rects.add(rect);
}
