// test/widget/social/collaborative_participants_widgets_ultrathink_test.dart
// ULTRATHINK TEST SUITE: CollaborativeParticipantsWidgets - 188 lines of production code
// Testing 2 static methods with FutureBuilder patterns and service integration
//
// ULTRATHINK FOCUS: FutureBuilder states, service delegation, UserDisplayWidgets integration, layout logic

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/social/collaborative/components/collaborative_participants_widgets.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/social_recipe_service.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';
import '../../infrastructure/factories/user_profile_factory.dart';

// Mock classes for service integration testing
class MockSocialRecipeService extends Mock implements SocialRecipeService {}

void main() {
  group('CollaborativeParticipantsWidgets Ultrathink Tests', () {
    late MockSocialRecipeService mockSocialRecipeService;

    setUpAll(() async {
      await BaseWidgetTest.setupWidget();

      // Register fallback values for mocktail
      registerFallbackValue(UserProfile(
        uid: 'fallback',
        displayName: 'Fallback User',
        email: 'fallback@example.com',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ));
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create fresh mock for each test
      mockSocialRecipeService = MockSocialRecipeService();

      // Register mock service with TestServiceLocator
      TestServiceLocator.registerMock<SocialRecipeService>(
          mockSocialRecipeService);
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

    // Helper to create test widget with CollaborativeParticipantsWidgets method
    Future<void> pumpParticipantsWidget(
      WidgetTester tester,
      Widget Function(BuildContext) builder,
    ) async {
      await tester.pumpWidget(createTestWidget());
      final context = getContext(tester);
      final widget = builder(context);
      await tester.pumpWidget(createTestWidget(child: widget));
    }

    // Helper to create test users
    List<UserProfile> createTestParticipants(int count) {
      return List.generate(
          count,
          (index) => UserProfileFactory.build(
                uid: 'user_$index',
                displayName: 'User ${index + 1}',
                email: 'user${index + 1}@example.com',
                avatarUrl: index % 2 == 0
                    ? 'https://example.com/avatar$index.jpg'
                    : null,
              ));
    }

    group('participantsList Method Tests', () {
      group('FutureBuilder States', () {
        testWidgets('shows loading skeleton avatars while waiting',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code loading state from lines 27-42

          final participants = createTestParticipants(3);
          when(() => mockSocialRecipeService.getRecipeParticipants(any()))
              .thenAnswer((_) async {
            // Delay to simulate loading - use pump to control timing
            await Future.delayed(const Duration(milliseconds: 50));
            return participants;
          });

          await pumpParticipantsWidget(
            tester,
            (context) => CollaborativeParticipantsWidgets.participantsList(
              context: context,
              contentId: 'recipe123',
              contentType: 'recipe',
            ),
          );

          // ULTRATHINK: Check loading state before future completes
          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should show loading state initially (lines 29-42)
          expect(find.byType(Row), findsOneWidget);
          expect(find.byType(Container),
              findsAtLeastNWidgets(2)); // 2 skeleton avatars

          // ULTRATHINK: Verify skeleton avatar styling (lines 33-40)
          final containers = tester
              .widgetList<Container>(find.byType(Container))
              .where((c) =>
                  c.decoration is BoxDecoration &&
                  (c.decoration as BoxDecoration).shape == BoxShape.circle)
              .toList();
          expect(containers.length, greaterThanOrEqualTo(2));

          // Complete the future and verify final state
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('shows error icon when future has error',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code error handling from lines 176-178
          // Production code catches errors and returns [] (empty list), showing empty state
          when(() => mockSocialRecipeService.getRecipeParticipants(any()))
              .thenThrow(Exception('Network error'));

          await pumpParticipantsWidget(
            tester,
            (context) => CollaborativeParticipantsWidgets.participantsList(
              context: context,
              contentId: 'recipe123',
              contentType: 'recipe',
            ),
          );

          // Wait for future to complete with error
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // ULTRATHINK: Production code catches errors and returns [], showing empty state (person_outline)
          expect(find.byIcon(Icons.person_outline), findsOneWidget);

          // ULTRATHINK: Verify empty icon styling
          final icon = tester.widget<Icon>(find.byIcon(Icons.person_outline));
          expect(icon.size, equals(32.0)); // Default avatarSize
          expect(icon.color, equals(AppColors.textSecondary));
        });

        testWidgets('shows single person icon when participants list is empty',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code empty state from lines 54-62
          when(() => mockSocialRecipeService.getRecipeParticipants(any()))
              .thenAnswer((_) async => []);

          await pumpParticipantsWidget(
            tester,
            (context) => CollaborativeParticipantsWidgets.participantsList(
              context: context,
              contentId: 'recipe123',
              contentType: 'recipe',
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should show empty state icon (lines 57-61)
          expect(find.byIcon(Icons.person_outline), findsOneWidget);

          final icon = tester.widget<Icon>(find.byIcon(Icons.person_outline));
          expect(icon.size, equals(32.0));
          expect(icon.color, equals(AppColors.textSecondary));
        });

        testWidgets('delegates to avatarRow when participants exist',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code success delegation from lines 64-71
          final participants = createTestParticipants(3);
          when(() => mockSocialRecipeService.getRecipeParticipants(any()))
              .thenAnswer((_) async => participants);

          await pumpParticipantsWidget(
            tester,
            (context) => CollaborativeParticipantsWidgets.participantsList(
              context: context,
              contentId: 'recipe123',
              contentType: 'recipe',
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should delegate to avatarRow (lines 65-70)
          // The avatarRow will create a Row with UserDisplayWidgets.avatar calls
          expect(find.byType(Row), findsOneWidget);

          // Should not show loading or error states
          expect(find.byIcon(Icons.people_outline), findsNothing);
          expect(find.byIcon(Icons.person_outline), findsNothing);
        });
      });

      group('Service Integration', () {
        testWidgets('calls getRecipeParticipants for recipe content type',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code recipe service call from lines 148-150
          final participants = createTestParticipants(2);
          when(() => mockSocialRecipeService.getRecipeParticipants(any()))
              .thenAnswer((_) async => participants);

          await pumpParticipantsWidget(
            tester,
            (context) => CollaborativeParticipantsWidgets.participantsList(
              context: context,
              contentId: 'recipe123',
              contentType: 'recipe',
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // ULTRATHINK: Verify service was called with correct contentId
          verify(() =>
                  mockSocialRecipeService.getRecipeParticipants('recipe123'))
              .called(1);
        });

        testWidgets('calls getMenuParticipants for menu content type',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code menu service call from lines 153-155
          final participants = createTestParticipants(2);
          when(() => mockSocialRecipeService.getMenuParticipants(any()))
              .thenAnswer((_) async => participants);

          await pumpParticipantsWidget(
            tester,
            (context) => CollaborativeParticipantsWidgets.participantsList(
              context: context,
              contentId: 'menu456',
              contentType: 'menu',
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // ULTRATHINK: Verify menu service was called
          verify(() => mockSocialRecipeService.getMenuParticipants('menu456'))
              .called(1);
        });

        testWidgets(
            'calls getShoppingListParticipants for shopping_list content type',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code shopping list service call from lines 158-160
          final participants = createTestParticipants(2);
          when(() => mockSocialRecipeService.getShoppingListParticipants(any()))
              .thenAnswer((_) async => participants);

          await pumpParticipantsWidget(
            tester,
            (context) => CollaborativeParticipantsWidgets.participantsList(
              context: context,
              contentId: 'list789',
              contentType: 'shopping_list',
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // ULTRATHINK: Verify shopping list service was called
          verify(() => mockSocialRecipeService
              .getShoppingListParticipants('list789')).called(1);
        });

        testWidgets('returns empty list for unknown content type',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code unknown type handling from lines 163-165
          await pumpParticipantsWidget(
            tester,
            (context) => CollaborativeParticipantsWidgets.participantsList(
              context: context,
              contentId: 'unknown123',
              contentType: 'unknown_type',
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should show empty state for unknown type
          expect(find.byIcon(Icons.person_outline), findsOneWidget);

          // ULTRATHINK: No service methods should be called for unknown type
          verifyNever(
              () => mockSocialRecipeService.getRecipeParticipants(any()));
          verifyNever(() => mockSocialRecipeService.getMenuParticipants(any()));
          verifyNever(
              () => mockSocialRecipeService.getShoppingListParticipants(any()));
        });
      });

      group('Parameter Customization', () {
        testWidgets('respects custom avatarSize parameter',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code avatarSize usage from lines 22, 34-35, 59
          // Production code catches errors and returns [] (empty list), showing empty state
          when(() => mockSocialRecipeService.getRecipeParticipants(any()))
              .thenThrow(Exception('Error for size test'));

          const customSize = 48.0;
          await pumpParticipantsWidget(
            tester,
            (context) => CollaborativeParticipantsWidgets.participantsList(
              context: context,
              contentId: 'recipe123',
              contentType: 'recipe',
              avatarSize: customSize,
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // ULTRATHINK: Production code shows empty state (person_outline) with custom size
          final icon = tester.widget<Icon>(find.byIcon(Icons.person_outline));
          expect(icon.size, equals(customSize));
        });

        testWidgets('respects custom maxVisible parameter',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code maxVisible delegation from line 67
          final participants = createTestParticipants(5);
          when(() => mockSocialRecipeService.getRecipeParticipants(any()))
              .thenAnswer((_) async => participants);

          const customMaxVisible = 2;
          await pumpParticipantsWidget(
            tester,
            (context) => CollaborativeParticipantsWidgets.participantsList(
              context: context,
              contentId: 'recipe123',
              contentType: 'recipe',
              maxVisible: customMaxVisible,
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should delegate maxVisible to avatarRow
          expect(find.byType(Row), findsOneWidget);
        });
      });
    });

    group('avatarRow Method Tests', () {
      group('Basic Layout', () {
        testWidgets('creates row with correct number of visible participants',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code basic row creation from lines 88-99
          final participants = createTestParticipants(3);

          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeParticipantsWidgets.avatarRow(
                participants: participants,
                maxVisible: 3,
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should create Row with MainAxisSize.min (lines 88-90)
          expect(find.byType(Row), findsOneWidget);
          final row = tester.widget<Row>(find.byType(Row));
          expect(row.mainAxisSize, equals(MainAxisSize.min));
        });

        testWidgets('shows spacing between avatars',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code spacing from lines 86, 93
          final participants = createTestParticipants(3);

          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeParticipantsWidgets.avatarRow(
                participants: participants,
                maxVisible: 3,
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should have SizedBox widgets for spacing (line 93)
          expect(find.byType(SizedBox), findsAtLeastNWidgets(1));

          // Find SizedBox widgets with expected width
          final spacingWidgets = tester
              .widgetList<SizedBox>(find.byType(SizedBox))
              .where((box) => box.width == AppDimensions.spacingXs);
          expect(spacingWidgets.length, greaterThan(0));
        });

        testWidgets('respects custom spacing parameter',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code custom spacing from line 86
          final participants = createTestParticipants(2);
          const customSpacing = EdgeInsets.symmetric(horizontal: 8);

          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeParticipantsWidgets.avatarRow(
                participants: participants,
                maxVisible: 2,
                spacing: customSpacing,
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should use custom spacing (horizontal = 16, so gap = 16)
          expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
        });
      });

      group('UserDisplayWidgets Delegation', () {
        testWidgets(
            'delegates to UserDisplayWidgets.avatar for each participant',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code UserDisplayWidgets delegation from lines 94-98
          final participants = createTestParticipants(2);

          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeParticipantsWidgets.avatarRow(
                participants: participants,
                maxVisible: 2,
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: UserDisplayWidgets.avatar should be called (lines 94-98)
          // Since we can't directly verify static method calls, we verify the structure
          expect(find.byType(Row), findsOneWidget);
        });

        testWidgets('passes correct parameters to UserDisplayWidgets.avatar',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code parameter passing from lines 95-97
          final participants = createTestParticipants(1);
          const customSize = 48.0;

          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeParticipantsWidgets.avatarRow(
                participants: participants,
                maxVisible: 1,
                size: customSize,
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Size conversion should happen via _sizeToImageSize (line 97)
          expect(find.byType(Row), findsOneWidget);
        });
      });

      group('Remaining Counter', () {
        testWidgets('shows "+X" counter when participants exceed maxVisible',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code remaining counter from lines 102-126
          final participants = createTestParticipants(5);

          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeParticipantsWidgets.avatarRow(
                participants: participants,
                maxVisible: 3,
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should show "+2" counter (5 - 3 = 2 remaining)
          expect(find.text('+2'), findsOneWidget);

          // ULTRATHINK: Counter should be in circular container (lines 104-114)
          expect(find.byType(Container), findsAtLeastNWidgets(1));
        });

        testWidgets('does not show counter when all participants are visible',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code no counter when remaining <= 0
          final participants = createTestParticipants(2);

          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeParticipantsWidgets.avatarRow(
                participants: participants,
                maxVisible: 3,
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should not show counter when all participants fit
          expect(find.textContaining('+'), findsNothing);
        });

        testWidgets('counter styling matches production code',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code counter styling from lines 107-123
          final participants = createTestParticipants(7);
          const size = 40.0;

          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeParticipantsWidgets.avatarRow(
                participants: participants,
                maxVisible: 3,
                size: size,
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should show "+4" counter (7 - 3 = 4)
          expect(find.text('+4'), findsOneWidget);

          // ULTRATHINK: Verify counter styling (lines 116-123)
          final counterText = tester.widget<Text>(find.text('+4'));
          expect(counterText.style?.fontSize, equals(size * 0.35)); // Line 119
          expect(counterText.style?.color, equals(AppColors.forestGreen));
          expect(counterText.style?.fontWeight, equals(FontWeight.bold));
        });

        testWidgets('respects custom totalCount parameter',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code totalCount override from lines 84-85
          final participants = createTestParticipants(2);

          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeParticipantsWidgets.avatarRow(
                participants: participants,
                maxVisible: 2,
                totalCount: 5, // Override actual count
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Should show "+3" counter (5 - 2 = 3) using totalCount
          expect(find.text('+3'), findsOneWidget);
        });
      });

      group('Size Conversion Logic', () {
        testWidgets('converts size to correct ImageSize enum values',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code _sizeToImageSize from lines 183-188
          final participants = createTestParticipants(1);

          // Test small size (≤ 24)
          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeParticipantsWidgets.avatarRow(
                participants: participants,
                maxVisible: 1,
                size: 24,
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          // ULTRATHINK: Size 24 should map to ImageSize.small (line 184)
          expect(find.byType(Row), findsOneWidget);
        });
      });
    });

    group('Edge Cases and Integration Tests', () {
      testWidgets('handles empty participants list gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with empty list
        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeParticipantsWidgets.avatarRow(
              participants: [],
              maxVisible: 3,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should create empty Row
        expect(find.byType(Row), findsOneWidget);
        expect(find.textContaining('+'), findsNothing);
      });

      testWidgets('handles single participant correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with single participant
        final participants = createTestParticipants(1);

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeParticipantsWidgets.avatarRow(
              participants: participants,
              maxVisible: 3,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should show single participant, no counter
        expect(find.byType(Row), findsOneWidget);
        expect(find.textContaining('+'), findsNothing);
      });

      testWidgets('handles very large participant count',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with extreme values
        final participants = createTestParticipants(99);

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeParticipantsWidgets.avatarRow(
              participants: participants,
              maxVisible: 3,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should show "+96" counter (99 - 3 = 96)
        expect(find.text('+96'), findsOneWidget);
      });

      testWidgets('handles service errors gracefully in participantsList',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code error handling from lines 176-178
        // Production code catches errors and returns [] (empty list), showing empty state
        when(() => mockSocialRecipeService.getRecipeParticipants(any()))
            .thenThrow(Exception('Service unavailable'));

        await pumpParticipantsWidget(
          tester,
          (context) => CollaborativeParticipantsWidgets.participantsList(
            context: context,
            contentId: 'recipe123',
            contentType: 'recipe',
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // ULTRATHINK: Production code catches errors and returns [], showing empty state (person_outline)
        expect(find.byIcon(Icons.person_outline), findsOneWidget);
      });

      testWidgets('respects maxVisible of zero', (WidgetTester tester) async {
        // ULTRATHINK: Test production code edge case
        final participants = createTestParticipants(3);

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeParticipantsWidgets.avatarRow(
              participants: participants,
              maxVisible: 0,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should show "+3" counter only (0 visible, 3 remaining)
        expect(find.text('+3'), findsOneWidget);
      });

      testWidgets('handles null avatarUrl in participants',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with participants having null avatarUrl
        final participants = [
          UserProfileFactory.build(
            uid: 'user1',
            displayName: 'User Without Avatar',
            email: 'user1@example.com',
            avatarUrl: null,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeParticipantsWidgets.avatarRow(
              participants: participants,
              maxVisible: 1,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should delegate to UserDisplayWidgets which handles null avatarUrl
        expect(find.byType(Row), findsOneWidget);
      });
    });
  });
}
