import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/image/recipe_image_widget.dart';
import 'package:butlery/widgets/image/editable_image_widget.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  // BUT-2183 5c: badges on a photo are overlay.paperCard with ink. The edit
  // tiles' own marker is paper with ink, and their add tile is not on a photo
  // and takes border.subtle.
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    group('BUT-2183 5c image badge tokens ($name)', () {
      final cs = theme.colorScheme;
      final modes = ModeColors.of(theme.brightness);

      setUpAll(() async {
        await BaseWidgetTest.setupWidget();
      });

      setUp(() async {
        await TestServiceLocator.initialize();
      });

      tearDown(() async {
        await BaseWidgetTest.teardownWidget();
      });

      BoxDecoration fillAround(WidgetTester tester, Finder of) => tester
          .widgetList<Container>(
            find.ancestor(of: of, matching: find.byType(Container)),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color != null);

      testWidgets('card: multiple-photo indicator is overlay.paperCard with '
          'ink', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Theme(
              data: theme,
              child: SizedBox(
                width: 200,
                height: 150,
                child: RecipeImageWidget.card(
                  imageUrls: const [
                    'https://example.com/a.jpg',
                    'https://example.com/b.jpg',
                  ],
                ),
              ),
            ),
          ),
        );

        final count = find.text('2');
        expect(fillAround(tester, count).color, modes.overlayPaperCard);
        expect(tester.widget<Text>(count).style?.color, cs.primary);
      });

      testWidgets('detail: page counter is overlay.paperCard with ink', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Theme(
              data: theme,
              child: RecipeImageWidget.detail(
                imageUrls: const [
                  'https://example.com/a.jpg',
                  'https://example.com/b.jpg',
                ],
              ),
            ),
          ),
        );

        final counter = find.text('1/2');
        expect(fillAround(tester, counter).color, modes.overlayPaperCard);
        expect(tester.widget<Text>(counter).style?.color, cs.primary);
      });

      testWidgets('edit tiles: the primary tile says "primär" in ink on '
          'paper, and the add tile ends the row on border.subtle', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Theme(
              data: theme,
              child: SingleChildScrollView(
                child: EditableImageWidget.recipeEdit(
                  imageUrls: const [
                    'https://example.com/a.jpg',
                    'https://example.com/b.jpg',
                  ],
                  maxImages: 5,
                ),
              ),
            ),
          ),
        );

        final primary = find.text('primär');
        expect(primary, findsOneWidget);
        expect(tester.widget<Text>(primary).style?.color, cs.onSurface);
        final marker = tester
            .widgetList<DecoratedBox>(
              find.ancestor(of: primary, matching: find.byType(DecoratedBox)),
            )
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .first;
        expect(marker.color, cs.surface);

        final add = tester
            .widgetList<Container>(
              find.ancestor(
                of: find.byIcon(ButleryIcons.plus),
                matching: find.byType(Container),
              ),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .first;
        expect((add.border! as Border).top.color, cs.outlineVariant);
      });
    });
  }
}
