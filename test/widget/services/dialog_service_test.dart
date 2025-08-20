import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/dialog_service.dart';
import 'package:butlery/theme/app_colors.dart';

// Test app wrapper for proper context
class DialogTestApp extends StatelessWidget {
  final Widget child;
  final NavigatorObserver? navigatorObserver;
  
  const DialogTestApp({
    super.key,
    required this.child,
    this.navigatorObserver,
  });
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: child),
      navigatorObservers: navigatorObserver != null ? [navigatorObserver!] : [],
    );
  }
}

// Mock navigator observer to track dialog interactions
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

// Test widget that triggers dialogs
class DialogTriggerWidget extends StatelessWidget {
  final DialogService dialogService;
  final VoidCallback? onExitDialog;
  final VoidCallback? onExitDialogAndExit;
  final VoidCallback? onConfirmDialog;
  
  const DialogTriggerWidget({
    super.key,
    required this.dialogService,
    this.onExitDialog,
    this.onExitDialogAndExit,
    this.onConfirmDialog,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (onExitDialog != null)
          ElevatedButton(
            key: const Key('exit_dialog_button'),
            onPressed: () async {
              final result = await dialogService.showExitDialog(context);
              if (result) {
                onExitDialog!();
              }
            },
            child: const Text('Show Exit Dialog'),
          ),
        if (onExitDialogAndExit != null)
          ElevatedButton(
            key: const Key('exit_and_quit_button'),
            onPressed: () async {
              await dialogService.showExitDialogAndExit(context);
              onExitDialogAndExit!();
            },
            child: const Text('Show Exit and Quit'),
          ),
        if (onConfirmDialog != null)
          ElevatedButton(
            key: const Key('confirm_dialog_button'),
            onPressed: () async {
              final result = await dialogService.showConfirmDialog(
                context,
                title: 'Test Title',
                message: 'Test Message',
              );
              if (result) {
                onConfirmDialog!();
              }
            },
            child: const Text('Show Confirm Dialog'),
          ),
      ],
    );
  }
}

