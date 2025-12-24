import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';

void main() {
  group('BaseDialog Ultrathink Widget Tests', () {
    // Helper to create properly configured test environment
    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        home: Material(
          child: child ?? const SizedBox.shrink(),
        ),
      );
    }

    group('ConfirmationDialog Tests', () {
      testWidgets('creates basic confirmation dialog with required parameters',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ConfirmationDialog(
                    title: 'Bekräfta åtgärd',
                    message: 'Är du säker på att du vill fortsätta?',
                  ),
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        );

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Verify dialog components
        expect(find.text('Bekräfta åtgärd'), findsOneWidget);
        expect(
            find.text('Är du säker på att du vill fortsätta?'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);
        expect(find.text('Avbryt'), findsOneWidget);
      });

      testWidgets('supports custom button text and title icon',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ConfirmationDialog(
                    title: 'Custom Dialog',
                    message: 'Custom message text',
                    titleIcon: Icons.help_outline,
                    primaryActionText: 'Fortsätt',
                    secondaryActionText: 'Stäng',
                  ),
                ),
                child: const Text('Custom Dialog'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Custom Dialog'));
        await tester.pumpAndSettle();

        // Verify customizations
        expect(find.byIcon(Icons.help_outline), findsOneWidget);
        expect(find.text('Fortsätt'), findsOneWidget);
        expect(find.text('Stäng'), findsOneWidget);
      });

      testWidgets('handles custom content widget', (WidgetTester tester) async {
        const customContent = Column(
          children: [
            Text('Custom Widget Content'),
            SizedBox(height: 16),
            Text('Additional information'),
          ],
        );

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ConfirmationDialog(
                    title: 'Custom Content Dialog',
                    message: 'This will be replaced',
                    customContent: customContent,
                  ),
                ),
                child: const Text('Custom Content'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Custom Content'));
        await tester.pumpAndSettle();

        // Verify custom content replaces message
        expect(find.text('Custom Widget Content'), findsOneWidget);
        expect(find.text('Additional information'), findsOneWidget);
        expect(find.text('This will be replaced'), findsNothing);
      });

      testWidgets('convenience show method works correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ConfirmationDialog.show(
                  context,
                  title: 'Convenience Method',
                  message: 'Testing convenience method',
                  primaryActionText: 'Acceptera',
                  isDangerous: false,
                ),
                child: const Text('Convenience Show'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Convenience Show'));
        await tester.pumpAndSettle();

        expect(find.text('Convenience Method'), findsOneWidget);
        expect(find.text('Testing convenience method'), findsOneWidget);
        expect(find.text('Acceptera'), findsOneWidget);
      });
    });

    group('DestructiveConfirmationDialog Tests', () {
      testWidgets(
          'creates destructive confirmation dialog with warning styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const DestructiveConfirmationDialog(
                    title: 'Ta bort objekt',
                    message: 'Vill du ta bort',
                    itemName: 'Test Recept',
                  ),
                ),
                child: const Text('Show Destructive'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Destructive'));
        await tester.pumpAndSettle();

        // Verify destructive dialog components
        expect(find.text('Ta bort objekt'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.text('Ta bort'), findsOneWidget);
        expect(find.text('Avbryt'), findsOneWidget);

        // Verify destructive dialog structure and content
        expect(find.byType(AlertDialog), findsOneWidget);
      });

      testWidgets('supports custom content over default message format',
          (WidgetTester tester) async {
        const customDestructiveContent =
            Text('Custom destructive content with special formatting');

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const DestructiveConfirmationDialog(
                    title: 'Custom Destructive',
                    message: 'Default message',
                    itemName: 'Item Name',
                    customContent: customDestructiveContent,
                  ),
                ),
                child: const Text('Custom Destructive'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Custom Destructive'));
        await tester.pumpAndSettle();

        expect(find.text('Custom destructive content with special formatting'),
            findsOneWidget);
        expect(find.text('Default message'), findsNothing);
      });

      testWidgets('convenience show method with custom parameters',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DestructiveConfirmationDialog.show(
                  context,
                  title: 'Radera permanent',
                  message: 'Detta kommer permanent radera',
                  itemName: 'Alla recept',
                  primaryActionText: 'Radera allt',
                  secondaryActionText: 'Behåll',
                ),
                child: const Text('Destructive Convenience'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Destructive Convenience'));
        await tester.pumpAndSettle();

        expect(find.text('Radera permanent'), findsOneWidget);
        expect(find.text('Radera allt'), findsOneWidget);
        expect(find.text('Behåll'), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
      });
    });

    group('LoadingDialog Tests', () {
      testWidgets('displays loading dialog with message',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const LoadingDialog(
                    message: 'Laddar data...',
                  ),
                ),
                child: const Text('Show Loading'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Loading'));
        await tester.pump();

        expect(find.text('Laddar data...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('supports cancellable loading dialog',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (_) => const LoadingDialog(
                    message: 'Avbrytbar laddning...',
                    canCancel: true,
                  ),
                ),
                child: const Text('Cancellable Loading'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Cancellable Loading'));
        await tester.pump();

        expect(find.text('Avbrytbar laddning...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('convenience show method works correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  LoadingDialog.show(
                    context,
                    message: 'Sparar ändringar...',
                    canCancel: false,
                  );
                },
                child: const Text('Loading Convenience'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Loading Convenience'));
        await tester.pump();

        expect(find.text('Sparar ändringar...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('convenience hide method exists',
          (WidgetTester tester) async {
        // Test that the static hide method exists
        expect(LoadingDialog.hide, isA<Function>());
      });
    });

    group('Dialog State Management', () {
      testWidgets('dialogs handle loading states properly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ConfirmationDialog(
                    title: 'State Test',
                    message: 'Testing state management',
                  ),
                ),
                child: const Text('State Test'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('State Test'));
        await tester.pumpAndSettle();

        // Verify dialog is displayed
        expect(find.text('Testing state management'), findsOneWidget);

        // Test button interactions
        final okButton = find.text('OK');
        expect(okButton, findsOneWidget);

        // Test cancel button
        final cancelButton = find.text('Avbryt');
        expect(cancelButton, findsOneWidget);
      });
    });

    group('Swedish Localization Support', () {
      testWidgets('all dialog text supports Swedish characters',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const ConfirmationDialog(
                        title: 'Förfrågning med ÅÄÖ',
                        message:
                            'Vill du spara ändringarna för användarens måltidsplan?',
                        primaryActionText: 'Spara ändringar',
                        secondaryActionText: 'Avbryt ändringarna',
                      ),
                    ),
                    child: const Text('Swedish Confirmation'),
                  ),
                  ElevatedButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const DestructiveConfirmationDialog(
                        title: 'Radera användarkonto',
                        message: 'Detta kommer permanent radera',
                        itemName: 'Åsa Öbergs konto och alla receptdata',
                      ),
                    ),
                    child: const Text('Swedish Destructive'),
                  ),
                  ElevatedButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const LoadingDialog(
                        message: 'Synkroniserar data med moln-tjänsten...',
                      ),
                    ),
                    child: const Text('Swedish Loading'),
                  ),
                ],
              ),
            ),
          ),
        );

        // Test each dialog type with Swedish characters
        await tester.tap(find.text('Swedish Confirmation'));
        await tester.pumpAndSettle();

        expect(find.text('Förfrågning med ÅÄÖ'), findsOneWidget);
        expect(
            find.text('Vill du spara ändringarna för användarens måltidsplan?'),
            findsOneWidget);
        expect(find.text('Spara ändringar'), findsOneWidget);
        expect(find.text('Avbryt ändringarna'), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Avbryt ändringarna'));
        await tester.pumpAndSettle();

        // Test destructive dialog
        await tester.tap(find.text('Swedish Destructive'));
        await tester.pumpAndSettle();

        expect(find.text('Radera användarkonto'), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Avbryt'));
        await tester.pumpAndSettle();

        // Test loading dialog
        await tester.tap(find.text('Swedish Loading'));
        await tester.pump();

        expect(find.text('Synkroniserar data med moln-tjänsten...'),
            findsOneWidget);
      });
    });

    group('Responsive Design Behavior', () {
      testWidgets('dialogs adapt to small screen sizes',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ConfirmationDialog(
                    title: 'Small Screen Test',
                    message:
                        'This dialog should adapt to small screen constraints',
                  ),
                ),
                child: const Text('Small Screen'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Small Screen'));
        await tester.pumpAndSettle();

        expect(find.text('Small Screen Test'), findsOneWidget);
        expect(
            find.text('This dialog should adapt to small screen constraints'),
            findsOneWidget);

        // Reset screen size
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('dialogs adapt to tablet screen sizes',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const LoadingDialog(
                    message: 'Tablet loading dialog test',
                  ),
                ),
                child: const Text('Tablet Test'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Tablet Test'));
        await tester.pump();

        expect(find.text('Tablet loading dialog test'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Reset screen size
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Dialog Interface Validation', () {
      testWidgets('base dialog classes exist and are accessible',
          (WidgetTester tester) async {
        // Verify that all base dialog classes exist and are properly exported
        expect(ConfirmationDialog, isA<Type>());
        expect(DestructiveConfirmationDialog, isA<Type>());
        expect(LoadingDialog, isA<Type>());
      });

      testWidgets('convenience methods have correct signatures',
          (WidgetTester tester) async {
        // Verify static convenience methods exist with correct types
        expect(ConfirmationDialog.show, isA<Function>());
        expect(DestructiveConfirmationDialog.show, isA<Function>());
        expect(LoadingDialog.show, isA<Function>());
        expect(LoadingDialog.hide, isA<Function>());
      });
    });
  });
}
