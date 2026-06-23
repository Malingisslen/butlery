/// Widget tests for [CommentImageAttachments] (BUT-1049): the thumbnail strip
/// shown under a comment that carries image attachments, plus the tap-to-open
/// full-screen viewer.
///
/// These assert rendering BEHAVIOUR (how many thumbnails for N urls, nothing
/// for an empty list, tapping a thumbnail opens a viewer), NOT pixel
/// appearance, so they need no human visual verification. CachedNetworkImage
/// renders its placeholder synchronously in tests — no network mocking needed.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/recipe/comment_image_attachments.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('empty list renders nothing (no thumbnail strip)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const CommentImageAttachments(imageUrls: [])),
    );

    // The shrink-to-nothing contract: no images, no tappable thumbnails.
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(
      find.byType(InkWell),
      findsNothing,
      reason: 'an empty attachment list must render no tappable thumbnails',
    );
  });

  testWidgets('renders one tappable thumbnail per url', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const CommentImageAttachments(
          imageUrls: [
            'https://example.test/a.jpg',
            'https://example.test/b.jpg',
            'https://example.test/c.jpg',
          ],
        ),
      ),
    );

    expect(
      find.byType(CachedNetworkImage),
      findsNWidgets(3),
      reason: 'one thumbnail image per attachment url',
    );
    expect(
      find.byType(InkWell),
      findsNWidgets(3),
      reason: 'each thumbnail must be independently tappable',
    );
  });

  testWidgets('tapping a thumbnail opens a full-screen viewer', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const CommentImageAttachments(
          imageUrls: [
            'https://example.test/a.jpg',
            'https://example.test/b.jpg',
          ],
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    // The viewer's loading placeholder is a CircularProgressIndicator (an
    // infinite animation) so pumpAndSettle would time out — pump fixed frames
    // to let the dialog route push in.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The viewer is a fullscreen Dialog carrying a swipeable PageView and a
    // close affordance — proves the tap routed into the viewer, not a no-op.
    expect(
      find.byType(Dialog),
      findsOneWidget,
      reason: 'tapping a thumbnail must open the full-screen viewer dialog',
    );
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
