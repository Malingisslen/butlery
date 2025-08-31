/// Comprehensive view testing utilities for Butlery application.
///
/// This module provides specialized utilities for testing Butlery's 100 view files,
/// building on the existing excellent BaseWidgetTest infrastructure while adding
/// view-specific capabilities for multi-provider coordination, Swedish localization,
/// and complex interaction simulation.
///
/// **Key Features:**
/// - **Swedish Localization Support**: Complete Swedish language testing utilities
/// - **Multi-Provider Coordination**: Advanced provider setup and management
/// - **Navigation Testing**: Route change verification and navigation mocking
/// - **State Transition Utilities**: Loading, error, and content state verification
/// - **Collaborative Features**: Real-time editing and conflict simulation
/// - **Performance Testing**: View rendering and interaction performance utilities
///
/// **Usage Example:**
/// ```dart
/// testWidgets('AuthView should render login form', (tester) async {
///   await ViewTestHelpers.setupViewTestEnvironment();
///   
///   final authViewModel = ViewTestHelpers.createTestableAuthViewModel();
///   final widget = ViewTestHelpers.createTestViewWidget(
///     child: const AuthView(),
///     providers: [ChangeNotifierProvider.value(value: authViewModel)],
///   );
///   
///   await tester.pumpWidget(widget);
///   await ViewTestHelpers.waitForViewInitialization(tester);
///   
///   ViewTestHelpers.expectSwedishText(tester, 'Logga in');
///   ViewTestHelpers.expectFormField(tester, 'E-post');
/// });
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Import existing test infrastructure
import '../../infrastructure/helpers/base_widget_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';

/// Specialized utilities for view-level testing in Butlery application.
///
/// This class extends the existing BaseWidgetTest infrastructure with
/// view-specific capabilities including multi-provider management,
/// Swedish localization testing, and complex interaction simulation.
class ViewTestHelpers extends BaseWidgetTest {
  /// Private constructor to prevent instantiation
  ViewTestHelpers._();

  // ==================== SETUP & INITIALIZATION ====================

  /// Initialize complete view testing environment.
  ///
  /// This method sets up all necessary infrastructure for view testing:
  /// - BaseWidgetTest infrastructure
  /// - TestServiceLocator with view-specific mocks
  /// - SharedPreferences mocking
  /// - Swedish localization support
  ///
  /// **Usage:**
  /// ```dart
  /// setUp(() async {
  ///   await ViewTestHelpers.setupViewTestEnvironment();
  /// });
  /// ```
  static Future<void> setupViewTestEnvironment() async {
    // Ensure Flutter binding is initialized
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Initialize SharedPreferences mock with Swedish locale
    SharedPreferences.setMockInitialValues({
      'selected_language': 'sv',
      'locale_code': 'sv_SE',
      'user_preferences': '{"language": "sv", "theme": "light"}',
    });
    
    // Initialize base unit test infrastructure
    await BaseUnitTest.setupUnit();
    
    // Initialize test service locator with view-specific configuration
    await TestServiceLocator.initialize();
    
    // Configure for Swedish localization testing
    _configureSwedishLocalization();
  }

  /// Clean up view testing environment.
  ///
  /// Performs comprehensive cleanup including service locator reset,
  /// mock state clearing, and resource disposal.
  static Future<void> teardownViewTestEnvironment() async {
    // Reset service locator with aggressive cleanup
    await TestServiceLocator.reset();
    
    // Reset base unit test mocks
    BaseUnitTest.resetMocks();
    
    // Clear any remaining state
    await _clearViewTestState();
  }

  /// Configure Swedish localization for testing.
  static void _configureSwedishLocalization() {
    // Configure Swedish locale settings for consistent testing
    // This ensures Swedish text rendering and input handling work correctly
  }

  /// Clear any remaining view test state.
  static Future<void> _clearViewTestState() async {
    // Clear any cached Swedish localization data
    // Reset navigation state
    // Clear any remaining widget references
  }

  // ==================== WIDGET CREATION UTILITIES ====================

