/// BUT-2376: the one fullscreen photo viewer. Every photo in the app opens
/// it, so the cases the old copies drew on their own (a chat photo's single
/// image, an admin screenshot that CachedNetworkImage cannot load) are pinned
/// here.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/image/fullscreen_image_viewer.dart';

final sv = AppLocalizationsSv();

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.lightTheme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: home,
);

Widget _drawn(BuildContext context, int index) =>
    Text('drawn $index', key: ValueKey('drawn.$index'));

void main() {
  testWidgets('a single photo is titled Bild, not 1 / 1', (tester) async {
    await tester.pumpWidget(
      _app(
        const FullscreenImageViewer(
          imageUrls: ['https://invalid.invalid/a.jpg'],
          photoBuilder: _drawn,
        ),
      ),
    );
    await tester.pump();

    expect(find.text(sv.imageTitle), findsOneWidget);
    expect(find.text('1 / 1'), findsNothing);
  });

  testWidgets('a photoBuilder draws the photo instead of the network image', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const FullscreenImageViewer(
          imageUrls: ['https://invalid.invalid/a.jpg'],
          photoBuilder: _drawn,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('drawn.0')), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('open pushes the viewer on the given page as a modal, and the '
      'X closes it', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => FullscreenImageViewer.open(
              context,
              const [
                'https://invalid.invalid/a.jpg',
                'https://invalid.invalid/b.jpg',
              ],
              initialIndex: 1,
              photoBuilder: _drawn,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenImageViewer), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('drawn.1')), findsOneWidget);
    final route = ModalRoute.of(
      tester.element(find.byType(FullscreenImageViewer)),
    )!;
    expect((route as MaterialPageRoute).fullscreenDialog, isTrue);

    await tester.tap(find.byTooltip(sv.commonClose));
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenImageViewer), findsNothing);
  });

  testWidgets('a caption is drawn on the ink band; without one there is no '
      'band', (tester) async {
    Finder band() => find.byWidgetPredicate(
      (w) => w is Container && w.color == AppColors.overlayBlack60,
    );
    await tester.pumpWidget(
      _app(
        const FullscreenImageViewer(
          imageUrls: ['https://invalid.invalid/a.jpg'],
          photoBuilder: _drawn,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('drawn.0')), findsOneWidget);
    expect(band(), findsNothing);

    await tester.pumpWidget(
      _app(
        const FullscreenImageViewer(
          imageUrls: ['https://invalid.invalid/a.jpg'],
          caption: 'Söndagsmiddag',
          photoBuilder: _drawn,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(of: band(), matching: find.text('Söndagsmiddag')),
      findsOneWidget,
    );
  });

  testWidgets('open with no photos pushes nothing', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => FullscreenImageViewer.open(context, const []),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenImageViewer), findsNothing);
  });
}
