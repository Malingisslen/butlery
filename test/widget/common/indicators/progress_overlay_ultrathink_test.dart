// test/widget/common/indicators/progress_overlay_ultrathink_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/progress_overlay.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

void main() {
  group('ProgressOverlay Widget Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment with theme support
    // ProgressOverlay uses Positioned.fill which requires Stack parent
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          body: Stack(
            children: [
              Container(
                width: 200,
                height: 200,
                color: Colors.grey.shade100,
                child: const Center(child: Text('Background')),
              ),
              child,
            ],
          ),
        ),
      );
    }

    group('Constructor Tests', () {
      testWidgets('creates widget with main constructor and required text',
          (tester) async {
        const testText = 'Loading...';

        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: testText),
          ),
        );

        expect(find.byType(ProgressOverlay), findsOneWidget);
        expect(find.text(testText), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('creates widget with main constructor and all parameters',
          (tester) async {
        const testText = 'Processing...';
        const testBackgroundColor = Colors.red;
        const testProgressColor = Colors.white;
        const testTextColor = Colors.yellow;

        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(
              text: testText,
              shape: BoxShape.rectangle,
              backgroundColor: testBackgroundColor,
              progressColor: testProgressColor,
              textColor: testTextColor,
            ),
          ),
        );

        expect(find.byType(ProgressOverlay), findsOneWidget);
        expect(find.text(testText), findsOneWidget);
      });

      testWidgets('creates widget with .avatar() named constructor',
          (tester) async {
        const testText = 'Uploading avatar...';

        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay.avatar(text: testText),
          ),
        );

        expect(find.byType(ProgressOverlay), findsOneWidget);
        expect(find.text(testText), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('creates widget with .rectangle() named constructor',
          (tester) async {
        const testText = 'Processing file...';

        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay.rectangle(text: testText),
          ),
        );

        expect(find.byType(ProgressOverlay), findsOneWidget);
        expect(find.text(testText), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Shape Configuration Tests', () {
      testWidgets('main constructor uses circle shape by default',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: 'Loading...'),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;

        expect(decoration.shape, BoxShape.circle);
      });

      testWidgets('main constructor accepts custom rectangle shape',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(
              text: 'Loading...',
              shape: BoxShape.rectangle,
            ),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;

        expect(decoration.shape, BoxShape.rectangle);
      });

      testWidgets('.avatar() constructor enforces circle shape',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay.avatar(text: 'Uploading...'),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;

        expect(decoration.shape, BoxShape.circle);
      });

      testWidgets('.rectangle() constructor enforces rectangle shape',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay.rectangle(text: 'Processing...'),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;

        expect(decoration.shape, BoxShape.rectangle);
      });
    });

    group('Color Configuration Tests', () {
      testWidgets('main constructor applies correct default colors',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: 'Loading...'),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        final progressIndicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));
        final text = tester.widget<Text>(find.text('Loading...'));

        expect(decoration.color, AppColors.neutralDark.withValues(alpha: 0.7));
        expect(progressIndicator.color, AppColors.neutralLight);
        expect(text.style?.color, AppColors.neutralLight);
      });

      testWidgets('main constructor applies custom colors', (tester) async {
        const customBackgroundColor = Colors.blue;
        const customProgressColor = Colors.red;
        const customTextColor = Colors.green;

        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(
              text: 'Loading...',
              backgroundColor: customBackgroundColor,
              progressColor: customProgressColor,
              textColor: customTextColor,
            ),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        final progressIndicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));
        final text = tester.widget<Text>(find.text('Loading...'));

        expect(decoration.color, customBackgroundColor);
        expect(progressIndicator.color, customProgressColor);
        expect(text.style?.color, customTextColor);
      });

      testWidgets('.avatar() constructor applies preset colors',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay.avatar(text: 'Uploading...'),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        final progressIndicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));
        final text = tester.widget<Text>(find.text('Uploading...'));

        // Avatar constructor sets backgroundColor to null, should use default
        expect(decoration.color, AppColors.neutralDark.withValues(alpha: 0.7));
        expect(progressIndicator.color, AppColors.neutralLight);
        expect(text.style?.color, AppColors.neutralLight);
      });

      testWidgets('.rectangle() constructor allows color customization',
          (tester) async {
        const customBackgroundColor = Colors.purple;
        const customProgressColor = Colors.orange;
        const customTextColor = Colors.pink;

        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay.rectangle(
              text: 'Processing...',
              backgroundColor: customBackgroundColor,
              progressColor: customProgressColor,
              textColor: customTextColor,
            ),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        final progressIndicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));
        final text = tester.widget<Text>(find.text('Processing...'));

        expect(decoration.color, customBackgroundColor);
        expect(progressIndicator.color, customProgressColor);
        expect(text.style?.color, customTextColor);
      });
    });

    group('Progress Indicator Tests', () {
      testWidgets('applies correct CircularProgressIndicator properties',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: 'Loading...'),
          ),
        );

        final progressIndicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));

        expect(progressIndicator.strokeWidth, 2);
        expect(progressIndicator.color, AppColors.neutralLight);
      });

      testWidgets('CircularProgressIndicator accepts custom color',
          (tester) async {
        const customProgressColor = Colors.yellow;

        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(
              text: 'Loading...',
              progressColor: customProgressColor,
            ),
          ),
        );

        final progressIndicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));

        expect(progressIndicator.color, customProgressColor);
        expect(progressIndicator.strokeWidth, 2); // Should remain constant
      });

      testWidgets('all constructor variants create CircularProgressIndicator',
          (tester) async {
        const constructors = [
          ProgressOverlay(text: 'Test'),
          ProgressOverlay.avatar(text: 'Test'),
          ProgressOverlay.rectangle(text: 'Test'),
        ];

        for (final constructor in constructors) {
          await tester.pumpWidget(createTestWidget(constructor));
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        }
      });
    });

    group('Text Configuration Tests', () {
      testWidgets('displays correct text content', (tester) async {
        const testTexts = [
          'Loading...',
          'Uploading avatar',
          'Processing file',
          'Almost done!',
          '',
        ];

        for (final testText in testTexts) {
          await tester.pumpWidget(
            createTestWidget(
              ProgressOverlay(text: testText),
            ),
          );

          expect(find.text(testText), findsOneWidget);
        }
      });

      testWidgets('applies correct text styling with defaults', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: 'Loading...'),
          ),
        );

        final text = tester.widget<Text>(find.text('Loading...'));

        expect(text.style?.fontSize, AppTextStyles.bodySmall.fontSize);
        expect(text.style?.color, AppColors.neutralLight);
      });

      testWidgets('applies custom text color while maintaining style',
          (tester) async {
        const customTextColor = Colors.cyan;

        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(
              text: 'Loading...',
              textColor: customTextColor,
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('Loading...'));

        expect(text.style?.color, customTextColor);
        expect(text.style?.fontSize, AppTextStyles.bodySmall.fontSize);
      });

      testWidgets('handles long text content', (tester) async {
        const longText =
            'This is a very long loading message that might wrap to multiple lines in the overlay display';

        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: longText),
          ),
        );

        expect(find.text(longText), findsOneWidget);
      });
    });

    group('Widget Layout Tests', () {
      testWidgets('has correct widget hierarchy', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: 'Loading...'),
          ),
        );

        // Check for correct widget hierarchy
        expect(find.byType(Positioned), findsOneWidget);
        expect(find.byType(DecoratedBox), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget);

        // Check parent-child relationships within ProgressOverlay
        final positioned = find.byType(Positioned);
        final decoratedBox = find.byType(DecoratedBox);
        final column = find.byType(Column);

        expect(find.descendant(of: positioned, matching: decoratedBox),
            findsOneWidget);
        expect(find.descendant(of: decoratedBox, matching: column),
            findsOneWidget);

        // Check that CircularProgressIndicator is within Column
        expect(
            find.descendant(
                of: column, matching: find.byType(CircularProgressIndicator)),
            findsOneWidget);
      });

      testWidgets('Column has correct properties', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: 'Loading...'),
          ),
        );

        final column = tester.widget<Column>(find.byType(Column));

        expect(column.mainAxisSize, MainAxisSize.min);
        expect(column.children.length,
            3); // CircularProgressIndicator, SizedBox, Text
      });

      testWidgets('SizedBox has correct spacing', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: 'Loading...'),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));

        expect(sizedBox.height, AppDimensions.spacingXs);
      });

      testWidgets('Positioned.fill creates overlay effect', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: 'Loading...'),
          ),
        );

        final positioned = tester.widget<Positioned>(find.byType(Positioned));

        expect(positioned.left, 0);
        expect(positioned.top, 0);
        expect(positioned.right, 0);
        expect(positioned.bottom, 0);
      });
    });

    group('Theme Integration Tests', () {
      testWidgets('uses AppDimensions constants correctly', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: 'Loading...'),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));

        expect(sizedBox.height, AppDimensions.spacingXs);
      });

      testWidgets('uses AppColors constants correctly', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: 'Loading...'),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        final progressIndicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));
        final text = tester.widget<Text>(find.text('Loading...'));

        expect(decoration.color, AppColors.neutralDark.withValues(alpha: 0.7));
        expect(progressIndicator.color, AppColors.neutralLight);
        expect(text.style?.color, AppColors.neutralLight);
      });

      testWidgets('uses AppTextStyles constants correctly', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: 'Loading...'),
          ),
        );

        final text = tester.widget<Text>(find.text('Loading...'));

        expect(text.style?.fontSize, AppTextStyles.bodySmall.fontSize);
      });
    });

    group('Constructor Behavior Tests', () {
      testWidgets('main constructor allows full customization', (tester) async {
        const testText = 'Custom overlay';
        const testShape = BoxShape.rectangle;
        const testBackgroundColor = Colors.indigo;
        const testProgressColor = Colors.amber;
        const testTextColor = Colors.teal;

        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(
              text: testText,
              shape: testShape,
              backgroundColor: testBackgroundColor,
              progressColor: testProgressColor,
              textColor: testTextColor,
            ),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        final progressIndicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));
        final text = tester.widget<Text>(find.text(testText));

        expect(decoration.shape, testShape);
        expect(decoration.color, testBackgroundColor);
        expect(progressIndicator.color, testProgressColor);
        expect(text.style?.color, testTextColor);
      });

      testWidgets('.avatar() constructor has correct fixed properties',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay.avatar(text: 'Avatar upload'),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;
        final progressIndicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));
        final text = tester.widget<Text>(find.text('Avatar upload'));

        // Shape is fixed to circle
        expect(decoration.shape, BoxShape.circle);

        // Colors are preset to neutralLight
        expect(progressIndicator.color, AppColors.neutralLight);
        expect(text.style?.color, AppColors.neutralLight);

        // Background uses default (null becomes neutralDark with alpha)
        expect(decoration.color, AppColors.neutralDark.withValues(alpha: 0.7));
      });

      testWidgets('.rectangle() constructor has correct fixed properties',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay.rectangle(text: 'File processing'),
          ),
        );

        final decoratedBox =
            tester.widget<DecoratedBox>(find.byType(DecoratedBox));
        final decoration = decoratedBox.decoration as BoxDecoration;

        // Shape is fixed to rectangle
        expect(decoration.shape, BoxShape.rectangle);

        // Other colors should use defaults when not specified
        expect(decoration.color, AppColors.neutralDark.withValues(alpha: 0.7));
      });
    });

    group('Edge Cases and Integration Tests', () {
      testWidgets('handles empty text gracefully', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: ''),
          ),
        );

        expect(find.byType(ProgressOverlay), findsOneWidget);
        expect(find.text(''), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('handles special characters in text', (tester) async {
        const specialText = 'Laddar... 🔄 åäö ñ';

        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: specialText),
          ),
        );

        expect(find.text(specialText), findsOneWidget);
      });

      testWidgets('works with extreme color values', (tester) async {
        const extremeColors = [
          Colors.transparent,
          Colors.black,
          Colors.white,
          Color(0x00000000),
          Color(0xFFFFFFFF),
        ];

        for (final color in extremeColors) {
          await tester.pumpWidget(
            createTestWidget(
              ProgressOverlay(
                text: 'Test',
                backgroundColor: color,
                progressColor: color,
                textColor: color,
              ),
            ),
          );

          expect(find.byType(ProgressOverlay), findsOneWidget);
        }
      });

      testWidgets('maintains functionality in Stack layout context',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const ProgressOverlay(text: 'Loading overlay'),
          ),
        );

        expect(find.byType(ProgressOverlay), findsOneWidget);
        expect(find.text('Loading overlay'), findsOneWidget);
        expect(
            find.text('Background'), findsOneWidget); // From our test wrapper
      });
    });
  });
}
