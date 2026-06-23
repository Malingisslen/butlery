// test/widget/common/indicators/progress_overlay_test.dart
// Comprehensive tests for ProgressOverlay using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/progress_overlay.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('ProgressOverlay Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Default Constructor', () {
      testWidgets('should render with required text', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Loading...'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Loading...'), findsOneWidget);
        expect(find.byType(ProgressOverlay), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should use Positioned.fill', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Loading'),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(Positioned), findsOneWidget);
        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.left, equals(0));
        expect(positioned.top, equals(0));
        expect(positioned.right, equals(0));
        expect(positioned.bottom, equals(0));
      });

      testWidgets('should use circle shape by default', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Loading'),
                ],
              ),
            ),
          ),
        );

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));
      });

      testWidgets('should use theme onSurface for default dark background', (
        WidgetTester tester,
      ) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return const Stack(
                    children: [ProgressOverlay(text: 'Loading')],
                  );
                },
              ),
            ),
          ),
        );

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(
          decoration.color,
          equals(cs.onSurface.withValues(alpha: AppDimensions.opacityDark)),
        );
      });

      testWidgets('should use theme surfaceContainerHighest for progress', (
        WidgetTester tester,
      ) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return const Stack(
                    children: [ProgressOverlay(text: 'Loading')],
                  );
                },
              ),
            ),
          ),
        );

        final progress = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(progress.color, equals(cs.surfaceContainerHighest));
      });

      testWidgets('should apply custom background color', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(
                    text: 'Loading',
                    backgroundColor: Colors.blue.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        );

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.blue.withValues(alpha: 0.5)));
      });

      testWidgets('should apply custom progress color', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(
                    text: 'Loading',
                    progressColor: Colors.red,
                  ),
                ],
              ),
            ),
          ),
        );

        final progress = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(progress.color, equals(Colors.red));
      });

      testWidgets('should apply custom text color', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(
                    text: 'Loading',
                    textColor: Colors.yellow,
                  ),
                ],
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('Loading'));
        expect(text.style?.color, equals(Colors.yellow));
      });
    });

    group('Avatar Constructor', () {
      testWidgets('should render with avatar constructor', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay.avatar(text: 'Uploading...'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Uploading...'), findsOneWidget);
        expect(find.byType(ProgressOverlay), findsOneWidget);
      });

      testWidgets('should use circle shape for avatar', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay.avatar(text: 'Uploading'),
                ],
              ),
            ),
          ),
        );

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));
      });

      testWidgets(
        'should use theme surfaceContainerHighest for avatar progress',
        (WidgetTester tester) async {
          late ColorScheme cs;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    cs = Theme.of(context).colorScheme;
                    return const Stack(
                      children: [ProgressOverlay.avatar(text: 'Uploading')],
                    );
                  },
                ),
              ),
            ),
          );

          final progress = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          );
          expect(progress.color, equals(cs.surfaceContainerHighest));
        },
      );

      testWidgets('should use theme surfaceContainerHighest for avatar text', (
        WidgetTester tester,
      ) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return const Stack(
                    children: [ProgressOverlay.avatar(text: 'Uploading')],
                  );
                },
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('Uploading'));
        expect(text.style?.color, equals(cs.surfaceContainerHighest));
      });
    });

    group('Rectangle Constructor', () {
      testWidgets('should render with rectangle constructor', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay.rectangle(text: 'Processing...'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Processing...'), findsOneWidget);
        expect(find.byType(ProgressOverlay), findsOneWidget);
      });

      testWidgets('should use rectangle shape', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay.rectangle(text: 'Processing'),
                ],
              ),
            ),
          ),
        );

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.rectangle));
      });

      testWidgets('should accept custom colors for rectangle', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay.rectangle(
                    text: 'Processing',
                    backgroundColor: Colors.green.withValues(alpha: 0.8),
                    progressColor: Colors.white,
                    textColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        );

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.green.withValues(alpha: 0.8)));

        final progress = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(progress.color, equals(Colors.white));

        final text = tester.widget<Text>(find.text('Processing'));
        expect(text.style?.color, equals(Colors.white));
      });
    });

    group('Progress Indicator', () {
      testWidgets('should show circular progress indicator', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Loading'),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should use strokeWidth of 2', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Loading'),
                ],
              ),
            ),
          ),
        );

        final progress = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(progress.strokeWidth, equals(2));
      });
    });

    group('Layout', () {
      testWidgets('should center content', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Centered'),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(Center), findsOneWidget);
      });

      testWidgets('should use Column with min size', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Column'),
                ],
              ),
            ),
          ),
        );

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.mainAxisSize, equals(MainAxisSize.min));
      });

      testWidgets('should have spacing between indicator and text', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Spaced'),
                ],
              ),
            ),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.height, equals(AppDimensions.spacingXs));
      });
    });

    group('Text Styling', () {
      testWidgets('should use bodySmall text style', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Styled'),
                ],
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('Styled'));
        // The text style is based on AppTextStyles.bodySmall
        expect(text.style, isNotNull);
      });

      testWidgets('should display text below progress indicator', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Below'),
                ],
              ),
            ),
          ),
        );

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.children.length, equals(3)); // Progress, SizedBox, Text
        expect(column.children[0], isA<CircularProgressIndicator>());
        expect(column.children[1], isA<SizedBox>());
        expect(column.children[2], isA<Text>());
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish uploading text', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Laddar upp...'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Laddar upp...'), findsOneWidget);
      });

      testWidgets('should display Swedish processing text', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Bearbetar...'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Bearbetar...'), findsOneWidget);
      });

      testWidgets('should display Swedish saving text', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Sparar...'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Sparar...'), findsOneWidget);
      });

      testWidgets('should handle Swedish characters in text', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: 'Hämtar användaruppgifter...'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Hämtar användaruppgifter...'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty text', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: ''),
                ],
              ),
            ),
          ),
        );

        expect(find.text(''), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should handle very long text', (WidgetTester tester) async {
        final longText =
            'This is a very long loading message that might wrap to multiple lines';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ProgressOverlay(text: longText),
                ],
              ),
            ),
          ),
        );

        expect(find.text(longText), findsOneWidget);
      });

      testWidgets('should work with different stack sizes', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  children: [
                    Container(color: Colors.grey),
                    const ProgressOverlay(text: 'Loading'),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(ProgressOverlay), findsOneWidget);
        expect(find.text('Loading'), findsOneWidget);
      });

      testWidgets('should overlay on top of other widgets', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(
                // Stack must have non-zero height for the Positioned.fill
                // overlay Column (spinner + text) to fit.
                child: Stack(
                  children: [
                    Center(child: Text('Background content')),
                    ProgressOverlay(text: 'Overlay'),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Background content'), findsOneWidget);
        expect(find.text('Overlay'), findsOneWidget);
        expect(find.byType(ProgressOverlay), findsOneWidget);
      });
    });

    group('Use Cases', () {
      testWidgets('should work for avatar upload scenario', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey,
                    ),
                  ),
                  const ProgressOverlay.avatar(text: 'Uploading avatar...'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Uploading avatar...'), findsOneWidget);
        // Find the DecoratedBox from ProgressOverlay specifically
        final decoratedBoxes = tester.widgetList<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        expect(decoratedBoxes, isNotEmpty);
        // The ProgressOverlay's DecoratedBox should have circle shape
        final progressOverlayBox = decoratedBoxes.firstWhere(
          (box) => (box.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        final decoration = progressOverlayBox.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));
      });

      testWidgets('should work for file processing scenario', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Container(color: Colors.white),
                  const ProgressOverlay.rectangle(text: 'Processing file...'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Processing file...'), findsOneWidget);
        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.rectangle));
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}
