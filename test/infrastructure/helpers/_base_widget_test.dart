/// Base class for widget tests with Flutter-specific utilities
/// 
/// Extends BaseTest with widget test specific functionality including
/// widget wrapping, theme injection, and interaction helpers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '_base_test.dart';

/// Base class for all widget tests
/// 
/// Provides:
/// - Automatic widget wrapping with MaterialApp
/// - Theme and localization support
/// - Provider injection helpers
/// - Common widget test patterns
abstract class BaseWidgetTest extends BaseTest {
  /// Default test viewport size (iPhone 14 Pro)
  static const Size defaultTestSize = Size(393, 852);
  
  /// Enhanced setup for widget tests
  static Future<void> setupWidget() async {
    await BaseTest.setup();
    // Set default test viewport size
    TestWidgetsFlutterBinding.ensureInitialized();
  }
  
  /// Enhanced teardown for widget tests
  static Future<void> teardownWidget() async {
    await BaseTest.teardown();
  }
  
  /// Run a widget test with automatic setup
  static void testWidget(
    String description,
    Future<void> Function(WidgetTester) body, {
    bool skip = false,
    Timeout? timeout,
    dynamic tags,
    Size? viewSize,
  }) {
    testWidgets(
      description,
      (WidgetTester tester) async {
        await setupWidget();
        
        // Set viewport size if specified
        if (viewSize != null) {
          await tester.binding.setSurfaceSize(viewSize);
        }
        
        try {
          await body(tester);
        } finally {
          await teardownWidget();
        }
      },
      skip: skip,
      timeout: timeout,
      tags: tags,
    );
  }
  
  /// Run a widget test group with automatic setup
  static void groupWidget(
    String description,
    void Function() body, {
    bool skip = false,
  }) {
    group(description, () {
      setUpAll(() async {
        await setupWidget();
      });
      
      tearDownAll(() async {
        await BaseTest.reset();
      });
      
      body();
    }, skip: skip);
  }
  
  /// Wrap a widget with MaterialApp and common requirements
  static Widget wrapWidget(
    Widget widget, {
    ThemeData? theme,
    ThemeData? darkTheme,
    ThemeMode? themeMode,
    Locale? locale,
    List<NavigatorObserver>? navigatorObservers,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: widget,
      ),
      theme: theme ?? _getDefaultTheme(),
      darkTheme: darkTheme,
      themeMode: themeMode ?? ThemeMode.light,
      locale: locale ?? const Locale('sv', 'SE'), // Swedish default
      navigatorObservers: navigatorObservers ?? [],
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
    );
  }
  
  /// Wrap a widget with providers
  static Widget wrapWithProviders(
    Widget widget, {
    required List<Provider> providers,
    ThemeData? theme,
    Locale? locale,
  }) {
    return MultiProvider(
      providers: providers,
      child: wrapWidget(widget, theme: theme, locale: locale),
    );
  }
  
  /// Get default theme for tests
  static ThemeData _getDefaultTheme() {
    return ThemeData(
      primarySwatch: Colors.orange,
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }
}

/// Helper utilities for widget tests
/// 
/// These utilities can be used directly in tests following the AAA pattern:
/// - Arrange: Set up test data and mocks
/// - Act: Execute the test action
/// - Assert: Verify the results
class WidgetTestHelpers {
  /// Pump a widget wrapped with MaterialApp
  static Future<void> pumpWidget(
    WidgetTester tester,
    Widget widget, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      BaseWidgetTest.wrapWidget(widget, theme: theme),
    );
  }
  
  /// Pump a widget with providers
  static Future<void> pumpWithProviders(
    WidgetTester tester,
    Widget widget, {
    required List<Provider> providers,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      BaseWidgetTest.wrapWithProviders(
        widget,
        providers: providers,
        theme: theme,
      ),
    );
  }
  
  /// Pump and settle with timeout
  static Future<void> pumpAndSettleWithTimeout(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  }
  
  /// Find and tap a widget
  static Future<void> findAndTap(
    WidgetTester tester,
    Finder finder,
  ) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
  
  /// Enter text in a text field
  static Future<void> enterText(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }
  
  /// Scroll until a widget is visible
  static Future<void> scrollUntilVisible(
    WidgetTester tester,
    Finder finder, {
    double delta = -100,
    Finder? scrollable,
    int maxScrolls = 50,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: scrollable,
      maxScrolls: maxScrolls,
    );
  }
}

/// Extension methods for WidgetTester
extension WidgetTesterExtensions on WidgetTester {
  /// Pump a test widget with standard wrapping
  Future<void> pumpTestWidget(Widget widget, {ThemeData? theme}) async {
    await pumpWidget(
      BaseWidgetTest.wrapWidget(widget, theme: theme),
    );
  }
  
  /// Pump until a finder is found or timeout
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);
    
    do {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      await pump(const Duration(milliseconds: 100));
    } while (DateTime.now().isBefore(end));
    
    throw TestFailure('Could not find widget within timeout');
  }
  
  /// Pump until a condition is met
  Future<void> pumpUntil(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);
    
    do {
      if (condition()) {
        return;
      }
      await pump(const Duration(milliseconds: 100));
    } while (DateTime.now().isBefore(end));
    
    throw TestFailure('Condition not met within timeout');
  }
  
  /// Get the render object of a widget
  T getRenderObject<T extends RenderObject>(Finder finder) {
    return renderObject(finder) as T;
  }
  
  /// Check if a widget is visible
  bool isVisible(Finder finder) {
    try {
      final Element element = finder.evaluate().single;
      final RenderBox renderBox = element.renderObject as RenderBox;
      return renderBox.hasSize && renderBox.size.height > 0 && renderBox.size.width > 0;
    } catch (_) {
      return false;
    }
  }
}

/// Common finders for widget tests
class WidgetTestFinders {
  /// Find by semantic label
  static Finder bySemanticLabel(String label) {
    return find.bySemanticsLabel(label);
  }
  
  /// Find IconButton by icon
  static Finder iconButton(IconData icon) {
    return find.widgetWithIcon(IconButton, icon);
  }
  
  /// Find by tooltip
  static Finder byTooltip(String tooltip) {
    return find.byTooltip(tooltip);
  }
  
  /// Find TextField with specific label
  static Finder textFieldWithLabel(String label) {
    return find.widgetWithText(TextField, label);
  }
  
  /// Find widget with specific text
  static Finder widgetWithText(Type widgetType, String text) {
    return find.widgetWithText(widgetType, text);
  }
}