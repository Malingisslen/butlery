/// Widget tests for ImagePreviewCard — verifies default container styling and
/// the two named constructors (loading / empty) wire theme colors + decoration
/// flags correctly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/content_cards/image_preview_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Returns the outer Container that ImagePreviewCard builds (i.e. the one
/// whose decoration is the BoxDecoration under test).
Container _outerContainer(WidgetTester tester) {
  return tester.firstWidget<Container>(find.descendant(
    of: find.byType(ImagePreviewCard),
    matching: find.byType(Container),
  ));
}

void main() {
  group('ImagePreviewCard — default constructor', () {
    testWidgets('renders supplied child', (tester) async {
      await tester.pumpWidget(_wrap(
        const ImagePreviewCard(child: Text('preview-body')),
      ));
      expect(find.text('preview-body'), findsOneWidget);
    });

    testWidgets('default height = AppDimensions.imageHeightMedium',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ImagePreviewCard(child: SizedBox.shrink()),
      ));
      final c = _outerContainer(tester);
      expect(c.constraints?.maxHeight, AppDimensions.imageHeightMedium);
    });

    testWidgets('explicit height overrides default', (tester) async {
      await tester.pumpWidget(_wrap(
        const ImagePreviewCard(height: 240, child: SizedBox.shrink()),
      ));
      final c = _outerContainer(tester);
      expect(c.constraints?.maxHeight, 240);
    });

    testWidgets('default decoration: no border, no shadow, default radius',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ImagePreviewCard(child: SizedBox.shrink()),
      ));
      final deco = _outerContainer(tester).decoration! as BoxDecoration;
      expect(deco.border, isNull);
      expect(deco.boxShadow, isNull);
      expect(deco.borderRadius, isNotNull);
    });

    testWidgets('explicit backgroundColor passes through to decoration',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ImagePreviewCard(
          backgroundColor: Colors.amber,
          child: SizedBox.shrink(),
        ),
      ));
      final deco = _outerContainer(tester).decoration! as BoxDecoration;
      expect(deco.color, Colors.amber);
    });

    testWidgets('explicit borderRadius passes through to decoration',
        (tester) async {
      const radius = BorderRadius.all(Radius.circular(24));
      await tester.pumpWidget(_wrap(
        const ImagePreviewCard(
          borderRadius: radius,
          child: SizedBox.shrink(),
        ),
      ));
      final deco = _outerContainer(tester).decoration! as BoxDecoration;
      expect(deco.borderRadius, radius);
    });

    testWidgets('explicit boxShadow passes through to decoration',
        (tester) async {
      const shadows = [BoxShadow(blurRadius: 7, color: Colors.black26)];
      await tester.pumpWidget(_wrap(
        const ImagePreviewCard(
          boxShadow: shadows,
          child: SizedBox.shrink(),
        ),
      ));
      final deco = _outerContainer(tester).decoration! as BoxDecoration;
      expect(deco.boxShadow, shadows);
    });

    testWidgets('showBorder=true with explicit color + width', (tester) async {
      await tester.pumpWidget(_wrap(
        const ImagePreviewCard(
          showBorder: true,
          borderColor: Colors.red,
          borderWidth: 3.0,
          child: SizedBox.shrink(),
        ),
      ));
      final deco = _outerContainer(tester).decoration! as BoxDecoration;
      final border = deco.border! as Border;
      expect(border.top.color, Colors.red);
      expect(border.top.width, 3.0);
      expect(border.top.style, BorderStyle.solid);
    });

    testWidgets('showBorder=true defaults borderWidth to 1.0 when omitted',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ImagePreviewCard(
          showBorder: true,
          child: SizedBox.shrink(),
        ),
      ));
      final deco = _outerContainer(tester).decoration! as BoxDecoration;
      final border = deco.border! as Border;
      expect(border.top.width, 1.0);
    });

    testWidgets('showBorder=false → no border even when borderColor provided',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ImagePreviewCard(
          showBorder: false,
          borderColor: Colors.red,
          child: SizedBox.shrink(),
        ),
      ));
      final deco = _outerContainer(tester).decoration! as BoxDecoration;
      expect(deco.border, isNull);
    });
  });

  group('ImagePreviewCard.loading', () {
    testWidgets('uses surfaceContainerHighest + has shadow + no border',
        (tester) async {
      late ImagePreviewCard built;
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        built = ImagePreviewCard.loading(
          context: ctx,
          child: const Text('loading-body'),
        );
        return built;
      })));

      expect(find.text('loading-body'), findsOneWidget);

      final deco = _outerContainer(tester).decoration! as BoxDecoration;
      // backgroundColor sourced from theme.colorScheme.surfaceContainerHighest
      final theme = Theme.of(tester.element(find.text('loading-body')));
      expect(deco.color, theme.colorScheme.surfaceContainerHighest);
      // Shadow is set from AppShadows.card (non-null, non-empty list)
      expect(deco.boxShadow, isNotNull);
      expect(deco.boxShadow, isNotEmpty);
      // No border
      expect(deco.border, isNull);
    });

    testWidgets('honors custom height', (tester) async {
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        return ImagePreviewCard.loading(
          context: ctx,
          height: 80,
          child: const SizedBox.shrink(),
        );
      })));
      final c = _outerContainer(tester);
      expect(c.constraints?.maxHeight, 80);
    });
  });

  group('ImagePreviewCard.empty', () {
    testWidgets('uses surfaceContainerHighest + outline border 2px, no shadow',
        (tester) async {
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        return ImagePreviewCard.empty(
          context: ctx,
          child: const Text('empty-body'),
        );
      })));

      expect(find.text('empty-body'), findsOneWidget);

      final deco = _outerContainer(tester).decoration! as BoxDecoration;
      final theme = Theme.of(tester.element(find.text('empty-body')));
      expect(deco.color, theme.colorScheme.surfaceContainerHighest);
      expect(deco.boxShadow, isNull);

      final border = deco.border! as Border;
      expect(border.top.color, theme.colorScheme.outline);
      expect(border.top.width, 2.0);
      expect(border.top.style, BorderStyle.solid);
    });

    testWidgets('honors custom height', (tester) async {
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        return ImagePreviewCard.empty(
          context: ctx,
          height: 100,
          child: const SizedBox.shrink(),
        );
      })));
      final c = _outerContainer(tester);
      expect(c.constraints?.maxHeight, 100);
    });
  });
}
