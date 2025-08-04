import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'test_service_locator.dart';

/// Creates a fully configured testable widget with all necessary wrappers
Widget createTestableWidget({
  required Widget child,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode? themeMode,
  List<NavigatorObserver>? navigatorObservers,
  GoRouter? router,
  Locale? locale,
  List<ChangeNotifierProvider>? providers,
  List<Provider>? additionalProviders,
  Size? surfaceSize,
  double? textScaleFactor,
  Brightness? platformBrightness,
  EdgeInsets? viewInsets,
  EdgeInsets? viewPadding,
  EdgeInsets? systemGestureInsets,
}) {
  // Build the widget with providers if specified
  Widget app = child;

  // Wrap with individual providers
  if (providers != null) {
    for (final provider in providers) {
      app = provider;
    }
  }

  // Wrap with additional providers
  if (additionalProviders != null) {
    app = MultiProvider(
      providers: additionalProviders,
      child: app,
    );
  }

  // Apply MediaQuery overrides if specified
  if (surfaceSize != null ||
      textScaleFactor != null ||
      platformBrightness != null ||
      viewInsets != null ||
      viewPadding != null ||
      systemGestureInsets != null) {
    app = MediaQuery(
      data: MediaQueryData(
        size: surfaceSize ?? const Size(375, 812), // iPhone X default
        textScaler: textScaleFactor != null
            ? TextScaler.linear(textScaleFactor)
            : TextScaler.noScaling,
        platformBrightness: platformBrightness ?? Brightness.light,
        viewInsets: viewInsets ?? EdgeInsets.zero,
        viewPadding: viewPadding ?? EdgeInsets.zero,
        systemGestureInsets: systemGestureInsets ?? EdgeInsets.zero,
      ),
      child: app,
    );
  }

  // Use router if provided, otherwise wrap in MaterialApp
  if (router != null) {
    return MaterialApp.router(
      routerConfig: router,
      theme: theme ?? ThemeData.light(),
      darkTheme: darkTheme,
      themeMode: themeMode ?? ThemeMode.light,
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('sv', 'SE'),
        Locale('en', 'US'),
      ],
      debugShowCheckedModeBanner: false,
    );
  }

  return MaterialApp(
    theme: theme ?? ThemeData.light(),
    darkTheme: darkTheme,
    themeMode: themeMode ?? ThemeMode.light,
    home: Scaffold(body: app),
    navigatorObservers: navigatorObservers ?? [],
    locale: locale,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('sv', 'SE'),
      Locale('en', 'US'),
    ],
    debugShowCheckedModeBanner: false,
  );
}

/// Creates a testable widget with ApplicationProvider configured
Widget createTestableWidgetWithProvider({
  required Widget child,
  MockDIContainer? container,
  MockApplicationBootstrap? bootstrap,
  ThemeData? theme,
  GoRouter? router,
  Locale? locale,
}) {
  // Initialize test service locator if not already done
  if (container == null) {
    TestServiceLocator.initialize();
  }

  return ApplicationProvider(
    container: container ?? TestServiceLocator.container,
    bootstrap: bootstrap ?? MockApplicationBootstrap(),
    child: createTestableWidget(
      child: child,
      theme: theme,
      router: router,
      locale: locale,
    ),
  );
}

/// Helper to pump widget with proper async handling
Future<void> pumpWidgetWithSetup(
  WidgetTester tester,
  Widget widget, {
  Duration? duration,
  EnginePhase phase = EnginePhase.sendSemanticsUpdate,
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(widget);
    if (duration != null) {
      await tester.pump(duration);
    }
    await tester.pumpAndSettle();
  });
}

/// Custom finder helpers for common assertions
Finder hasText(String text) => find.text(text);
Finder hasIcon(IconData icon) => find.byIcon(icon);
Finder hasType<T>() => find.byType(T);
Finder hasKey(Key key) => find.byKey(key);

/// Matcher for widgets with specific semantics
Matcher hasSemantics({
  String? label,
  String? hint,
  String? value,
  bool? isButton,
  bool? isEnabled,
  bool? isFocused,
  bool? isTextField,
}) {
  return predicate<SemanticsNode>((semantics) {
    if (label != null && semantics.label != label) return false;
    if (hint != null && semantics.hint != hint) return false;
    if (value != null && semantics.value != value) return false;
    if (isButton != null &&
        semantics.hasFlag(SemanticsFlag.isButton) != isButton) {
      return false;
    }
    if (isEnabled != null &&
        semantics.hasFlag(SemanticsFlag.hasEnabledState) != isEnabled) {
      return false;
    }
    if (isFocused != null &&
        semantics.hasFlag(SemanticsFlag.isFocused) != isFocused) {
      return false;
    }
    if (isTextField != null &&
        semantics.hasFlag(SemanticsFlag.isTextField) != isTextField) {
      return false;
    }
    return true;
  });
}

/// Helper for testing async operations
Future<void> testAsync<T>(
  String description,
  Future<void> Function() test, {
  Duration timeout = const Duration(seconds: 30),
  bool skip = false,
}) async {
  return testWidgets(
    description,
    (tester) async {
      await tester.runAsync(test);
    },
    timeout: Timeout(timeout),
    skip: skip,
  );
}

