// test/widget/branding/app_logo_test.dart
// Comprehensive tests for AppLogo and AppBranding widgets using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/branding/app_logo.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';

void main() {
  group('AppLogo Widget Tests', () {
    // Helper to wrap widget with MaterialApp for proper theming
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('Default Constructor', () {
      testWidgets('should render with default properties', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const AppLogo()));

        // Verify widget exists
        expect(find.byType(AppLogo), findsOneWidget);
        
        // Verify Container with default size
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, equals(AppDimensions.imageSizeLarge));
        expect(container.constraints?.maxHeight, equals(AppDimensions.imageSizeLarge));
        
        // Verify decoration
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.primaryBlue));
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadius12)));
        expect(decoration.boxShadow, isNull); // No shadow by default
        
        // Verify Icon
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, equals(Icons.restaurant_menu));
        expect(icon.color, equals(AppColors.neutralLight));
        expect(icon.size, equals(AppDimensions.imageSizeLarge * 0.4));
      });

      testWidgets('should accept custom size', (WidgetTester tester) async {
        const customSize = 100.0;
        await tester.pumpWidget(createTestWidget(const AppLogo(size: customSize)));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, equals(customSize));
        expect(container.constraints?.maxHeight, equals(customSize));
        
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, equals(customSize * 0.4)); // Icon is 40% of container
      });

      testWidgets('should accept custom colors', (WidgetTester tester) async {
        const customBgColor = Colors.red;
        const customIconColor = Colors.white;
        
        await tester.pumpWidget(createTestWidget(
          const AppLogo(
            backgroundColor: customBgColor,
            iconColor: customIconColor,
          ),
        ));

        final decoration = tester.widget<Container>(find.byType(Container)).decoration as BoxDecoration;
        expect(decoration.color, equals(customBgColor));
        
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(customIconColor));
      });

      testWidgets('should accept custom icon', (WidgetTester tester) async {
        const customIcon = Icons.kitchen;
        
        await tester.pumpWidget(createTestWidget(
          const AppLogo(icon: customIcon),
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, equals(customIcon));
      });

      testWidgets('should render shadow when showShadow is true', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const AppLogo(showShadow: true),
        ));

        final decoration = tester.widget<Container>(find.byType(Container)).decoration as BoxDecoration;
        expect(decoration.boxShadow, isNotNull);
        expect(decoration.boxShadow!.length, equals(1));
        
        final shadow = decoration.boxShadow!.first;
        expect(shadow.color, equals(AppColors.primaryBlue.withValues(alpha: 0.3)));
        expect(shadow.blurRadius, equals(AppDimensions.elevationMedium * 2));
        expect(shadow.offset, equals(const Offset(0, AppDimensions.elevationMedium)));
      });
    });

    group('Named Constructors', () {
      testWidgets('AppLogo.large should render with large size and shadow', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const AppLogo.large()));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, equals(AppDimensions.imageSizeLarge));
        
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.boxShadow, isNotNull); // Large has shadow
        
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, equals(AppDimensions.imageSizeLarge * 0.4));
      });

      testWidgets('AppLogo.medium should render with medium size', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const AppLogo.medium()));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, equals(120.0));
        
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.boxShadow, isNull); // Medium has no shadow
        
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, equals(120.0 * 0.4));
      });

      testWidgets('AppLogo.small should render with small size', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const AppLogo.small()));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, equals(AppDimensions.iconSizeXxl));
        
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.boxShadow, isNull); // Small has no shadow
        
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, equals(AppDimensions.iconSizeXxl * 0.4));
      });

      testWidgets('named constructors should accept custom colors', (WidgetTester tester) async {
        const customBg = Colors.green;
        const customIcon = Colors.yellow;
        
        await tester.pumpWidget(createTestWidget(
          const AppLogo.large(
            backgroundColor: customBg,
            iconColor: customIcon,
          ),
        ));

        final decoration = tester.widget<Container>(find.byType(Container)).decoration as BoxDecoration;
        expect(decoration.color, equals(customBg));
        
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(customIcon));
      });
    });

    group('Visual Consistency', () {
      testWidgets('should maintain proper icon to container ratio', (WidgetTester tester) async {
        const sizes = [50.0, 100.0, 200.0, 300.0];
        
        for (final size in sizes) {
          await tester.pumpWidget(createTestWidget(AppLogo(size: size)));
          
          final icon = tester.widget<Icon>(find.byType(Icon));
          expect(icon.size, equals(size * 0.4), 
            reason: 'Icon should be 40% of container size for size $size');
        }
      });

      testWidgets('should have consistent border radius', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const AppLogo()));
        
        final decoration = tester.widget<Container>(find.byType(Container)).decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadius12)));
      });
    });
  });

  group('AppBranding Widget Tests', () {
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          textTheme: const TextTheme(
            headlineMedium: TextStyle(fontSize: 24),
            bodyMedium: TextStyle(fontSize: 14),
          ),
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryBlue,
            onSurface: Colors.black,
          ),
        ),
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('Default Constructor', () {
      testWidgets('should render with default app name', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const AppBranding()));

        expect(find.byType(AppLogo), findsOneWidget);
        expect(find.text('Butlery'), findsOneWidget);
        expect(find.textContaining('assistent'), findsNothing); // No tagline by default
      });

      testWidgets('should render with custom app name', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const AppBranding(appName: 'CustomApp'),
        ));

        expect(find.text('CustomApp'), findsOneWidget);
        expect(find.text('Butlery'), findsNothing);
      });

      testWidgets('should render tagline when provided', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const AppBranding(tagline: 'Test Tagline'),
        ));

        expect(find.text('Test Tagline'), findsOneWidget);
        
        // Verify spacing
        final column = tester.widget<Column>(find.byType(Column));
        expect(column.children.length, equals(5)); // Logo, spacing, name, spacing, tagline
      });

      testWidgets('should not render tagline when null', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const AppBranding()));

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.children.length, equals(3)); // Logo, spacing, name only
      });

      testWidgets('should apply custom text styles', (WidgetTester tester) async {
        const customNameStyle = TextStyle(fontSize: 30, color: Colors.red);
        const customTaglineStyle = TextStyle(fontSize: 12, color: Colors.blue);
        
        await tester.pumpWidget(createTestWidget(
          const AppBranding(
            tagline: 'Test',
            nameStyle: customNameStyle,
            taglineStyle: customTaglineStyle,
          ),
        ));

        final nameText = tester.widget<Text>(find.text('Butlery'));
        expect(nameText.style?.fontSize, equals(30));
        expect(nameText.style?.color, equals(Colors.red));
        
        final taglineText = tester.widget<Text>(find.text('Test'));
        expect(taglineText.style?.fontSize, equals(12));
        expect(taglineText.style?.color, equals(Colors.blue));
      });
    });

    group('Named Constructors', () {
      testWidgets('AppBranding.auth should render with Swedish tagline', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const AppBranding.auth()));

        expect(find.text('Butlery'), findsOneWidget);
        expect(find.text('Din personliga recept-assistent'), findsOneWidget);
        
        // Verify large logo size
        final appLogo = tester.widget<AppLogo>(find.byType(AppLogo));
        expect(appLogo.size, equals(AppDimensions.imageSizeLarge));
        expect(appLogo.showShadow, isTrue);
      });

      testWidgets('AppBranding.auth should accept custom tagline', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const AppBranding.auth(tagline: 'Custom Swedish Text'),
        ));

        expect(find.text('Custom Swedish Text'), findsOneWidget);
        expect(find.text('Din personliga recept-assistent'), findsNothing);
      });

      testWidgets('AppBranding.header should render without tagline', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const AppBranding.header()));

        expect(find.text('Butlery'), findsOneWidget);
        expect(find.textContaining('assistent'), findsNothing);
        
        // Verify small logo size
        final appLogo = tester.widget<AppLogo>(find.byType(AppLogo));
        expect(appLogo.size, equals(AppDimensions.iconSizeXxl));
        expect(appLogo.showShadow, isFalse);
      });
    });

    group('Layout and Spacing', () {
      testWidgets('should have correct spacing between elements', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const AppBranding(tagline: 'Test'),
        ));

        final column = tester.widget<Column>(find.byType(Column));
        final children = column.children;
        
        // Check spacing after logo
        expect(children[1], isA<SizedBox>());
        expect((children[1] as SizedBox).height, equals(AppDimensions.spacing16));
        
        // Check spacing before tagline
        expect(children[3], isA<SizedBox>());
        expect((children[3] as SizedBox).height, equals(AppDimensions.spacing8));
      });

      testWidgets('should center align tagline text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const AppBranding(tagline: 'Centered Tagline'),
        ));

        final taglineText = tester.widget<Text>(find.text('Centered Tagline'));
        expect(taglineText.textAlign, equals(TextAlign.center));
      });
    });

    group('Theme Integration', () {
      testWidgets('should use theme colors for text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const AppBranding(tagline: 'Test')));

        final nameText = tester.widget<Text>(find.text('Butlery'));
        expect(nameText.style?.color, equals(AppColors.primaryBlue));
        
        final taglineText = tester.widget<Text>(find.text('Test'));
        expect(taglineText.style?.color?.a, lessThan(1.0)); // Has transparency
      });

      testWidgets('should apply bold weight to app name', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const AppBranding()));

        final nameText = tester.widget<Text>(find.text('Butlery'));
        expect(nameText.style?.fontWeight, equals(FontWeight.bold));
      });
    });

    group('Swedish Localization', () {
      testWidgets('auth variant should display Swedish tagline', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const AppBranding.auth()));

        // Verify Swedish text is present
        expect(find.text('Din personliga recept-assistent'), findsOneWidget);
        
        // Verify it's properly displayed as a Text widget
        final tagline = tester.widget<Text>(find.text('Din personliga recept-assistent'));
        expect(tagline, isNotNull);
      });
    });
  });
}