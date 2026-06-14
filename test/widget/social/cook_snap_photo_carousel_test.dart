/// Widget tests for the BUT-949 cook-snap photo carousel + gallery badge.
///
/// Intent: prove the render-branch decision the carousel makes — a single-photo
/// album degrades to a plain image with NO swipeable PageView and NO counter
/// badge, while a multi-photo album renders a PageView plus the "current/total"
/// counter. Also prove the gallery thumbnail only shows its photo-count badge
/// for multi-photo snaps. These are the exact branches a regression could flip
/// (e.g. always rendering a PageView, or showing a "1" badge on legacy snaps).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/widgets/recipe/cook_snap_gallery.dart';
import 'package:butlery/widgets/recipe/cook_snap_photo_carousel.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(body: child),
    );

CookSnap _snap({required List<String> photoUrls}) => CookSnap(
      id: 'snap-1',
      recipeId: 'recipe-1',
      userId: 'user-1',
      userDisplayName: 'Kalle',
      photoUrls: photoUrls,
      createdAt: DateTime(2026, 6, 14),
    );

void main() {
  group('CookSnapPhotoCarousel render branch (BUT-949)', () {
    testWidgets(
        'single-photo album renders a plain image — no PageView, no counter',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const CookSnapPhotoCarousel(photoUrls: ['https://x/a.jpg']),
      ));

      // The single-photo branch must NOT build a swipeable carousel...
      expect(find.byType(PageView), findsNothing,
          reason: 'one photo should degrade to a plain image, not a PageView');
      // ...and must NOT show the "current/total" counter badge.
      expect(find.text('1/1'), findsNothing,
          reason: 'a single-photo snap gets no counter badge');
    });

    testWidgets(
        'multi-photo album renders a PageView plus the current/total counter',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const CookSnapPhotoCarousel(
          photoUrls: ['https://x/a.jpg', 'https://x/b.jpg', 'https://x/c.jpg'],
        ),
      ));

      // The >1 branch is the swipeable carousel.
      expect(find.byType(PageView), findsOneWidget,
          reason: 'multiple photos must render a swipeable PageView');
      // Counter starts on page 1 of 3 (cookSnapPhotoCounter = "{current}/{total}").
      expect(find.text('1/3'), findsOneWidget,
          reason: 'the counter badge must show the current/total page');
    });
  });

  group('CookSnapGallery photo-count badge (BUT-949)', () {
    Widget gallery(List<CookSnap> snaps) => _wrap(CookSnapGallery(
          snaps: snaps,
          isLoading: false,
          isUploading: false,
          onAdd: () {},
          onDelete: (_) {},
          onReport: (_) {},
          currentUserId: 'user-1',
        ));

    testWidgets('single-photo thumbnail shows NO album count badge',
        (tester) async {
      await tester.pumpWidget(gallery([
        _snap(photoUrls: const ['https://x/a.jpg']),
      ]));
      await tester.pump();

      // The album badge is an Icons.collections marker — absent for one photo.
      expect(find.byIcon(Icons.collections), findsNothing,
          reason: 'a legacy single-photo snap must not show an album badge');
    });

    testWidgets('multi-photo thumbnail shows the album count badge with N',
        (tester) async {
      await tester.pumpWidget(gallery([
        _snap(photoUrls: const [
          'https://x/a.jpg',
          'https://x/b.jpg',
          'https://x/c.jpg',
        ]),
      ]));
      await tester.pump();

      expect(find.byIcon(Icons.collections), findsOneWidget,
          reason: 'a multi-photo album thumbnail must show the count badge');
      expect(find.text('3'), findsOneWidget,
          reason: 'the badge must show the album photo count');
    });
  });
}
