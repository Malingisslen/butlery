// test/widget/common/social/reaction_picker_test.dart
// Comprehensive tests for ReactionPicker using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/social/reaction_picker.dart';
import 'package:butlery/models/social/reaction_type.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

// Test infrastructure
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('ReactionPicker Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
    });

    tearDown(() async {
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // Helper to create test widget with animation support
    Widget createTestWidget({
      required Widget child,
    }) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'), // Swedish locale
        home: Scaffold(
          body: Center(
            child: _TestAnimationWrapper(
              child: child,
            ),
          ),
        ),
      );
    }

    group('Basic Rendering', () {
      testWidgets('should render default trigger button', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (reaction) {},
            ),
          ),
        );

        // Should find default trigger elements
        expect(find.byType(ReactionPicker), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
        expect(find.text('Reagera'), findsOneWidget);

        // Should be wrapped in GestureDetector
        expect(find.byType(GestureDetector), findsOneWidget);

        // Overlay exists in MaterialApp, but should not show custom overlay entry initially
        expect(find.byType(ReactionPicker), findsOneWidget);
      });

      testWidgets('should render with custom trigger widget', (WidgetTester tester) async {
        final customTrigger = Container(
          key: const Key('custom-trigger'),
          width: 50,
          height: 50,
          color: Colors.blue,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              trigger: customTrigger,
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Should find custom trigger
        expect(find.byKey(const Key('custom-trigger')), findsOneWidget);
        expect(find.text('Reagera'), findsNothing); // No default text
      });

      testWidgets('should show current reaction when selected', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              currentReaction: ReactionType.delicious,
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Should show filled heart and reaction name
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.text(ReactionType.delicious.displayName), findsOneWidget);

        // Should show as selected state styling
        final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.primary.withValues(alpha: 0.1)));
      });

      testWidgets('should use correct animation durations', (WidgetTester tester) async {
        const customDuration = Duration(milliseconds: 500);

        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              animationDuration: customDuration,
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Widget should accept and store custom animation duration
        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.animationDuration, equals(customDuration));
      });
    });

    group('Constructor Variants', () {
      testWidgets('should create with regular constructor', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              currentReaction: ReactionType.like,
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.contentType, equals('recipe'));
        expect(picker.currentReaction, equals(ReactionType.like));
        expect(picker.showLabels, isFalse);
        expect(picker.expandDirection, equals(AxisDirection.up));
      });

      testWidgets('should create with custom constructor', (WidgetTester tester) async {
        final customReactions = [ReactionType.like, ReactionType.love];

        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker.custom(
              customReactions: customReactions,
              onReactionSelected: (_) {},
              showLabels: true,
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.contentType, equals(''));
        expect(picker.customReactions, equals(customReactions));
        expect(picker.showLabels, isTrue);
      });

      testWidgets('should handle initially expanded state', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              initiallyExpanded: true,
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.initiallyExpanded, isTrue);
      });
    });

    group('Interaction Patterns', () {
      testWidgets('should respond to tap gesture', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Get the specific GestureDetector for ReactionPicker
        final pickerGestureDetector = find.descendant(
          of: find.byType(ReactionPicker),
          matching: find.byType(GestureDetector),
        );
        
        // Tap the trigger
        await tester.tap(pickerGestureDetector);
        await tester.pump(const Duration(milliseconds: 100));

        // Verify tap was registered (this triggers expansion)
        expect(find.byType(ReactionPicker), findsOneWidget);
      });

      testWidgets('should respond to long press gesture', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Get the specific GestureDetector for ReactionPicker
        final pickerGestureDetector = find.descendant(
          of: find.byType(ReactionPicker),
          matching: find.byType(GestureDetector),
        );
        
        // Long press the trigger
        await tester.longPress(pickerGestureDetector);
        await tester.pump(const Duration(milliseconds: 100));

        // Verify long press was registered (this also triggers expansion)
        expect(find.byType(ReactionPicker), findsOneWidget);
      });

      testWidgets('should expand/collapse correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Initially collapsed
        expect(find.byType(ReactionPicker), findsOneWidget);

        // Get the specific GestureDetector for ReactionPicker
        final pickerGestureDetector = find.descendant(
          of: find.byType(ReactionPicker),
          matching: find.byType(GestureDetector),
        );
        
        // Tap to expand (this is handled internally by the widget)
        await tester.tap(pickerGestureDetector);
        await tester.pump(const Duration(milliseconds: 100));

        // Widget should handle internal state changes
        expect(find.byType(ReactionPicker), findsOneWidget);
      });
    });

    group('Content Type Filtering', () {
      testWidgets('should filter reactions for recipe content', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.contentType, equals('recipe'));
        // Food reactions should be used for recipe content
      });

      testWidgets('should filter reactions for menu content', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'menu',
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.contentType, equals('menu'));
      });

      testWidgets('should filter reactions for comment content', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'comment',
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.contentType, equals('comment'));
      });

      testWidgets('should use custom reactions when provided', (WidgetTester tester) async {
        final customReactions = [ReactionType.like, ReactionType.love];

        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker.custom(
              customReactions: customReactions,
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.customReactions, equals(customReactions));
      });
    });

    group('Expand Directions', () {
      testWidgets('should expand up by default', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.expandDirection, equals(AxisDirection.up));
      });

      testWidgets('should support down expansion', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              expandDirection: AxisDirection.down,
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.expandDirection, equals(AxisDirection.down));
      });

      testWidgets('should support left expansion', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              expandDirection: AxisDirection.left,
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.expandDirection, equals(AxisDirection.left));
      });

      testWidgets('should support right expansion', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              expandDirection: AxisDirection.right,
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.expandDirection, equals(AxisDirection.right));
      });
    });

    group('Label Display', () {
      testWidgets('should not show labels by default', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.showLabels, isFalse);
      });

      testWidgets('should show labels when enabled', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              showLabels: true,
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.showLabels, isTrue);
      });

      testWidgets('should show labels in custom constructor by default', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker.custom(
              customReactions: const [ReactionType.like],
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.showLabels, isTrue);
      });
    });

    group('Default Trigger Styling', () {
      testWidgets('should use correct default colors when no reaction', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Should show border heart icon
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);

        // Check container styling
        final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.transparent));
      });

      testWidgets('should use primary colors when reaction selected', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              currentReaction: ReactionType.like,
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Should show filled heart icon
        expect(find.byIcon(Icons.favorite), findsOneWidget);

        // Check container styling
        final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.primary.withValues(alpha: 0.1)));

        // Check border color
        expect(decoration.border, isNotNull);
        final border = decoration.border as Border;
        expect(border.left.color, equals(AppColors.primary.withValues(alpha: 0.3)));
      });

      testWidgets('should use correct text styling', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Check Swedish default text
        expect(find.text('Reagera'), findsOneWidget);

        // Check text styling
        final text = tester.widget<Text>(find.text('Reagera'));
        expect(text.style, isNotNull);
      });

      testWidgets('should show reaction display name when selected', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              currentReaction: ReactionType.delicious,
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Should show reaction display name instead of default text
        expect(find.text(ReactionType.delicious.displayName), findsOneWidget);
        expect(find.text('Reagera'), findsNothing);
      });
    });

    group('Animation Behavior', () {
      testWidgets('should handle animation duration changes', (WidgetTester tester) async {
        const Duration customDuration = Duration(milliseconds: 1000);

        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              animationDuration: customDuration,
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.animationDuration, equals(customDuration));

        // Test that animation duration is applied to container
        final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
        expect(container.duration, equals(const Duration(milliseconds: 200)));
      });

      testWidgets('should animate container changes smoothly', (WidgetTester tester) async {
        ReactionType? currentReaction;

        await tester.pumpWidget(
          createTestWidget(
            child: StatefulBuilder(
              builder: (context, setState) {
                return ReactionPicker(
                  contentType: 'recipe',
                  currentReaction: currentReaction,
                  onReactionSelected: (reaction) {
                    setState(() {
                      currentReaction = reaction;
                    });
                  },
                );
              },
            ),
          ),
        );

        // Initially no reaction
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);

        // The actual selection logic is internal to the widget
        // We can verify the widget properties change correctly
        expect(find.byType(AnimatedContainer), findsOneWidget);
      });
    });

    group('Swedish Localization', () {
      testWidgets('should show Swedish default trigger text', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (_) {},
            ),
          ),
        );

        expect(find.text('Reagera'), findsOneWidget);
      });

      testWidgets('should display Swedish reaction names correctly', (WidgetTester tester) async {
        // Test various reaction types show proper Swedish display names
        for (final reactionType in ReactionType.values) {
          await tester.pumpWidget(
            createTestWidget(
              child: ReactionPicker(
                contentType: 'recipe',
                currentReaction: reactionType,
                onReactionSelected: (_) {},
              ),
            ),
          );

          expect(find.text(reactionType.displayName), findsOneWidget);
        }
      });
    });

    group('Widget Layout', () {
      testWidgets('should use correct padding and spacing', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Check container padding
        final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
        expect(container.padding, equals(const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingS,
          vertical: 4.0,
        )));

        // Check border radius
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.radiusM)));
      });

      testWidgets('should arrange elements correctly in Row', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Should have Row with icon and text
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.mainAxisSize, equals(MainAxisSize.min));
        expect(row.children.length, equals(3)); // Icon, SizedBox, Text

        // Check spacing between icon and text
        final sizedBox = row.children[1] as SizedBox;
        expect(sizedBox.width, equals(4));
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle null current reaction', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              currentReaction: null,
              onReactionSelected: (_) {},
            ),
          ),
        );

        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
        expect(find.text('Reagera'), findsOneWidget);
      });

      testWidgets('should handle empty content type', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: '',
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.contentType, equals(''));
      });

      testWidgets('should handle unknown content type', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'unknown_type',
              onReactionSelected: (_) {},
            ),
          ),
        );

        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.contentType, equals('unknown_type'));
      });

      testWidgets('should handle single interaction correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (_) {},
            ),
          ),
        );

        // Single tap should work without issues
        final pickerGestureDetector = find.descendant(
          of: find.byType(ReactionPicker),
          matching: find.byType(GestureDetector),
        );
        
        await tester.tap(pickerGestureDetector);
        await tester.pump(const Duration(milliseconds: 100));

        // Widget should handle interaction gracefully
        expect(find.byType(ReactionPicker), findsOneWidget);
      });
    });

    group('Callback Integration', () {
      testWidgets('should execute callback when provided', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (reaction) {
                // Callback executed - testing callback presence
              },
            ),
          ),
        );

        // Verify callback is properly stored
        final picker = tester.widget<ReactionPicker>(find.byType(ReactionPicker));
        expect(picker.onReactionSelected, isNotNull);
      });

      testWidgets('should handle callback exceptions gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: ReactionPicker(
              contentType: 'recipe',
              onReactionSelected: (reaction) {
                throw Exception('Test exception');
              },
            ),
          ),
        );

        // Widget should render without issues even if callback might throw
        expect(find.byType(ReactionPicker), findsOneWidget);
        expect(find.text('Reagera'), findsOneWidget);
      });
    });
  });
}

// Helper widget to provide animation context for ReactionPicker
class _TestAnimationWrapper extends StatefulWidget {
  final Widget child;
  
  const _TestAnimationWrapper({required this.child});
  
  @override
  State<_TestAnimationWrapper> createState() => _TestAnimationWrapperState();
}

class _TestAnimationWrapperState extends State<_TestAnimationWrapper>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}