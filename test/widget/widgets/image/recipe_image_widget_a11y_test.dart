// BUT-551: RecipeImageWidget exposes the recipe title as the image's
// content description, so screen readers announce "image, <dish>" instead
// of an unlabelled image. Decorative empty-state placeholders (no onTap)
// must be excluded from the semantics tree entirely.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/image/recipe_image_widget.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('BUT-551 RecipeImageWidget Semantics', () {
    testWidgets('detail constructor announces dish name as image label',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: RecipeImageWidget.detail(
            imageUrls: const ['https://example.com/img.jpg'],
            semanticsLabel: 'Köttbullar med potatismos',
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Köttbullar med potatismos'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('card constructor announces dish name as image label',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: RecipeImageWidget.card(
            imageUrls: const ['https://example.com/img.jpg'],
            semanticsLabel: 'Pannkakor',
          ),
        ),
      );

      expect(find.bySemanticsLabel('Pannkakor'), findsOneWidget);
      handle.dispose();
    });

    testWidgets(
        'empty state with no onTap excludes decorative placeholder from a11y',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: RecipeImageWidget.card(
            imageUrls: const [],
            semanticsLabel: 'No-image recipe',
          ),
        ),
      );

      // semanticsLabel is only emitted when there are images — for the empty
      // decorative state, neither the dish label nor an "image" announcement
      // should reach the screen reader.
      expect(find.bySemanticsLabel('No-image recipe'), findsNothing);
      handle.dispose();
    });
  });
}
