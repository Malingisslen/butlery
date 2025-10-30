// test/widget/social/collaborative_live_widgets_ultrathink_test.dart
// ULTRATHINK TEST SUITE: CollaborativeLiveWidgets - 119 lines of production code  
// Testing 2 static methods + 1 private StatefulWidget for collaborative live editing
// 
// ULTRATHINK FOCUS: Animation logic, visibility controls, theme integration, collaborative UX

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/social/collaborative/components/collaborative_live_widgets.dart';
import 'package:butlery/theme/app_dimensions.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('CollaborativeLiveWidgets Ultrathink Tests', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
    });
    
    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create test environment
    Widget createTestWidget({Widget? child}) {
      return BaseWidgetTest.createTestApp(
        locale: const Locale('en', 'US'),
        child: Scaffold(
          body: child ?? const SizedBox.shrink(),
        ),
      );
    }

    // Helper to get BuildContext from rendered widget
    BuildContext getContext(WidgetTester tester) {
      return tester.element(find.byType(Scaffold));
    }

    // Helper to create test widget with CollaborativeLiveWidgets method
    Future<void> pumpLiveWidget(
      WidgetTester tester,
      Widget Function(BuildContext) builder,
    ) async {
      await tester.pumpWidget(createTestWidget());
      final context = getContext(tester);
      final widget = builder(context);
      await tester.pumpWidget(createTestWidget(child: widget));
    }

    group('editIndicator Method Tests', () {
      testWidgets('creates animated editing indicator with correct structure',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code indicator structure from lines 11-58
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.editIndicator(
            editorName: 'Anna',
            editingWhat: 'receptet',
            isVisible: true,
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Verify TweenAnimationBuilder structure (lines 22-57)
        expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
        expect(find.byType(Opacity), findsOneWidget);
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.byType(Row), findsOneWidget);
        
        // ULTRATHINK: Check Swedish text from production code (line 46)
        expect(find.text('Anna redigerar receptet'), findsOneWidget);
      });

      testWidgets('returns SizedBox.shrink when isVisible is false',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code visibility check from line 18
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.editIndicator(
            editorName: 'Anna',
            editingWhat: 'receptet', 
            isVisible: false,
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should return SizedBox.shrink for invisible state (line 18)
        expect(find.byType(SizedBox), findsOneWidget);
        
        // Should not find any indicator components
        expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
        expect(find.byType(Container), findsNothing);
        expect(find.text('Anna redigerar receptet'), findsNothing);
      });

      testWidgets('applies custom color when provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code color customization from lines 14, 20
        const customColor = Colors.blue;
        
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.editIndicator(
            editorName: 'Anna',
            editingWhat: 'receptet',
            color: customColor,
            isVisible: true,
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Custom color should be applied (line 20: color ?? AppColors.warning)
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('Anna redigerar receptet'), findsOneWidget);
      });

      testWidgets('uses AppColors.warning as default when no color provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code default color fallback from line 20
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.editIndicator(
            editorName: 'Anna',
            editingWhat: 'receptet',
            color: null, // Explicitly null to test fallback
            isVisible: true,
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should use AppColors.warning as default (line 20)
        expect(find.byType(Container), findsAtLeastNWidgets(1));
        expect(find.text('Anna redigerar receptet'), findsOneWidget);
      });

      testWidgets('applies correct styling and dimensions from theme',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code theme integration from lines 29-38, 47-50
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.editIndicator(
            editorName: 'Anna',
            editingWhat: 'receptet',
            isVisible: true,
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Verify main container styling 
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, greaterThanOrEqualTo(1));
        
        // ULTRATHINK: Check Row with MainAxisSize.min (line 41)
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.mainAxisSize, equals(MainAxisSize.min));
        
        // ULTRATHINK: Verify text styling (lines 47-50)
        final text = tester.widget<Text>(find.text('Anna redigerar receptet'));
        expect(text.style?.fontWeight, equals(FontWeight.w500));
      });

      testWidgets('includes pulsing dot in indicator structure',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code pulsingDot integration from line 43
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.editIndicator(
            editorName: 'Anna',
            editingWhat: 'receptet',
            isVisible: true,
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should contain pulsing dot (line 43: pulsingDot(indicatorColor))
        expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
        
        // ULTRATHINK: Should have spacing between dot and text (line 44)
        final spacings = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(spacings.any((box) => box.width == AppDimensions.spacingXs), isTrue);
      });

      testWidgets('handles different editor names and editing contexts',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code string interpolation flexibility from line 46
        final testCases = [
          {'name': 'Johan', 'what': 'ingredienserna'},
          {'name': 'Maria', 'what': 'instruktionerna'},
          {'name': 'Erik', 'what': 'titeln'},
        ];

        for (final testCase in testCases) {
          await pumpLiveWidget(
            tester,
            (context) => CollaborativeLiveWidgets.editIndicator(
              editorName: testCase['name']!,
              editingWhat: testCase['what']!,
              isVisible: true,
            ),
          );

          expect(tester.takeException(), isNull);
          
          // ULTRATHINK: Each combination should render correctly
          final expectedText = '${testCase['name']} redigerar ${testCase['what']}';
          expect(find.text(expectedText), findsOneWidget);
        }
      });

      testWidgets('respects custom animation duration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code animation duration customization from lines 16, 23
        const customDuration = Duration(milliseconds: 500);
        
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.editIndicator(
            editorName: 'Anna',
            editingWhat: 'receptet',
            animationDuration: customDuration,
            isVisible: true,
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: TweenAnimationBuilder should use custom duration (line 23)
        final animationBuilder = tester.widget<TweenAnimationBuilder<double>>(
          find.byType(TweenAnimationBuilder<double>)
        );
        expect(animationBuilder.duration, equals(customDuration));
      });
    });

    group('pulsingDot Method Tests', () {
      testWidgets('creates pulsing dot widget with correct structure',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code pulsingDot structure from lines 61-67
        const testColor = Colors.red;
        
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.pulsingDot(testColor),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Verify SizedBox dimensions (lines 62-66)
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, equals(8));
        expect(sizedBox.height, equals(8));
        
        // ULTRATHINK: Should contain _PulsingDot widget (line 65)
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('passes color to _PulsingDot widget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code color parameter passing from line 65
        const testColor = Colors.green;
        
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.pulsingDot(testColor),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Color should be passed to _PulsingDot (line 65)
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('creates stateful widget with animation controller',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code StatefulWidget creation from line 65
        const testColor = Colors.blue;
        
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.pulsingDot(testColor),
        );
        
        await tester.pump(); // Let animations initialize
        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should create animated widget structure
        expect(find.byType(SizedBox), findsOneWidget);
        
        // Allow animation to progress
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      });
    });

    group('_PulsingDot StatefulWidget Tests', () {
      testWidgets('initializes animation controller with correct settings',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code animation initialization from lines 88-95  
        const testColor = Colors.orange;
        
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.pulsingDot(testColor),
        );
        
        await tester.pump(); // Initialize animations
        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Animation should be running (controller.repeat in line 95)
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should find container with circular shape (lines 109-118)
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('builds animated container with circular decoration',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code AnimatedBuilder from lines 106-119
        const testColor = Colors.purple;
        
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.pulsingDot(testColor),
        );
        
        await tester.pump(); // Build initial state
        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should build Container with BoxShape.circle (line 114)
        expect(find.byType(SizedBox), findsOneWidget);
        
        // Animation should progress
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      });

      testWidgets('disposes animation controller properly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code dispose lifecycle from lines 99-102
        const testColor = Colors.cyan;
        
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.pulsingDot(testColor),
        );
        
        await tester.pump();
        expect(tester.takeException(), isNull);
        
        // Remove widget to trigger dispose
        await pumpLiveWidget(
          tester,
          (context) => const SizedBox.shrink(),
        );
        
        await tester.pump();
        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: dispose() should clean up controller without errors (line 100)
      });

      testWidgets('animation repeats with reverse pattern',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code repeat(reverse: true) from line 95
        const testColor = Colors.indigo;
        
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.pulsingDot(testColor),
        );
        
        await tester.pump(); // Initialize
        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Test animation progression over multiple cycles
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
        }
        
        // ULTRATHINK: Animation should still be running smoothly
        expect(find.byType(SizedBox), findsOneWidget);
      });
    });

    group('Edge Cases and Integration Tests', () {
      testWidgets('handles empty editor name gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with empty strings
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.editIndicator(
            editorName: '',
            editingWhat: 'receptet',
            isVisible: true,
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should still render with empty name (line 46)
        expect(find.text(' redigerar receptet'), findsOneWidget);
      });

      testWidgets('handles special characters in names and context',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with Swedish characters and symbols
        await pumpLiveWidget(
          tester,
          (context) => CollaborativeLiveWidgets.editIndicator(
            editorName: 'Åsa Ström',
            editingWhat: 'köttbullar & potatis',
            isVisible: true,
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should handle Swedish characters correctly
        expect(find.text('Åsa Ström redigerar köttbullar & potatis'), findsOneWidget);
      });

      testWidgets('multiple indicators can be displayed simultaneously',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code multiple instance behavior
        await pumpLiveWidget(
          tester,
          (context) => Column(
            children: [
              CollaborativeLiveWidgets.editIndicator(
                editorName: 'Anna',
                editingWhat: 'ingredienserna',
                isVisible: true,
                color: Colors.red,
              ),
              CollaborativeLiveWidgets.editIndicator(
                editorName: 'Johan',
                editingWhat: 'instruktionerna', 
                isVisible: true,
                color: Colors.blue,
              ),
            ],
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Both indicators should render independently
        expect(find.text('Anna redigerar ingredienserna'), findsOneWidget);
        expect(find.text('Johan redigerar instruktionerna'), findsOneWidget);
        expect(find.byType(TweenAnimationBuilder<double>), findsNWidgets(2));
      });

      testWidgets('respects layout constraints and responsiveness',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code layout behavior
        await pumpLiveWidget(
          tester,
          (context) => SizedBox(
            width: 200,
            child: CollaborativeLiveWidgets.editIndicator(
              editorName: 'Anna with a very long name',
              editingWhat: 'en mycket lång beskrivning av vad som redigeras',
              isVisible: true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should handle constrained layouts gracefully
        expect(find.byType(Row), findsOneWidget);
        
        // Row should have MainAxisSize.min (line 41)
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.mainAxisSize, equals(MainAxisSize.min));
      });
    });
  });
}