/// Helper for golden test scenarios
class GoldenTestHelper {
  static Future<void> testGolden(
    WidgetTester tester,
    String name,
    Widget widget, {
    Size? surfaceSize,
    double? textScaleFactor,
  }) async {
    if (surfaceSize != null) {
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 2.0;
    }

    await pumpWidgetWithSetup(
      tester,
      createTestableWidget(
        child: widget,
        surfaceSize: surfaceSize,
        textScaleFactor: textScaleFactor,
      ),
    );

    await expectLater(
      find.byWidget(widget),
      matchesGoldenFile('goldens/$name.png'),
    );

    if (surfaceSize != null) {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  }
}

/// Helper for navigation testing
class NavigationTestHelper {
  static final mockGoRouter = MockGoRouter();

  static GoRouter createTestRouter({
    required String initialLocation,
    required List<RouteBase> routes,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: routes,
      errorBuilder: (context, state) => const Scaffold(
        body: Center(child: Text('Route Error')),
      ),
    );
  }

  static void expectNavigatedTo(String location) {
    verify(() => mockGoRouter.go(location)).called(1);
  }

  static void expectNotNavigated() {
    verifyNever(() => mockGoRouter.go(any()));
  }
}

/// Helper for gesture testing
class GestureTestHelper {
  static Future<void> performSwipe(
    WidgetTester tester,
    Finder finder, {
    required Offset from,
    required Offset to,
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    final center = tester.getCenter(finder);
    final startLocation = center + from;
    final endLocation = center + to;

    final gesture = await tester.startGesture(startLocation);
    await gesture.moveTo(endLocation, timeStamp: duration);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  static Future<void> performLongPress(
    WidgetTester tester,
    Finder finder, {
    Duration duration = const Duration(seconds: 1),
  }) async {
    final center = tester.getCenter(finder);
    final gesture = await tester.startGesture(center);
    await tester.pump(duration);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  static Future<void> performDoubleTap(
    WidgetTester tester,
    Finder finder,
  ) async {
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

/// Helper for platform-specific testing
class PlatformTestHelper {
  static void runOnPlatform(
    TargetPlatform platform,
    VoidCallback test,
  ) {
    debugDefaultTargetPlatformOverride = platform;
    test();
    debugDefaultTargetPlatformOverride = null;
  }

  static void testOnAllPlatforms(
    String description,
    Future<void> Function(WidgetTester tester, TargetPlatform platform) test,
  ) {
    for (final platform in TargetPlatform.values) {
      testWidgets(
        '$description on ${platform.name}',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          await test(tester, platform);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
}

/// Helper for animation testing
class AnimationTestHelper {
  static Future<void> testAnimation(
    WidgetTester tester, {
    required Duration duration,
    required List<Duration> checkpoints,
    required Future<void> Function(WidgetTester) verify,
  }) async {
    for (final checkpoint in checkpoints) {
      await tester.pump(checkpoint);
      await verify(tester);
    }
    await tester.pumpAndSettle();
  }

  static Future<void> skipToEndOfAnimation(
    WidgetTester tester,
    Duration animationDuration,
  ) async {
    await tester.pump(animationDuration);
    await tester.pumpAndSettle();
  }
}

/// Helper for error and exception testing
class ErrorTestHelper {
  static void expectErrorWidget(WidgetTester tester, {String? containing}) {
    final errorWidgets = find.byType(ErrorWidget);
    expect(errorWidgets, findsOneWidget);

    if (containing != null) {
      expect(
        tester.widget<ErrorWidget>(errorWidgets).message,
        contains(containing),
      );
    }
  }

  static Future<void> testErrorHandling(
    WidgetTester tester,
    Future<void> Function() triggerError,
    void Function() verifyError,
  ) async {
    await tester.runAsync(() async {
      try {
        await triggerError();
      } catch (e) {
        // Expected error
      }
    });
    await tester.pumpAndSettle();
    verifyError();
  }
}

/// Helper for focus testing
class FocusTestHelper {
  static bool hasFocus(WidgetTester tester, Finder finder) {
    final FocusNode? focusNode = Focus.maybeOf(
      tester.element(finder),
      scopeOk: true,
    );
    return focusNode?.hasFocus ?? false;
  }

  static Future<void> ensureFocus(
    WidgetTester tester,
    Finder finder,
  ) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(hasFocus(tester, finder), isTrue);
  }

  static Future<void> moveFocus(
    WidgetTester tester, {
    bool forward = true,
  }) async {
    await tester.sendKeyEvent(
      forward ? LogicalKeyboardKey.tab : LogicalKeyboardKey.tab,
      platform: 'android',
    );
    await tester.pumpAndSettle();
  }
}

/// Test lifecycle helpers
class TestLifecycleHelper {
  static final List<VoidCallback> _tearDownCallbacks = [];

  static void addTearDown(VoidCallback callback) {
    _tearDownCallbacks.add(callback);
    addTearDown(() {
      callback();
      _tearDownCallbacks.remove(callback);
    });
  }

  static Future<void> setupTestEnvironment() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestServiceLocator.initialize();

    // Set up test defaults
    debugDisableShadows = true;
  }

  static Future<void> tearDownTestEnvironment() async {
    TestServiceLocator.dispose();
    for (final callback in _tearDownCallbacks) {
      callback();
    }
    _tearDownCallbacks.clear();
  }
}

/// Mock classes
class MockGoRouter extends Mock implements GoRouter {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}
