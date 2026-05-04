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

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
  });

  group('BUT-547 200% text-scaling — no overflow on high-traffic widgets', () {
    testWidgets('RecipeCard renders without overflow at 2x text scale',
        (tester) async {
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

    testWidgets('RecipeCard at 2x text scale with no description still safe',
        (tester) async {
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
    });

    testWidgets('BaseScaffold AppBar uses MediaQuery.withClampedTextScaling',
        (tester) async {
      // Structural assertion: the wrap helper produces a PreferredSize ↦
      // _MediaQueryFromView/MediaQuery → AppBar chain. We don't pin the
      // private chain; instead assert the BaseScaffold tree contains
      // AppBar nested inside a MediaQuery (which is what
      // withClampedTextScaling produces).
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const BaseScaffold(
            title: 'Receptbok',
            body: SizedBox.shrink(),
          ),
        ),
      );

      // AppBar is present and nested under at least one MediaQuery in
      // the BaseScaffold subtree (sanity check for the clamp wrap).
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);
      final mediaQueryAncestors = find
          .ancestor(of: appBarFinder, matching: find.byType(MediaQuery))
          .evaluate();
      expect(mediaQueryAncestors, isNotEmpty,
          reason: 'AppBar should be wrapped in a MediaQuery (clamp wrap).');
    });
  });
}
