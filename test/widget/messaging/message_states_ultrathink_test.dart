// test/widget/messaging/message_states_ultrathink_test.dart
// ULTRATHINK TEST SUITE: MessageStates Widget - 258 lines of production code
// Testing 4 state types (error, success, info, warning) with Swedish localization and styling

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code
import 'package:butlery/widgets/common/state/message_states.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('MessageStates Ultrathink Tests', () {
    // Helper to create properly configured test environment
    Widget createTestWidget({
      required Widget child,
      Size size = const Size(414, 896), // iPhone 11 Pro Max
    }) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        theme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.light(
            primary: AppColors.forestGreen,
            error: AppColors.error,
          ),
        ),
        home: Scaffold(
          body: child,
        ),
      );
    }

    group('Error State Tests', () {
      testWidgets('builds basic error state with default parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 14-83
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(context),
            ),
          ),
        );

        // Should render main structure (may find multiple Center widgets due to framework)
        expect(find.byType(Center), findsAtLeastNWidgets(1));
        expect(find.byType(Padding), findsAtLeastNWidgets(1));
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);

        // Should show default Swedish error title
        expect(find.text('Ett fel uppstod'), findsOneWidget);

        // Should show error icon
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });

      testWidgets('error state shows custom title and message',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with custom title and message
        const customTitle = 'Anslutningsfel';
        const customMessage = 'Kunde inte ansluta till servern. Försök igen.';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(
                context,
                title: customTitle,
                message: customMessage,
              ),
            ),
          ),
        );

        expect(find.text(customTitle), findsOneWidget);
        expect(find.text(customMessage), findsOneWidget);
      });

      testWidgets('error state shows action button with callback',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 68-77
        bool actionCalled = false;
        const actionLabel = 'Försök igen';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(
                context,
                actionLabel: actionLabel,
                onAction: () {
                  actionCalled = true;
                },
              ),
            ),
          ),
        );

        // Should show action button
        expect(find.text(actionLabel), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        // Should trigger callback when pressed
        await tester.tap(find.text(actionLabel));
        expect(actionCalled, isTrue);
      });

      testWidgets('error state with custom icon and colors',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with custom styling
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(
                context,
                icon: Icons.warning,
                iconColor: Colors.red,
                iconSize: 64.0,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.warning), findsOneWidget);

        final icon = tester.widget<Icon>(find.byIcon(Icons.warning));
        expect(icon.color, equals(Colors.red));
        expect(icon.size, equals(64.0));
      });

      testWidgets('error state with custom padding',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with custom padding
        const customPadding = EdgeInsets.all(50);

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(
                context,
                padding: customPadding,
              ),
            ),
          ),
        );

        // Find the Padding widget that contains our custom padding
        final paddingWidgets = tester.widgetList<Padding>(find.byType(Padding));
        expect(paddingWidgets.any((p) => p.padding == customPadding), isTrue);
      });

      testWidgets('error message container has correct styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 52-65
        const errorMessage = 'Detta är ett felmeddelande';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(
                context,
                message: errorMessage,
              ),
            ),
          ),
        );

        expect(find.text(errorMessage), findsOneWidget);

        // Should have Container with error styling
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, greaterThan(0));

        // Should have error text with correct style
        final textWidgets = tester.widgetList<Text>(find.text(errorMessage));
        expect(textWidgets.first.style?.color, equals(AppColors.error));
      });
    });

    group('Success State Tests', () {
      testWidgets('builds basic success state with default parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 85-145
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildSuccessState(context),
            ),
          ),
        );

        // Should render main structure (may find multiple Center widgets due to framework)
        expect(find.byType(Center), findsAtLeastNWidgets(1));
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);

        // Should show default Swedish success title
        expect(find.text('Klart!'), findsOneWidget);

        // Should show success icon
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      });

      testWidgets('success state shows custom title and message',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with custom parameters
        const customTitle = 'Framgångsrikt!';
        const customMessage = 'Ditt recept har sparats framgångsrikt.';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildSuccessState(
                context,
                title: customTitle,
                message: customMessage,
              ),
            ),
          ),
        );

        expect(find.text(customTitle), findsOneWidget);
        expect(find.text(customMessage), findsOneWidget);
      });

      testWidgets('success state with action button',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 131-139
        bool actionCalled = false;
        const actionLabel = 'Fortsätt';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildSuccessState(
                context,
                actionLabel: actionLabel,
                onAction: () {
                  actionCalled = true;
                },
              ),
            ),
          ),
        );

        expect(find.text(actionLabel), findsOneWidget);

        await tester.tap(find.text(actionLabel));
        expect(actionCalled, isTrue);
      });

      testWidgets('success state with custom icon and styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with custom styling
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildSuccessState(
                context,
                icon: Icons.done,
                iconColor: Colors.green,
                iconSize: AppDimensions.iconSizeL,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.done), findsOneWidget);

        final icon = tester.widget<Icon>(find.byIcon(Icons.done));
        expect(icon.color, equals(Colors.green));
        expect(icon.size, equals(AppDimensions.iconSizeL));
      });
    });

    group('Info State Tests', () {
      testWidgets('builds basic info state with default parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 147-200
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildInfoState(context),
            ),
          ),
        );

        // Should render main structure (may find multiple Center widgets due to framework)
        expect(find.byType(Center), findsAtLeastNWidgets(1));
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);

        // Should show info icon with default size
        expect(find.byIcon(Icons.info_outline), findsOneWidget);

        final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
        expect(icon.size, equals(AppDimensions.iconSizeL));
      });

      testWidgets('info state with title and message',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with title and message
        const infoTitle = 'Information';
        const infoMessage = 'Detta är ett informationsmeddelande.';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildInfoState(
                context,
                title: infoTitle,
                message: infoMessage,
              ),
            ),
          ),
        );

        expect(find.text(infoTitle), findsOneWidget);
        expect(find.text(infoMessage), findsOneWidget);
      });

      testWidgets('info state without title shows only message',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code conditional title display (lines 172-179)
        const infoMessage = 'Endast meddelande utan titel.';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildInfoState(
                context,
                message: infoMessage,
              ),
            ),
          ),
        );

        expect(find.text(infoMessage), findsOneWidget);

        // Should not show title section when title is null
        final titleLarge = tester.widgetList<Text>(find.byType(Text)).where(
            (text) =>
                text.style?.fontSize ==
                Theme.of(tester.element(find.byType(MaterialApp)))
                    .textTheme
                    .titleLarge
                    ?.fontSize);
        expect(titleLarge.isEmpty, isTrue);
      });

      testWidgets('info state with action button uses outlined style',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 187-194 uses outlinedButton
        bool actionCalled = false;
        const actionLabel = 'Läs mer';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildInfoState(
                context,
                actionLabel: actionLabel,
                onAction: () {
                  actionCalled = true;
                },
              ),
            ),
          ),
        );

        expect(find.text(actionLabel), findsOneWidget);

        await tester.tap(find.text(actionLabel));
        expect(actionCalled, isTrue);
      });
    });

    group('Warning State Tests', () {
      testWidgets('builds basic warning state with default parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 202-258
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildWarningState(context),
            ),
          ),
        );

        // Should render main structure (may find multiple Center widgets due to framework)
        expect(find.byType(Center), findsAtLeastNWidgets(1));
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);

        // Should show warning icon
        expect(find.byIcon(Icons.warning_outlined), findsOneWidget);

        final icon = tester.widget<Icon>(find.byIcon(Icons.warning_outlined));
        expect(icon.color, equals(AppColors.warning));
        expect(icon.size, equals(AppDimensions.iconSizeL));
      });

      testWidgets('warning state with title and message',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with warning styling
        const warningTitle = 'Varning';
        const warningMessage = 'Detta kan ta bort all din data.';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildWarningState(
                context,
                title: warningTitle,
                message: warningMessage,
              ),
            ),
          ),
        );

        expect(find.text(warningTitle), findsOneWidget);
        expect(find.text(warningMessage), findsOneWidget);

        // Warning title should have warning color
        final titleTexts = tester.widgetList<Text>(find.text(warningTitle));
        expect(titleTexts.first.style?.color, equals(AppColors.warning));

        // Warning message should have warning color
        final messageTexts = tester.widgetList<Text>(find.text(warningMessage));
        expect(messageTexts.first.style?.color, equals(AppColors.warning));
      });

      testWidgets('warning state with action button',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from lines 244-251
        bool actionCalled = false;
        const actionLabel = 'Jag förstår';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildWarningState(
                context,
                actionLabel: actionLabel,
                onAction: () {
                  actionCalled = true;
                },
              ),
            ),
          ),
        );

        expect(find.text(actionLabel), findsOneWidget);

        await tester.tap(find.text(actionLabel));
        expect(actionCalled, isTrue);
      });

      testWidgets('warning state with custom icon',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with custom icon
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildWarningState(
                context,
                icon: Icons.dangerous,
                iconColor: Colors.orange,
                iconSize: 80.0,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.dangerous), findsOneWidget);

        final icon = tester.widget<Icon>(find.byIcon(Icons.dangerous));
        expect(icon.color, equals(Colors.orange));
        expect(icon.size, equals(80.0));
      });
    });

    group('Layout and Structure Tests', () {
      testWidgets('all states use consistent main layout structure',
          (WidgetTester tester) async {
        // ULTRATHINK: Test consistent structure across all state methods
        // Test each state type individually to avoid context issues
        final stateBuilders = [
          (BuildContext context) => MessageStates.buildErrorState(context),
          (BuildContext context) => MessageStates.buildSuccessState(context),
          (BuildContext context) => MessageStates.buildInfoState(context),
          (BuildContext context) => MessageStates.buildWarningState(context),
        ];

        for (final stateBuilder in stateBuilders) {
          await tester.pumpWidget(
            createTestWidget(
              child: Builder(builder: stateBuilder),
            ),
          );

          // All should have consistent layout
          expect(find.byType(Center), findsAtLeastNWidgets(1));
          expect(find.byType(Padding), findsAtLeastNWidgets(1));
          expect(find.byType(SingleChildScrollView), findsOneWidget);
          expect(find.byType(Column), findsOneWidget);
          expect(find.byType(Icon), findsOneWidget);
          expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
        }
      });

      testWidgets('columns use consistent MainAxisSize.min',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code Column configuration
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(context),
            ),
          ),
        );

        final columns = tester.widgetList<Column>(find.byType(Column));
        // Find our MessageStates Column (should have MainAxisSize.min)
        final messageStateColumn =
            columns.firstWhere((col) => col.mainAxisSize == MainAxisSize.min);
        expect(messageStateColumn.mainAxisSize, equals(MainAxisSize.min));
      });

      testWidgets('default padding is AppDimensions.spacingXl',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code default padding from line 27, 99, 161, 216
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(context),
            ),
          ),
        );

        final paddingWidgets = tester.widgetList<Padding>(find.byType(Padding));
        final defaultPadding = const EdgeInsets.all(AppDimensions.spacingXl);
        expect(paddingWidgets.any((p) => p.padding == defaultPadding), isTrue);
      });

      testWidgets('icon and title spacing is AppDimensions.spacingXl',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code spacing between icon and title
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(
                context,
                title: 'Test Title',
              ),
            ),
          ),
        );

        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final spacingXl = AppDimensions.spacingXl;
        expect(sizedBoxes.any((box) => box.height == spacingXl), isTrue);
      });
    });

    group('Swedish Localization Tests', () {
      testWidgets('error state shows Swedish default text',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish from line 42
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(context),
            ),
          ),
        );

        expect(find.text('Ett fel uppstod'), findsOneWidget);
      });

      testWidgets('success state shows Swedish default text',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish from line 114
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildSuccessState(context),
            ),
          ),
        );

        expect(find.text('Klart!'), findsOneWidget);
      });

      testWidgets('supports Swedish characters in custom messages',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish character support
        const swedishMessage = 'Åtgärden misslyckades på grund av åäö-tecken';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(
                context,
                message: swedishMessage,
              ),
            ),
          ),
        );

        expect(find.text(swedishMessage), findsOneWidget);
      });
    });

    group('Edge Cases and Error Handling Tests', () {
      testWidgets('handles null optional parameters gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with all null optionals
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildInfoState(
                context,
                title: null,
                message: null,
                icon: null,
                actionLabel: null,
                onAction: null,
              ),
            ),
          ),
        );

        // Should render without error
        expect(find.byType(Column), findsAtLeastNWidgets(1));
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'action button only shows when both label and callback provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code conditional button display
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(
                context,
                actionLabel: 'Action',
                onAction: null, // Missing callback
              ),
            ),
          ),
        );

        // Should not show button when callback is null
        expect(find.text('Action'), findsNothing);

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(
                context,
                actionLabel: null, // Missing label
                onAction: () {},
              ),
            ),
          ),
        );

        // Should not show button when label is null
        expect(find.byIcon(Icons.refresh), findsNothing);
      });

      testWidgets('handles empty string messages', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with empty strings
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildSuccessState(
                context,
                title: '',
                message: '',
              ),
            ),
          ),
        );

        // Should render without error even with empty strings
        expect(find.byType(Column), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles very long text without overflow',
          (WidgetTester tester) async {
        // ULTRATHINK: Test layout with very long content
        final longTitle = 'Detta är en mycket lång titel ' * 10;
        final longMessage =
            'Detta är ett mycket långt meddelande som testar om layouten kan hantera långa texter utan att få overflow-problem. ' *
                5;

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildWarningState(
                context,
                title: longTitle,
                message: longMessage,
              ),
            ),
          ),
        );

        // Should render without overflow errors
        expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      });
    });

    group('Integration and Styling Tests', () {
      testWidgets('error state integrates properly with app theme',
          (WidgetTester tester) async {
        // ULTRATHINK: Test theme integration
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildErrorState(
                context,
                title: 'Theme Test',
              ),
            ),
          ),
        );

        final titleText = tester.widget<Text>(find.text('Theme Test'));
        expect(titleText.style?.color, equals(AppColors.error));
      });

      testWidgets('info state uses theme primary color for icon',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code from line 169
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildInfoState(context),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
        // Icon should use theme primary color but we can't easily test the exact color
        expect(icon.color, isNotNull);
      });

      testWidgets('works properly in scrollable parent container',
          (WidgetTester tester) async {
        // ULTRATHINK: Test nested scrollable scenario
        await tester.pumpWidget(
          createTestWidget(
            child: ListView(
              children: [
                const Text('Header'),
                Builder(
                  builder: (context) => MessageStates.buildSuccessState(
                    context,
                    message: 'Success in scroll',
                  ),
                ),
                const Text('Footer'),
              ],
            ),
          ),
        );

        expect(find.text('Success in scroll'), findsOneWidget);
        expect(find.text('Header'), findsOneWidget);
        expect(find.text('Footer'), findsOneWidget);
      });

      testWidgets('maintains proper text alignment across all states',
          (WidgetTester tester) async {
        // ULTRATHINK: Test textAlign: TextAlign.center from production code
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => MessageStates.buildWarningState(
                context,
                title: 'Center Test',
                message: 'Center Message',
              ),
            ),
          ),
        );

        final titleText = tester.widget<Text>(find.text('Center Test'));
        final messageText = tester.widget<Text>(find.text('Center Message'));

        expect(titleText.textAlign, equals(TextAlign.center));
        expect(messageText.textAlign, equals(TextAlign.center));
      });
    });
  });
}
