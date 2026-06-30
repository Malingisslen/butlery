// BUT-962: regex behaviour test for LinkifiedText.
// Pins the conservative URL-matching pattern so future refactors of
// `_urlRegex` don't silently change what counts as a link.
//
// BUT-1446: links now render as a WidgetSpan wrapping
// Semantics(link:) -> GestureDetector -> Text(url). The visible link text is
// the URL itself, tapping it calls url_launcher's launchUrl in
// externalApplication mode, and the link exposes a link role + accessible
// name (context.l10n.a11yLinkTo(url)). Tests locate links via the rendered
// Text / Semantics and drive taps through the widget, never via a span
// recognizer (which no longer exists).

import 'package:butlery/widgets/common/linkified_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

/// Captures the URLs handed to url_launcher so a tapped link's outcome can be
/// asserted without opening a real browser. Registered as the platform
/// instance so production's `launchUrl(...)` resolves through it.
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

  group('LinkifiedText.from (BUT-962)', () {
    testWidgets('renders plain Text when no URLs', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: LinkifiedText.from('Just a comment about cooking'),
        ),
      );
      // Fast path returns plain Text (not Text.rich) — assert the
      // displayed text matches.
      expect(find.text('Just a comment about cooking'), findsOneWidget);
    });

    testWidgets('linkifies a single URL in the middle of a sentence', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: LinkifiedText.from(
            'Try https://serious-eats.com for the technique.',
          ),
        ),
      );
      // The non-URL chunks stay plain TextSpans inside Text.rich; the URL is
      // its own rendered Text inside the link WidgetSpan.
      expect(find.textContaining('Try '), findsWidgets);
      expect(find.text('https://serious-eats.com'), findsOneWidget);
      expect(find.textContaining('for the technique.'), findsWidgets);
    });

    testWidgets('trailing sentence punctuation stays out of the URL', (
      tester,
    ) async {
      // Regex deliberately stops before `.`, `,`, `;`, `:`, `!`, `?`, `)`,
      // `]` when followed by whitespace or EOS. The dot at the end below
      // is the sentence terminator — must not get pulled into the URL.
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: LinkifiedText.from('See https://example.com.'),
        ),
      );
      // The link's visible Text is exactly the URL without the terminating
      // dot; the dot survives as trailing plain text.
      expect(find.text('https://example.com'), findsOneWidget);
      expect(find.textContaining('.'), findsWidgets);
    });

    testWidgets('handles two URLs in one comment', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: LinkifiedText.from(
            'Both https://a.com and https://b.com work.',
          ),
        ),
      );
      expect(find.text('https://a.com'), findsOneWidget);
      expect(find.text('https://b.com'), findsOneWidget);
    });

    testWidgets('non-URL "https" mentions in prose stay plain', (tester) async {
      // The protocol requires `://`. A bare word "https" or "http" stays
      // un-linkified.
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: LinkifiedText.from('We use https everywhere.'),
        ),
      );
      expect(find.text('We use https everywhere.'), findsOneWidget);
    });

    testWidgets('tapping a linkified URL opens it via url_launcher', (
      tester,
    ) async {
      // BUT-1446: the recognizer is gone — the interactive contract is now
      // driven through the rendered link widget. Tapping must hand the exact
      // URL to launchUrl (externalApplication mode is the production default).
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: LinkifiedText.from('Open https://butlery.se/recipe now.'),
        ),
      );

      await tester.tap(find.text('https://butlery.se/recipe'));
      await tester.pump();

      expect(launcher.launched, contains('https://butlery.se/recipe'));
    });

    testWidgets('linkified URL exposes a link role and accessible name', (
      tester,
    ) async {
      // BUT-1446 core win: screen readers must announce the URL as a link
      // (not generic text) with a name. The Swedish a11y label is
      // "Länk till {url}".
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: LinkifiedText.from('Read https://butlery.se/policy please.'),
        ),
      );

      // The link's accessible name ("Länk till {url}") is exposed, and the
      // semantics node carrying it has the link role. (Text.rich merges its
      // spans into one node; the link's a11y label and isLink flag survive
      // that merge — both are absent in the pre-BUT-1446 recognizer markup.)
      final linkNameMatcher = RegExp(r'Länk till https://butlery\.se/policy');
      final node = tester.getSemantics(find.bySemanticsLabel(linkNameMatcher));
      expect(node.label, contains('Länk till https://butlery.se/policy'));
      expect(
        node.flagsCollection.isLink,
        isTrue,
        reason: 'the linkified URL must carry the link role',
      );

      handle.dispose();
    });
  });
}
