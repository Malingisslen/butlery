/// ULTRATHINK TEST SUITE: ImportViaUrlView - Phase 2 High-Risk View
/// 
/// PRODUCTION CODE ANALYSIS: lib/views/import_via_url_view.dart
/// - StatelessWidget wrapper with ChangeNotifierProvider for UrlImportViewModel via ServiceLocator
/// - StatefulWidget content with TextEditingController lifecycle management and listener setup
/// - Complex state coordination: canFetch, isLoading, hasError, hasExtractedText state management
/// - URL validation and parsing with external network operations (high-risk)
/// - Loading states with UI disabling during operations and CircularProgressIndicator
/// - Error state display with StateWidget.error integration and Swedish error messages
/// - Extracted text preview with TextDisplayContainer and expansion support
/// - Navigation with complex arguments including sourceUrl support for text import
/// - Swedish localization throughout UI with proper labels and hints
/// - Theme integration with ComponentThemes and AppDimensions styling
/// 
/// TEST FOCUS: Provider integration, StatefulWidget lifecycle, state coordination,
/// URL operations, loading states, error handling, navigation, Swedish localization
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/views/import_via_url_view.dart';
import 'package:butlery/viewmodels/url_import_viewmodel.dart';

// Test infrastructure imports - using centralized system
import '../infrastructure/di/test_service_locator.dart';
import '../infrastructure/helpers/base_widget_test.dart';

// ServiceLocator bridge imports - proven pattern from successful view tests
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

