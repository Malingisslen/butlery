/// The week generator's prompt box: its heading, "Vad vill du ha för meny?",
/// wraps under large text instead of running off the box (BUT-2192).
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/menu/menu_content_widgets.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('MenuContentWidgets.buildPromptInput — 320 dp and 200 % text', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    testWidgets('the heading stays inside the box', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 2.0,
            maxScaleFactor: 2.0,
            child: Builder(
              builder: (context) => MenuContentWidgets.buildPromptInput(
                context,
                controller: controller,
                isGenerating: false,
                onClear: () {},
                onChanged: () {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final heading = find.text('Vad vill du ha för meny?');
      expect(heading, findsOneWidget);
      // The input spans the box's content width, so its right edge is the
      // edge the heading must not pass.
      expect(
        tester.getRect(heading).right,
        lessThanOrEqualTo(tester.getRect(find.byType(StyledInput)).right),
      );
      // Taller than one line at unlimited width: the heading wraps, it is
      // not cut to one line.
      final paragraph = tester.renderObject<RenderParagraph>(heading);
      expect(
        paragraph.size.height,
        greaterThan(paragraph.getMaxIntrinsicHeight(double.infinity)),
      );
    });
  });
}
