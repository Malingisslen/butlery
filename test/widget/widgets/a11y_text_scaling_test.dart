// BUT-547: WCAG 1.4.4 — Resize Text (AA). The user must be able to scale
// up to 200% without loss of content or function. Flutter honors
// MediaQuery.textScaler automatically, but fixed-height containers can
// silently clip when the contained text grows.
//
// This test wraps high-traffic surfaces in a 2x text scaler and asserts
// that no Flutter render-overflow exception is thrown. It does not check
// pixel-perfect layout — it catches the regression of "I added a fixed
// height: N container around Text without thinking about scaling".
//
// Audit findings filed on BUT-547 cover the broader sweep; this file is
// the regression-prevention guardrail going forward.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
  });

  group('BUT-547 200% text-scaling — no overflow on high-traffic widgets', () {
    testWidgets('RecipeCard renders without overflow at 2x text scale', (
      tester,
    ) async {
      final recipe = RecipeFactory.build(
        id: 'r1',
        title: 'Köttbullar med potatismos och brunsås — en lång svensk titel',
        description:
            'Klassisk svensk husmanskost med en längre beskrivning som '
            'kan ta plats om text-scalingen är hög.',
        imageUrls: const [],
        mealType: 'Middag',
        portions: 4,
        timeMinutes: 45,
        rating: 4.5,
      );

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: SizedBox(
              width: 360,
              child: RecipeCard(recipe: recipe, onTap: (_) {}),
            ),
          ),
        ),
      );

      // No render-overflow exceptions surfaced by the framework. Flutter
      // surfaces overflow as `tester.takeException()` returning a
      // FlutterError with "RenderFlex overflowed" when present.
      expect(tester.takeException(), isNull);
    });

    testWidgets('RecipeCard at 2x text scale with no description still safe', (
      tester,
    ) async {
      final minimal = RecipeFactory.build(
        id: 'r2',
        title: 'Pannkakor',
        description: '',
        imageUrls: const [],
        mealType: '',
        portions: null,
        timeMinutes: null,
        rating: null,
      );

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: SizedBox(
              width: 360,
              child: RecipeCard(recipe: minimal, onTap: (_) {}),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('BUT-763 BaseScaffold AppBar text-scaling clamp', () {
    testWidgets(
      'BaseScaffold AppBar with long title renders clean at 2x text scale',
      (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: const BaseScaffold(
                title: 'Veckomeny för familjen Andersson — lång svensk titel',
                body: SizedBox.shrink(),
              ),
            ),
          ),
        );

        // Without the BUT-763 clamp this throws RenderFlex overflowed.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('BaseScaffold top bar grows with the text instead of '
        'clamping it', (tester) async {
      // Package 4: BaseScaffold draws ButleryTopBar.undersida, whose height
      // follows its content up to 200 % text (tillganglighetshandoff:85),
      // so the BUT-763 clamp is no longer needed and the title keeps the
      // user's text size.
      Future<double> barHeight(double scale) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const BaseScaffold(
                title: 'Receptbok',
                body: SizedBox.shrink(),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(AppBar), findsNothing);
        return tester.getSize(find.byType(ButleryTopBar)).height;
      }

      final normal = await barHeight(1);
      final large = await barHeight(2);
      expect(large, greaterThanOrEqualTo(normal));
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byKey(const ValueKey('butleryTopBar.title'))),
        ).scale(14),
        28,
        reason: 'the title is not clamped',
      );
    });
  });
}
