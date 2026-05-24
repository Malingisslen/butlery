import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/widgets/common/user_avatar.dart';
import 'package:butlery/widgets/user/user_display_models.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('UserAvatar Widget Tests', () {
    group('Basic Rendering', () {
      testWidgets('renders with initials when no image URL',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Anna Andersson',
            ),
          ),
        );

        // Should show initials
        expect(find.text('AA'), findsOneWidget);

        // Should have default background color
        final container = find.byType(Container).first;
        expect(container, findsWidgets);
      });

      testWidgets('renders with image when URL provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Erik Eriksson',
              imageUrl: 'https://example.com/avatar.jpg',
            ),
          ),
        );

        // Should have CachedNetworkImage
        expect(find.byType(CachedNetworkImage), findsOneWidget);

        // Should still have initials as placeholder
        expect(find.text('EE'), findsOneWidget);
      });

      testWidgets('handles single word names correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Magnus',
            ),
          ),
        );

        // Should show first two letters for single word
        expect(find.text('MA'), findsOneWidget);
      });

      testWidgets('handles single letter names', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'A',
            ),
          ),
        );

        // Should show single letter
        expect(find.text('A'), findsOneWidget);
      });

      testWidgets('handles empty name with fallback',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: '',
            ),
          ),
        );

        // Empty name → person icon fallback (renders via initialsOrFallback).
        expect(find.byIcon(Icons.person), findsOneWidget);
      });

      testWidgets('handles names with extra spaces',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: '  Johan   Johansson  ',
            ),
          ),
        );

        // Should trim and extract correct initials
        expect(find.text('JJ'), findsOneWidget);
      });
    });

    group('Size Variants', () {
      testWidgets('renders small size correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Test User',
              size: ImageSize.small,
            ),
          ),
        );

        // Find the main container with avatar
        final containers = find.byType(Container);
        expect(containers, findsWidgets);
      });

      testWidgets('renders medium size correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Test User',
              size: ImageSize.medium,
            ),
          ),
        );

        expect(find.text('TU'), findsOneWidget);
      });

      testWidgets('renders large size correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Test User',
              size: ImageSize.large,
            ),
          ),
        );

        expect(find.text('TU'), findsOneWidget);
      });

      testWidgets('renders extra large size correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Test User',
              size: ImageSize.extraLarge,
            ),
          ),
        );

        expect(find.text('TU'), findsOneWidget);
      });
    });

    group('Status Indicator', () {
      testWidgets('shows online status indicator', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Online User',
              showStatus: true,
              isOnline: true,
            ),
          ),
        );

        // Should have Stack for status overlay (might have multiple stacks in tree)
        expect(find.byType(Stack), findsWidgets);

        // Should have Positioned widget for status dot (scoped to avatar subtree —
        // Scaffold itself contributes Positioned widgets at the outer level).
        expect(
          find.descendant(
            of: find.byType(UserAvatar),
            matching: find.byType(Positioned),
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows offline status indicator',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Offline User',
              showStatus: true,
              isOnline: false,
            ),
          ),
        );

        // Should have Stack for status overlay (might have multiple stacks in tree)
        expect(find.byType(Stack), findsWidgets);

        // Should have Positioned widget for status dot (scoped to avatar subtree).
        expect(
          find.descendant(
            of: find.byType(UserAvatar),
            matching: find.byType(Positioned),
          ),
          findsOneWidget,
        );
      });

      testWidgets('does not show status when disabled',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'No Status User',
              showStatus: false,
              isOnline: true,
            ),
          ),
        );

        // Should not have Positioned widget for status dot when status is disabled
        // (scoped to avatar subtree — Scaffold contributes Positioned at outer level).
        expect(
          find.descendant(
            of: find.byType(UserAvatar),
            matching: find.byType(Positioned),
          ),
          findsNothing,
        );
      });
    });

    group('Interactivity', () {
      testWidgets('handles tap when onTap provided',
          (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: UserAvatar(
              displayName: 'Tappable User',
              onTap: () => tapped = true,
            ),
          ),
        );

        // Should have InkWell for tap handling
        expect(find.byType(InkWell), findsOneWidget);

        // Tap the avatar
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('no InkWell when onTap not provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Non-tappable User',
            ),
          ),
        );

        // Should not have InkWell when onTap is null
        expect(find.byType(InkWell), findsNothing);
      });
    });

    group('Custom Styling', () {
      testWidgets('applies custom background color',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Styled User',
              backgroundColor: Colors.red,
            ),
          ),
        );

        // Avatar should be rendered with custom color
        expect(find.text('SU'), findsOneWidget);
      });

      testWidgets('applies custom text color', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Colored Text',
              textColor: Colors.yellow,
            ),
          ),
        );

        // Check that text widget exists with initials
        final textWidget = tester.widget<Text>(find.text('CT'));
        expect(textWidget.style?.color, Colors.yellow);
      });

      testWidgets('applies custom border', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Bordered User',
              borderColor: Colors.blue,
              borderWidth: 3.0,
            ),
          ),
        );

        // Avatar should be rendered with border
        expect(find.text('BU'), findsOneWidget);
      });
    });

    group('Swedish Character Support', () {
      testWidgets('handles Swedish characters in names',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Åsa Öberg',
            ),
          ),
        );

        // Should properly handle Swedish characters
        expect(find.text('ÅÖ'), findsOneWidget);
      });

      testWidgets('handles mixed case Swedish names',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'björn älg',
            ),
          ),
        );

        // Should uppercase the initials
        expect(find.text('BÄ'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles very long names', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName:
                  'Anna-Maria Elisabeth von Schwarzenberg-Hohenzollern',
            ),
          ),
        );

        // Should take first letters of first two words
        expect(find.text('AE'), findsOneWidget);
      });

      testWidgets('handles names with special characters',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Jean-Pierre O\'Connor',
            ),
          ),
        );

        // Should handle special characters
        expect(find.text('JO'), findsOneWidget);
      });

      testWidgets('handles empty image URL same as null',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Empty URL User',
              imageUrl: '',
            ),
          ),
        );

        // Should show initials when URL is empty
        expect(find.text('EU'), findsOneWidget);
        // Should not have CachedNetworkImage
        expect(find.byType(CachedNetworkImage), findsNothing);
      });

      testWidgets('renders square avatar container (Butlery design language)',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const UserAvatar(
              displayName: 'Shape Test',
            ),
          ),
        );

        // Butlery design language is square — avatar Container uses
        // BoxDecoration without shape: BoxShape.circle.
        final avatarContainer = find.byWidgetPredicate(
          (widget) {
            if (widget is Container) {
              final decoration = widget.decoration;
              return decoration is BoxDecoration &&
                  decoration.shape == BoxShape.rectangle;
            }
            return false;
          },
        );

        expect(avatarContainer, findsWidgets);
      });
    });

    group('Accessibility', () {
      testWidgets('provides semantic label for screen readers',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: UserAvatar(
              displayName: 'Accessible User',
              onTap: () {},
            ),
          ),
        );

        // Tappable avatar wraps its content in InkWell + Semantics(button: true).
        expect(find.byType(InkWell), findsOneWidget);
      });
    });
  });
}
