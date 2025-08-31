// test/widget/messaging/error_widgets_ultrathink_test.dart
// ULTRATHINK TEST SUITE: ErrorText and ErrorListTile
// 50 lines total - Simple error display widgets with consistent theming

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/widgets/messaging/error_text.dart';
import 'package:butlery/widgets/messaging/error_list_tile.dart';
import 'package:butlery/theme/app_colors.dart';

// Mock for callbacks
class MockCallbacks extends Mock {
  void onTap();
}

void main() {
  group('Error Widgets Ultrathink Tests', () {
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
            body: Center(child: child),
          ),
        ),
      );
    }

    group('ErrorText Tests', () {
      testWidgets('renders text with error color',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 16-21
        const testText = 'Ett fel uppstod';
        
        await tester.pumpWidget(
          createTestWidget(
            child: const ErrorText(testText),
          ),
        );

        // Should show the text
        expect(find.text(testText), findsOneWidget);
        
        // Should have error color styling
        final textWidget = tester.widget<Text>(find.text(testText));
        expect(textWidget.style?.color, equals(AppColors.error));
      });

      testWidgets('handles long error messages',
          (WidgetTester tester) async {
        // ULTRATHINK: Test text overflow handling
        final longText = 'Detta är ett väldigt långt felmeddelande som kan ' * 5;
        
        await tester.pumpWidget(
          createTestWidget(
            child: ErrorText(longText),
          ),
        );

        // Should render without overflow
        expect(find.text(longText), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles Swedish characters correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish character support
        const swedishText = 'Åtgärden misslyckades för användare Åsa';
        
        await tester.pumpWidget(
          createTestWidget(
            child: const ErrorText(swedishText),
          ),
        );

        expect(find.text(swedishText), findsOneWidget);
        final textWidget = tester.widget<Text>(find.text(swedishText));
        expect(textWidget.style?.color, equals(AppColors.error));
      });

      testWidgets('handles empty string',
          (WidgetTester tester) async {
        // ULTRATHINK: Edge case - empty string
        await tester.pumpWidget(
          createTestWidget(
            child: const ErrorText(''),
          ),
        );

        // Should render empty text without error
        expect(find.text(''), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('maintains consistent styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify TextStyle from line 19
        const testText = 'Fel';
        
        await tester.pumpWidget(
          createTestWidget(
            child: const ErrorText(testText),
          ),
        );

        final textWidget = tester.widget<Text>(find.text(testText));
        expect(textWidget.style, isNotNull);
        expect(textWidget.style?.color, equals(AppColors.error));
        // Should only set color, not other properties
        expect(textWidget.style?.fontSize, isNull);
        expect(textWidget.style?.fontWeight, isNull);
      });
    });

    group('ErrorListTile Tests', () {
      late MockCallbacks mockCallbacks;

      setUp(() {
        mockCallbacks = MockCallbacks();
        when(() => mockCallbacks.onTap()).thenReturn(null);
      });

      testWidgets('renders all components correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 21-26
        const testTitle = 'Försök igen';
        
        await tester.pumpWidget(
          createTestWidget(
            child: ErrorListTile(
              icon: Icons.refresh,
              title: testTitle,
              onTap: mockCallbacks.onTap,
            ),
          ),
        );

        // Should render ListTile
        expect(find.byType(ListTile), findsOneWidget);
        
        // Should show icon with error color
        final iconWidget = tester.widget<Icon>(find.byIcon(Icons.refresh));
        expect(iconWidget.color, equals(AppColors.error));
        
        // Should show ErrorText for title
        expect(find.byType(ErrorText), findsOneWidget);
        expect(find.text(testTitle), findsOneWidget);
      });

      testWidgets('handles tap correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test onTap from line 25
        await tester.pumpWidget(
          createTestWidget(
            child: ErrorListTile(
              icon: Icons.error_outline,
              title: 'Klicka för att försöka igen',
              onTap: mockCallbacks.onTap,
            ),
          ),
        );

        // Tap the ListTile
        await tester.tap(find.byType(ListTile));
        await tester.pump();
        
        // Verify callback was called
        verify(() => mockCallbacks.onTap()).called(1);
      });

      testWidgets('renders different icons correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test various icon types
        final icons = [
          Icons.error,
          Icons.warning,
          Icons.error_outline,
          Icons.cancel,
          Icons.close,
        ];

        for (final icon in icons) {
          await tester.pumpWidget(
            createTestWidget(
              child: ErrorListTile(
                icon: icon,
                title: 'Test',
                onTap: () {},
              ),
            ),
          );

          expect(find.byIcon(icon), findsOneWidget);
          final iconWidget = tester.widget<Icon>(find.byIcon(icon));
          expect(iconWidget.color, equals(AppColors.error));
        }
      });

      testWidgets('uses ErrorText for title styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify ErrorText usage from line 24
        const testTitle = 'Nätverksfel';
        
        await tester.pumpWidget(
          createTestWidget(
            child: ErrorListTile(
              icon: Icons.wifi_off,
              title: testTitle,
              onTap: () {},
            ),
          ),
        );

        // Should use ErrorText widget
        expect(find.byType(ErrorText), findsOneWidget);
        
        // ErrorText should contain the title
        final errorText = tester.widget<ErrorText>(find.byType(ErrorText));
        expect(errorText.text, equals(testTitle));
      });

      testWidgets('handles long titles correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test text overflow in ListTile
        final longTitle = 'Detta är en mycket lång felbeskrivning som ' * 3;
        
        await tester.pumpWidget(
          createTestWidget(
            child: ErrorListTile(
              icon: Icons.info,
              title: longTitle,
              onTap: () {},
            ),
          ),
        );

        // Should render without overflow
        expect(find.text(longTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles Swedish error messages',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish localization
        final swedishMessages = [
          'Kunde inte ansluta till servern',
          'Åtgärden avbröts av användaren',
          'Ogiltiga användaruppgifter',
          'Sessionen har löpt ut',
          'Försök igen senare',
        ];

        for (final message in swedishMessages) {
          await tester.pumpWidget(
            createTestWidget(
              child: ErrorListTile(
                icon: Icons.error,
                title: message,
                onTap: () {},
              ),
            ),
          );

          expect(find.text(message), findsOneWidget);
        }
      });

      testWidgets('maintains consistent theming',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify consistent error theming
        await tester.pumpWidget(
          createTestWidget(
            child: ErrorListTile(
              icon: Icons.warning_amber,
              title: 'Varning',
              onTap: () {},
            ),
          ),
        );

        // Icon should be error colored
        final icon = tester.widget<Icon>(find.byIcon(Icons.warning_amber));
        expect(icon.color, equals(AppColors.error));
        
        // Title should use ErrorText with error color
        final errorText = tester.widget<ErrorText>(find.byType(ErrorText));
        expect(errorText.text, equals('Varning'));
        
        final textWidget = tester.widget<Text>(find.text('Varning'));
        expect(textWidget.style?.color, equals(AppColors.error));
      });

      testWidgets('ListTile properties are properly set',
          (WidgetTester tester) async {
        // ULTRATHINK: Verify ListTile configuration from lines 22-26
        await tester.pumpWidget(
          createTestWidget(
            child: ErrorListTile(
              icon: Icons.replay,
              title: 'Försök på nytt',
              onTap: () {},
            ),
          ),
        );

        final listTile = tester.widget<ListTile>(find.byType(ListTile));
        
        // Should have leading icon
        expect(listTile.leading, isNotNull);
        expect(listTile.leading, isA<Icon>());
        
        // Should have title as ErrorText
        expect(listTile.title, isNotNull);
        expect(listTile.title, isA<ErrorText>());
        
        // Should have onTap
        expect(listTile.onTap, isNotNull);
      });
    });

    group('Integration Tests', () {
      testWidgets('ErrorText and ErrorListTile work together',
          (WidgetTester tester) async {
        // ULTRATHINK: Test both widgets together
        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ErrorText('Ett fel har inträffat'),
                ErrorListTile(
                  icon: Icons.refresh,
                  title: 'Försök igen',
                  onTap: () {},
                ),
              ],
            ),
          ),
        );

        // Both widgets should render
        expect(find.byType(ErrorText), findsNWidgets(2)); // One standalone, one in ListTile
        expect(find.byType(ErrorListTile), findsOneWidget);
        
        // All text should be error colored
        final texts = tester.widgetList<Text>(find.byType(Text));
        for (final text in texts) {
          if (text.data != null && text.data!.isNotEmpty) {
            expect(text.style?.color, equals(AppColors.error));
          }
        }
      });
    });
  });
}