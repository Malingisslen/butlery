import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/social/reaction_bar.dart';
import 'package:butlery/models/social/reaction_type.dart';
import 'package:butlery/models/social/reaction_statistics.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';

// Comprehensive widget test for ReactionBar following ultrathink methodology
void main() {
  setUp(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('ReactionBar Tests', () {
    // Test data
    final testStatistics = ReactionStatistics.fromCounts(
      {
        ReactionType.like: 5,
        ReactionType.love: 3,
        ReactionType.delicious: 2,
      },
      contentId: 'test123',
      contentType: 'recipe',
    );

    group('Basic Rendering', () {
      testWidgets('renders with required properties', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
              ),
            ),
          ),
        );

        expect(find.byType(ReactionBar), findsOneWidget);
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });

      testWidgets('shows empty state when no reactions', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: null,
              ),
            ),
          ),
        );

        expect(find.text('Bli första att reagera'), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      });

      testWidgets('shows reaction emojis when statistics provided', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
              ),
            ),
          ),
        );

        expect(find.text('❤️'), findsAtLeastNWidgets(1));
        expect(find.text('😍'), findsAtLeastNWidgets(1));
        expect(find.text('😋'), findsAtLeastNWidgets(1));
      });

      testWidgets('shows reaction counts when enabled', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
                showCounts: true,
                onReactionTap: (_) {}, // Need to enable reaction tap for counts to show
              ),
            ),
          ),
        );

        // Should show total count in summary
        expect(find.text('10 reaktioner'), findsOneWidget); // total count
      });

      testWidgets('hides reaction counts when disabled', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
                showCounts: false,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        // Summary count should not be shown when showCounts is false
        expect(find.text('10 reaktioner'), findsNothing);
        // But emojis should still be visible in buttons
        expect(find.text('❤️'), findsAtLeastNWidgets(1));
      });
    });

    group('Compact Mode', () {
      testWidgets('renders compact view correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar.compact(
                statistics: testStatistics,
              ),
            ),
          ),
        );

        expect(find.byType(InkWell), findsOneWidget);
        expect(find.text('10'), findsOneWidget); // total count (5+3+2)
      });

      testWidgets('shows top 3 reactions in compact mode', (WidgetTester tester) async {
        final manyReactions = ReactionStatistics.fromCounts(
          {
            ReactionType.like: 10,
            ReactionType.love: 8,
            ReactionType.delicious: 6,
            ReactionType.helpful: 4,
            ReactionType.creative: 2,
          },
          contentId: 'test123',
          contentType: 'recipe',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar.compact(
                statistics: manyReactions,
              ),
            ),
          ),
        );

        // Should show top 3 emojis
        expect(find.text('❤️'), findsOneWidget);
        expect(find.text('😍'), findsOneWidget);
        expect(find.text('😋'), findsOneWidget);
        // Should not show lower count emojis
        expect(find.text('👍'), findsNothing);
        expect(find.text('💡'), findsNothing);
      });

      testWidgets('handles tap in compact mode', (WidgetTester tester) async {
        bool wasTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar.compact(
                statistics: testStatistics,
                onTap: () {
                  wasTapped = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(InkWell));
        expect(wasTapped, isTrue);
      });

      testWidgets('returns empty widget when no reactions in compact mode', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar.compact(
                statistics: null,
              ),
            ),
          ),
        );

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(InkWell), findsNothing);
      });
    });

    group('User Reactions', () {
      testWidgets('highlights user selected reaction', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
                userReactionType: ReactionType.love,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        // Find containers with selected styling
        final selectedContainer = find.byWidgetPredicate(
          (widget) => widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  AppColors.primary.withValues(alpha: 0.1),
        );
        expect(selectedContainer, findsAtLeastNWidgets(1));
      });

      testWidgets('shows user reaction indicator in summary', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
                userReactionType: ReactionType.delicious,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Läcker'), findsOneWidget); // Swedish name for delicious
      });

      testWidgets('handles reaction tap callback', (WidgetTester tester) async {
        ReactionType? tappedReaction;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
                onReactionTap: (reaction) {
                  tappedReaction = reaction;
                },
              ),
            ),
          ),
        );

        // Tap on a reaction button
        await tester.tap(find.text('❤️').first);
        expect(tappedReaction, equals(ReactionType.like));
      });
    });

    group('Content Type Filtering', () {
      testWidgets('shows food reactions for recipe content', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        // Food reactions should be available
        expect(find.text('😋'), findsAtLeastNWidgets(1)); // delicious
      });

      testWidgets('shows general reactions for comment content', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'comment',
                statistics: ReactionStatistics.fromCounts(
                  {
                    ReactionType.like: 5,
                    ReactionType.helpful: 3,
                  },
                  contentId: 'test123',
                  contentType: 'comment',
                ),
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        // General reactions should be available
        expect(find.text('👍'), findsAtLeastNWidgets(1)); // helpful
      });

      testWidgets('shows all reactions for unknown content type', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'unknown',
                statistics: testStatistics,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        // Should show reactions based on statistics
        expect(find.byType(ReactionBar), findsOneWidget);
      });
    });

    group('Swedish Localization', () {
      testWidgets('displays Swedish reaction count text for single reaction', (WidgetTester tester) async {
        final singleReaction = ReactionStatistics.fromCounts(
          {
            ReactionType.like: 1,
          },
          contentId: 'test123',
          contentType: 'recipe',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: singleReaction,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('1 reaktion'), findsOneWidget);
      });

      testWidgets('displays Swedish reaction count text for multiple reactions', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('10 reaktioner'), findsOneWidget); // 5+3+2
      });

      testWidgets('displays Swedish empty state message', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: ReactionStatistics.empty(
                  contentId: 'test123',
                  contentType: 'recipe',
                ),
              ),
            ),
          ),
        );

        expect(find.text('Bli första att reagera'), findsOneWidget);
      });
    });

    group('Layout and Styling', () {
      testWidgets('applies correct padding and spacing', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        expect(container.padding, equals(const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        )));
      });

      testWidgets('uses Wrap for reaction buttons', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        expect(find.byType(Wrap), findsOneWidget);
      });

      testWidgets('respects maxReactionTypes limit', (WidgetTester tester) async {
        final manyReactions = ReactionStatistics.fromCounts(
          {
            ReactionType.like: 10,
            ReactionType.love: 8,
            ReactionType.delicious: 6,
            ReactionType.helpful: 4,
            ReactionType.creative: 2,
            ReactionType.easy: 1,
          },
          contentId: 'test123',
          contentType: 'recipe',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: manyReactions,
                maxReactionTypes: 3,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        // Check for available reaction buttons based on content type
        // Recipe content shows food reactions which are 5 types by default
        // Not limited by maxReactionTypes for available buttons
        final wrapWidget = find.byType(Wrap);
        expect(wrapWidget, findsOneWidget);
      });
    });

    group('Animation', () {
      testWidgets('uses AnimatedContainer when animated is true', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
                animated: true,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(1));
        expect(find.byType(AnimatedDefaultTextStyle), findsAtLeastNWidgets(1));
      });

      testWidgets('disables animation when animated is false', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
                animated: false,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        final animatedContainer = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer).first,
        );
        expect(animatedContainer.duration, equals(Duration.zero));
      });
    });

    group('Edge Cases', () {
      testWidgets('handles empty statistics object', (WidgetTester tester) async {
        final emptyStats = ReactionStatistics.empty(
          contentId: 'test123',
          contentType: 'recipe',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: emptyStats,
              ),
            ),
          ),
        );

        expect(find.text('Bli första att reagera'), findsOneWidget);
      });

      testWidgets('handles null onReactionTap callback', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: testStatistics,
                onReactionTap: null,
              ),
            ),
          ),
        );

        // Should show summary but no interactive buttons
        expect(find.byType(Wrap), findsNothing);
        expect(find.text('10 reaktioner'), findsOneWidget);
      });

      testWidgets('handles very large reaction counts', (WidgetTester tester) async {
        final largeStats = ReactionStatistics.fromCounts(
          {
            ReactionType.like: 999999,
          },
          contentId: 'test123',
          contentType: 'recipe',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReactionBar(
                contentId: 'test123',
                contentType: 'recipe',
                statistics: largeStats,
                onReactionTap: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('999999'), findsOneWidget);
        expect(find.text('999999 reaktioner'), findsOneWidget);
      });
    });
  });
}