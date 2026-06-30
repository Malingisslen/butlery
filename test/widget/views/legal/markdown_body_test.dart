import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:butlery/views/legal/markdown_body.dart';

/// Captures the URLs handed to url_launcher so a tapped legal-doc link's
/// outcome can be asserted without opening a real browser.
class _RecordingUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<String> launched = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

void main() {
  late _RecordingUrlLauncher launcher;
  late UrlLauncherPlatform original;

  setUp(() {
    original = UrlLauncherPlatform.instance;
    launcher = _RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = original;
  });

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

  testWidgets('turns [label](url) into a tappable link that opens the url', (
    tester,
  ) async {
    // BUT-1446: links render as WidgetSpan -> Semantics(link:) ->
    // GestureDetector -> Text(label). The visible text is the label; the URL
    // and bracket syntax never render. Interactivity is proven by driving a
    // real tap through the widget (the old TapGestureRecognizer is gone) and
    // asserting url_launcher received the underlying URL.
    await pump(tester, 'Se [vår policy](https://butlery.se/x) här.');

    // The label renders; the URL and bracket syntax do not.
    expect(find.text('vår policy'), findsOneWidget);
    expect(find.textContaining(']('), findsNothing);
    expect(find.textContaining('https://butlery.se'), findsNothing);

    await tester.tap(find.text('vår policy'));
    await tester.pump();

    expect(launcher.launched, contains('https://butlery.se/x'));
  });

  testWidgets('link exposes a link role with the visible label as its name', (
    tester,
  ) async {
    // BUT-1446 core win: screen readers announce the legal-doc link as a link
    // (role) named by its visible label — not as generic styled text.
    final handle = tester.ensureSemantics();
    await pump(tester, 'Se [vår policy](https://butlery.se/x) här.');

    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp(r'vår policy')),
    );
    expect(node.label, contains('vår policy'));
    expect(
      node.flagsCollection.isLink,
      isTrue,
      reason: 'the markdown link must carry the link role',
    );

    handle.dispose();
  });
}