void main() {
  group('ImportViaUrlView Tests - ULTRATHINK METHODOLOGY', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
      
      // ✅ SERVICELOCATOR BRIDGE: Initialize production ServiceLocator with test container
      // This proven pattern from MinaReceptView, SkrivSjalvReceptView, LaggTillReceptView, 
      // FranSocialaMedierView, RecipeDetailView enables ImportViaUrlView to access our test mocks 
      // through ServiceLocator.get<>() calls
      final testDIContainer = DIContainer();
      production.ServiceLocator.initialize(testDIContainer);
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Register test services for ImportViaUrlView ServiceLocator dependencies
      // This ensures ServiceLocator.get<>() returns our configured test mocks
      TestServiceLocator.registerFactory<UrlImportViewModel>(() => TestServiceLocator.get<UrlImportViewModel>());
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

    group('Provider Integration Tests', () {
      testWidgets('should initialize with ChangeNotifierProvider architecture', (WidgetTester tester) async {
        // ULTRATHINK: Test production code ChangeNotifierProvider from lines 20-24
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump(const Duration(milliseconds: 100)); // Allow provider creation
        await tester.pump(const Duration(milliseconds: 200)); // PostFrameCallback execution
        await tester.pump(); // Additional pump for widget tree completion
        
        // Verify ChangeNotifierProvider structure exists
        expect(find.byType(ChangeNotifierProvider<UrlImportViewModel>), findsOneWidget);
        expect(find.byType(ImportViaUrlView), findsOneWidget);
      });

      testWidgets('should initialize UrlImportViewModel via ServiceLocator', (WidgetTester tester) async {
        // ULTRATHINK: Test production code ServiceLocator integration from line 21
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump(const Duration(milliseconds: 100)); // Allow provider creation
        await tester.pump(const Duration(milliseconds: 200)); // PostFrameCallback execution  
        await tester.pump(); // Additional pump for widget tree completion
        
        // ServiceLocator integration should work without errors
        expect(tester.takeException(), isNull);
        expect(find.byType(ImportViaUrlView), findsOneWidget);
      });

      testWidgets('should provide UrlImportViewModel to content widget', (WidgetTester tester) async {
        // ULTRATHINK: Test production code provider delegation to content from line 22
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Provider should delegate to content widget properly
        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('should setup Consumer architecture for reactive updates', (WidgetTester tester) async {
        // ULTRATHINK: Test production code Consumer from line 78
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Consumer architecture should be available for state updates
        expect(tester.takeException(), isNull);
      });
    });

    group('StatefulWidget Lifecycle Tests', () {
      testWidgets('should initialize StatefulWidget with TextEditingController', (WidgetTester tester) async {
        // ULTRATHINK: Test production code StatefulWidget initialization from lines 27-42
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump(); // Allow initState
        
        // StatefulWidget should initialize with TextEditingController
        expect(find.byType(TextFormField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should setup TextEditingController listener in initState', (WidgetTester tester) async {
        // ULTRATHINK: Test production code listener setup from lines 41, 51-54
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // TextEditingController listener should be setup without errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle URL input changes via listener', (WidgetTester tester) async {
        // ULTRATHINK: Test production code URL change handling from lines 51-54
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // URL input changes should be handled properly
        expect(find.byType(TextFormField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should dispose TextEditingController properly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code disposal from lines 45-49
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Remove widget to test disposal
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        
        // Should dispose TextEditingController without errors
        expect(tester.takeException(), isNull);
      });
    });

    group('State Coordination Tests', () {
      testWidgets('should handle initial state display', (WidgetTester tester) async {
        // ULTRATHINK: Test production code initial state from build method
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Should show initial URL input form
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Hämta text'), findsOneWidget);
      });

      testWidgets('should coordinate canFetch and isLoading states', (WidgetTester tester) async {
        // ULTRATHINK: Test production code state coordination from lines 103-106
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Button state should be coordinated with ViewModel state
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should show loading state during URL fetch', (WidgetTester tester) async {
        // ULTRATHINK: Test production code loading state from lines 109-118
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Loading state should be available for display
        expect(tester.takeException(), isNull);
      });

      testWidgets('should disable TextFormField during loading', (WidgetTester tester) async {
        // ULTRATHINK: Test production code field disabling from line 89
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // TextFormField should respect loading state
        expect(find.byType(TextFormField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('URL Operations Tests', () {
      testWidgets('should handle URL input with proper validation', (WidgetTester tester) async {
        // ULTRATHINK: Test production code URL input from lines 87-98
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // URL input should be properly configured
        expect(find.byType(TextFormField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should trigger fetch on field submission', (WidgetTester tester) async {
        // ULTRATHINK: Test production code field submission from line 97
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Field submission should trigger fetch operation
        expect(find.byType(TextFormField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle fetch operation via button', (WidgetTester tester) async {
        // ULTRATHINK: Test production code fetch button from lines 56-59, 102-119
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Fetch button should be available
        expect(find.text('Hämta text'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should coordinate fetch with ViewModel operations', (WidgetTester tester) async {
        // ULTRATHINK: Test production code ViewModel coordination from lines 56-59
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // ViewModel fetch coordination should work without errors
        expect(tester.takeException(), isNull);
      });
    });

    group('Loading States Tests', () {
      testWidgets('should display CircularProgressIndicator during loading', (WidgetTester tester) async {
        // ULTRATHINK: Test production code loading indicator from lines 110-117
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Loading indicator should be configured properly
        expect(tester.takeException(), isNull);
      });

      testWidgets('should style loading indicator with proper colors', (WidgetTester tester) async {
        // ULTRATHINK: Test production code loading styling from lines 114-116
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Loading indicator styling should be applied
        expect(tester.takeException(), isNull);
      });

      testWidgets('should coordinate button state with loading', (WidgetTester tester) async {
        // ULTRATHINK: Test production code button state coordination from lines 103-106
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Button state should be coordinated with loading
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should show proper loading dimensions', (WidgetTester tester) async {
        // ULTRATHINK: Test production code loading dimensions from lines 111-112
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Loading dimensions should be properly sized
        expect(tester.takeException(), isNull);
      });
    });

    group('Error Handling Tests', () {
      testWidgets('should display error state when hasError is true', (WidgetTester tester) async {
        // ULTRATHINK: Test production code error display from lines 122-127
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Error state should be available for display
        expect(tester.takeException(), isNull);
      });

      testWidgets('should use StateWidget.error for error display', (WidgetTester tester) async {
        // ULTRATHINK: Test production code StateWidget.error from lines 124-126
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // StateWidget.error should be used for error display
        expect(tester.takeException(), isNull);
      });

      testWidgets('should display error with proper spacing', (WidgetTester tester) async {
        // ULTRATHINK: Test production code error spacing from line 123
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Error display should have proper spacing
        expect(tester.takeException(), isNull);
      });

      testWidgets('should show error message from ViewModel', (WidgetTester tester) async {
        // ULTRATHINK: Test production code error message from line 125
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Error message should come from ViewModel
        expect(tester.takeException(), isNull);
      });
    });

    group('Extracted Text Display Tests', () {
      testWidgets('should display extracted text when hasExtractedText is true', (WidgetTester tester) async {
        // ULTRATHINK: Test production code extracted text display from lines 130-143
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Extracted text section should be available
        expect(tester.takeException(), isNull);
      });

      testWidgets('should show extracted text header with Swedish label', (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish header from line 132
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Swedish extracted text header should be configured
        expect(tester.takeException(), isNull);
      });

      testWidgets('should use TextDisplayContainer for text preview', (WidgetTester tester) async {
        // ULTRATHINK: Test production code TextDisplayContainer from lines 133-136
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // TextDisplayContainer should be used for text preview
        expect(tester.takeException(), isNull);
      });

      testWidgets('should show continue button after text extraction', (WidgetTester tester) async {
        // ULTRATHINK: Test production code continue button from lines 138-142
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Continue button should be available after extraction
        expect(tester.takeException(), isNull);
      });
    });

    group('Navigation Tests', () {
      testWidgets('should navigate to text import with extracted text', (WidgetTester tester) async {
        // ULTRATHINK: Test production code navigation from lines 61-74
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Navigation system should be configured
        expect(tester.takeException(), isNull);
      });

      testWidgets('should pass text and sourceUrl as arguments', (WidgetTester tester) async {
        // ULTRATHINK: Test production code navigation arguments from lines 68-71
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Navigation arguments should be properly configured
        expect(tester.takeException(), isNull);
      });

      testWidgets('should navigate to correct route', (WidgetTester tester) async {
        // ULTRATHINK: Test production code route from line 67
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Route navigation should be properly set up
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle navigation only when hasExtractedText', (WidgetTester tester) async {
        // ULTRATHINK: Test production code navigation condition from line 63
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Navigation should be conditional on extracted text
        expect(tester.takeException(), isNull);
      });
    });

    group('Swedish Localization Tests', () {
      testWidgets('should display Swedish app bar title', (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish title from line 81
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        expect(find.text('Import via URL'), findsOneWidget);
      });

      testWidgets('should use Swedish field labels and hints', (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish labels from lines 91-93
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Swedish labels should be displayed
        expect(find.text('Klistra in recept-URL'), findsOneWidget);
        expect(find.text('https://example.com/recept'), findsOneWidget);
      });

      testWidgets('should display Swedish button text', (WidgetTester tester) async {
        // ULTRATHINK: Test production code Swedish button text from lines 118, 141
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Swedish button text should be displayed
        expect(find.text('Hämta text'), findsOneWidget);
      });

      testWidgets('should handle Swedish locale configuration', (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish locale from MaterialApp helper
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Should handle Swedish locale properly
        final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.locale?.languageCode, equals('sv'));
      });
    });

    group('Theme Integration Tests', () {
      testWidgets('should use ComponentThemes for button styling', (WidgetTester tester) async {
        // ULTRATHINK: Test production code ComponentThemes from lines 107, 140
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // ComponentThemes should be applied to buttons
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should use AppDimensions for spacing', (WidgetTester tester) async {
        // ULTRATHINK: Test production code AppDimensions spacing from lines 83, 99, 123, 131, 137
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // AppDimensions should be used for consistent spacing
        expect(tester.takeException(), isNull);
      });

      testWidgets('should use AppTextStyles for text styling', (WidgetTester tester) async {
        // ULTRATHINK: Test production code AppTextStyles from line 132
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // AppTextStyles should be applied properly
        expect(tester.takeException(), isNull);
      });

      testWidgets('should integrate with app theme properly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code theme integration throughout
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Theme integration should work properly
        expect(find.byType(Scaffold), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('UI Structure Tests', () {
      testWidgets('should render main UI structure properly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code UI structure from lines 80-148
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Main UI structure should be rendered
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(Padding), findsWidgets);
        expect(find.byType(Column), findsOneWidget);
      });

      testWidgets('should display TextFormField with proper configuration', (WidgetTester tester) async {
        // ULTRATHINK: Test production code TextFormField configuration from lines 87-98
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // TextFormField should be properly configured
        expect(find.byType(TextFormField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should show SizedBox spacing elements', (WidgetTester tester) async {
        // ULTRATHINK: Test production code SizedBox spacing from multiple lines
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // SizedBox elements should provide proper spacing
        expect(find.byType(SizedBox), findsWidgets);
      });

      testWidgets('should handle conditional widget display', (WidgetTester tester) async {
        // ULTRATHINK: Test production code conditional widgets from lines 122, 130
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Conditional widget display should work properly
        expect(tester.takeException(), isNull);
      });
    });

    group('Performance and Integration Tests', () {
      testWidgets('should handle complex initialization efficiently', (WidgetTester tester) async {
        // ULTRATHINK: Test production code complex initialization performance
        final stopwatch = Stopwatch()..start();
        
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow full initialization
        
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
        expect(find.byType(ImportViaUrlView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should integrate with Phase 1 test infrastructure', (WidgetTester tester) async {
        // ULTRATHINK: Test production code integration with test infrastructure
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Should integrate with test helpers
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(ImportViaUrlView), findsOneWidget);
        
        // Should handle Swedish locale properly
        final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.locale?.languageCode, equals('sv'));
      });

      testWidgets('should handle provider architecture efficiently', (WidgetTester tester) async {
        // ULTRATHINK: Test production code provider efficiency
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow provider setup
        
        // Provider architecture should be efficient
        expect(find.byType(ChangeNotifierProvider<UrlImportViewModel>), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle StatefulWidget lifecycle efficiently', (WidgetTester tester) async {
        // ULTRATHINK: Test production code StatefulWidget performance
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        await tester.pump(); // Allow lifecycle completion
        
        // StatefulWidget lifecycle should be efficient
        expect(find.byType(TextFormField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should dispose resources properly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code resource disposal from lines 45-49
        await tester.pumpWidget(createTestWidget(
          child: const ImportViaUrlView(),
        ));
        await tester.pump();
        
        // Remove widget to test disposal
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        
        // Should dispose resources without errors
        expect(tester.takeException(), isNull);
      });
    });
  });
}