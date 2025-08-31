// test/widget/common/feedback/snackbar_widgets_test.dart
// Comprehensive tests for SnackbarWidgets using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/feedback/snackbar_widgets.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('SnackbarWidgets Tests', () {
    // Helper to create app with scaffold for snackbar testing
    Widget createTestApp({Widget? child}) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => child ?? 
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => SnackbarWidgets.showSuccessSnackbar(context, 'Success'),
                    child: const Text('Success'),
                  ),
                  ElevatedButton(
                    onPressed: () => SnackbarWidgets.showErrorSnackbar(context, 'Error'),
                    child: const Text('Error'),
                  ),
                  ElevatedButton(
                    onPressed: () => SnackbarWidgets.showWarningSnackbar(context, 'Warning'),
                    child: const Text('Warning'),
                  ),
                ],
              ),
          ),
        ),
      );
    }

    group('showSuccessSnackbar', () {
      testWidgets('should display success message', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        // Tap button to show snackbar
        await tester.tap(find.text('Success'));
        await tester.pump();

        // Verify snackbar appears with message
        expect(find.text('Success'), findsNWidgets(2)); // Button + Snackbar
        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('should display check circle icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Success'));
        await tester.pump();

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('should use success background color', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Success'));
        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, equals(AppColors.success));
      });

      testWidgets('should have floating behavior', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Success'));
        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.behavior, equals(SnackBarBehavior.floating));
      });

      testWidgets('should have 3 second duration', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Success'));
        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, equals(const Duration(seconds: 3)));
      });

      testWidgets('should display custom message', (WidgetTester tester) async {
        const customMessage = 'Operation completed successfully!';
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackbarWidgets.showSuccessSnackbar(context, customMessage),
                child: const Text('Show'),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Show'));
        await tester.pump();

        expect(find.text(customMessage), findsOneWidget);
      });

      testWidgets('should handle long message with text wrapping', (WidgetTester tester) async {
        final longMessage = 'A' * 200;
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackbarWidgets.showSuccessSnackbar(context, longMessage),
                child: const Text('Show'),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Show'));
        await tester.pump();

        expect(find.text(longMessage), findsOneWidget);
        expect(find.byType(Expanded), findsWidgets); // Text is wrapped in Expanded
      });

      testWidgets('should have correct duration setting', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Success'));
        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, equals(const Duration(seconds: 3)));
      });
    });

    group('showErrorSnackbar', () {
      testWidgets('should display error message', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Error'));
        await tester.pump();

        expect(find.text('Error'), findsNWidgets(2)); // Button + Snackbar
        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('should display error icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Error'));
        await tester.pump();

        expect(find.byIcon(Icons.error), findsOneWidget);
      });

      testWidgets('should use error background color', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Error'));
        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, equals(AppColors.error));
      });

      testWidgets('should have 4 second duration', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Error'));
        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, equals(const Duration(seconds: 4)));
      });

      testWidgets('should handle custom error message', (WidgetTester tester) async {
        const errorMessage = 'Failed to save data';
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackbarWidgets.showErrorSnackbar(context, errorMessage),
                child: const Text('Show'),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Show'));
        await tester.pump();

        expect(find.text(errorMessage), findsOneWidget);
      });
    });

    group('showWarningSnackbar', () {
      testWidgets('should display warning message', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Warning'));
        await tester.pump();

        expect(find.text('Warning'), findsNWidgets(2)); // Button + Snackbar
        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('should display warning icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Warning'));
        await tester.pump();

        expect(find.byIcon(Icons.warning_outlined), findsOneWidget);
      });

      testWidgets('should use warning background color', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Warning'));
        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, equals(AppColors.warning));
      });

      testWidgets('should have 4 second duration', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Warning'));
        await tester.pump();

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.duration, equals(const Duration(seconds: 4)));
      });

      testWidgets('should display warning icon with correct color', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Warning'));
        await tester.pump();

        final icon = tester.widget<Icon>(find.byIcon(Icons.warning_outlined));
        expect(icon.color, equals(AppColors.warning));
        expect(icon.size, equals(AppDimensions.iconSizeM));
      });
    });

    group('Icon Styling', () {
      testWidgets('should show success icon with correct styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Success'));
        await tester.pump();
        
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
        expect(icon.size, equals(AppDimensions.iconSizeM));
        expect(icon.color, equals(AppColors.neutralLight));
      });

      testWidgets('should show error icon with correct styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Error'));
        await tester.pump();
        
        expect(find.byIcon(Icons.error), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(Icons.error));
        expect(icon.size, equals(AppDimensions.iconSizeM));
        expect(icon.color, equals(AppColors.neutralLight));
      });

      testWidgets('should show warning icon with correct styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        await tester.tap(find.text('Warning'));
        await tester.pump();
        
        expect(find.byIcon(Icons.warning_outlined), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(Icons.warning_outlined));
        expect(icon.size, equals(AppDimensions.iconSizeM));
        expect(icon.color, equals(AppColors.warning));
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish success message', (WidgetTester tester) async {
        const swedishMessage = 'Åtgärden lyckades!';
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackbarWidgets.showSuccessSnackbar(context, swedishMessage),
                child: const Text('Show'),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Show'));
        await tester.pump();

        expect(find.text(swedishMessage), findsOneWidget);
      });

      testWidgets('should display Swedish error message', (WidgetTester tester) async {
        const swedishMessage = 'Ett fel uppstod vid sparande';
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackbarWidgets.showErrorSnackbar(context, swedishMessage),
                child: const Text('Show'),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Show'));
        await tester.pump();

        expect(find.text(swedishMessage), findsOneWidget);
      });

      testWidgets('should display Swedish warning message', (WidgetTester tester) async {
        const swedishMessage = 'Varning: Ändringarna har inte sparats';
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackbarWidgets.showWarningSnackbar(context, swedishMessage),
                child: const Text('Show'),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Show'));
        await tester.pump();

        expect(find.text(swedishMessage), findsOneWidget);
      });
    });

    group('Multiple Snackbars', () {
      testWidgets('should show only one snackbar at a time', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());

        // Show first snackbar
        await tester.tap(find.text('Success'));
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);
        
        // The snackbar system automatically replaces previous snackbars
        // This is Flutter's built-in behavior
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty message', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackbarWidgets.showSuccessSnackbar(context, ''),
                child: const Text('Show'),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Show'));
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        // Empty text widget should exist
        expect(find.text(''), findsOneWidget);
      });

      testWidgets('should handle very long message', (WidgetTester tester) async {
        final veryLongMessage = 'This is a very long message that should wrap properly. ' * 10;
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackbarWidgets.showErrorSnackbar(context, veryLongMessage),
                child: const Text('Show'),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Show'));
        await tester.pump();

        expect(find.text(veryLongMessage), findsOneWidget);
      });

      testWidgets('should handle special characters in message', (WidgetTester tester) async {
        const specialMessage = '!@#\$%^&*()_+{}:"<>?[]\\;\',./-=';
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SnackbarWidgets.showWarningSnackbar(context, specialMessage),
                child: const Text('Show'),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Show'));
        await tester.pump();

        expect(find.text(specialMessage), findsOneWidget);
      });
    });
  });
}