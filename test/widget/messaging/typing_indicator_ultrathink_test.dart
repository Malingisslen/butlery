// test/widget/messaging/typing_indicator_ultrathink_test.dart
// ULTRATHINK TEST SUITE: TypingIndicator
// 191-line animated typing widget with Swedish localization and multi-user support

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/widgets/messaging/typing_indicator.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('TypingIndicator Ultrathink Tests', () {
    // Helper to create properly configured test environment
    Widget createTestWidget({
      required Widget child,
      Size size = const Size(414, 896), // iPhone 11 Pro Max
    }) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        theme: ThemeData(
          primaryColor: AppColors.forestGreen,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: child,
          ),
        ),
      );
    }

    group('Rendering Tests', () {
      testWidgets('shows nothing when no users are typing',
          (WidgetTester tester) async {
        // ULTRATHINK: Test empty state from lines 68-70
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: [],
            ),
          ),
        );

        // Should show SizedBox.shrink for empty list
        expect(find.byType(TypingIndicator), findsOneWidget);
        expect(find.byType(Container), findsNothing);
        expect(find.byType(Icon), findsNothing);
      });

      testWidgets('shows indicator when users are typing',
          (WidgetTester tester) async {
        // ULTRATHINK: Test rendering from lines 72-136
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Anna'],
            ),
          ),
        );

        // Should show the typing container
        expect(find.byType(FadeTransition), findsOneWidget);
        expect(find.byType(Container), findsWidgets); // Multiple containers

        // Should show the avatar placeholder with icon
        expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      });

      testWidgets('displays avatar placeholder correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test avatar from lines 82-97
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Erik'],
            ),
          ),
        );

        // Find the avatar container
        final avatarContainer = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 32 &&
              widget.constraints?.maxHeight == 32,
        );

        expect(avatarContainer, findsOneWidget);

        // Check the icon inside
        final icon = tester.widget<Icon>(find.byIcon(Icons.more_horiz));
        expect(icon.color, equals(AppColors.forestGreen));
        expect(icon.size, equals(16));
      });

      testWidgets('shows typing bubble with correct styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test bubble styling from lines 102-117
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Maria'],
            ),
          ),
        );

        // Wait for animation
        await tester.pump(const Duration(milliseconds: 100));

        // Should have properly styled container
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).color ==
                    AppColors.cardWhite &&
                (widget.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          findsOneWidget,
        );
      });
    });

    group('Swedish Localization Tests', () {
      testWidgets('shows correct text for single user typing',
          (WidgetTester tester) async {
        // ULTRATHINK: Test single user text from lines 177-178
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Johan'],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Should show "Johan skriver"
        expect(find.text('Johan skriver'), findsOneWidget);
      });

      testWidgets('shows correct text for two users typing',
          (WidgetTester tester) async {
        // ULTRATHINK: Test two users text from lines 179-180
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Anna', 'Erik'],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Should show "Anna och Erik skriver"
        expect(find.text('Anna och Erik skriver'), findsOneWidget);
      });

      testWidgets('shows correct text for multiple users typing',
          (WidgetTester tester) async {
        // ULTRATHINK: Test multiple users text from lines 181-182
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Maria', 'Johan', 'Sara', 'Per'],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Should show "Maria, Johan och 2 andra skriver"
        expect(find.text('Maria, Johan och 2 andra skriver'), findsOneWidget);
      });

      testWidgets('handles Swedish characters in names correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish character support
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Åsa', 'Örjan'],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Should handle Swedish characters
        expect(find.text('Åsa och Örjan skriver'), findsOneWidget);
      });
    });

    group('Animation Tests', () {
      testWidgets('creates animation controller on init',
          (WidgetTester tester) async {
        // ULTRATHINK: Test animation init from lines 35-53
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Test'],
              animationDuration: Duration(milliseconds: 500),
            ),
          ),
        );

        // Verify FadeTransition is present (indicates animation setup)
        expect(find.byType(FadeTransition), findsOneWidget);

        // Pump to trigger animation
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // Widget should still be visible
        expect(find.byType(TypingIndicator), findsOneWidget);
      });

      testWidgets('animates in when users start typing',
          (WidgetTester tester) async {
        // ULTRATHINK: Test forward animation from lines 50-52, 59-60
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: [],
            ),
          ),
        );

        // Initially should be shrunk
        expect(find.byType(Container), findsNothing);

        // Update with typing users
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Anna'],
            ),
          ),
        );

        // Should start animating
        expect(find.byType(FadeTransition), findsOneWidget);

        // Complete animation
        await tester.pumpAndSettle();

        // Should be fully visible
        expect(find.text('Anna skriver'), findsOneWidget);
      });

      testWidgets('animates out when users stop typing',
          (WidgetTester tester) async {
        // ULTRATHINK: Test reverse animation from lines 61-62
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Test User'],
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Test User skriver'), findsOneWidget);

        // Clear typing users
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: [],
            ),
          ),
        );

        // Should animate out
        await tester.pump();
        expect(find.byType(FadeTransition),
            findsNothing); // Becomes SizedBox.shrink
      });

      testWidgets('shows animated dots correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test animated dots from lines 139-172
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['User'],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Should have 3 dots
        final dots = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 4 &&
              widget.constraints?.maxHeight == 4 &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        );

        expect(dots, findsNWidgets(3));
      });

      testWidgets('dots have staggered animation', (WidgetTester tester) async {
        // ULTRATHINK: Test staggered animation from lines 158-160
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Test'],
              animationDuration: Duration(milliseconds: 300),
            ),
          ),
        );

        // Start animation
        await tester.pump();

        // Check at different points in animation
        await tester.pump(const Duration(milliseconds: 100));

        // Find the dot container specifically
        final dotsContainer = find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 24 && widget.height == 16,
        );

        expect(dotsContainer, findsOneWidget);

        // Within the dots container, should have 3 AnimatedBuilders
        final animatedBuilders = find.descendant(
          of: dotsContainer,
          matching: find.byType(AnimatedBuilder),
        );

        expect(animatedBuilders, findsNWidgets(3));
      });
    });

    group('State Management Tests', () {
      testWidgets('handles widget updates correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test didUpdateWidget from lines 56-64
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['User1'],
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('User1 skriver'), findsOneWidget);

        // Add another user
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['User1', 'User2'],
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('User1 och User2 skriver'), findsOneWidget);

        // Remove all users
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: [],
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('User1 och User2 skriver'), findsNothing);
      });

      testWidgets('maintains state during rapid updates',
          (WidgetTester tester) async {
        // ULTRATHINK: Test rapid state changes
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['A'],
            ),
          ),
        );

        // Rapid updates
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['A', 'B'],
            ),
          ),
        );

        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['A', 'B', 'C'],
            ),
          ),
        );

        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['A'],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show final state correctly
        expect(find.text('A skriver'), findsOneWidget);
      });
    });

    group('Layout Tests', () {
      testWidgets('uses correct spacing between elements',
          (WidgetTester tester) async {
        // ULTRATHINK: Test spacing from lines 99, 128
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['User'],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Check for SizedBox spacers
        final spacers = find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == AppDimensions.paddingS,
        );

        expect(spacers, findsWidgets); // Should have spacers
      });

      testWidgets('has correct padding in container',
          (WidgetTester tester) async {
        // ULTRATHINK: Test padding from lines 75-78
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Test'],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Check main container padding
        final mainContainer = find.byWidgetPredicate(
          (widget) => widget is Container && widget.color == AppColors.cream,
        );

        expect(mainContainer, findsOneWidget);

        final container = tester.widget<Container>(mainContainer);
        expect(
          container.padding,
          equals(const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          )),
        );
      });
    });

    group('Lifecycle Tests', () {
      testWidgets('properly disposes animation controller',
          (WidgetTester tester) async {
        // ULTRATHINK: Test dispose from lines 187-190
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['User'],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Replace widget to trigger dispose
        await tester.pumpWidget(
          createTestWidget(
            child: const SizedBox(),
          ),
        );

        // Should dispose without errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles animation duration parameter',
          (WidgetTester tester) async {
        // ULTRATHINK: Test custom animation duration from line 22
        const customDuration = Duration(milliseconds: 200);

        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Fast'],
              animationDuration: customDuration,
            ),
          ),
        );

        // Animation should respect custom duration
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should be mid-animation
        expect(find.byType(FadeTransition), findsOneWidget);

        // Complete custom duration
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Fast skriver'), findsOneWidget);
      });
    });

    group('Edge Cases Tests', () {
      testWidgets('handles empty string in user names',
          (WidgetTester tester) async {
        // ULTRATHINK: Edge case handling
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: [''],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Should still render but with empty name
        expect(find.text(' skriver'), findsOneWidget);
      });

      testWidgets('handles very long user names', (WidgetTester tester) async {
        // ULTRATHINK: Test text overflow handling
        final longName = 'A' * 50;

        await tester.pumpWidget(
          createTestWidget(
            child: TypingIndicator(
              typingUserNames: [longName],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Should handle without overflow
        expect(find.text('$longName skriver'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles many users typing', (WidgetTester tester) async {
        // ULTRATHINK: Test with many users
        final manyUsers = List.generate(10, (i) => 'User$i');

        await tester.pumpWidget(
          createTestWidget(
            child: TypingIndicator(
              typingUserNames: manyUsers,
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Should show first 2 and count of others
        expect(find.text('User0, User1 och 8 andra skriver'), findsOneWidget);
      });

      testWidgets('handles rapid show/hide cycles',
          (WidgetTester tester) async {
        // ULTRATHINK: Test rapid visibility changes
        for (int i = 0; i < 5; i++) {
          await tester.pumpWidget(
            createTestWidget(
              child: TypingIndicator(
                typingUserNames: i % 2 == 0 ? ['User'] : [],
              ),
            ),
          );

          await tester.pump(const Duration(milliseconds: 50));
        }

        // Should not crash
        expect(tester.takeException(), isNull);
      });
    });

    group('Visual Style Tests', () {
      testWidgets('uses correct text styles', (WidgetTester tester) async {
        // ULTRATHINK: Test text styling from lines 123-126
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Styled'],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        final text = tester.widget<Text>(find.text('Styled skriver'));
        expect(text.style?.fontStyle, equals(FontStyle.italic));
        expect(text.style?.color, equals(AppColors.textMedium));
      });

      testWidgets('shows correct background color',
          (WidgetTester tester) async {
        // ULTRATHINK: Test background color from line 79
        await tester.pumpWidget(
          createTestWidget(
            child: const TypingIndicator(
              typingUserNames: ['Color'],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        final container = find.byWidgetPredicate(
          (widget) => widget is Container && widget.color == AppColors.cream,
        );

        expect(container, findsOneWidget);
      });
    });
  });
}
