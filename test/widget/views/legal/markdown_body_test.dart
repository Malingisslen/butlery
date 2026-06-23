import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/views/legal/markdown_body.dart';

void main() {
  Future<void> pump(WidgetTester tester, String data) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: MarkdownBody(data: data)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The whole point of this widget: render Markdown structure instead of
  // dumping the raw source (the old SelectableText behaviour).
  testWidgets('strips heading/bold markers from the rendered text', (
    tester,
  ) async {
    await pump(tester, '# Rubrik\n\nLite **fet** text.');

    // Header text shows without the leading '# '.
    expect(find.textContaining('Rubrik'), findsWidgets);
    // No literal markdown markers survive in any rendered string.
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('# '), findsNothing);
    // The bold word is still part of the rendered paragraph.
    expect(find.textContaining('fet'), findsWidgets);
  });

  testWidgets('renders bullets with a marker and no leading dash', (
    tester,
  ) async {
    await pump(tester, '- första\n- andra');

    expect(find.textContaining('•'), findsWidgets);
    expect(find.textContaining('första'), findsWidgets);
    // The raw "- " bullet source must not leak through.
    expect(find.textContaining('- första'), findsNothing);
  });

  testWidgets('turns [label](url) into a tappable link span (recognizer)', (
    tester,
  ) async {
    await pump(tester, 'Se [vår policy](https://butlery.se/x) här.');

    // The label renders; the URL and bracket syntax do not.
    expect(find.textContaining('vår policy'), findsWidgets);
    expect(find.textContaining(']('), findsNothing);
    expect(find.textContaining('https://butlery.se'), findsNothing);

    // Prove a gesture recognizer was attached to the link span (i.e. it's
    // interactive, not just styled text).
    final richTexts = tester.widgetList<Text>(find.byType(Text));
    var foundRecognizer = false;
    for (final st in richTexts) {
      st.textSpan?.visitChildren((span) {
        if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
          foundRecognizer = true;
        }
        return true;
      });
    }
    expect(
      foundRecognizer,
      isTrue,
      reason: 'a link must carry a TapGestureRecognizer',
    );
  });
}