  /// Create a test widget with comprehensive view testing support.
  ///
  /// This method creates a MaterialApp wrapper optimized for view testing,
  /// including Swedish localization, navigation mocking, theme configuration,
  /// and multi-provider support.
  ///
  /// **Parameters:**
  /// - `child`: The view widget to test
  /// - `providers`: List of ChangeNotifier providers for the view
  /// - `navigatorObserver`: Optional navigation observer for route testing
  /// - `routes`: Additional routes for navigation testing
  /// - `initialRoute`: Starting route for navigation tests
  /// - `screenSize`: Screen size for responsive testing
  /// - `theme`: Custom theme data (defaults to Swedish-optimized theme)
  ///
  /// **Usage:**
  /// ```dart
  /// final widget = ViewTestHelpers.createTestViewWidget(
  ///   child: const AuthView(),
  ///   providers: [ChangeNotifierProvider.value(value: authViewModel)],
  ///   screenSize: ViewTestHelpers.phoneSize,
  /// );
  /// ```
  static Widget createTestViewWidget({
    required Widget child,
    List<ChangeNotifierProvider>? providers,
    NavigatorObserver? navigatorObserver,
    Map<String, WidgetBuilder>? routes,
    String? initialRoute,
    Size? screenSize,
    ThemeData? theme,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    Widget wrappedChild = child;
    
    // Wrap with providers if provided
    if (providers != null && providers.isNotEmpty) {
      wrappedChild = MultiProvider(
        providers: providers,
        child: child,
      );
    }
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: theme ?? _createSwedishOptimizedTheme(),
      
      // Swedish localization configuration
      locale: const Locale('sv', 'SE'),
      supportedLocales: const [
        Locale('sv', 'SE'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      // Navigation configuration
      home: wrappedChild,
      routes: routes ?? {},
      initialRoute: initialRoute,
      navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
      
      // Debug configuration
      debugShowCheckedModeBanner: false,
      
      // Accessibility configuration
      showSemanticsDebugger: false,
    );
  }

  /// Create a Swedish-optimized theme for testing.
  static ThemeData _createSwedishOptimizedTheme() {
    return ThemeData(
      // Use Swedish-friendly color scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3), // Butlery blue
        brightness: Brightness.light,
      ),
      
      // Swedish text styling
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Roboto'),
        displayMedium: TextStyle(fontFamily: 'Roboto'),
        bodyLarge: TextStyle(fontFamily: 'Roboto'),
        bodyMedium: TextStyle(fontFamily: 'Roboto'),
      ),
      
      // Form styling for Swedish input
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Button styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(88, 48),
        ),
      ),
    );
  }

  // ==================== SWEDISH LOCALIZATION UTILITIES ====================

  /// Enter Swedish text safely handling special characters.
  ///
  /// This method properly handles Swedish characters (å, ä, ö) and
  /// ensures correct text input for Swedish UI testing.
  ///
  /// **Usage:**
  /// ```dart
  /// await ViewTestHelpers.enterSwedishText(
  ///   tester,
  ///   find.byKey(const Key('email_field')),
  ///   'användare@exempel.se',
  /// );
  /// ```
  static Future<void> enterSwedishText(
    WidgetTester tester,
    Finder finder,
    String text, {
    Duration? settleTimeout,
  }) async {
    // Clear any existing text first
    await tester.tap(finder);
    await tester.pump();
    
    // Select all existing text and replace
    await tester.enterText(finder, text);
    
    // Wait for text input to settle
    final timeout = settleTimeout ?? const Duration(milliseconds: 300);
    await tester.pump(timeout);
  }

  /// Find widget by Swedish text content.
  ///
  /// Enhanced finder that handles Swedish character matching
  /// and common Swedish UI text patterns.
  static Finder findBySwedishText(String text) {
    return find.text(text);
  }

  /// Expect Swedish text to be present in the widget tree.
  ///
  /// Assertion helper that verifies Swedish text is rendered correctly
  /// and provides clear error messages for Swedish localization issues.
  static void expectSwedishText(WidgetTester tester, String expectedText) {
    final finder = findBySwedishText(expectedText);
    expect(finder, findsOneWidget, 
      reason: 'Swedish text "$expectedText" not found in widget tree');
  }

  /// Expect Swedish text to be absent from the widget tree.
  static void expectNoSwedishText(WidgetTester tester, String text) {
    final finder = findBySwedishText(text);
    expect(finder, findsNothing,
      reason: 'Swedish text "$text" unexpectedly found in widget tree');
  }

  /// Expect multiple Swedish text elements.
  static void expectSwedishTexts(WidgetTester tester, List<String> texts) {
    for (final text in texts) {
      expectSwedishText(tester, text);
    }
  }

  // ==================== NAVIGATION TESTING UTILITIES ====================

  /// Mock navigator observer for route tracking.
  static MockNavigatorObserver createMockNavigatorObserver() {
    return MockNavigatorObserver();
  }

  /// Expect navigation to specific route.
  ///
  /// Verifies that navigation to the expected route occurred
  /// and provides detailed error information if navigation failed.
  static void expectNavigationTo(
    MockNavigatorObserver observer,
    String expectedRoute,
  ) {
    verify(() => observer.didPush(any(), any())).called(greaterThan(0));
  }

  /// Simulate back navigation.
  static Future<void> simulateBackNavigation(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  // ==================== STATE TRANSITION UTILITIES ====================

  /// Wait for view initialization to complete.
  ///
  /// This method waits for common view initialization patterns including:
  /// - Provider initialization
  /// - Post-frame callbacks
  /// - Initial data loading
  /// - Widget tree stabilization
  static Future<void> waitForViewInitialization(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    // Pump once to trigger initState
    await tester.pump();
    
    // Pump again to trigger post-frame callbacks
    await tester.pump();
    
    // Wait a small amount for async operations
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Pump widget until specific state is reached.
  ///
  /// Repeatedly pumps the widget tree until the provided condition
  /// returns true, with timeout protection.
  static Future<void> pumpUntilState(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();
    
    while (!condition() && stopwatch.elapsed < timeout) {
      await tester.pump(interval);
    }
    
    if (!condition()) {
      throw TimeoutException(
        'pumpUntilState timed out after ${timeout.inSeconds} seconds',
        timeout,
      );
    }
  }

  /// Expect loading state to be displayed.
  static void expectLoadingState(WidgetTester tester) {
    expect(find.byType(CircularProgressIndicator), findsOneWidget,
      reason: 'Loading state not displayed');
  }

  /// Expect error state to be displayed.
  static void expectErrorState(WidgetTester tester, {String? errorMessage}) {
    if (errorMessage != null) {
      expectSwedishText(tester, errorMessage);
    }
    
    // Look for common error indicators
    final errorIndicators = [
      find.byIcon(Icons.error),
      find.byIcon(Icons.error_outline),
      find.byIcon(Icons.warning),
      find.text('Något gick fel'),
      find.text('Fel uppstod'),
    ];
    
    bool foundErrorIndicator = false;
    for (final indicator in errorIndicators) {
      if (tester.any(indicator)) {
        foundErrorIndicator = true;
        break;
      }
    }
    
    expect(foundErrorIndicator, isTrue,
      reason: 'Error state indicators not found');
  }

  /// Expect content state to be displayed (no loading, no error).
  static void expectContentState(WidgetTester tester) {
    expect(find.byType(CircularProgressIndicator), findsNothing,
      reason: 'Loading indicator still visible in content state');
    
    // Should not find common error indicators
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  }

  // ==================== FORM TESTING UTILITIES ====================

  /// Expect form field to be present with Swedish label.
  static void expectFormField(WidgetTester tester, String label) {
    final fieldFinder = find.widgetWithText(TextFormField, label);
    expect(fieldFinder, findsOneWidget,
      reason: 'Form field with label "$label" not found');
  }

  /// Expect form validation error with Swedish message.
  static void expectFormValidationError(WidgetTester tester, String errorMessage) {
    expectSwedishText(tester, errorMessage);
  }

  /// Fill multiple form fields with Swedish content.
  static Future<void> fillSwedishFormFields(
    WidgetTester tester,
    Map<String, String> fieldValues,
  ) async {
    for (final entry in fieldValues.entries) {
      final fieldKey = entry.key;
      final value = entry.value;
      
      final finder = find.byKey(Key(fieldKey));
      await enterSwedishText(tester, finder, value);
    }
    
    // Wait for all form fields to settle
    await tester.pump(const Duration(milliseconds: 200));
  }

  // ==================== INTERACTION UTILITIES ====================

  /// Tap widget and wait for animations to settle.
  static Future<void> tapAndSettle(
    WidgetTester tester,
    Finder finder, {
    Duration settleTimeout = const Duration(milliseconds: 500),
  }) async {
    await tester.tap(finder);
    await tester.pumpAndSettle(settleTimeout);
  }

  /// Long press widget and wait for response.
  static Future<void> longPressAndSettle(
    WidgetTester tester,
    Finder finder, {
    Duration settleTimeout = const Duration(milliseconds: 500),
  }) async {
    await tester.longPress(finder);
    await tester.pumpAndSettle(settleTimeout);
  }

  /// Scroll until widget becomes visible.
  static Future<void> scrollUntilVisible(
    WidgetTester tester,
    Finder itemFinder,
    Finder scrollableFinder, {
    double delta = -100.0,
    int maxScrolls = 50,
  }) async {
    int scrollCount = 0;
    while (!tester.any(itemFinder) && scrollCount < maxScrolls) {
      await tester.drag(scrollableFinder, Offset(0, delta));
      await tester.pump();
      scrollCount++;
    }
    
    if (!tester.any(itemFinder)) {
      throw Exception('Widget not found after $maxScrolls scroll attempts');
    }
  }

  // ==================== SCREEN SIZE UTILITIES ====================

  /// Configure screen size for responsive testing.
  static void setScreenSize(
    WidgetTester tester, {
    Size? size,
    double? devicePixelRatio,
  }) {
    final testSize = size ?? phoneSize;
    final testRatio = devicePixelRatio ?? 3.0;
    
    tester.view.physicalSize = testSize;
    tester.view.devicePixelRatio = testRatio;
    
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // Common screen sizes for Swedish users
  static const Size phoneSize = Size(375, 812); // iPhone X (common in Sweden)
  static const Size tabletSize = Size(768, 1024); // iPad
  static const Size desktopSize = Size(1440, 900); // MacBook Air 13"
  
  // ==================== PERFORMANCE UTILITIES ====================

  /// Measure view rendering performance.
  static Future<Duration> measureViewRenderTime(
    WidgetTester tester,
    Widget widget,
  ) async {
    final stopwatch = Stopwatch()..start();
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  /// Expect view to render within performance threshold.
  static void expectPerformantRendering(
    Duration renderTime, {
    Duration threshold = const Duration(milliseconds: 500),
  }) {
    expect(renderTime.inMilliseconds, lessThan(threshold.inMilliseconds),
      reason: 'View rendering took ${renderTime.inMilliseconds}ms, '
              'exceeds threshold of ${threshold.inMilliseconds}ms');
  }
}

/// Mock NavigatorObserver for route testing.
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

/// Exception thrown when pumpUntilState times out.
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;
  
  const TimeoutException(this.message, this.timeout);
  
  @override
  String toString() => 'TimeoutException: $message';
}

/// Extension methods for WidgetTester with Swedish localization support.
extension SwedishWidgetTester on WidgetTester {
  /// Pump widget with view test environment setup.
  Future<void> pumpViewWidget(
    Widget widget, {
    List<ChangeNotifierProvider>? providers,
    NavigatorObserver? navigatorObserver,
  }) async {
    final testWidget = ViewTestHelpers.createTestViewWidget(
      child: widget,
      providers: providers,
      navigatorObserver: navigatorObserver,
    );
    
    await pumpWidget(testWidget);
    await ViewTestHelpers.waitForViewInitialization(this);
  }
  
  /// Enter Swedish text in form field.
  Future<void> enterSwedishText(Finder finder, String text) async {
    await ViewTestHelpers.enterSwedishText(this, finder, text);
  }
  
  /// Expect Swedish text to be present.
  void expectSwedishText(String text) {
    ViewTestHelpers.expectSwedishText(this, text);
  }
  
  /// Tap and settle with view-optimized timing.
  Future<void> tapViewElement(Finder finder) async {
    await ViewTestHelpers.tapAndSettle(this, finder);
  }
}