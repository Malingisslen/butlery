// BUT-2183 5f, decision B101 (2026-10-01, option A throughout): what the photo
// widgets draw, pinned in both modes.
//
//  1. the failed-upload "Ta bort" button is the red the photo grid and the
//     picker already draw; "Försök igen" is opaque paper with ink (B102)
//  4. the whole-photo upload scrim is overlay.inkStrong, the state circles on
//     it are opaque paper with an ink glyph (B102), the recipe-photo bottom
//     gradient is gone, the avatar initials sit on a solid raised disc, and
//     the off-photo bulk-action button is a normal raised button
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/image/avatar_image_widget.dart';
import 'package:butlery/widgets/image/components/upload_progress_widgets.dart';
import 'package:butlery/widgets/image/recipe_image_widget.dart';

import '../../infrastructure/helpers/base_widget_test.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

Widget _themed(ThemeData theme, Widget child) => createLocalizedTestApp(
  child: Theme(data: theme, child: child),
);

double _luminance(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _contrast(Color fg, Color bg) {
  final a = _luminance(fg);
  final b = _luminance(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

BoxDecoration _fillAround(WidgetTester tester, Finder of) => tester
    .widgetList<Container>(
      find.ancestor(of: of, matching: find.byType(Container)),
    )
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((d) => d.color != null);

Color? _textColor(WidgetTester tester, Finder of) =>
    tester.widget<Text>(of).style?.color;

Widget _overlay(ImageUploadStatus status, {bool withActions = true}) =>
    SizedBox(
      width: 600,
      height: 400,
      child: Stack(
        children: [
          UploadProgressWidgets.buildUploadProgressOverlay(
            status: status,
            imageUrl: 'https://example.com/x.jpg',
            borderRadius: BorderRadius.zero,
            onRetryUpload: withActions ? (_) {} : null,
            onCancelUpload: withActions ? (_) {} : null,
          ),
        ],
      ),
    );

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;

    group('B101 photo widgets ($name)', () {
      testWidgets('1: failed upload "Ta bort" is red with onError, '
          '"Försök igen" is opaque paper with ink', (tester) async {
        const failed = ImageUploadStatus(
          state: ImageUploadState.failed,
          error: 'network failure',
        );
        await tester.pumpWidget(_themed(theme, _overlay(failed)));

        final remove = find.text('Ta bort');
        expect(_fillAround(tester, remove).color, cs.error);
        expect(_textColor(tester, remove), cs.onError);
        expect(_contrast(cs.onError, cs.error), greaterThanOrEqualTo(4.5));
        final removeIcon = tester.widget<ButleryIcon>(
          find.descendant(
            of: find.ancestor(of: remove, matching: find.byType(Row)).first,
            matching: find.byType(ButleryIcon),
          ),
        );
        expect(removeIcon.color, cs.onError);

        final retry = find.text('Försök igen');
        final retryFill = _fillAround(tester, retry).color!;
        expect(retryFill, AppModeColors.surfacePaperOnPhoto());
        expect(retryFill.a, 1.0);
        expect(_textColor(tester, retry), cs.primary);
        expect(_contrast(cs.primary, retryFill), greaterThanOrEqualTo(10.5));
        final retryIcon = tester.widget<ButleryIcon>(
          find.descendant(
            of: find.ancestor(of: retry, matching: find.byType(Row)).first,
            matching: find.byType(ButleryIcon),
          ),
        );
        expect(retryIcon.color, cs.primary);
      });

      testWidgets('B102: the status card is opaque paper with ink text, so '
          'the pair does not depend on the photo', (tester) async {
        const uploading = ImageUploadStatus(
          state: ImageUploadState.failed,
          error: 'network failure',
          totalBytes: 2 * 1024 * 1024,
        );
        await tester.pumpWidget(_themed(theme, _overlay(uploading)));

        final label = find.text(uploading.statusDescription);
        final card = _fillAround(tester, label);
        expect(card.color, AppModeColors.surfacePaperOnPhoto());
        expect(card.color, const Color(0xFFF5F4ED));
        expect(card.color!.a, 1.0);
        expect(_textColor(tester, label), cs.primary);
        expect(
          _contrast(cs.primary, card.color!),
          greaterThanOrEqualTo(10.5),
        );
        final size = find.textContaining('MB');
        expect(size, findsOneWidget);
        expect(_textColor(tester, size), cs.primary);
      });

      testWidgets('4: the whole-photo scrim is overlay.inkStrong at 60 %', (
        tester,
      ) async {
        const failed = ImageUploadStatus(state: ImageUploadState.failed);
        await tester.pumpWidget(_themed(theme, _overlay(failed)));

        final scrim = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(Stack).first,
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.color == AppColors.overlayBlack60);
        expect(scrim.color, const Color(0x9917251D));
        expect(scrim.color!.a, closeTo(0.6, 0.005));
      });

      for (final (state, icon) in [
        (ImageUploadState.pending, ButleryIcons.clock),
        (ImageUploadState.completed, ButleryIcons.check),
        (ImageUploadState.failed, ButleryIcons.triangleAlert),
        (ImageUploadState.cancelled, ButleryIcons.x),
      ]) {
        testWidgets(
          '4: the ${state.name} circle is opaque paper (B102) with an '
          'ink glyph',
          (tester) async {
            await tester.pumpWidget(
              _themed(
                theme,
                UploadProgressWidgets.buildProgressIndicator(
                  ImageUploadStatus(state: state),
                ),
              ),
            );

            final glyph = find.byWidgetPredicate(
              (w) => w is ButleryIcon && w.icon == icon,
            );
            final disc = _fillAround(tester, glyph);
            expect(disc.shape, BoxShape.circle);
            expect(disc.color, AppModeColors.surfacePaperOnPhoto());
            expect(disc.color!.a, 1.0);
            expect(tester.widget<ButleryIcon>(glyph).color, cs.primary);
            expect(
              _contrast(cs.primary, disc.color!),
              greaterThanOrEqualTo(10.5),
            );
          },
        );
      }

      testWidgets('4: the off-photo bulk-action button is a raised button '
          'with a subtle border and the text token', (tester) async {
        for (final (label, color) in [
          ('Försök alla (2)', cs.onSurface),
          ('Stoppa alla (1)', cs.onSurfaceVariant),
          ('Rensa misslyckade', cs.error),
        ]) {
          await tester.pumpWidget(
            _themed(
              theme,
              UploadProgressWidgets.buildBulkActionButton(
                icon: ButleryIcons.refreshCw,
                label: label,
                onTap: () {},
                color: color,
              ),
            ),
          );

          final material = tester.widget<Material>(
            find
                .ancestor(of: find.text(label), matching: find.byType(Material))
                .first,
          );
          expect(material.color, cs.surfaceContainerHighest);
          final shape = material.shape! as RoundedRectangleBorder;
          expect(shape.side.color, cs.outlineVariant);
          // The label is always onSurface: the red variant's own colour
          // measures 4.18:1 on the dark raised fill, so it tints the glyph only.
          expect(_textColor(tester, find.text(label)), cs.onSurface);
          expect(
            _contrast(cs.onSurface, cs.surfaceContainerHighest),
            greaterThanOrEqualTo(4.5),
          );
          final glyph = tester.widget<ButleryIcon>(
            find.descendant(
              of: find.byType(Material).last,
              matching: find.byType(ButleryIcon),
            ),
          );
          expect(glyph.color, color);
          expect(
            _contrast(color, cs.surfaceContainerHighest),
            greaterThanOrEqualTo(3.0),
          );
        }
      });

      testWidgets('4: avatar initials sit on a solid raised disc in '
          'onSurface, with no gradient', (tester) async {
        await tester.pumpWidget(
          _themed(theme, AvatarImageWidget.readonly(displayName: 'Anna Berg')),
        );

        final initials = find.text('AB');
        // The nearest container is the disc itself, not a frame around it.
        final disc =
            tester
                    .widget<Container>(
                      find
                          .ancestor(
                            of: initials,
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        expect(disc.shape, BoxShape.circle);
        expect(disc.color, cs.surfaceContainerHighest);
        expect(disc.gradient, isNull);
        expect(_textColor(tester, initials), cs.onSurface);
        expect(
          _contrast(cs.onSurface, cs.surfaceContainerHighest),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('4: the recipe-photo card draws no bottom gradient', (
        tester,
      ) async {
        await tester.pumpWidget(
          _themed(
            theme,
            RecipeImageWidget.card(
              imageUrls: const ['https://example.com/img.jpg'],
              semanticsLabel: 'Pannkakor',
            ),
          ),
        );

        final gradients = find.byWidgetPredicate(
          (w) =>
              (w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).gradient != null) ||
              (w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).gradient != null),
        );
        expect(gradients, findsNothing);
      });
    });
  }
}
