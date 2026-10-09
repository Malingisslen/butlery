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
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/recipe/cook_snap_gallery.dart';
import 'package:butlery/widgets/recipe/cook_snap_photo_carousel.dart';

import '../../test_support/semantics_announcement.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  theme: theme,
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
        await tester.pumpWidget(
          _wrap(
            const CookSnapPhotoCarousel(photoUrls: ['https://x/a.jpg']),
          ),
        );

        // The single-photo branch must NOT build a swipeable carousel...
        expect(
          find.byType(PageView),
          findsNothing,
          reason: 'one photo should degrade to a plain image, not a PageView',
        );
        // ...and must NOT show the "current/total" counter badge.
        expect(
          find.text('1/1'),
          findsNothing,
          reason: 'a single-photo snap gets no counter badge',
        );
      },
    );

    testWidgets(
      'multi-photo album renders a PageView plus the current/total counter',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CookSnapPhotoCarousel(
              photoUrls: [
                'https://x/a.jpg',
                'https://x/b.jpg',
                'https://x/c.jpg',
              ],
            ),
          ),
        );

        // The >1 branch is the swipeable carousel.
        expect(
          find.byType(PageView),
          findsOneWidget,
          reason: 'multiple photos must render a swipeable PageView',
        );
        // Counter starts on page 1 of 3 (cookSnapPhotoCounter = "{current}/{total}").
        expect(
          find.text('1/3'),
          findsOneWidget,
          reason: 'the counter badge must show the current/total page',
        );
      },
    );

    testWidgets('a multi-photo album announces its position exactly once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const CookSnapPhotoCarousel(
            photoUrls: [
              'https://x/a.jpg',
              'https://x/b.jpg',
              'https://x/c.jpg',
            ],
          ),
        ),
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(CookSnapPhotoCarousel)),
      );
      final node = find.bySemanticsLabel(
        RegExp(RegExp.escape(l10n.a11yCookSnapPhotoCarousel(1, 3))),
      );
      // The visible "1/3" badge repeats the position in different words, so
      // only an exact list catches it being read after the label.
      expect(announcedLines(tester, node), [
        l10n.a11yCookSnapPhotoCarousel(1, 3),
      ]);
      handle.dispose();
    });

    testWidgets(
      'swiping the multi-photo carousel advances the counter to the next page',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CookSnapPhotoCarousel(
              photoUrls: [
                'https://x/a.jpg',
                'https://x/b.jpg',
                'https://x/c.jpg',
              ],
            ),
          ),
        );

        // Sanity: the carousel starts on page 1 of 3.
        expect(
          find.text('1/3'),
          findsOneWidget,
          reason: 'the counter must start on the first page before swiping',
        );

        // Drag the PageView left by a full page to advance to the next photo.
        // onPageChanged updates _index, which the counter badge reads.
        await tester.drag(find.byType(PageView), const Offset(-500, 0));
        await tester.pumpAndSettle();

        expect(
          find.text('2/3'),
          findsOneWidget,
          reason: 'swiping forward must advance the counter to the next page',
        );
        expect(
          find.text('1/3'),
          findsNothing,
          reason: 'the previous page counter must no longer be shown',
        );
      },
    );

    testWidgets(
      'zero-photo album renders nothing — no PageView and no counter',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CookSnapPhotoCarousel(photoUrls: []),
          ),
        );

        // The empty branch returns SizedBox.shrink(): no swipeable carousel...
        expect(
          find.byType(PageView),
          findsNothing,
          reason: 'an empty album must not build a PageView',
        );
        // ...and no counter badge of any page form.
        expect(
          find.textContaining('/'),
          findsNothing,
          reason: 'an empty album must not render a current/total counter',
        );
      },
    );
  });

  // B83-3: the page counter and the album badge are on
  // overlay.paperCard (rgba(245,244,237,0.54)) with ink text (surface.ink
  // #24382C); the photo shows through the tile.
  group('photo badges on overlay.paperCard with ink text (B83-3)', () {
    final modes = [
      ('light', AppTheme.lightTheme, AppColors.cardWhite54),
      ('dark', AppTheme.darkTheme, AppColorsDark.cardWhite54),
    ];
    const ink = Color(0xFF24382C);

    for (final (name, theme, tile) in modes) {
      testWidgets('$name: the carousel counter badge', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CookSnapPhotoCarousel(
              photoUrls: ['https://x/a.jpg', 'https://x/b.jpg'],
            ),
            theme: theme,
          ),
        );

        final counter = find.text('1/2');
        final box = tester.widget<Container>(
          find.ancestor(of: counter, matching: find.byType(Container)).first,
        );
        expect(box.color, tile);
        expect(tester.widget<Text>(counter).style!.color, ink);
      });

      testWidgets('$name: the gallery album badge', (tester) async {
        await tester.pumpWidget(
          _wrap(
            CookSnapGallery(
              snaps: [
                _snap(photoUrls: const ['https://x/a.jpg', 'https://x/b.jpg']),
              ],
              isLoading: false,
              isUploading: false,
              onAdd: () {},
              onDelete: (_) {},
              onReport: (_) {},
              currentUserId: 'user-1',
            ),
            theme: theme,
          ),
        );
        await tester.pump();

        final count = find.text('2');
        final box = tester.widget<Container>(
          find.ancestor(of: count, matching: find.byType(Container)).first,
        );
        expect(box.color, tile);
        expect(tester.widget<Text>(count).style!.color, ink);
        expect(
          tester.widget<ButleryIcon>(find.byIcon(ButleryIcons.image)).color,
          ink,
        );
      });
    }
  });

  group('CookSnapGallery photo-count badge (BUT-949)', () {
    Widget gallery(List<CookSnap> snaps) => _wrap(
      CookSnapGallery(
        snaps: snaps,
        isLoading: false,
        isUploading: false,
        onAdd: () {},
        onDelete: (_) {},
        onReport: (_) {},
        currentUserId: 'user-1',
      ),
    );

    testWidgets(
      'the thumbnail announces the actor once and offers long-press',
      (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(
            CookSnapGallery(
              snaps: [
                _snap(photoUrls: const ['https://x/a.jpg']),
              ],
              isLoading: false,
              isUploading: false,
              onAdd: () {},
              onDelete: (_) {},
              onReport: (_) {},
              currentUserId: 'someone-else',
            ),
          ),
        );
        await tester.pump();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CookSnapGallery)),
        );
        final node = find.bySemanticsLabel(
          RegExp(RegExp.escape(l10n.a11yCookSnapOptions)),
        );
        final lines = announcedLines(tester, node);
        expect(lines.first, l10n.a11yCookSnapOptions);
        expect(
          lines.where((l) => l.contains('Kalle')),
          hasLength(1),
          reason:
              'the visible name is the only place the actor is read: $lines',
        );
        final data = tester.getSemantics(node).getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.longPress), isTrue);
        handle.dispose();
      },
    );

    testWidgets('single-photo thumbnail shows NO album count badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        gallery([
          _snap(photoUrls: const ['https://x/a.jpg']),
        ]),
      );
      await tester.pump();

      // The album badge is an ButleryIcons.image marker — absent for one photo.
      expect(
        find.byIcon(ButleryIcons.image),
        findsNothing,
        reason: 'a legacy single-photo snap must not show an album badge',
      );
    });

    testWidgets('multi-photo thumbnail shows the album count badge with N', (
      tester,
    ) async {
      await tester.pumpWidget(
        gallery([
          _snap(
            photoUrls: const [
              'https://x/a.jpg',
              'https://x/b.jpg',
              'https://x/c.jpg',
            ],
          ),
        ]),
      );
      await tester.pump();

      expect(
        find.byIcon(ButleryIcons.image),
        findsOneWidget,
        reason: 'a multi-photo album thumbnail must show the count badge',
      );
      expect(
        find.text('3'),
        findsOneWidget,
        reason: 'the badge must show the album photo count',
      );
    });
  });
}
