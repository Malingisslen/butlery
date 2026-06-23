/// Widget tests for EditIndicatorWidget.
///
/// PulseDot's infinite repeat animation breaks pumpAndSettle. We wrap
/// the test widget in MediaQuery(disableAnimations: true) so the inner
/// AnimationControllers collapse to Duration.zero, letting a single
/// pump deliver the final state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/indicators/edit_indicator_widget.dart';
import 'package:butlery/widgets/common/indicators/pulse_dot.dart';

Widget _wrap(Widget child, {bool disableAnimations = true}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('renders "<editorName> redigerar <editingWhat>" composite text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const EditIndicatorWidget(
          editorName: 'Alice',
          editingWhat: 'ingredients',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Alice redigerar ingredients'), findsOneWidget);
  });

  testWidgets('contains a PulseDot for the live-presence animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const EditIndicatorWidget(
          editorName: 'Alice',
          editingWhat: 'instructions',
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(PulseDot), findsOneWidget);
  });

  testWidgets('PulseDot uses theme primary color when no color provided', (
    tester,
  ) async {
    final theme = ThemeData(
      colorScheme: const ColorScheme.light(primary: Colors.indigo),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: EditIndicatorWidget(
              editorName: 'Alice',
              editingWhat: 'recipe',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final dot = tester.widget<PulseDot>(find.byType(PulseDot));
    expect(dot.color, Colors.indigo);
  });

  testWidgets('explicit color overrides theme', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const EditIndicatorWidget(
          editorName: 'Alice',
          editingWhat: 'recipe',
          color: Colors.orange,
        ),
      ),
    );
    await tester.pump();
    final dot = tester.widget<PulseDot>(find.byType(PulseDot));
    expect(dot.color, Colors.orange);
  });

  testWidgets('isVisible=true reaches full opacity after animation duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const EditIndicatorWidget(
          editorName: 'Alice',
          editingWhat: 'recipe',
        ),
      ),
    );
    // Let the fade-in (default 300ms) complete.
    await tester.pump(const Duration(milliseconds: 500));
    final opacity = tester.widget<Opacity>(find.byType(Opacity).first).opacity;
    expect(opacity, closeTo(1.0, 0.01));
  });

  testWidgets('isVisible=false stays at zero opacity', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const EditIndicatorWidget(
          editorName: 'Alice',
          editingWhat: 'recipe',
          isVisible: false,
        ),
      ),
    );
    await tester.pump();
    final opacity = tester.widget<Opacity>(find.byType(Opacity).first).opacity;
    expect(opacity, closeTo(0.0, 0.01));
  });

  testWidgets('flipping isVisible false → true reaches full opacity', (
    tester,
  ) async {
    Widget build(bool visible) => _wrap(
      EditIndicatorWidget(
        editorName: 'A',
        editingWhat: 'r',
        isVisible: visible,
      ),
    );

    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<Opacity>(find.byType(Opacity).first).opacity,
      closeTo(0.0, 0.01),
    );

    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<Opacity>(find.byType(Opacity).first).opacity,
      closeTo(1.0, 0.01),
    );
  });

  testWidgets('flipping isVisible true → false reaches zero opacity', (
    tester,
  ) async {
    Widget build(bool visible) => _wrap(
      EditIndicatorWidget(
        editorName: 'A',
        editingWhat: 'r',
        isVisible: visible,
      ),
    );

    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<Opacity>(find.byType(Opacity).first).opacity,
      closeTo(0.0, 0.01),
    );
  });

  testWidgets('disposes its AnimationController cleanly on removal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const EditIndicatorWidget(
          editorName: 'Alice',
          editingWhat: 'recipe',
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    expect(tester.takeException(), isNull);
  });
}
