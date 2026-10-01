// P7-B4: a chosen photo carries its choice with the 2 px text.primary border
// and the ink check, never a tint or a faded plate (tokens.json:40-53;
// Grafisk manual v6:209, "Vald = riktig border").

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/image/image_gallery_widget.dart';

import '../../infrastructure/helpers/base_widget_test.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  for (final dark in [false, true]) {
    testWidgets('long-press chooses a photo: onSurface 2 px border, solid '
        'plates (${dark ? 'dark' : 'light'})', (tester) async {
      final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
      final cs = theme.colorScheme;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Theme(
            data: theme,
            child: ImageGalleryWidget.gallery(
              imageUrls: const [
                'https://example.invalid/a.jpg',
                'https://example.invalid/b.jpg',
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.bySemanticsLabel('Visa bild').first);
      await tester.pump();

      final borders = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(ImageGalleryWidget),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.rectangle && d.border != null)
          .map((d) => (d.border! as Border).top)
          .toList();
      expect(
        borders.where((b) => b.color == cs.onSurface && b.width == 2),
        hasLength(1),
        reason: 'the chosen photo',
      );
      expect(
        borders.where((b) => b.color == cs.outlineVariant && b.width == 1),
        hasLength(1),
        reason: 'the other photo keeps border.subtle, not a faded one',
      );

      final circles = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(ImageGalleryWidget),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle)
          .toList();
      expect(
        circles.map((d) => d.color),
        containsAll([cs.primary, cs.surface]),
      );
      for (final d in circles) {
        expect(d.color!.a, 1, reason: 'no translucent plate');
      }
      tester.takeException();
    });
  }

  // BUT-2183 5c: the empty gallery is no photo, so it takes border.subtle,
  // text.disabled for the glyph and text.secondary for the lines.
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('empty gallery: border.subtle, disabled glyph, secondary '
        'text ($name)', (tester) async {
      final cs = theme.colorScheme;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Theme(
            data: theme,
            child: ImageGalleryWidget.gallery(imageUrls: const []),
          ),
        ),
      );

      final frame = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(ImageGalleryWidget),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null);
      expect(frame.color, cs.surfaceContainerHighest);
      expect((frame.border! as Border).top.color, cs.outlineVariant);

      final glyph = tester.widget<ButleryIcon>(
        find.byWidgetPredicate(
          (w) => w is ButleryIcon && w.icon == ButleryIcons.image,
        ),
      );
      expect(glyph.color, AppModeColors.textDisabled(theme.brightness));
      expect(
        tester.widget<Text>(find.text('Inga bilder ännu')).style?.color,
        cs.onSurfaceVariant,
      );
      expect(
        tester.widget<Text>(find.text('Bilder visas här')).style?.color,
        cs.onSurfaceVariant,
      );
    });
  }
}