void main() {
  group('DialogService Widget Tests', () {
    late DialogService dialogService;
    
    setUp(() {
      dialogService = DialogService();
    });
    
    group('Exit Dialog', () {
      testWidgets('should display Swedish exit dialog with correct text', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onExitDialog: () {},
            ),
          ),
        );
        
        // Act
        await tester.tap(find.byKey(const Key('exit_dialog_button')));
        await tester.pumpAndSettle();
        
        // Assert
        expect(find.text('Avsluta Butlery?'), findsOneWidget);
        expect(find.text('Vill du verkligen avsluta appen?'), findsOneWidget);
        expect(find.text('Avbryt'), findsOneWidget);
        expect(find.text('Avsluta'), findsOneWidget);
      });
      
      testWidgets('should return true when user confirms exit', 
          (WidgetTester tester) async {
        // Arrange
        bool exitConfirmed = false;
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onExitDialog: () {
                exitConfirmed = true;
              },
            ),
          ),
        );
        
        // Act
        await tester.tap(find.byKey(const Key('exit_dialog_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Avsluta'));
        await tester.pumpAndSettle();
        
        // Assert
        expect(exitConfirmed, isTrue);
        expect(find.text('Avsluta Butlery?'), findsNothing); // Dialog closed
      });
      
      testWidgets('should return false when user cancels exit', 
          (WidgetTester tester) async {
        // Arrange
        bool exitConfirmed = false;
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onExitDialog: () {
                exitConfirmed = true;
              },
            ),
          ),
        );
        
        // Act
        await tester.tap(find.byKey(const Key('exit_dialog_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Avbryt'));
        await tester.pumpAndSettle();
        
        // Assert
        expect(exitConfirmed, isFalse);
        expect(find.text('Avsluta Butlery?'), findsNothing); // Dialog closed
      });
      
      testWidgets('should style exit button with error color', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onExitDialog: () {},
            ),
          ),
        );
        
        // Act
        await tester.tap(find.byKey(const Key('exit_dialog_button')));
        await tester.pumpAndSettle();
        
        // Assert
        final exitButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Avsluta'),
        );
        final buttonStyle = exitButton.style?.backgroundColor?.resolve({});
        expect(buttonStyle, equals(AppColors.error));
      });
      
      testWidgets('should dismiss dialog when tapping outside', 
          (WidgetTester tester) async {
        // Arrange
        bool exitConfirmed = false;
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onExitDialog: () {
                exitConfirmed = true;
              },
            ),
          ),
        );
        
        // Act
        await tester.tap(find.byKey(const Key('exit_dialog_button')));
        await tester.pumpAndSettle();
        
        // Tap outside dialog (on the barrier)
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        
        // Assert
        expect(exitConfirmed, isFalse);
        expect(find.text('Avsluta Butlery?'), findsNothing); // Dialog dismissed
      });
    });
    
    group('Exit Dialog and Exit', () {
      testWidgets('should show dialog and call exit when confirmed', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onExitDialogAndExit: () {
                // SystemNavigator.pop() will be called
              },
            ),
          ),
        );
        
        // Act
        await tester.tap(find.byKey(const Key('exit_and_quit_button')));
        await tester.pumpAndSettle();
        
        // Dialog should appear
        expect(find.text('Avsluta Butlery?'), findsOneWidget);
        
        // Confirm exit
        await tester.tap(find.text('Avsluta'));
        await tester.pumpAndSettle();
        
        // Note: SystemNavigator.pop() will be called but won't actually exit in tests
        // We can't directly test the system exit, but we can verify the flow
        expect(find.text('Avsluta Butlery?'), findsNothing);
      });
      
      testWidgets('should not exit when dialog is cancelled', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onExitDialogAndExit: () {},
            ),
          ),
        );
        
        // Act
        await tester.tap(find.byKey(const Key('exit_and_quit_button')));
        await tester.pumpAndSettle();
        
        // Cancel exit
        await tester.tap(find.text('Avbryt'));
        await tester.pumpAndSettle();
        
        // Assert - dialog closed, app still running
        expect(find.text('Avsluta Butlery?'), findsNothing);
        expect(find.byKey(const Key('exit_and_quit_button')), findsOneWidget);
      });
    });
    
    group('Confirmation Dialog', () {
      testWidgets('should display custom confirmation dialog with provided text', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          DialogTestApp(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await dialogService.showConfirmDialog(
                    context,
                    title: 'Delete Recipe',
                    message: 'Are you sure you want to delete this recipe?',
                    confirmText: 'Delete',
                    cancelText: 'Keep',
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        );
        
        // Act
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();
        
        // Assert
        expect(find.text('Delete Recipe'), findsOneWidget);
        expect(find.text('Are you sure you want to delete this recipe?'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
        expect(find.text('Keep'), findsOneWidget);
      });
      
      testWidgets('should use default Swedish text when not customized', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          DialogTestApp(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await dialogService.showConfirmDialog(
                    context,
                    title: 'Bekräfta åtgärd',
                    message: 'Är du säker?',
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        );
        
        // Act
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();
        
        // Assert
        expect(find.text('Bekräfta'), findsOneWidget); // Default confirm text
        expect(find.text('Avbryt'), findsOneWidget); // Default cancel text
      });
      
      testWidgets('should return true when confirmed', 
          (WidgetTester tester) async {
        // Arrange
        bool confirmed = false;
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onConfirmDialog: () {
                confirmed = true;
              },
            ),
          ),
        );
        
        // Act
        await tester.tap(find.byKey(const Key('confirm_dialog_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bekräfta'));
        await tester.pumpAndSettle();
        
        // Assert
        expect(confirmed, isTrue);
      });
      
      testWidgets('should return false when cancelled', 
          (WidgetTester tester) async {
        // Arrange
        bool confirmed = false;
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onConfirmDialog: () {
                confirmed = true;
              },
            ),
          ),
        );
        
        // Act
        await tester.tap(find.byKey(const Key('confirm_dialog_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Avbryt'));
        await tester.pumpAndSettle();
        
        // Assert
        expect(confirmed, isFalse);
      });
      
      testWidgets('should apply destructive styling when isDestructive is true', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          DialogTestApp(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await dialogService.showConfirmDialog(
                    context,
                    title: 'Delete All',
                    message: 'This action cannot be undone',
                    confirmText: 'Delete All',
                    isDestructive: true,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        );
        
        // Act
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();
        
        // Assert
        final deleteButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Delete All'),
        );
        final buttonStyle = deleteButton.style?.backgroundColor?.resolve({});
        expect(buttonStyle, equals(AppColors.error));
      });
      
      testWidgets('should not apply destructive styling when isDestructive is false', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          DialogTestApp(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await dialogService.showConfirmDialog(
                    context,
                    title: 'Save Changes',
                    message: 'Do you want to save your changes?',
                    confirmText: 'Save',
                    isDestructive: false,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        );
        
        // Act
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();
        
        // Assert
        final saveButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save'),
        );
        // When not destructive, style should be null (default)
        expect(saveButton.style, isNull);
      });
    });
    
    group('Dialog Layout and Behavior', () {
      testWidgets('should position buttons correctly with cancel on left', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          DialogTestApp(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await dialogService.showConfirmDialog(
                    context,
                    title: 'Test',
                    message: 'Test message',
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        );
        
        // Act
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();
        
        // Assert - Get button positions
        final cancelButton = tester.getCenter(find.text('Avbryt'));
        final confirmButton = tester.getCenter(find.text('Bekräfta'));
        
        // Cancel should be to the left of confirm
        expect(cancelButton.dx, lessThan(confirmButton.dx));
      });
      
      testWidgets('should handle rapid dialog opening and closing', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onExitDialog: () {},
            ),
          ),
        );
        
        // Act - Open and close rapidly
        for (int i = 0; i < 3; i++) {
          await tester.tap(find.byKey(const Key('exit_dialog_button')));
          await tester.pump(); // Don't wait for animation
          await tester.tap(find.text('Avbryt').last);
          await tester.pump();
        }
        
        await tester.pumpAndSettle();
        
        // Assert - Should handle rapid actions without issues
        expect(find.text('Avsluta Butlery?'), findsNothing);
        expect(find.byKey(const Key('exit_dialog_button')), findsOneWidget);
      });
      
      testWidgets('should handle context that becomes invalid', 
          (WidgetTester tester) async {
        // Arrange
        late BuildContext capturedContext;
        await tester.pumpWidget(
          DialogTestApp(
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return const Text('Test');
              },
            ),
          ),
        );
        
        // Navigate away to invalidate context
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Text('New Page')),
          ),
        );
        
        // Act - Try to show dialog with invalid context
        final result = await dialogService.showExitDialog(capturedContext);
        
        // Assert - Should return false safely
        expect(result, isFalse);
      });
      
      testWidgets('should properly clean up when widget is disposed', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onExitDialog: () {},
            ),
          ),
        );
        
        // Act
        await tester.tap(find.byKey(const Key('exit_dialog_button')));
        await tester.pumpAndSettle();
        
        // Dispose by navigating away
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        
        // Assert - Dialog should be gone
        expect(find.text('Avsluta Butlery?'), findsNothing);
      });
    });
    
    group('Accessibility and Theming', () {
      testWidgets('should be accessible with semantic labels', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onExitDialog: () {},
            ),
          ),
        );
        
        // Act
        await tester.tap(find.byKey(const Key('exit_dialog_button')));
        await tester.pumpAndSettle();
        
        // Assert - Dialog components should be accessible
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget); // Cancel button
        expect(find.byType(FilledButton), findsOneWidget); // Confirm button
      });
      
      testWidgets('should respond to theme changes', 
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: ThemeMode.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await dialogService.showExitDialog(context);
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        );
        
        // Act
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();
        
        // Assert - Dialog should use current theme
        final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(dialog, isNotNull);
      });
    });
    
    group('Edge Cases', () {
      testWidgets('should handle null return from dialog gracefully', 
          (WidgetTester tester) async {
        // Arrange
        bool exitConfirmed = false;
        await tester.pumpWidget(
          DialogTestApp(
            child: DialogTriggerWidget(
              dialogService: dialogService,
              onExitDialog: () {
                exitConfirmed = true;
              },
            ),
          ),
        );
        
        // Act - Open dialog and dismiss with back button
        await tester.tap(find.byKey(const Key('exit_dialog_button')));
        await tester.pumpAndSettle();
        
        // Simulate back button press
        final NavigatorState navigator = tester.state(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();
        
        // Assert - Should treat as cancellation
        expect(exitConfirmed, isFalse);
      });
      
      testWidgets('should handle very long text in dialogs', 
          (WidgetTester tester) async {
        // Arrange
        final longTitle = 'A' * 100;
        final longMessage = 'B' * 500;
        
        await tester.pumpWidget(
          DialogTestApp(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await dialogService.showConfirmDialog(
                    context,
                    title: longTitle,
                    message: longMessage,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        );
        
        // Act
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();
        
        // Assert - Dialog should handle long text (scrollable if needed)
        expect(find.text(longTitle), findsOneWidget);
        expect(find.text(longMessage), findsOneWidget);
      });
      
      testWidgets('should handle special characters in text', 
          (WidgetTester tester) async {
        // Arrange
        const specialText = 'Test with åäö ÅÄÖ & special chars!@#\$%^&*()';
        
        await tester.pumpWidget(
          DialogTestApp(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await dialogService.showConfirmDialog(
                    context,
                    title: specialText,
                    message: 'Message with émojis 🍽️ 👨‍🍳',
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        );
        
        // Act
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();
        
        // Assert
        expect(find.text(specialText), findsOneWidget);
        expect(find.text('Message with émojis 🍽️ 👨‍🍳'), findsOneWidget);
      });
    });
  });
}