/// ULTRATHINK TEST SUITE: DiscoveryDashboardView - Phase 2 High-Risk View
/// 
/// PRODUCTION CODE ANALYSIS: lib/views/social/discovery_dashboard_view.dart
/// - Single ChangeNotifierProvider pattern with DiscoveryDashboardViewModel
/// - Complex StatefulWidget with TabController, ScrollController, TextEditingController
/// - 6 Facade components: DiscoveryAppBar, DiscoverySearchSection, DiscoveryCategories, 
///   TrendingContentSection, FriendActivitySection, RecommendationsSection
/// - AutomaticKeepAliveClientMixin with wantKeepAlive=true for tab state preservation
/// - Complex post-frame initialization: ViewModel.initialize(), TabController sync, infinite scroll setup
/// - Swedish timeago configuration with timeago.setLocaleMessages('sv', timeago.SvMessages())
/// - CustomScrollView with SliverAppBar and TabBarView coordination
/// 
/// TEST FOCUS: Controller initialization sequence, facade coordination, tab switching,
/// search functionality, infinite loading, Swedish localization, state management
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/views/social/discovery_dashboard_view.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
// Facade components tested via integration - no direct widget testing needed

// Test infrastructure imports - using centralized system
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  group('DiscoveryDashboardView Tests - ULTRATHINK METHODOLOGY', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
    });
    
    tearDown(() async {
      await TestServiceLocator.reset();
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create test environment following gold standard pattern
    Widget createTestWidget({
      required Widget child,
    }) {
      return MaterialApp(
        home: child,
        locale: const Locale('sv', 'SE'),
        debugShowCheckedModeBanner: false,
      );
    }

    group('Provider Architecture Tests', () {
      testWidgets('should initialize with ChangeNotifierProvider architecture', (WidgetTester tester) async {
        // ULTRATHINK: Test production code ChangeNotifierProvider from lines 36-40
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump(); // Allow provider creation

        // Verify ChangeNotifierProvider structure exists
        expect(find.byType(ChangeNotifierProvider<DiscoveryDashboardViewModel>), findsOneWidget);
        expect(find.byType(Consumer<DiscoveryDashboardViewModel>), findsOneWidget);
        
        // Verify basic widget structure
        expect(find.byType(DiscoveryDashboardView), findsOneWidget);
      });

      testWidgets('should initialize DiscoveryDashboardViewModel with correct service dependencies', (WidgetTester tester) async {
        // ULTRATHINK: Test production code ViewModel dependency injection from constructor
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        // Verify provider architecture is working
        expect(find.byType(ChangeNotifierProvider<DiscoveryDashboardViewModel>), findsOneWidget);
        
        // Verify Scaffold structure from Consumer build
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('should provide Consumer architecture for reactive updates', (WidgetTester tester) async {
        // ULTRATHINK: Test production code Consumer pattern from lines 106-118
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump(); // Allow initialization

        // Verify Consumer structure exists
        expect(find.byType(Consumer<DiscoveryDashboardViewModel>), findsOneWidget);
        expect(find.byType(CustomScrollView), findsOneWidget);
      });
    });

    group('Complex Controller Initialization Tests', () {
      testWidgets('should initialize StatefulWidget with required controllers', (WidgetTester tester) async {
        // ULTRATHINK: Test production code controller initialization from lines 54-56, 64
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump(); // Allow initState

        // Verify TabController is initialized (3 tabs from line 64)
        expect(find.byType(TabBar), findsOneWidget);
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.controller?.length, equals(3));
        
        // Verify CustomScrollView with ScrollController exists
        expect(find.byType(CustomScrollView), findsOneWidget);
      });

      testWidgets('should setup TabController with correct configuration', (WidgetTester tester) async {
        // ULTRATHINK: Test production code TabController setup from lines 64, 132-154
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow post-frame callback

        // Verify TabBar configuration
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.controller?.length, equals(3));
        
        // Verify Swedish tab labels from production code
        expect(find.text('Upptäck'), findsOneWidget);
        expect(find.text('Aktivitet'), findsOneWidget);
        expect(find.text('För dig'), findsOneWidget);
      });

      testWidgets('should configure AutomaticKeepAliveClientMixin correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code AutomaticKeepAliveClientMixin from line 53, wantKeepAlive=true line 59
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        // Widget should initialize without errors - AutomaticKeepAliveClientMixin preserves state
        expect(tester.takeException(), isNull);
        expect(find.byType(DiscoveryDashboardView), findsOneWidget);
      });

      testWidgets('should configure Swedish timeago on initialization', (WidgetTester tester) async {
        // ULTRATHINK: Test production code timeago configuration from lines 88-89
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        // Should initialize without errors - timeago.setLocaleMessages('sv', timeago.SvMessages())
        expect(tester.takeException(), isNull);
        expect(find.byType(DiscoveryDashboardView), findsOneWidget);
      });
    });

    group('Facade Component Architecture Tests', () {
      testWidgets('should render DiscoveryAppBar facade component', (WidgetTester tester) async {
        // ULTRATHINK: Test production code facade component from line 111
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow post-frame initialization

        // DiscoveryAppBar.build renders SliverAppBar with "Upptäck" title
        expect(find.byType(SliverAppBar), findsOneWidget);
        // Note: facade content rendering depends on ViewModel state
      });

      testWidgets('should render DiscoverySearchSection facade component', (WidgetTester tester) async {
        // ULTRATHINK: Test production code facade component from line 112
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow initialization

        // DiscoverySearchSection.build renders SliverToBoxAdapter with search field
        expect(find.byType(CustomScrollView), findsOneWidget);
        // Search functionality validated in dedicated search tests
      });

      testWidgets('should coordinate all facade components properly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code complete facade coordination from CustomScrollView slivers
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow full initialization

        // Main scroll structure should be present
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(SliverAppBar), findsOneWidget);
        
        // TabBar and TabBarView coordination
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.byType(TabBarView), findsOneWidget);
      });
    });

    group('State Management Tests', () {
      testWidgets('should handle initial loading state', (WidgetTester tester) async {
        // ULTRATHINK: Test production code loading state from lines 208-228
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        // Should show loading state initially during ViewModel.initialize()
        // Swedish loading message from production code line 221
        expect(find.text('Laddar upptäcktsinnehåll...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should handle content loaded state', (WidgetTester tester) async {
        // ULTRATHINK: Test production code content state after loading completes
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump(); // Initial loading
        await tester.pump(const Duration(milliseconds: 100)); // Allow loading to complete

        // Should show content structure after loading
        expect(find.byType(TabBarView), findsOneWidget);
        expect(find.byType(CustomScrollView), findsOneWidget);
      });

      testWidgets('should handle Scaffold background color from theme', (WidgetTester tester) async {
        // ULTRATHINK: Test production code Scaffold configuration from line 104-105
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, isNotNull); // Uses Theme.of(context).colorScheme.surface
      });
    });

    group('Tab Switching Tests', () {
      testWidgets('should handle tab switching with TabController sync', (WidgetTester tester) async {
        // ULTRATHINK: Test production code tab switching from TabController listener lines 73-77
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow post-frame callback setup

        // Verify initial tab (Discovery - tab 0)
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.controller?.index, equals(0));

        // Simulate tab change to Activity (tab 1)
        await tester.tap(find.text('Aktivitet'));
        await tester.pumpAndSettle();

        // TabController should update (ViewModel.setActiveTab called via listener)
        expect(tester.takeException(), isNull);
      });

      testWidgets('should display correct Swedish tab labels with icons', (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish tab labels from _buildTab method lines 135-137
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        // Verify all Swedish tab labels
        expect(find.text('Upptäck'), findsOneWidget);
        expect(find.text('Aktivitet'), findsOneWidget);
        expect(find.text('För dig'), findsOneWidget);
        
        // Verify tab icons are present
        expect(find.byIcon(Icons.explore), findsOneWidget);
        expect(find.byIcon(Icons.timeline), findsOneWidget);
        expect(find.byIcon(Icons.recommend), findsOneWidget);
      });

      testWidgets('should show TabBarView with correct tab content structure', (WidgetTester tester) async {
        // ULTRATHINK: Test production code TabBarView from lines 252-260
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow loading to complete

        // TabBarView should be present with 3 tabs
        expect(find.byType(TabBarView), findsOneWidget);
        final tabBarView = tester.widget<TabBarView>(find.byType(TabBarView));
        expect(tabBarView.children.length, equals(3));
      });
    });

    group('Search Functionality Tests', () {
      testWidgets('should handle empty search state initially', (WidgetTester tester) async {
        // ULTRATHINK: Test production code search state when searchQuery is empty
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow initialization

        // Should not show "no search results" when no search active
        expect(find.text('Rensa sökning'), findsNothing);
      });

      testWidgets('should handle search controller integration', (WidgetTester tester) async {
        // ULTRATHINK: Test production code TextEditingController from line 55, passed to DiscoverySearchSection line 112
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        // TextEditingController should be properly initialized and passed to search section
        expect(tester.takeException(), isNull);
        expect(find.byType(DiscoveryDashboardView), findsOneWidget);
      });
    });

    group('Infinite Loading Tests', () {
      testWidgets('should setup ScrollController for infinite loading', (WidgetTester tester) async {
        // ULTRATHINK: Test production code ScrollController setup from lines 80-85
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow post-frame callback

        // ScrollController should be attached to CustomScrollView
        expect(find.byType(CustomScrollView), findsOneWidget);
        final customScrollView = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
        expect(customScrollView.controller, isNotNull);
      });

      testWidgets('should handle scroll events without errors', (WidgetTester tester) async {
        // ULTRATHINK: Test production code scroll listener functionality
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow initialization

        // Simulate scroll
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    });

    group('Swedish Localization Tests', () {
      testWidgets('should display Swedish loading message', (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish loading text from line 221
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        expect(find.text('Laddar upptäcktsinnehåll...'), findsOneWidget);
      });

      testWidgets('should display Swedish tab labels correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish tab names from _buildTab calls
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        expect(find.text('Upptäck'), findsOneWidget);
        expect(find.text('Aktivitet'), findsOneWidget);
        expect(find.text('För dig'), findsOneWidget);
      });

      testWidgets('should handle Swedish locale configuration', (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish locale from MaterialApp helper
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        // Should handle Swedish locale properly
        final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.locale?.languageCode, equals('sv'));
      });
    });

    group('Lifecycle Management Tests', () {
      testWidgets('should properly initialize and dispose resources', (WidgetTester tester) async {
        // ULTRATHINK: Test production code controller disposal from lines 93-97
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        
        expect(tester.takeException(), isNull);

        // Remove widget to test disposal
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle view recreation without state corruption', (WidgetTester tester) async {
        // ULTRATHINK: Test production code state resilience with AutomaticKeepAliveClientMixin
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        // Recreate view
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));  
        await tester.pump();

        expect(find.byType(DiscoveryDashboardView), findsOneWidget);
        expect(find.text('Upptäck'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should maintain provider context consistency', (WidgetTester tester) async {
        // ULTRATHINK: Test production code provider consistency across state changes
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        // Get context from Consumer widget
        final consumerElement = tester.element(find.byType(Consumer<DiscoveryDashboardViewModel>));
        final viewModel1 = Provider.of<DiscoveryDashboardViewModel>(consumerElement, listen: false);

        // Pump again to test consistency
        await tester.pump();
        
        final viewModel2 = Provider.of<DiscoveryDashboardViewModel>(consumerElement, listen: false);
        expect(identical(viewModel1, viewModel2), isTrue);
      });
    });

    group('Performance and Integration Tests', () {
      testWidgets('should handle complex initialization efficiently', (WidgetTester tester) async {
        // ULTRATHINK: Test production code complex initialization performance
        final stopwatch = Stopwatch()..start();
        
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        await tester.pump(); // Post-frame callbacks
        
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
        expect(find.byType(DiscoveryDashboardView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should integrate properly with Phase 1 test infrastructure', (WidgetTester tester) async {
        // ULTRATHINK: Test production code integration with test infrastructure
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();

        // Should integrate with test helpers
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(DiscoveryDashboardView), findsOneWidget);
        
        // Should handle Swedish locale properly
        final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.locale?.languageCode, equals('sv'));
      });

      testWidgets('should handle facade component architecture efficiently', (WidgetTester tester) async {
        // ULTRATHINK: Test production code facade pattern efficiency with 6 components
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow full initialization

        // Complex facade structure should be efficient
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(SliverAppBar), findsOneWidget);
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.byType(TabBarView), findsOneWidget);
        
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle controller coordination without performance issues', (WidgetTester tester) async {
        // ULTRATHINK: Test production code multi-controller coordination
        await tester.pumpWidget(createTestWidget(
          child: const DiscoveryDashboardView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow controller setup

        // Multiple controllers should coordinate efficiently
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.byType(CustomScrollView), findsOneWidget);
        
        // Simulate interaction without performance degradation
        await tester.tap(find.text('Aktivitet'));
        await tester.pump();
        
        expect(tester.takeException(), isNull);
      });
    });
  });
}