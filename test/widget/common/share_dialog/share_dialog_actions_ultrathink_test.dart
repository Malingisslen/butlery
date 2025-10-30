// test/widget/common/share_dialog/share_dialog_actions_ultrathink_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/share_dialog/share_dialog_actions.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('ShareDialogActions Widget Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment with theme support
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          body: child,
        ),
      );
    }

    // Helper widget to test static methods with BuildContext  
    Widget createActionButtonsTest({
      required ShareContentType contentType,
      required ShareMode shareMode,
      required bool supportsRealtimeSharing,
      required bool hasSelectedFriends,
      required bool isLoading,
      required VoidCallback onCancel,
      required VoidCallback onShare,
    }) {
      return Builder(
        builder: (context) {
          return ShareDialogActions.buildActionButtons(
            context,
            contentType,
            shareMode,
            supportsRealtimeSharing,
            hasSelectedFriends,
            isLoading,
            onCancel,
            onShare,
          );
        },
      );
    }

    Widget createSelectionSummaryTest({
      required int selectedCount,
      required String contentTypeName,
    }) {
      return Builder(
        builder: (context) {
          return ShareDialogActions.buildSelectionSummary(
            context,
            selectedCount,
            contentTypeName,
          );
        },
      );
    }

    group('buildActionButtons Method Tests', () {
      testWidgets('creates buttons with basic required parameters', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: false,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Avbryt'), findsOneWidget);
      });

      testWidgets('applies correct container styling', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: false,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;

        expect(container.padding, const EdgeInsets.all(AppDimensions.paddingL));
        expect(decoration.borderRadius, const BorderRadius.only(
          bottomLeft: Radius.circular(AppDimensions.borderRadiusM),
          bottomRight: Radius.circular(AppDimensions.borderRadiusM),
        ));
      });

      testWidgets('handles loading state correctly', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: true,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(SizedBox), findsAtLeastNWidgets(1)); // For progress indicator sizing

        // Verify progress indicator properties
        final progressIndicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(progressIndicator.strokeWidth, equals(2));
      });

      testWidgets('handles disabled state when no friends selected', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: false,
              isLoading: false,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        final shareButton = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(shareButton.onPressed, isNull); // Button should be disabled
      });

      testWidgets('enables share button when friends selected and not loading', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: false,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        final shareButton = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(shareButton.onPressed, isNotNull); // Button should be enabled
      });

      testWidgets('disables cancel button during loading', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: true,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        final cancelButton = tester.widget<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        expect(cancelButton.onPressed, isNull); // Cancel button should be disabled during loading
      });

      testWidgets('handles button callbacks correctly', (tester) async {
        bool cancelCalled = false;
        bool shareCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: false,
              onCancel: () => cancelCalled = true,
              onShare: () => shareCalled = true,
            ),
          ),
        );

        // Test cancel callback
        await tester.tap(find.text('Avbryt'));
        await tester.pump();
        expect(cancelCalled, isTrue);

        // Test share callback (find by button type since text varies)
        final shareButton = find.byType(ElevatedButton);
        await tester.tap(shareButton);
        await tester.pump();
        expect(shareCalled, isTrue);
      });
    });

    group('_getShareButtonText Method Tests', () {
      testWidgets('returns correct text for recipe static sharing', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: false,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        expect(find.text('Dela recept'), findsOneWidget);
      });

      testWidgets('returns correct text for menu static sharing', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.menu,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: false,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        expect(find.text('Dela meny'), findsOneWidget);
      });

      testWidgets('returns correct text for shopping list static sharing', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.shoppingList,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: false,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        expect(find.text('Dela inköpslista'), findsOneWidget);
      });

      testWidgets('returns correct text for realtime sharing when supported', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.realtime,
              supportsRealtimeSharing: true,
              hasSelectedFriends: true,
              isLoading: false,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        expect(find.text('Skapa & Dela'), findsOneWidget);
      });

      testWidgets('falls back to static text when realtime not supported', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.realtime,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: false,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        // Should fall back to static recipe text since realtime not supported
        expect(find.text('Dela recept'), findsOneWidget);
        expect(find.text('Skapa & Dela'), findsNothing);
      });

      testWidgets('tests all ShareContentType variations', (tester) async {
        final contentTypeExpectations = [
          (ShareContentType.recipe, 'Dela recept'),
          (ShareContentType.menu, 'Dela meny'),
          (ShareContentType.shoppingList, 'Dela inköpslista'),
        ];

        for (final (contentType, expectedText) in contentTypeExpectations) {
          await tester.pumpWidget(
            createTestWidget(
              createActionButtonsTest(
                contentType: contentType,
                shareMode: ShareMode.staticCopy,
                supportsRealtimeSharing: false,
                hasSelectedFriends: true,
                isLoading: false,
                onCancel: () {},
                onShare: () {},
              ),
            ),
          );

          expect(find.text(expectedText), findsOneWidget,
              reason: 'Expected "$expectedText" for $contentType');
        }
      });
    });

    group('buildSelectionSummary Method Tests', () {
      testWidgets('displays warning state when no selections', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createSelectionSummaryTest(
              selectedCount: 0,
              contentTypeName: 'recept',
            ),
          ),
        );

        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.text('Välj minst en vän för att dela recept'), findsOneWidget);
        
        // Verify warning styling
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, AppColors.warning.withValues(alpha: 0.1));
      });

      testWidgets('displays success state with singular friend', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createSelectionSummaryTest(
              selectedCount: 1,
              contentTypeName: 'meny',
            ),
          ),
        );

        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.text('1 vän valda'), findsOneWidget); // Singular form
        
        // Verify success styling
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, AppColors.success.withValues(alpha: 0.1));
      });

      testWidgets('displays success state with plural friends', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createSelectionSummaryTest(
              selectedCount: 3,
              contentTypeName: 'inköpslista',
            ),
          ),
        );

        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.text('3 vänner valda'), findsOneWidget); // Plural form with 'ner'
      });

      testWidgets('tests Swedish pluralization logic', (tester) async {
        final pluralizationTests = [
          (1, '1 vän valda'), // Singular - no 'ner' suffix
          (2, '2 vänner valda'), // Plural - with 'ner' suffix  
          (5, '5 vänner valda'), // Plural - with 'ner' suffix
        ];

        for (final (count, expectedText) in pluralizationTests) {
          await tester.pumpWidget(
            createTestWidget(
              createSelectionSummaryTest(
                selectedCount: count,
                contentTypeName: 'test',
              ),
            ),
          );

          expect(find.text(expectedText), findsOneWidget,
              reason: 'Expected "$expectedText" for count $count');
        }
      });

      testWidgets('handles different content type names correctly', (tester) async {
        final contentTypeTests = [
          ('recept', 'Välj minst en vän för att dela recept'),
          ('meny', 'Välj minst en vän för att dela meny'),
          ('inköpslista', 'Välj minst en vän för att dela inköpslista'),
        ];

        for (final (contentTypeName, expectedText) in contentTypeTests) {
          await tester.pumpWidget(
            createTestWidget(
              createSelectionSummaryTest(
                selectedCount: 0,
                contentTypeName: contentTypeName,
              ),
            ),
          );

          expect(find.text(expectedText), findsOneWidget,
              reason: 'Expected "$expectedText" for content type "$contentTypeName"');
        }
      });

      testWidgets('applies correct border radius for different states', (tester) async {
        // Test warning state border radius
        await tester.pumpWidget(
          createTestWidget(
            createSelectionSummaryTest(
              selectedCount: 0,
              contentTypeName: 'test',
            ),
          ),
        );

        var container = tester.widget<Container>(find.byType(Container));
        var decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(AppDimensions.borderRadiusM));

        // Test success state border radius  
        await tester.pumpWidget(
          createTestWidget(
            createSelectionSummaryTest(
              selectedCount: 1,
              contentTypeName: 'test',
            ),
          ),
        );

        container = tester.widget<Container>(find.byType(Container));
        decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(AppDimensions.borderRadiusS));
      });
    });

    group('Theme Integration Tests', () {
      testWidgets('uses modern withValues alpha syntax throughout', (tester) async {
        // Test buildActionButtons uses withValues for border color
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: false,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        
        // Verify border uses theme context and alpha
        expect(border.top.color, isA<Color>());
        expect(border.top.color.a, lessThan(1.0)); // Should have alpha transparency
      });

      testWidgets('uses AppDimensions constants correctly', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: false,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final spacingM = tester.widget<SizedBox>(find.byType(SizedBox));

        expect(container.padding, const EdgeInsets.all(AppDimensions.paddingL));
        expect(spacingM.width, AppDimensions.spacingM);
      });

      testWidgets('applies AppColors correctly in selection summary', (tester) async {
        // Test warning colors
        await tester.pumpWidget(
          createTestWidget(
            createSelectionSummaryTest(
              selectedCount: 0,
              contentTypeName: 'test',
            ),
          ),
        );

        final warningIcon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
        expect(warningIcon.color, AppColors.warning);

        // Test success colors  
        await tester.pumpWidget(
          createTestWidget(
            createSelectionSummaryTest(
              selectedCount: 1,
              contentTypeName: 'test',
            ),
          ),
        );

        final successIcon = tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));
        expect(successIcon.color, AppColors.success);
      });
    });

    group('Widget Structure and Layout Tests', () {
      testWidgets('maintains consistent button layout structure', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createActionButtonsTest(
              contentType: ShareContentType.recipe,
              shareMode: ShareMode.staticCopy,
              supportsRealtimeSharing: false,
              hasSelectedFriends: true,
              isLoading: false,
              onCancel: () {},
              onShare: () {},
            ),
          ),
        );

        // Verify layout hierarchy: Container > Row > [Expanded(OutlinedButton), SizedBox, Expanded(ElevatedButton)]
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Expanded), findsNWidgets(2)); // Two expanded buttons
        expect(find.byType(SizedBox), findsAtLeastNWidgets(1)); // Spacing between buttons
      });

      testWidgets('maintains consistent summary layout structure', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            createSelectionSummaryTest(
              selectedCount: 1,
              contentTypeName: 'test',
            ),
          ),
        );

        // Verify layout hierarchy: Container > Row > [Icon, SizedBox(s), Text]
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
        expect(find.byType(SizedBox), findsAtLeastNWidgets(1)); // May have multiple for spacing
        expect(find.byType(Text), findsOneWidget);
      });
    });

    group('Edge Cases and Comprehensive Coverage', () {
      testWidgets('handles all parameter combination states', (tester) async {
        final parameterCombinations = [
          // (contentType, shareMode, supportsRealtime, hasSelected, isLoading)
          (ShareContentType.recipe, ShareMode.staticCopy, false, false, false),
          (ShareContentType.recipe, ShareMode.staticCopy, false, true, false),  
          (ShareContentType.recipe, ShareMode.staticCopy, false, false, true),
          (ShareContentType.recipe, ShareMode.realtime, true, true, false),
          (ShareContentType.menu, ShareMode.realtime, false, true, false), // Realtime not supported
          (ShareContentType.shoppingList, ShareMode.staticCopy, false, true, true), // Loading state
        ];

        for (final (contentType, shareMode, supportsRealtime, hasSelected, isLoading) in parameterCombinations) {
          await tester.pumpWidget(
            createTestWidget(
              createActionButtonsTest(
                contentType: contentType,
                shareMode: shareMode,
                supportsRealtimeSharing: supportsRealtime,
                hasSelectedFriends: hasSelected,
                isLoading: isLoading,
                onCancel: () {},
                onShare: () {},
              ),
            ),
          );

          // Each combination should render without crashing
          expect(find.byType(Container), findsOneWidget,
              reason: 'Failed for combination: $contentType, $shareMode, $supportsRealtime, $hasSelected, $isLoading');
          expect(find.text('Avbryt'), findsOneWidget);
        }
      });

      testWidgets('handles extreme selection counts for pluralization', (tester) async {
        final extremeCounts = [0, 1, 2, 10, 100, 999];

        for (final count in extremeCounts) {
          await tester.pumpWidget(
            createTestWidget(
              createSelectionSummaryTest(
                selectedCount: count,
                contentTypeName: 'test',
              ),
            ),
          );

          // Should handle all counts without crashing
          expect(find.byType(Container), findsOneWidget,
              reason: 'Failed for count: $count');
        }
      });
    });
  });
}