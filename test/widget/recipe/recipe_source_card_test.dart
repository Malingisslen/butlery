import 'package:butlery/core/utils/external_link.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/recipe_detail/borrowed_image_frame.dart';
import 'package:butlery/views/recipe_detail/recipe_source_card.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../test_support/base_unit_test.dart';

const _source = 'https://www.matbloggen.se/recept/laxpudding';
const _ownPhoto =
    'https://firebasestorage.googleapis.com/v0/b/butlery-prod.firebasestorage.app/o/users%2Fu1%2Fa.jpg?alt=media';

/// Records how url_launcher was asked to open each page.
class _RecordingUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<(String, PreferredLaunchMode)> launched = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add((url, options.mode));
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      locale: const Locale('sv'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

Widget _photo() => Semantics(
  label: 'Visa receptbild i fullskärm',
  button: true,
  child: const ColoredBox(color: Color(0xFFD9C9A3)),
);

Widget _hero(String imageUrl, String? sourceUrl) => SizedBox(
  width: 360,
  height: 200,
  child: BorrowedImageFrame(
    imageUrl: imageUrl,
    sourceUrl: sourceUrl,
    child: _photo(),
  ),
);

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  group('RecipeSourceCard', () {
    testWidgets('names site and author and offers the original', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const RecipeSourceCard(sourceUrl: _source, sourceAuthor: 'Anna Berg'),
      );

      expect(find.text('Hämtat från matbloggen.se'), findsOneWidget);
      expect(find.text('Av Anna Berg'), findsOneWidget);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            'Receptet är hämtat från matbloggen.se, av Anna Berg',
          ),
        ),
        isNotNull,
      );
      final button = find.byKey(const ValueKey('recipe-source-open-original'));
      expect(
        tester.getSemantics(button),
        matchesSemantics(
          label: 'Öppna originalet',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      handle.dispose();
    });

    testWidgets('Öppna originalet opens the page in a tab over the app', (
      tester,
    ) async {
      final original = UrlLauncherPlatform.instance;
      final launcher = _RecordingUrlLauncher();
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = original);

      await _pump(tester, const RecipeSourceCard(sourceUrl: _source));
      await tester.tap(
        find.byKey(const ValueKey('recipe-source-open-original')),
      );
      await tester.pump();

      expect(launcher.launched, [
        (_source, PreferredLaunchMode.inAppBrowserView),
      ]);
    });

    test('other links still leave the app', () async {
      final original = UrlLauncherPlatform.instance;
      final launcher = _RecordingUrlLauncher();
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = original);

      await openExternalLink(Uri.parse(_source));

      expect(
        launcher.launched.single.$2,
        PreferredLaunchMode.externalApplication,
      );
    });

    testWidgets('without an author it names only the site', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const RecipeSourceCard(sourceUrl: _source));

      expect(find.textContaining('Av '), findsNothing);
      expect(
        find.bySemanticsLabel('Receptet är hämtat från matbloggen.se'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a video source keeps its video mark', (tester) async {
      await _pump(
        tester,
        const RecipeSourceCard(sourceUrl: 'https://youtu.be/abc123'),
      );

      expect(find.byIcon(ButleryIcons.video), findsOneWidget);
      expect(find.byIcon(ButleryIcons.globe), findsNothing);
    });

    testWidgets('fits at 1.4x text in dark mode', (tester) async {
      await _pump(
        tester,
        const SizedBox(
          width: 320,
          child: RecipeSourceCard(
            sourceUrl: _source,
            sourceAuthor: 'Anna Berg och Lisa Ek',
          ),
        ),
        textScale: 1.4,
        theme: AppTheme.darkTheme,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('BorrowedImageFrame', () {
    testWidgets('a borrowed photo gets a credit that is its own node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _hero('https://matbloggen.se/bilder/lax.jpg', _source),
      );

      expect(find.text('Bild: matbloggen.se'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(BorrowedImageCredit)),
        matchesSemantics(label: 'Bilden visas från matbloggen.se'),
      );
      // The photo's own action is untouched by the credit.
      expect(
        find.bySemanticsLabel('Visa receptbild i fullskärm'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the user\'s own photo runs edge to edge, uncredited', (
      tester,
    ) async {
      await _pump(tester, _hero(_ownPhoto, _source));

      expect(find.byType(BorrowedImageCredit), findsNothing);
      expect(
        tester.getSize(find.byType(ColoredBox).last),
        const Size(360, 200),
      );
    });

    testWidgets('no web source, no credit', (tester) async {
      await _pump(
        tester,
        _hero('https://matbloggen.se/bilder/lax.jpg', 'Butlerys receptsamling'),
      );

      expect(find.byType(BorrowedImageCredit), findsNothing);
    });

    test('a gallery is credited when any photo in it is borrowed', () {
      expect(
        BorrowedImageCredit.forGallery(
          imageUrls: [_ownPhoto, 'https://matbloggen.se/bilder/lax.jpg'],
          sourceUrl: _source,
        )?.site,
        'matbloggen.se',
      );
      expect(
        BorrowedImageCredit.forGallery(
          imageUrls: [_ownPhoto],
          sourceUrl: _source,
        ),
        isNull,
      );
      expect(
        BorrowedImageCredit.forGallery(
          imageUrls: ['https://matbloggen.se/bilder/lax.jpg'],
          sourceUrl: 'Butlerys receptsamling',
        ),
        isNull,
      );
    });

    testWidgets('the credit fits at 1.4x text', (tester) async {
      await _pump(
        tester,
        _hero(
          'https://cdn.example.com/lax.jpg',
          'https://en-mycket-lang-receptsajt-med-langt-namn.example.com/recept',
        ),
        textScale: 1.4,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(BorrowedImageCredit), findsOneWidget);
    });
  });
}
