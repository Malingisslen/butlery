// test/widget/messaging/attachment_options_container_ultrathink_test.dart
// ULTRATHINK TEST SUITE: AttachmentOptionsContainer
// 98-line attachment options widget with Swedish localization "Dela innehåll"

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/widgets/messaging/attachment_options_container.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

// Mock for callbacks
class MockCallbacks extends Mock {
  void onTap();
}

void main() {
  group('AttachmentOptionsContainer Ultrathink Tests', () {
    late MockCallbacks mockCallbacks1;
    late MockCallbacks mockCallbacks2;
    late MockCallbacks mockCallbacks3;
    late List<AttachmentOption> defaultOptions;

    // Helper to create properly configured test environment
    Widget createTestWidget({
      required Widget child,
      Size size = const Size(414, 896), // iPhone 11 Pro Max
    }) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        theme: ThemeData(
          primaryColor: AppColors.primaryBlue,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: child,
          ),
        ),
      );
    }

    setUp(() {
      mockCallbacks1 = MockCallbacks();
      mockCallbacks2 = MockCallbacks();
      mockCallbacks3 = MockCallbacks();

      // Setup default mock behavior
      when(() => mockCallbacks1.onTap()).thenReturn(null);
      when(() => mockCallbacks2.onTap()).thenReturn(null);
      when(() => mockCallbacks3.onTap()).thenReturn(null);

      // Create default options with Swedish labels
      defaultOptions = [
        AttachmentOption(
          icon: Icons.restaurant_menu,
          label: 'Recept',
          onTap: mockCallbacks1.onTap,
        ),
        AttachmentOption(
          icon: Icons.calendar_today,
          label: 'Meny',
          onTap: mockCallbacks2.onTap,
        ),
        AttachmentOption(
          icon: Icons.shopping_cart,
          label: 'Handlingslista',
          onTap: mockCallbacks3.onTap,
        ),
      ];
    });

    group('Rendering Tests', () {
      testWidgets('renders container with Swedish title',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 18-43
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        // Should show Swedish title "Dela innehåll" from line 25
        expect(find.text('Dela innehåll'), findsOneWidget);
        
        // Should have container with correct padding from line 20
        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        expect(container.padding, equals(const EdgeInsets.all(AppDimensions.paddingL)));
      });

      testWidgets('renders all attachment options',
          (WidgetTester tester) async {
        // ULTRATHINK: Test option rendering from lines 32-37
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        // Should render all option buttons
        expect(find.byType(AttachmentOptionButton), findsNWidgets(3));
        
        // Should show all labels
        expect(find.text('Recept'), findsOneWidget);
        expect(find.text('Meny'), findsOneWidget);
        expect(find.text('Handlingslista'), findsOneWidget);
        
        // Should show all icons
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
        expect(find.byIcon(Icons.calendar_today), findsOneWidget);
        expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
      });

      testWidgets('renders empty state correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty options list
        await tester.pumpWidget(
          createTestWidget(
            child: const AttachmentOptionsContainer(
              options: [],
            ),
          ),
        );

        // Should still show title
        expect(find.text('Dela innehåll'), findsOneWidget);
        
        // Should not have any option buttons
        expect(find.byType(AttachmentOptionButton), findsNothing);
      });

      testWidgets('uses correct title styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test title styling from lines 26-28
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        final titleText = tester.widget<Text>(find.text('Dela innehåll'));
        expect(titleText.style?.fontWeight, equals(FontWeight.bold));
        // Verify it's using headlineSmall style (from production line 26)
        expect(titleText.style?.fontSize, equals(AppTextStyles.headlineSmall.fontSize));
      });
    });

    group('AttachmentOptionButton Tests', () {
      testWidgets('renders individual button correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test button rendering from lines 56-84
        final option = AttachmentOption(
          icon: Icons.photo,
          label: 'Foto',
          onTap: mockCallbacks1.onTap,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionButton(option: option),
          ),
        );

        // Should show icon container
        final container = find.byWidgetPredicate(
          (widget) => widget is Container &&
              widget.constraints?.maxWidth == 56 &&
              widget.constraints?.maxHeight == 56,
        );
        expect(container, findsOneWidget);
        
        // Should show icon
        expect(find.byIcon(Icons.photo), findsOneWidget);
        
        // Should show label
        expect(find.text('Foto'), findsOneWidget);
      });

      testWidgets('icon container has correct styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test container styling from lines 61-67
        final option = AttachmentOption(
          icon: Icons.image,
          label: 'Bild',
          onTap: () {},
        );

        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionButton(option: option),
          ),
        );

        final container = tester.widget<Container>(
          find.byWidgetPredicate(
            (widget) => widget is Container &&
                widget.constraints?.maxWidth == 56 &&
                widget.constraints?.maxHeight == 56,
          ),
        );

        final decoration = container.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));
        expect(decoration.color, equals(AppColors.accent.withValues(alpha: 0.2)));
      });

      testWidgets('icon has correct size and color',
          (WidgetTester tester) async {
        // ULTRATHINK: Test icon styling from lines 68-72
        final option = AttachmentOption(
          icon: Icons.folder,
          label: 'Fil',
          onTap: () {},
        );

        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionButton(option: option),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.folder));
        expect(icon.size, equals(28));
        expect(icon.color, equals(AppColors.primaryBlue));
      });

      testWidgets('label has correct styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test label styling from lines 75-80
        final option = AttachmentOption(
          icon: Icons.link,
          label: 'Länk',
          onTap: () {},
        );

        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionButton(option: option),
          ),
        );

        final labelText = tester.widget<Text>(find.text('Länk'));
        expect(labelText.style?.color, equals(AppColors.textMedium));
        expect(labelText.style?.fontSize, equals(AppTextStyles.labelSmall.fontSize));
      });
    });

    group('Interaction Tests', () {
      testWidgets('handles tap on attachment option',
          (WidgetTester tester) async {
        // ULTRATHINK: Test tap handling from lines 57-58
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        // Tap the first option (Recept)
        await tester.tap(find.text('Recept'));
        await tester.pump();

        // Verify callback was called
        verify(() => mockCallbacks1.onTap()).called(1);
        verifyNever(() => mockCallbacks2.onTap());
        verifyNever(() => mockCallbacks3.onTap());
      });

      testWidgets('handles tap on icon',
          (WidgetTester tester) async {
        // ULTRATHINK: Test tapping icon triggers callback
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        // Tap the icon directly
        await tester.tap(find.byIcon(Icons.calendar_today));
        await tester.pump();

        // Verify correct callback was called
        verify(() => mockCallbacks2.onTap()).called(1);
      });

      testWidgets('handles multiple option taps independently',
          (WidgetTester tester) async {
        // ULTRATHINK: Test each option works independently
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        // Tap all options
        await tester.tap(find.text('Recept'));
        await tester.pump();
        
        await tester.tap(find.text('Meny'));
        await tester.pump();
        
        await tester.tap(find.text('Handlingslista'));
        await tester.pump();

        // Verify all callbacks were called once
        verify(() => mockCallbacks1.onTap()).called(1);
        verify(() => mockCallbacks2.onTap()).called(1);
        verify(() => mockCallbacks3.onTap()).called(1);
      });
    });

    group('Layout Tests', () {
      testWidgets('maintains proper spacing between elements',
          (WidgetTester tester) async {
        // ULTRATHINK: Test spacing from lines 30, 39, 74
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        // Check for SizedBox spacers
        final sizedBoxes = find.byType(SizedBox);
        expect(sizedBoxes, findsWidgets);
        
        // Verify spacing values
        final spacers = tester.widgetList<SizedBox>(sizedBoxes);
        for (final spacer in spacers) {
          if (spacer.height == AppDimensions.paddingL) {
            expect(spacer.height, equals(AppDimensions.paddingL));
          } else if (spacer.height == AppDimensions.paddingS) {
            expect(spacer.height, equals(AppDimensions.paddingS));
          }
        }
      });

      testWidgets('uses Row with spaceEvenly for options',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Row layout from lines 32-37
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        final row = tester.widget<Row>(
          find.descendant(
            of: find.byType(AttachmentOptionsContainer),
            matching: find.byType(Row),
          ),
        );
        expect(row.mainAxisAlignment, equals(MainAxisAlignment.spaceEvenly));
      });

      testWidgets('Column uses mainAxisSize.min',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Column configuration from line 22
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        final column = tester.widget<Column>(
          find.descendant(
            of: find.byType(AttachmentOptionsContainer),
            matching: find.byType(Column),
          ).first,
        );
        expect(column.mainAxisSize, equals(MainAxisSize.min));
      });
    });

    group('Swedish Localization Tests', () {
      testWidgets('displays Swedish title correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify Swedish text from line 25
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        expect(find.text('Dela innehåll'), findsOneWidget);
      });

      testWidgets('handles Swedish characters in labels',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish character support
        final swedishOptions = [
          AttachmentOption(
            icon: Icons.restaurant,
            label: 'Köttbullar',
            onTap: () {},
          ),
          AttachmentOption(
            icon: Icons.cake,
            label: 'Smörgåstårta',
            onTap: () {},
          ),
          AttachmentOption(
            icon: Icons.local_cafe,
            label: 'Fika',
            onTap: () {},
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: swedishOptions,
            ),
          ),
        );

        // Should handle Swedish characters correctly
        expect(find.text('Köttbullar'), findsOneWidget);
        expect(find.text('Smörgåstårta'), findsOneWidget);
        expect(find.text('Fika'), findsOneWidget);
      });
    });

    group('Edge Cases Tests', () {
      testWidgets('handles single option correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test with only one option
        final singleOption = [
          AttachmentOption(
            icon: Icons.photo,
            label: 'Foto',
            onTap: () {},
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: singleOption,
            ),
          ),
        );

        expect(find.byType(AttachmentOptionButton), findsOneWidget);
        expect(find.text('Foto'), findsOneWidget);
      });

      testWidgets('handles many options correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test with many options
        final manyOptions = List.generate(
          6,
          (index) => AttachmentOption(
            icon: Icons.folder,
            label: 'Option $index',
            onTap: () {},
          ),
        );

        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: manyOptions,
            ),
          ),
        );

        expect(find.byType(AttachmentOptionButton), findsNWidgets(6));
        for (int i = 0; i < 6; i++) {
          expect(find.text('Option $i'), findsOneWidget);
        }
      });

      testWidgets('handles long labels with proper layout',
          (WidgetTester tester) async {
        // ULTRATHINK: Test text overflow handling
        final longLabelOptions = [
          AttachmentOption(
            icon: Icons.description,
            label: 'Mycket lång etikett som kan orsaka overflow',
            onTap: () {},
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: longLabelOptions,
            ),
          ),
        );

        // Should render without overflow errors
        expect(tester.takeException(), isNull);
        expect(find.text('Mycket lång etikett som kan orsaka overflow'), findsOneWidget);
      });

      testWidgets('handles null callbacks gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test with direct function callbacks
        final options = [
          AttachmentOption(
            icon: Icons.photo,
            label: 'Test',
            onTap: () {
              // Direct callback without mock
            },
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: options,
            ),
          ),
        );

        // Should render without errors
        expect(find.text('Test'), findsOneWidget);
        
        // Tapping should not throw
        await tester.tap(find.text('Test'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    });

    group('Visual Tests', () {
      testWidgets('uses correct colors throughout',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify color scheme
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        // Icon should be primary blue (line 70)
        final icon = tester.widget<Icon>(find.byIcon(Icons.restaurant_menu));
        expect(icon.color, equals(AppColors.primaryBlue));
        
        // Label should be text medium (line 78)
        final label = tester.widget<Text>(find.text('Recept'));
        expect(label.style?.color, equals(AppColors.textMedium));
      });

      testWidgets('maintains consistent icon sizes',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify icon size consistency (line 71)
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        // All icons should be size 28
        final icons = tester.widgetList<Icon>(
          find.descendant(
            of: find.byType(AttachmentOptionButton),
            matching: find.byType(Icon),
          ),
        );
        
        for (final icon in icons) {
          expect(icon.size, equals(28));
        }
      });

      testWidgets('maintains consistent container sizes',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify container size consistency (lines 62-63)
        await tester.pumpWidget(
          createTestWidget(
            child: AttachmentOptionsContainer(
              options: defaultOptions,
            ),
          ),
        );

        // All containers should be 56x56
        final containers = find.byWidgetPredicate(
          (widget) => widget is Container &&
              widget.constraints?.maxWidth == 56 &&
              widget.constraints?.maxHeight == 56,
        );
        
        expect(containers, findsNWidgets(3)); // One for each option
      });
    });
  });
}