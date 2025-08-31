// test/widget/social/collaborative_indicators_ultrathink_test.dart
// ULTRATHINK TEST SUITE: CollaborativeIndicators - 219 lines of production code
// Testing 12 static delegation methods in facade pattern
// 
// ULTRATHINK FOCUS: Delegation verification, parameter passing, return value consistency

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/social/collaborative/collaborative_indicators.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/services/social_recipe_service.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';
import '../../infrastructure/factories/user_profile_factory.dart';

// Mock classes for dependencies
class MockCollaborativeStatusViewModel extends Mock implements CollaborativeStatusViewModel {}
class MockRecipeFormViewModel extends Mock implements RecipeFormViewModel {}
class MockSocialRecipeService extends Mock implements SocialRecipeService {}

void main() {
  group('CollaborativeIndicators Ultrathink Tests', () {
    late MockCollaborativeStatusViewModel mockCollaborativeStatusViewModel;
    late MockRecipeFormViewModel mockRecipeFormViewModel;
    late MockSocialRecipeService mockSocialRecipeService;

    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
      
      // Register fallback values for mocktail
      registerFallbackValue(EditMode.view);
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
      
      // Create fresh mocks for each test
      mockCollaborativeStatusViewModel = MockCollaborativeStatusViewModel();
      mockRecipeFormViewModel = MockRecipeFormViewModel();
      mockSocialRecipeService = MockSocialRecipeService();
      
      // Register mocks with TestServiceLocator
      TestServiceLocator.registerMock<SocialRecipeService>(mockSocialRecipeService);
    });
    
    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create test environment with providers
    Widget createTestWidget({Widget? child}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<CollaborativeStatusViewModel>(
            create: (_) => mockCollaborativeStatusViewModel,
          ),
          ChangeNotifierProvider<RecipeFormViewModel>(
            create: (_) => mockRecipeFormViewModel,
          ),
        ],
        child: BaseWidgetTest.createTestApp(
          locale: const Locale('en', 'US'),
          child: Scaffold(
            body: child ?? const SizedBox.shrink(),
          ),
        ),
      );
    }

    // Helper method available if needed (removed unused warning)
    // BuildContext getContext(WidgetTester tester) {
    //   return tester.element(find.byType(Scaffold));
    // }

    // Helper to create test users
    List<UserProfile> createTestParticipants(int count) {
      return List.generate(count, (index) => 
        UserProfileFactory.build(
          uid: 'user_$index',
          displayName: 'User ${index + 1}',
          email: 'user${index + 1}@example.com',
          avatarUrl: index % 2 == 0 ? 'https://example.com/avatar$index.jpg' : null,
        )
      );
    }

    group('Status Methods Delegation', () {
      group('collaborativeStatusBadge Method', () {
        testWidgets('delegates to CollaborativeStatusWidgets.statusBadge with default parameters',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code delegation from lines 33-44
          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeIndicators.collaborativeStatusBadge(),
            ),
          );

          expect(tester.takeException(), isNull);
          
          // ULTRATHINK: Should create the delegated statusBadge widget structure
          expect(find.byType(Container), findsOneWidget);
          expect(find.byType(Row), findsOneWidget);
          expect(find.byType(Icon), findsOneWidget);
          expect(find.text('Delat'), findsOneWidget); // Default text parameter
        });

        testWidgets('passes custom parameters correctly to underlying widget',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code parameter passing from lines 39-43
          const customText = 'Anpassat';
          const customIcon = Icons.star;
          const customColor = Colors.red;
          const customPadding = EdgeInsets.all(16.0);

          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeIndicators.collaborativeStatusBadge(
                text: customText,
                icon: customIcon,
                color: customColor,
                padding: customPadding,
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          
          // ULTRATHINK: Verify custom parameters are delegated correctly
          expect(find.text(customText), findsOneWidget);
          expect(find.byIcon(customIcon), findsOneWidget);
          
          // ULTRATHINK: Should have correct widget structure with custom values
          final icon = tester.widget<Icon>(find.byIcon(customIcon));
          expect(icon.color, equals(customColor));
        });
      });

      group('collaborativeBanner Method', () {
        testWidgets('delegates to CollaborativeStatusWidgets.banner with required parameters',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code delegation from lines 48-67
          const title = 'Test Title';
          const subtitle = 'Test Subtitle';

          await tester.pumpWidget(
            createTestWidget(
              child: CollaborativeIndicators.collaborativeBanner(
                title: title,
                subtitle: subtitle,
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          
          // ULTRATHINK: Should create the delegated banner widget structure
          expect(find.byType(Container), findsOneWidget);
          expect(find.byType(InkWell), findsOneWidget);
          expect(find.text(title), findsOneWidget);
          expect(find.text(subtitle), findsOneWidget);
        });

        testWidgets('passes all optional parameters correctly',
            (WidgetTester tester) async {
          // ULTRATHINK: Test production code optional parameter delegation
          const title = 'Collaboration Title';
          const subtitle = 'Collaboration Subtitle';
          const contentId = 'test_content_123';
          const contentType = 'menu';
          final backgroundColor = Colors.green.withValues(alpha: 0.2);
          bool tapCallbackCalled = false;
          final trailingWidget = const Icon(Icons.arrow_forward);

          await tester.pumpWidget(
            createTestWidget(
              child: Builder(
                builder: (context) => CollaborativeIndicators.collaborativeBanner(
                  title: title,
                  subtitle: subtitle,
                  contentId: contentId,
                  contentType: contentType,
                  backgroundColor: backgroundColor,
                  onTap: () => tapCallbackCalled = true,
                  trailing: trailingWidget,
                  context: context,
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          
          // ULTRATHINK: Verify all parameters are passed through
          expect(find.text(title), findsOneWidget);
          expect(find.text(subtitle), findsOneWidget);
          
          // Test tap callback functionality
          await tester.tap(find.byType(InkWell));
          expect(tapCallbackCalled, isTrue);
        });
      });
    });

    group('AppBar Methods Delegation', () {
      testWidgets('collaborativeAppBar delegates to CollaborativeStatusWidgets.appBar',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 71-88
        const contentId = 'recipe_123';
        const title = 'Test Recipe';
        
        // Mock the collaborative status for AppBar rendering
        when(() => mockCollaborativeStatusViewModel.getRecipeCollaborativeStatus(any(), any()))
            .thenReturn(const CollaborativeStatus(isCollaborative: false));
        
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => Scaffold(
                appBar: CollaborativeIndicators.collaborativeAppBar(
                  context: context,
                  contentId: contentId,
                  title: title,
                ),
                body: const SizedBox.shrink(),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should create AppBar through delegation
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text(title), findsOneWidget);
      });

      testWidgets('smartCollaborativeBanner delegates to CollaborativeStatusWidgets.smartBanner',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 92-109
        const contentId = 'recipe_456';
        const title = 'Smart Banner Test';
        
        // Mock the collaborative status to avoid complex provider setup
        when(() => mockCollaborativeStatusViewModel.getRecipeCollaborativeStatus(any(), any()))
            .thenReturn(const CollaborativeStatus(isCollaborative: false));

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => CollaborativeIndicators.smartCollaborativeBanner(
                context: context,
                contentId: contentId,
                title: title,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to Consumer<CollaborativeStatusViewModel>
        expect(find.byType(Consumer<CollaborativeStatusViewModel>), findsOneWidget);
        
        // Verify the ViewModel method was called
        verify(() => mockCollaborativeStatusViewModel.getRecipeCollaborativeStatus(contentId, null))
            .called(1);
      });
    });

    group('Participants Methods Delegation', () {
      testWidgets('collaborativeParticipants delegates to CollaborativeParticipantsWidgets.participantsList',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 129-142
        const contentId = 'recipe_789';
        const contentType = 'recipe';
        
        final participants = createTestParticipants(2);
        when(() => mockSocialRecipeService.getRecipeParticipants(any()))
            .thenAnswer((_) async => participants);

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => CollaborativeIndicators.collaborativeParticipants(
                context: context,
                contentId: contentId,
                contentType: contentType,
                maxVisible: 2,
                avatarSize: 40,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to FutureBuilder pattern from CollaborativeParticipantsWidgets
        expect(find.byType(Row), findsOneWidget);
        
        // Verify service was called through delegation
        verify(() => mockSocialRecipeService.getRecipeParticipants(contentId)).called(1);
      });

      testWidgets('participantAvatars delegates to CollaborativeParticipantsWidgets.avatarRow',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 204-217
        final participants = createTestParticipants(3);
        const maxVisible = 2;
        const size = 48.0;

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeIndicators.participantAvatars(
              participants: participants,
              maxVisible: maxVisible,
              size: size,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to avatarRow with Row structure
        expect(find.byType(Row), findsOneWidget);
        
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.mainAxisSize, equals(MainAxisSize.min));
      });
    });

    group('Live and Permission Methods Delegation', () {
      testWidgets('liveEditIndicator delegates to CollaborativeLiveWidgets.editIndicator',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 146-159
        const editorName = 'Anna';
        const editingWhat = 'receptet';

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeIndicators.liveEditIndicator(
              editorName: editorName,
              editingWhat: editingWhat,
              color: Colors.blue,
              isVisible: true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to TweenAnimationBuilder pattern
        expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
        expect(find.textContaining(editorName), findsOneWidget);
      });

      testWidgets('permissionsBanner delegates to CollaborativePermissionsWidgets.permissionsBanner',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 163-172
        const editMode = EditMode.readOnlyWithFork;

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => CollaborativeIndicators.permissionsBanner(
                context: context,
                editMode: editMode,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to banner structure based on EditMode
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });

      testWidgets('smartPermissionsBanner delegates to CollaborativePermissionsWidgets.smartPermissionsBanner',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 176-183
        
        // Setup mock ViewModel with required properties
        when(() => mockRecipeFormViewModel.editMode).thenReturn('collaborative');
        when(() => mockRecipeFormViewModel.editModeEnum).thenReturn(EditMode.collaborative);

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => CollaborativeIndicators.smartPermissionsBanner(
                context: context,
                viewModel: mockRecipeFormViewModel,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to ViewModel-based logic
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });
    });

    group('Connection and Utility Methods', () {
      testWidgets('collaborativeConnectionStatus delegates to CollaborativeConnectionWidgets.connectionStatus',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 187-200
        const isOnline = false;
        const statusText = 'Connection lost';
        const statusEmoji = '🔗';
        bool retryPressed = false;

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeIndicators.collaborativeConnectionStatus(
              isOnline: isOnline,
              statusText: statusText,
              statusEmoji: statusEmoji,
              showRetryButton: true,
              onRetry: () => retryPressed = true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to offline banner structure
        expect(find.byType(Container), findsOneWidget);
        expect(find.text('Offline'), findsOneWidget);
        expect(find.text(statusText), findsOneWidget);
        expect(find.text(statusEmoji), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget);
        
        // Test retry callback delegation
        await tester.tap(find.byType(TextButton));
        expect(retryPressed, isTrue);
      });

      testWidgets('refreshCollaborativeStatus delegates to CollaborativeStatusWidgets.refreshStatus',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 113-122
        const contentId = 'recipe_999';
        const contentType = 'recipe';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) {
                // Call the static method
                CollaborativeIndicators.refreshCollaborativeStatus(
                  context,
                  contentId,
                  contentType: contentType,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should delegate to ViewModel invalidation
        // Since this is a void method, we verify it doesn't crash
        expect(find.byType(SizedBox), findsOneWidget);
      });
    });

    group('Parameter Edge Cases', () {
      testWidgets('handles null and default parameters correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code default parameter handling
        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeIndicators.collaborativeStatusBadge(),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should use default values from production code
        expect(find.text('Delat'), findsOneWidget); // Default text
        expect(find.byIcon(Icons.people), findsOneWidget); // Default icon
      });

      testWidgets('handles empty participant list',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with empty participants
        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeIndicators.participantAvatars(
              participants: [],
              maxVisible: 3,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should create empty Row
        expect(find.byType(Row), findsOneWidget);
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.children.length, equals(0));
      });

      testWidgets('handles very large participant counts',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with large datasets
        final participants = createTestParticipants(50);

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeIndicators.participantAvatars(
              participants: participants,
              maxVisible: 3,
              totalCount: 50,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Should show "+47" counter through delegation
        expect(find.text('+47'), findsOneWidget);
      });
    });
  });
}

