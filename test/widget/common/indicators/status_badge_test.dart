// test/widget/common/indicators/status_badge_test.dart
// Comprehensive tests for StatusBadge using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/status_badge.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('StatusBadge Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Default Constructor', () {
      testWidgets('should render with required text', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: 'TEST'),
            ),
          ),
        );

        expect(find.text('TEST'), findsOneWidget);
        expect(find.byType(StatusBadge), findsOneWidget);
      });

      testWidgets('should use theme primary color by default', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                primary: Colors.blue,
              ),
            ),
            home: const Scaffold(
              body: StatusBadge(text: 'STATUS'),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.blue));
      });

      testWidgets('should use theme onPrimary color for text by default', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                primary: Colors.blue,
                onPrimary: Colors.white,
              ),
            ),
            home: const Scaffold(
              body: StatusBadge(text: 'STATUS'),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('STATUS'));
        expect(text.style?.color, equals(Colors.white));
      });

      testWidgets('should apply custom background color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(
                text: 'CUSTOM',
                backgroundColor: Colors.red,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.red));
      });

      testWidgets('should apply custom text color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(
                text: 'CUSTOM',
                textColor: Colors.yellow,
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('CUSTOM'));
        expect(text.style?.color, equals(Colors.yellow));
      });

      testWidgets('should apply both custom colors', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(
                text: 'BOTH',
                backgroundColor: Colors.purple,
                textColor: Colors.orange,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.purple));

        final text = tester.widget<Text>(find.text('BOTH'));
        expect(text.style?.color, equals(Colors.orange));
      });
    });

    group('Primary Constructor', () {
      testWidgets('should render with primary constructor', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge.primary(text: 'PRIMARY'),
            ),
          ),
        );

        expect(find.text('PRIMARY'), findsOneWidget);
        expect(find.byType(StatusBadge), findsOneWidget);
      });

      testWidgets('should use theme primary color', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                primary: Colors.green,
              ),
            ),
            home: const Scaffold(
              body: StatusBadge.primary(text: 'PRIMARY'),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.green));
      });

      testWidgets('should use theme onPrimary color for text', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                primary: Colors.green,
                onPrimary: Colors.black,
              ),
            ),
            home: const Scaffold(
              body: StatusBadge.primary(text: 'PRIMARY'),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('PRIMARY'));
        expect(text.style?.color, equals(Colors.black));
      });
    });

    group('Styling', () {
      testWidgets('should have correct padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: 'PADDED'),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(
          container.padding,
          equals(const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingS,
            vertical: AppDimensions.spacingXs,
          )),
        );
      });

      testWidgets('should have rounded corners', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: 'ROUNDED'),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(
          decoration.borderRadius,
          equals(BorderRadius.circular(AppDimensions.borderRadiusRound)),
        );
      });

      testWidgets('should use labelSmall text style', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              textTheme: const TextTheme(
                labelSmall: TextStyle(fontSize: 11),
              ),
            ),
            home: const Scaffold(
              body: StatusBadge(text: 'SMALL'),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('SMALL'));
        expect(text.style?.fontSize, equals(11));
      });

      testWidgets('should have fontWeight 600', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: 'BOLD'),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('BOLD'));
        expect(text.style?.fontWeight, equals(FontWeight.w600));
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish text correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: 'DELAD MENY'),
            ),
          ),
        );

        expect(find.text('DELAD MENY'), findsOneWidget);
      });

      testWidgets('should display Swedish status "NYA"', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: 'NYA'),
            ),
          ),
        );

        expect(find.text('NYA'), findsOneWidget);
      });

      testWidgets('should display Swedish status "AKTIV"', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: 'AKTIV'),
            ),
          ),
        );

        expect(find.text('AKTIV'), findsOneWidget);
      });

      testWidgets('should handle Swedish characters', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: 'ÄRENDEN'),
            ),
          ),
        );

        expect(find.text('ÄRENDEN'), findsOneWidget);
      });
    });

    group('Theme Variations', () {
      testWidgets('should adapt to light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: StatusBadge(text: 'LIGHT'),
            ),
          ),
        );

        expect(find.byType(StatusBadge), findsOneWidget);
        expect(find.text('LIGHT'), findsOneWidget);
      });

      testWidgets('should adapt to dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: StatusBadge(text: 'DARK'),
            ),
          ),
        );

        expect(find.byType(StatusBadge), findsOneWidget);
        expect(find.text('DARK'), findsOneWidget);
      });

      testWidgets('should use dark theme primary color', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: const ColorScheme.dark(
                primary: Colors.tealAccent,
              ),
            ),
            home: const Scaffold(
              body: StatusBadge(text: 'DARK PRIMARY'),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.tealAccent));
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty text', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: ''),
            ),
          ),
        );

        expect(find.text(''), findsOneWidget);
        expect(find.byType(StatusBadge), findsOneWidget);
      });

      testWidgets('should handle very long text', (WidgetTester tester) async {
        final longText = 'VERY LONG STATUS TEXT THAT MIGHT OVERFLOW';
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: longText),
            ),
          ),
        );

        expect(find.text(longText), findsOneWidget);
      });

      testWidgets('should handle special characters', (WidgetTester tester) async {
        const specialText = 'STATUS!@#\$%^&*()';
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: specialText),
            ),
          ),
        );

        expect(find.text(specialText), findsOneWidget);
      });

      testWidgets('should handle numbers in text', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: '123'),
            ),
          ),
        );

        expect(find.text('123'), findsOneWidget);
      });

      testWidgets('should handle mixed case text', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: 'MiXeD CaSe'),
            ),
          ),
        );

        expect(find.text('MiXeD CaSe'), findsOneWidget);
      });
    });

    group('Layout Integration', () {
      testWidgets('should work in a Row', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  StatusBadge(text: 'LEFT'),
                  StatusBadge(text: 'RIGHT'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('LEFT'), findsOneWidget);
        expect(find.text('RIGHT'), findsOneWidget);
      });

      testWidgets('should work in a Column', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  StatusBadge(text: 'TOP'),
                  StatusBadge(text: 'BOTTOM'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('TOP'), findsOneWidget);
        expect(find.text('BOTTOM'), findsOneWidget);
      });

      testWidgets('should work in a Wrap', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Wrap(
                children: [
                  StatusBadge(text: 'ONE'),
                  StatusBadge(text: 'TWO'),
                  StatusBadge(text: 'THREE'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('ONE'), findsOneWidget);
        expect(find.text('TWO'), findsOneWidget);
        expect(find.text('THREE'), findsOneWidget);
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}