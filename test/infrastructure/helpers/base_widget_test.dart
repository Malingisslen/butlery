import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../test_support/base_unit_test.dart';
import '../di/test_service_locator.dart';

/// Base class for all widget tests in the Butlery app.
/// Provides common setup, teardown, and helper methods.
abstract class BaseWidgetTest {
  /// Initialize widget test environment
  static Future<void> setupWidget() async {
    // Ensure Flutter binding is initialized
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Initialize SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
    
    // Initialize base unit test infrastructure
    await BaseUnitTest.setupUnit();
    
    // Initialize test service locator
    await TestServiceLocator.initialize();
  }
  
  /// Clean up after widget tests
  static Future<void> teardownWidget() async {
    // Reset mocks
    BaseUnitTest.resetMocks();
    
    // Reset service locator
    await TestServiceLocator.reset();
  }
  
  /// Create a test widget with proper Material app wrapper
  static Widget createTestApp({
    required Widget child,
    NavigatorObserver? navigatorObserver,
    Map<String, WidgetBuilder>? routes,
    GlobalKey<NavigatorState>? navigatorKey,
    ThemeData? theme,
    Locale? locale,
  }) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: theme ?? ThemeData.light(),
      locale: locale ?? const Locale('en', 'US'),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('sv', 'SE'),
      ],
      home: child,
      routes: routes ?? {},
      navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
    );
  }
  
  /// Create a test widget with Provider support for ViewModels
  static Widget createTestAppWithProvider<T extends ChangeNotifier>({
    required T viewModel,
    required Widget child,
    NavigatorObserver? navigatorObserver,
    Map<String, WidgetBuilder>? routes,
    GlobalKey<NavigatorState>? navigatorKey,
    ThemeData? theme,
    Locale? locale,
  }) {
    return createTestApp(
      navigatorObserver: navigatorObserver,
      routes: routes,
      navigatorKey: navigatorKey,
      theme: theme,
      locale: locale,
      child: ChangeNotifierProvider<T>.value(
        value: viewModel,
        child: child,
      ),
    );
  }
  
  /// Create a test widget with multiple Providers
  static Widget createTestAppWithMultiProvider({
    required List<ChangeNotifierProvider> providers,
    required Widget child,
    NavigatorObserver? navigatorObserver,
    Map<String, WidgetBuilder>? routes,
    GlobalKey<NavigatorState>? navigatorKey,
    ThemeData? theme,
    Locale? locale,
  }) {
    return createTestApp(
      navigatorObserver: navigatorObserver,
      routes: routes,
      navigatorKey: navigatorKey,
      theme: theme,
      locale: locale,
      child: MultiProvider(
        providers: providers,
        child: child,
      ),
    );
  }
  
  /// Helper to pump widget and wait for animations
  static Future<void> pumpWidgetAndSettle(
    WidgetTester tester,
    Widget widget, {
    Duration? duration,
  }) async {
    await tester.pumpWidget(widget);
    if (duration != null) {
      await tester.pumpAndSettle(duration);
    } else {
      await tester.pumpAndSettle();
    }
  }
  
  /// Helper to find widgets by Swedish text (common in our app)
  static Finder findBySwedishText(String text) {
    return find.text(text);
  }
  
  /// Helper to tap and wait for animations
  static Future<void> tapAndSettle(
    WidgetTester tester,
    Finder finder, {
    Duration? duration,
  }) async {
    await tester.tap(finder);
    if (duration != null) {
      await tester.pumpAndSettle(duration);
    } else {
      await tester.pumpAndSettle();
    }
  }
  
  /// Helper to enter text and wait
  static Future<void> enterTextAndSettle(
    WidgetTester tester,
    Finder finder,
    String text, {
    Duration? duration,
  }) async {
    await tester.enterText(finder, text);
    if (duration != null) {
      await tester.pumpAndSettle(duration);
    } else {
      await tester.pumpAndSettle();
    }
  }
  
  /// Helper to scroll until visible
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
  }
  
  /// Helper to verify dialog is shown
  static void expectDialog({String? title, String? content}) {
    if (title != null) {
      expect(find.text(title), findsOneWidget);
    }
    if (content != null) {
      expect(find.text(content), findsOneWidget);
    }
    expect(find.byType(Dialog), findsOneWidget);
  }
  
  /// Helper to verify snackbar is shown
  static void expectSnackbar(String message) {
    expect(find.text(message), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  }
  
  /// Helper to verify loading indicator
  static void expectLoading() {
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  }
  
  /// Helper to verify no loading indicator
  static void expectNotLoading() {
    expect(find.byType(CircularProgressIndicator), findsNothing);
  }
  
  /// Helper to set screen size for responsive testing
  static void setScreenSize(
    WidgetTester tester, {
    Size? size,
    double? devicePixelRatio,
  }) {
    final testSize = size ?? const Size(375, 812); // iPhone X default
    final testRatio = devicePixelRatio ?? 3.0;
    
    tester.view.physicalSize = testSize;
    tester.view.devicePixelRatio = testRatio;
    
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
  
  /// Common screen sizes for testing
  static const Size phoneSize = Size(375, 812); // iPhone X
  static const Size tabletSize = Size(768, 1024); // iPad
  static const Size desktopSize = Size(1920, 1080); // Desktop
  
  /// Helper to wait for async operations
  static Future<void> waitForAsync(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  
  /// Helper to verify widget accessibility
  static void expectAccessible(
    WidgetTester tester,
    Finder finder, {
    String? label,
    String? hint,
    String? value,
  }) {
    final semantics = tester.getSemantics(finder);
    if (label != null) {
      expect(semantics.label, contains(label));
    }
    if (hint != null) {
      expect(semantics.hint, contains(hint));
    }
    if (value != null) {
      expect(semantics.value, contains(value));
    }
  }
  
  /// Helper to create a Scaffold wrapper for widgets that need it
  static Widget wrapInScaffold(Widget child) {
    return Scaffold(
      body: child,
    );
  }
  
  /// Helper to create a Card wrapper for widgets that need Material ancestor
  static Widget wrapInCard(Widget child) {
    return Card(
      child: child,
    );
  }
}

/// Extension methods for WidgetTester
extension WidgetTesterExtensions on WidgetTester {
  /// Pump widget with BaseWidgetTest app wrapper
  Future<void> pumpTestWidget(
    Widget widget, {
    NavigatorObserver? navigatorObserver,
    Map<String, WidgetBuilder>? routes,
    ThemeData? theme,
  }) async {
    await pumpWidget(
      BaseWidgetTest.createTestApp(
        child: widget,
        navigatorObserver: navigatorObserver,
        routes: routes,
        theme: theme,
      ),
    );
  }
  
  /// Pump widget with Provider support
  Future<void> pumpTestWidgetWithProvider<T extends ChangeNotifier>(
    Widget widget, {
    required T viewModel,
    NavigatorObserver? navigatorObserver,
    Map<String, WidgetBuilder>? routes,
    ThemeData? theme,
  }) async {
    await pumpWidget(
      BaseWidgetTest.createTestAppWithProvider<T>(
        viewModel: viewModel,
        child: widget,
        navigatorObserver: navigatorObserver,
        routes: routes,
        theme: theme,
      ),
    );
  }
}

/// Test entry point for widget test infrastructure validation
/// 
/// This file contains infrastructure classes for widget testing.
/// Individual widget tests import and use these classes.
void main() {
  group('Widget Test Infrastructure Validation', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });
    
    tearDownAll(() async {
      await BaseWidgetTest.teardownWidget();
    });
    
    test('Screen size constants are properly defined', () {
      expect(BaseWidgetTest.phoneSize, equals(const Size(375, 812)));
      expect(BaseWidgetTest.tabletSize, equals(const Size(768, 1024)));
      expect(BaseWidgetTest.desktopSize, equals(const Size(1920, 1080)));
    });
    
    testWidgets('Can create basic test app', (tester) async {
      final testWidget = Container(
        key: const Key('test-container'),
        child: const Text('Test Widget'),
      );
      
      final app = BaseWidgetTest.createTestApp(child: testWidget);
      expect(app, isA<MaterialApp>());
      
      await tester.pumpWidget(app);
      expect(find.text('Test Widget'), findsOneWidget);
      expect(find.byKey(const Key('test-container')), findsOneWidget);
    });
    
    testWidgets('Can create test app with provider', (tester) async {
      final mockViewModel = MockChangeNotifier();
      final testWidget = Container(
        key: const Key('provider-test'),
        child: const Text('Provider Test'),
      );
      
      final app = BaseWidgetTest.createTestAppWithProvider<MockChangeNotifier>(
        viewModel: mockViewModel,
        child: testWidget,
      );
      
      await tester.pumpWidget(app);
      expect(find.text('Provider Test'), findsOneWidget);
      expect(find.byKey(const Key('provider-test')), findsOneWidget);
    });
  });
}

/// Simple mock ChangeNotifier for infrastructure testing
class MockChangeNotifier extends ChangeNotifier {
  // Simple mock implementation for testing infrastructure
}