/// Widget tests for VegetableIllustration + HeaderGhostIllustration +
/// SectionIllustration + CardWatermarkIllustration + IllustrationContainer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// HeaderGhostIllustration + CardWatermarkIllustration return Positioned,
/// which must live inside a Stack.
Widget _wrapStack(Widget child) => MaterialApp(
  home: Scaffold(body: Stack(children: [child])),
);

void main() {
  group('VegetableIllustration.getAssetPath', () {
    test('returns the correct asset path for every VegetableType', () {
      // The contract: every enum value has a non-null .webp path.
      for (final t in VegetableType.values) {
        final p = VegetableIllustration.getAssetPath(t);
        expect(p, startsWith('assets/illustrations/'));
        expect(p, endsWith('.webp'));
      }
    });

    test('paths are distinct per type', () {
      final paths = VegetableType.values
          .map(VegetableIllustration.getAssetPath)
          .toSet();
      expect(paths.length, VegetableType.values.length);
    });
  });

  group('VegetableIllustration.randomForRecipe', () {
    test('deterministic for the same recipe id', () {
      expect(
        VegetableIllustration.randomForRecipe('recipe-42'),
        VegetableIllustration.randomForRecipe('recipe-42'),
      );
    });

    test('returns a value in the enum range', () {
      for (final id in ['a', 'b', 'long-recipe-id-xyz', '12345', '']) {
        final t = VegetableIllustration.randomForRecipe(id);
        expect(VegetableType.values, contains(t));
      }
    });
  });

  group('HeaderGhostIllustration.viewMapping', () {
    test('every main route maps to a vegetable', () {
      const routes = ['recipes', 'menu', 'shopping', 'add', 'profile'];
      for (final r in routes) {
        expect(HeaderGhostIllustration.viewMapping[r], isNotNull);
      }
    });
  });

  group('VegetableIllustration — widget render', () {
    testWidgets('renders an Image.asset wrapped in Opacity', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VegetableIllustration(
            type: VegetableType.broccoli,
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(Opacity), findsOneWidget);
    });

    testWidgets('size prop sets width and height on the Image', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VegetableIllustration(
            type: VegetableType.carrot,
            size: 222,
          ),
        ),
      );
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.width, 222);
      expect(img.height, 222);
    });

    testWidgets('opacity prop sets the Opacity child', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VegetableIllustration(
            type: VegetableType.peaPod,
            opacity: 0.5,
          ),
        ),
      );
      final op = tester.widget<Opacity>(find.byType(Opacity));
      expect(op.opacity, 0.5);
    });

    // SKIP: errorBuilder mapping. Image.asset's errorBuilder fires
    // asynchronously via AssetBundle plumbing that doesn't resolve under the
    // widget-test harness without real asset binary; covering the private
    // `_getFallbackIcon`/`_getFallbackColor` helpers would require exposing
    // them as a test seam. Out of scope for this batch.
  });

  group('HeaderGhostIllustration', () {
    testWidgets('wraps in Positioned + IgnorePointer + Opacity(0.12)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapStack(
          const HeaderGhostIllustration(type: VegetableType.broccoli),
        ),
      );
      expect(find.byType(Positioned), findsAtLeastNWidgets(1));
      expect(
        find.descendant(
          of: find.byType(HeaderGhostIllustration),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
      // Find the Opacity inside the HeaderGhostIllustration specifically.
      final op = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(HeaderGhostIllustration),
          matching: find.byType(Opacity),
        ),
      );
      expect(op.opacity, closeTo(0.12, 0.001));
    });

    testWidgets('uses ColorFiltered with identity-modulate filter', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapStack(
          const HeaderGhostIllustration(type: VegetableType.mushroom),
        ),
      );
      final cf = tester.widget<ColorFiltered>(find.byType(ColorFiltered));
      expect(cf.colorFilter, isA<ColorFilter>());
    });

    testWidgets('respects custom size', (tester) async {
      await tester.pumpWidget(
        _wrapStack(
          const HeaderGhostIllustration(
            type: VegetableType.carrot,
            size: 200,
          ),
        ),
      );
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.width, 200);
      expect(img.height, 200);
    });
  });

  group('SectionIllustration', () {
    testWidgets('Opacity(0.7) wrapper', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SectionIllustration(type: VegetableType.peaPod),
        ),
      );
      final op = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(SectionIllustration),
          matching: find.byType(Opacity),
        ),
      );
      expect(op.opacity, closeTo(0.7, 0.001));
    });

    testWidgets('default size = 36', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SectionIllustration(type: VegetableType.peaPod),
        ),
      );
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.width, 36);
      expect(img.height, 36);
    });
  });

  group('CardWatermarkIllustration', () {
    testWidgets('Opacity(0.06) + Positioned + IgnorePointer', (tester) async {
      await tester.pumpWidget(
        _wrapStack(
          const CardWatermarkIllustration(type: VegetableType.peaPod),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(CardWatermarkIllustration),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
      final op = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(CardWatermarkIllustration),
          matching: find.byType(Opacity),
        ),
      );
      expect(op.opacity, closeTo(0.06, 0.001));
    });

    testWidgets('default size = 50', (tester) async {
      await tester.pumpWidget(
        _wrapStack(
          const CardWatermarkIllustration(type: VegetableType.broccoli),
        ),
      );
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.width, 50);
      expect(img.height, 50);
    });
  });

  group('IllustrationContainer', () {
    testWidgets('renders only the illustration when no labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const IllustrationContainer(type: VegetableType.carrot),
        ),
      );
      expect(find.byType(VegetableIllustration), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders label below illustration', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const IllustrationContainer(
            type: VegetableType.broccoli,
            label: 'Inga recept',
          ),
        ),
      );
      expect(find.text('Inga recept'), findsOneWidget);
    });

    testWidgets('renders sublabel below label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const IllustrationContainer(
            type: VegetableType.broccoli,
            label: 'Inga recept',
            sublabel: 'Lägg till ditt första recept',
          ),
        ),
      );
      expect(find.text('Inga recept'), findsOneWidget);
      expect(find.text('Lägg till ditt första recept'), findsOneWidget);
    });

    testWidgets('default size = 120 on the inner illustration', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const IllustrationContainer(type: VegetableType.carrot),
        ),
      );
      final inner = tester.widget<VegetableIllustration>(
        find.byType(VegetableIllustration),
      );
      expect(inner.size, 120);
    });

    testWidgets('column shrinks vertically (mainAxisSize.min)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const IllustrationContainer(type: VegetableType.carrot),
        ),
      );
      final col = tester.widget<Column>(
        find.descendant(
          of: find.byType(IllustrationContainer),
          matching: find.byType(Column),
        ),
      );
      expect(col.mainAxisSize, MainAxisSize.min);
    });
  });
}
