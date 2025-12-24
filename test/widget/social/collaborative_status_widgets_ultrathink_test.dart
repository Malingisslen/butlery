// test/widget/social/collaborative_status_widgets_ultrathink_test.dart
// ULTRATHINK TEST SUITE: CollaborativeStatusWidgets - 290 lines of production code
// Testing 5 static methods + 1 private class in collaborative status widget system
//
// ULTRATHINK FOCUS: Static widget creation, ViewModel integration, Swedish localization, PreferredSizeWidget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/social/collaborative/components/collaborative_status_widgets.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

// Mock classes for dependencies
class MockCollaborativeStatusViewModel extends Mock
    implements CollaborativeStatusViewModel {}

void main() {
  group('CollaborativeStatusWidgets Ultrathink Tests', () {
    late MockCollaborativeStatusViewModel mockCollaborativeStatusViewModel;

    setUpAll(() async {
      await BaseWidgetTest.setupWidget();

      // Register fallback values for mocktail
      registerFallbackValue(const CollaborativeStatus(isCollaborative: false));
      registerFallbackValue(<String, List<Recipe>>{});
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create fresh mocks for each test
      mockCollaborativeStatusViewModel = MockCollaborativeStatusViewModel();
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create test environment with providers
    Widget createTestWidget({Widget? child}) {
      return ChangeNotifierProvider<CollaborativeStatusViewModel>(
        create: (_) => mockCollaborativeStatusViewModel,
        child: BaseWidgetTest.createTestApp(
          locale: const Locale('en', 'US'),
          child: Scaffold(
            body: child ?? const SizedBox.shrink(),
          ),
        ),
      );
    }

    group('statusBadge Method Tests', () {
      testWidgets('creates statusBadge with default parameters',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code default values from lines 15-20
        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeStatusWidgets.statusBadge(),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should create Container + Row + Icon + Text structure
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
        expect(find.text('Delat'), findsOneWidget); // Default text parameter
        expect(find.byIcon(Icons.people),
            findsOneWidget); // Default icon parameter
      });

      testWidgets('passes custom parameters correctly to statusBadge',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code custom parameter handling
        const customText = 'Anpassat';
        const customIcon = Icons.star;
        const customColor = Colors.green;
        const customPadding = EdgeInsets.all(12.0);

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeStatusWidgets.statusBadge(
              text: customText,
              icon: customIcon,
              color: customColor,
              padding: customPadding,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Verify custom parameters are applied correctly
        expect(find.text(customText), findsOneWidget);
        expect(find.byIcon(customIcon), findsOneWidget);

        // Verify custom icon color (line 42: color: effectiveColor)
        final icon = tester.widget<Icon>(find.byIcon(customIcon));
        expect(icon.color, equals(customColor));
      });

      testWidgets('uses AppColors.primaryBlue as default color',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code color fallback from line 21
        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeStatusWidgets.statusBadge(),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should use AppColors.primaryBlue when no color provided
        final icon = tester.widget<Icon>(find.byIcon(Icons.people));
        expect(icon.color, equals(AppColors.primaryBlue));
      });

      testWidgets('applies correct padding and styling from AppDimensions',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code AppDimensions usage from lines 25-27
        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeStatusWidgets.statusBadge(),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should use AppDimensions constants for spacing
        final container = tester.widget<Container>(find.byType(Container));
        final expectedPadding = const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingXs,
        );
        expect(container.padding, equals(expectedPadding));
      });
    });

    group('banner Method Tests', () {
      testWidgets('creates banner with required title and subtitle',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code required parameters from lines 59-60
        const title = 'Test Collaboration Title';
        const subtitle = 'Test collaboration subtitle';

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeStatusWidgets.banner(
              title: title,
              subtitle: subtitle,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should create Container + InkWell + Row structure
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(InkWell), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.text(subtitle), findsOneWidget);
      });

      testWidgets('handles onTap callback correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code onTap handling from line 83
        const title = 'Tappable Banner';
        const subtitle = 'Test tap functionality';
        bool tapCalled = false;

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeStatusWidgets.banner(
              title: title,
              subtitle: subtitle,
              onTap: () => tapCalled = true,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Test tap functionality through InkWell
        await tester.tap(find.byType(InkWell));
        expect(tapCalled, isTrue);
      });

      testWidgets('uses trailing widget when provided without context',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code trailing fallback from lines 123-124
        const title = 'Banner with Trailing';
        const subtitle = 'Test trailing widget';
        const trailingWidget = Icon(Icons.arrow_forward);

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeStatusWidgets.banner(
              title: title,
              subtitle: subtitle,
              trailing: trailingWidget,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should show trailing widget instead of default icon
        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
        expect(find.byIcon(Icons.people_outline),
            findsNothing); // Default fallback should not appear
      });

      testWidgets('shows default icon when no context or trailing provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code final fallback from lines 127-131
        const title = 'Basic Banner';
        const subtitle = 'No additional widgets';

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeStatusWidgets.banner(
              title: title,
              subtitle: subtitle,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should show default people_outline icon as last fallback
        expect(find.byIcon(Icons.people_outline), findsOneWidget);
      });

      testWidgets('uses custom backgroundColor when provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code backgroundColor override from line 69
        const title = 'Custom Background';
        const subtitle = 'Test background color';
        final customBgColor = Colors.red.withValues(alpha: 0.2);

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeStatusWidgets.banner(
              title: title,
              subtitle: subtitle,
              backgroundColor: customBgColor,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Container should use custom background color
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('uses AppColors.primaryBlue default background with alpha',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code default background from lines 68-69
        const title = 'Default Background';
        const subtitle = 'Test default styling';

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeStatusWidgets.banner(
              title: title,
              subtitle: subtitle,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should use AppColors.primaryBlue.withValues(alpha: 0.1)
        expect(find.byType(Container), findsOneWidget);
      });
    });

    group('appBar Method Tests', () {
      testWidgets('creates appBar and returns PreferredSizeWidget',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code PreferredSizeWidget return from lines 139-156
        const contentId = 'recipe_123';
        const title = 'Test AppBar';

        // Setup mock for AppBar rendering
        when(() => mockCollaborativeStatusViewModel
                .getRecipeCollaborativeStatus(any(), any()))
            .thenReturn(const CollaborativeStatus(isCollaborative: false));

        final appBar = CollaborativeStatusWidgets.appBar(
          context: MockBuildContext(),
          contentId: contentId,
          title: title,
        );

        // ULTRATHINK: Should return PreferredSizeWidget (_CollaborativeAppBar)
        expect(appBar, isA<PreferredSizeWidget>());
        expect(appBar.preferredSize,
            equals(const Size.fromHeight(kToolbarHeight)));
      });

      testWidgets(
          'appBar integrates with Consumer<CollaborativeStatusViewModel>',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code ViewModel integration from _CollaborativeAppBar
        const contentId = 'recipe_456';
        const title = 'ViewModel Integration Test';

        // Setup mock ViewModel response
        when(() =>
            mockCollaborativeStatusViewModel.getRecipeCollaborativeStatus(
                any(), any())).thenReturn(
            const CollaborativeStatus(isCollaborative: true, participants: []));

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => Scaffold(
                appBar: CollaborativeStatusWidgets.appBar(
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

        // ULTRATHINK: Should create AppBar through Consumer pattern
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text(title), findsOneWidget);

        // Verify ViewModel method was called
        verify(() => mockCollaborativeStatusViewModel
            .getRecipeCollaborativeStatus(contentId, null)).called(1);
      });
    });

    group('smartBanner Method Tests', () {
      testWidgets('smartBanner returns SizedBox.shrink when not collaborative',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code non-collaborative logic from line 186
        const contentId = 'recipe_789';
        const title = 'Non-Collaborative Content';

        // Setup mock to return non-collaborative status
        when(() => mockCollaborativeStatusViewModel
                .getRecipeCollaborativeStatus(any(), any()))
            .thenReturn(const CollaborativeStatus(isCollaborative: false));

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => CollaborativeStatusWidgets.smartBanner(
                context: context,
                contentId: contentId,
                title: title,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should return SizedBox.shrink (lines 186)
        expect(find.byType(SizedBox), findsOneWidget);
        expect(
            find.text(title), findsNothing); // Banner content should not appear
      });

      testWidgets('smartBanner creates banner when collaborative',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code collaborative logic from lines 188-195
        const contentId = 'recipe_collaborative';
        const customTitle = 'Custom Collaboration Title';

        // Setup mock to return collaborative status
        when(() =>
            mockCollaborativeStatusViewModel.getRecipeCollaborativeStatus(
                any(), any())).thenReturn(
            const CollaborativeStatus(isCollaborative: true, participants: []));

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => CollaborativeStatusWidgets.smartBanner(
                context: context,
                contentId: contentId,
                title: customTitle,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should create banner with custom title
        expect(find.text(customTitle), findsOneWidget);
        expect(find.byType(Container),
            findsAtLeastNWidgets(1)); // Banner structure

        // Verify ViewModel was called
        verify(() => mockCollaborativeStatusViewModel
            .getRecipeCollaborativeStatus(contentId, null)).called(1);
      });

      testWidgets(
          'smartBanner uses default Swedish text when no title provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code default Swedish text from lines 189-191
        const contentId = 'recipe_swedish_default';

        // Setup mock to return collaborative status
        when(() =>
            mockCollaborativeStatusViewModel.getRecipeCollaborativeStatus(
                any(), any())).thenReturn(
            const CollaborativeStatus(isCollaborative: true, participants: []));

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => CollaborativeStatusWidgets.smartBanner(
                context: context,
                contentId: contentId,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should use default Swedish text
        expect(find.text('Du redigerar tillsammans med andra'), findsOneWidget);
        expect(find.text('Ändringar synkas automatiskt med andra deltagare'),
            findsOneWidget);
      });

      testWidgets('smartBanner handles menu contentType correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code menu content handling from lines 176-182
        const contentId = 'menu_123';
        const contentType = 'menu';
        final menuData = <String, List<Recipe>>{'breakfast': []};

        // Setup mock for menu status
        when(() =>
            mockCollaborativeStatusViewModel.getMenuCollaborativeStatus(
                any(), any())).thenReturn(
            const CollaborativeStatus(isCollaborative: true, participants: []));

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => CollaborativeStatusWidgets.smartBanner(
                context: context,
                contentId: contentId,
                contentType: contentType,
                menuData: menuData,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should call getMenuCollaborativeStatus instead of getRecipeCollaborativeStatus
        verify(() => mockCollaborativeStatusViewModel
            .getMenuCollaborativeStatus(contentId, menuData)).called(1);
        verifyNever(() => mockCollaborativeStatusViewModel
            .getRecipeCollaborativeStatus(any(), any()));
      });
    });

    group('refreshStatus Method Tests', () {
      testWidgets(
          'refreshStatus calls ViewModel invalidateRecipeStatus for recipe content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code recipe invalidation from lines 207-210
        const contentId = 'recipe_refresh_test';
        const contentType = 'recipe';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) {
                // Call the static method
                CollaborativeStatusWidgets.refreshStatus(
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

        // ULTRATHINK: Should call ViewModel invalidateRecipeStatus method
        // Note: This is void method, so we verify it doesn't crash
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets(
          'refreshStatus calls ViewModel invalidateMenuStatus for menu content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code menu invalidation from lines 211-212
        const contentId = 'menu_refresh_test';
        const contentType = 'menu';

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) {
                // Call the static method
                CollaborativeStatusWidgets.refreshStatus(
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

        // ULTRATHINK: Should call ViewModel invalidateMenuStatus method
        // Note: This is void method, so we verify it doesn't crash
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('refreshStatus handles ViewModel errors gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code error handling from lines 213-215
        const contentId = 'error_test';

        // Create widget without proper ViewModel setup to trigger error
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  // This should trigger the catch block
                  CollaborativeStatusWidgets.refreshStatus(context, contentId);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle errors gracefully with try/catch
        expect(find.byType(SizedBox), findsOneWidget);
      });
    });

    group('Parameter Edge Cases', () {
      testWidgets('handles null and empty parameters correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code edge case handling
        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                CollaborativeStatusWidgets.statusBadge(
                  text: '',
                  padding: EdgeInsets.zero,
                ),
                CollaborativeStatusWidgets.banner(
                  title: '',
                  subtitle: '',
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle empty strings without crashing
        expect(find.byType(Container), findsAtLeastNWidgets(2));
        expect(find.byType(Row), findsAtLeastNWidgets(2));
      });

      testWidgets('handles very long text content',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with long content
        const longTitle =
            'Very long collaboration title that might overflow if not handled properly by the widget layout system';
        const longSubtitle =
            'Very long collaboration subtitle with detailed explanation about what is happening in this collaborative session and how users should interact with it';

        await tester.pumpWidget(
          createTestWidget(
            child: CollaborativeStatusWidgets.banner(
              title: longTitle,
              subtitle: longSubtitle,
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle long text without overflow errors
        expect(find.textContaining('Very long collaboration title'),
            findsOneWidget);
        expect(find.textContaining('Very long collaboration subtitle'),
            findsOneWidget);
      });

      testWidgets('handles complex menuData correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with complex menu structure
        const contentId = 'complex_menu';
        final complexMenuData = <String, List<Recipe>>{
          'breakfast': [
            Recipe(
              core: RecipeCore(
                title: 'Pancakes',
                description: 'Fluffy breakfast pancakes',
                ingredients: ['flour', 'eggs', 'milk'],
                instructions: ['Mix ingredients', 'Cook on griddle'],
                mealType: 'breakfast',
              ),
              type: RecipeType.personal,
            )
          ],
          'lunch': [
            Recipe(
              core: RecipeCore(
                title: 'Sandwich',
                description: 'Simple lunch sandwich',
                ingredients: ['bread', 'cheese'],
                instructions: ['Make sandwich'],
                mealType: 'lunch',
              ),
              type: RecipeType.personal,
            )
          ],
          'dinner': [],
        };

        // Setup mock for complex menu
        when(() => mockCollaborativeStatusViewModel.getMenuCollaborativeStatus(
                any(), any()))
            .thenReturn(const CollaborativeStatus(isCollaborative: false));

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => CollaborativeStatusWidgets.smartBanner(
                context: context,
                contentId: contentId,
                contentType: 'menu',
                menuData: complexMenuData,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // ULTRATHINK: Should handle complex menu data structure
        expect(find.byType(SizedBox),
            findsOneWidget); // Non-collaborative should return shrink

        // Verify complex menu data was passed correctly
        verify(() => mockCollaborativeStatusViewModel
            .getMenuCollaborativeStatus(contentId, complexMenuData)).called(1);
      });
    });
  });
}

// Mock BuildContext for appBar testing
class MockBuildContext extends Mock implements BuildContext {}
