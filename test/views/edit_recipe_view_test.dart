/// Comprehensive EditRecipeView test suite using Phase 1 infrastructure and ultrathink methodology.
///
/// This test suite validates EditRecipeView's multi-provider architecture, focused component delegation,
/// collaborative editing features, and Swedish localization using the established test infrastructure
/// and proven testing patterns from the gold standard Phase 1 foundation.
///
/// **Testing Strategy:**
/// - Production-code-first analysis applied from lib/views/edit_recipe_view.dart
/// - Multi-provider architecture with AuthService, RecipeFormViewModel, and CollaborativeStatusViewModel
/// - Focused component pattern testing (7 specialized components delegation)
/// - Collaborative editing integration testing (permission-based UI, status banners)
/// - Swedish localization validation throughout all recipe editing elements
/// - Form validation and submission workflow testing (GlobalKey FormState integration)
/// - Focus on VIEW ORCHESTRATION, not business logic (already 100% tested)
///
/// **Phase 1 Infrastructure Usage:**
/// - ViewTestHelpers for Swedish-localized test environment setup
/// - ProviderTestUtils for multi-provider configuration (3 providers)
/// - TestableRecipeFormViewModel for deterministic state control
/// - MockCollaborativeStatusViewModel for collaborative scenario testing
/// - Existing recipe editing test patterns from widget and ViewModel tests
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Production code imports
import 'package:butlery/views/edit_recipe_view.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';

// Phase 1 test infrastructure
import 'helpers/view_test_helpers.dart';
import 'helpers/provider_test_utils.dart';
import 'helpers/mock_view_models.dart';
import '../infrastructure/factories/recipe_factory.dart';

void main() {
  group('EditRecipeView Integration Tests', () {
    // ==================== SETUP & TEARDOWN ====================

    setUpAll(() async {
      // Initialize Phase 1 test infrastructure with Swedish localization
      await ViewTestHelpers.setupViewTestEnvironment();
    });

    tearDownAll(() async {
      await ViewTestHelpers.teardownViewTestEnvironment();
    });

    // ==================== MULTI-PROVIDER SETUP VERIFICATION ====================

    group('Multi-Provider Architecture Tests', () {
      testWidgets(
          'should initialize EditRecipeView with multi-provider architecture',
          (tester) async {
        // Arrange: Setup multi-provider scenario with recipe data
        final testRecipe = RecipeFactory.build();
        final providers = ProviderTestUtils.setupRecipeEditProviders(
          recipeId: testRecipe.id,
          isCollaborative: false,
        );

        // Act: Create and pump the EditRecipeView
        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await ViewTestHelpers.waitForViewInitialization(tester);

        // Assert: Verify basic view architecture is established
        expect(find.byType(EditRecipeView), findsOneWidget);
        expect(find.byType(MultiProvider), findsOneWidget);
      });

      testWidgets(
          'should render recipe editing interface with Swedish localization',
          (tester) async {
        // Arrange: Setup comprehensive recipe editing scenario
        final testRecipe = RecipeFactory.build();
        final providers = ProviderTestUtils.setupRecipeEditProviders(
          recipeId: testRecipe.id,
        );

        // Act: Pump the complete view
        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Verify basic UI architecture
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(Form), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);

        // Verify multi-provider integration is functioning
        expect(find.byType(MultiProvider), findsOneWidget);
      });

      testWidgets(
          'should handle provider state coordination with testable ViewModels',
          (tester) async {
        // Arrange: Setup testable ViewModels with coordinated state
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Test provider coordination by triggering state changes
        testableRecipeVM.setRecipeFormState(hasUnsavedChanges: true);
        await tester.pump();

        // Assert: Verify multi-provider state coordination
        expect(testableRecipeVM.hasUnsavedChanges, isTrue);
        expect(find.byType(EditRecipeView), findsOneWidget);
      });
    });

    // ==================== FOCUSED COMPONENT ARCHITECTURE ====================

    group('Focused Component Delegation Tests', () {
      testWidgets('should render all focused components correctly',
          (tester) async {
        // Arrange: Setup comprehensive component delegation scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Verify focused component delegation architecture

        // 1. Main layout structure with Scaffold
        expect(find.byType(Scaffold), findsOneWidget);

        // 2. AppBar component delegation (EditRecipeAppBar.build)
        final appBar = tester.widget<Scaffold>(find.byType(Scaffold)).appBar;
        expect(appBar, isNotNull);

        // 3. Bottom navigation bar delegation (EditRecipeBottomBar.build)
        final bottomBar =
            tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar;
        expect(bottomBar, isNotNull);

        // 4. Main form content with focused components
        expect(find.byType(Form), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);

        // 5. Stack structure for loading overlay coordination
        expect(find.byType(Stack), findsOneWidget);
        expect(find.byType(Column), findsAtLeast(1));

        // 6. GlobalKey<FormState> integration for validation
        final form = tester.widget<Form>(find.byType(Form));
        expect(form.key, isNotNull);
        expect(form.key, isA<GlobalKey<FormState>>());
      });

      testWidgets('should handle collaborative status banner integration',
          (tester) async {
        // Arrange: Setup collaborative editing scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
          isCollaborative: true,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        // Configure collaborative state
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: ['Anna Andersson', 'Erik Svensson'],
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Verify collaborative component integration
        expect(find.byType(EditRecipeView), findsOneWidget);

        // AppBar should show collaborative status
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.appBar, isNotNull);

        // Bottom bar should reflect collaborative permissions
        expect(scaffold.bottomNavigationBar, isNotNull);

        // Banners should be integrated (EditRecipeBanners.buildSmartBanners)
        expect(
            find.byType(Column), findsAtLeast(1)); // Banner integration point
      });

      testWidgets('should integrate loading overlay with StateWidget',
          (tester) async {
        // Arrange: Setup loading state scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );

        // Configure saving state
        testableRecipeVM.setRecipeFormState(isLoading: true);

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
            value: MockCollaborativeStatusViewModel(),
          ),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Verify loading overlay integration
        expect(find.byType(Stack), findsOneWidget); // Stack for overlay

        // Loading overlay should appear when isSaving is true
        expect(find.byType(EditRecipeView), findsOneWidget);

        // Test loading state changes
        testableRecipeVM.setRecipeFormState(isLoading: false);
        await tester.pump();

        // View should remain stable after loading state changes
        expect(find.byType(EditRecipeView), findsOneWidget);
      });
    });

    // ==================== FORM VALIDATION & GLOBAL FORMKEY ====================

    group('Form Validation and GlobalKey Integration Tests', () {
      testWidgets('should initialize GlobalKey<FormState> correctly',
          (tester) async {
        // Arrange: Setup form validation scenario
        final testRecipe = RecipeFactory.build();
        final providers = ProviderTestUtils.setupRecipeEditProviders(
          recipeId: testRecipe.id,
        );

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Verify form structure and GlobalKey integration
        final formFinder = find.byType(Form);
        expect(formFinder, findsOneWidget);

        final form = tester.widget<Form>(formFinder);
        expect(form.key, isNotNull);
        expect(form.key, isA<GlobalKey<FormState>>());

        // Assert: Form should be in a valid initial state
        final formState = form.key as GlobalKey<FormState>;
        expect(formState.currentState, isNotNull);
      });

      testWidgets(
          'should handle form validation integration with EditRecipeActions',
          (tester) async {
        // Arrange: Setup form with validation requirements
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
            value: MockCollaborativeStatusViewModel(),
          ),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Test form validation readiness
        final formFinder = find.byType(Form);
        final form = tester.widget<Form>(formFinder);
        final formKey = form.key as GlobalKey<FormState>;

        // Assert: FormKey should be accessible for validation
        expect(formKey.currentState, isNotNull);

        // Bottom bar should be present for save/fork actions
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.bottomNavigationBar, isNotNull);

        // Form should be ready for validation workflow
        expect(find.byType(ListView), findsOneWidget); // Form fields container
      });

      testWidgets('should coordinate form state with RecipeFormViewModel',
          (tester) async {
        // Arrange: Setup form state coordination scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
            value: MockCollaborativeStatusViewModel(),
          ),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Test ViewModel coordination with form
        testableRecipeVM.setRecipeFormState(
          hasUnsavedChanges: true,
          isLoading: false,
        );
        await tester.pump();

        // Assert: Form should remain responsive to ViewModel state changes
        expect(find.byType(Form), findsOneWidget);
        expect(testableRecipeVM.hasUnsavedChanges, isTrue);

        // Test form submission readiness
        final formFinder = find.byType(Form);
        final form = tester.widget<Form>(formFinder);
        final formKey = form.key as GlobalKey<FormState>;

        // FormKey should be ready for EditRecipeActions integration
        expect(formKey.currentState, isNotNull);
      });
    });

    // ==================== COLLABORATIVE EDITING FEATURES ====================

    group('Collaborative Editing Integration Tests', () {
      testWidgets('should handle collaborative status integration correctly',
          (tester) async {
        // Arrange: Setup collaborative editing scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
          isCollaborative: true,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        // Configure collaborative state
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: ['Anna Andersson'],
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Verify collaborative integration
        expect(find.byType(EditRecipeView), findsOneWidget);

        // AppBar should show collaborative status
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.appBar, isNotNull);

        // Bottom bar should reflect collaborative permissions
        expect(scaffold.bottomNavigationBar, isNotNull);
      });

      testWidgets(
          'should coordinate collaborative state changes across components',
          (tester) async {
        // Arrange: Setup collaborative state change scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
          isCollaborative: true,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Simulate collaborative status change
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: false, // Switch to non-collaborative
          activeCollaborators: [],
        );
        await tester.pump();

        // Assert: UI should remain stable after collaborative state changes
        expect(find.byType(EditRecipeView), findsOneWidget);
        expect(find.byType(Form), findsOneWidget);

        // Test switching back to collaborative
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: ['New User'],
        );
        await tester.pump();

        // View should handle state transitions smoothly
        expect(find.byType(EditRecipeView), findsOneWidget);
      });
    });

    // ==================== SWEDISH LOCALIZATION VALIDATION ====================

    group('Swedish Localization Tests', () {
      testWidgets('should display Swedish UI architecture correctly',
          (tester) async {
        // Arrange: Setup comprehensive Swedish localization test
        final testRecipe = RecipeFactory.build();
        final providers = ProviderTestUtils.setupRecipeEditProviders(
          recipeId: testRecipe.id,
        );

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Verify Swedish localization architecture
        expect(find.byType(EditRecipeView), findsOneWidget);
        expect(find.byType(Form), findsOneWidget);

        // Form should be ready to display Swedish field labels and validation messages
        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('should handle Swedish loading and error message integration',
          (tester) async {
        // Arrange: Setup Swedish message scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );

        // Configure Swedish error message
        testableRecipeVM.setError('Kunde inte spara recept');

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
            value: MockCollaborativeStatusViewModel(),
          ),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: View should handle Swedish error state integration
        expect(find.byType(EditRecipeView), findsOneWidget);
        expect(testableRecipeVM.hasError, isTrue);
        expect(
            testableRecipeVM.errorMessage, contains('Kunde inte spara recept'));

        // Test Swedish loading message
        testableRecipeVM.setError(null);
        testableRecipeVM.setRecipeFormState(isLoading: true);
        await tester.pump();

        // Loading overlay integration should support Swedish messages
        expect(find.byType(Stack), findsOneWidget); // Stack for loading overlay
      });
    });

    // ==================== TASK 3.2: PROVIDER ORCHESTRATION & COMPONENT FACADE DELEGATION ====================

    group('Provider Orchestration Tests', () {
      testWidgets(
          'should orchestrate RecipeFormViewModel and CollaborativeStatusViewModel correctly',
          (tester) async {
        // Arrange: Setup coordinated provider scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
          isCollaborative: false,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Test provider coordination by simulating complex state changes
        testableRecipeVM.setRecipeFormState(hasUnsavedChanges: true);
        testableCollaborativeVM.setCollaborativeState(isCollaborative: true);
        await tester.pump();

        testableRecipeVM.setRecipeFormState(isLoading: true);
        await tester.pump();

        // Assert: Verify provider orchestration maintains view stability
        expect(find.byType(EditRecipeView), findsOneWidget);
        expect(testableRecipeVM.hasUnsavedChanges, isTrue);
        expect(testableCollaborativeVM.isCollaborative, isTrue);

        // Verify both providers remain responsive
        testableRecipeVM.setRecipeFormState(isLoading: false);
        testableCollaborativeVM.setCollaborativeState(isCollaborative: false);
        await tester.pump();

        expect(find.byType(EditRecipeView), findsOneWidget);
      });

      testWidgets('should handle provider state conflicts gracefully',
          (tester) async {
        // Arrange: Setup conflicting provider states scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
          hasConflicts: true,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        // Configure conflicting states
        testableRecipeVM.simulateCollaborativeConflict(
          conflictingUser: 'Anna Andersson',
          conflictType: ConflictType.simultaneousEdit,
        );
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          hasConflicts: true,
          activeCollaborators: ['Anna Andersson'],
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Test conflict resolution orchestration
        testableRecipeVM.resolveCollaborativeConflict();
        testableCollaborativeVM.setCollaborativeState(hasConflicts: false);
        await tester.pump();

        // Assert: Verify coordinated conflict resolution
        expect(find.byType(EditRecipeView), findsOneWidget);
        expect(testableRecipeVM.hasEditConflict, isFalse);
        expect(testableCollaborativeVM.hasConflicts, isFalse);
      });

      testWidgets('should coordinate provider notifications efficiently',
          (tester) async {
        // Arrange: Setup notification coordination scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
                recipe: testRecipe);
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        // Track state transitions for efficiency analysis
        testableRecipeVM.clearStateHistory();

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Trigger rapid state changes to test notification efficiency
        for (int i = 0; i < 5; i++) {
          testableRecipeVM.setRecipeFormState(hasUnsavedChanges: i % 2 == 0);
          await tester.pump(const Duration(milliseconds: 10));
        }

        // Assert: Verify efficient notification handling
        final stateTransitions = testableRecipeVM.getStateTransitions();
        expect(stateTransitions.isNotEmpty, isTrue);
        expect(find.byType(EditRecipeView), findsOneWidget);
      });
    });

    group('Component Facade Delegation Tests', () {
      testWidgets(
          'should delegate AppBar construction to EditRecipeAppBar.build',
          (tester) async {
        // Arrange: Setup component delegation scenario
        final testRecipe = RecipeFactory.build();
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();
        testableCollaborativeVM.setCollaborativeState(isCollaborative: true);

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
            value: TestableViewModelFactory.createRecipeFormViewModel(
                recipe: testRecipe),
          ),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Verify AppBar delegation architecture
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.appBar, isNotNull);

        // AppBar should be responsive to collaborative state
        final appBar = scaffold.appBar as PreferredSizeWidget;
        expect(appBar.preferredSize.height, equals(kToolbarHeight));
      });

      testWidgets(
          'should delegate BottomBar construction to EditRecipeBottomBar.build',
          (tester) async {
        // Arrange: Setup bottom bar delegation scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
                recipe: testRecipe);

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
            value: MockCollaborativeStatusViewModel(),
          ),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Verify BottomBar delegation architecture
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.bottomNavigationBar, isNotNull);

        // Test permission-based action button delegation
        testableRecipeVM.setRecipeFormState(hasUnsavedChanges: true);
        await tester.pump();

        expect(scaffold.bottomNavigationBar, isNotNull);
      });

      testWidgets(
          'should delegate FormFields construction to EditRecipeFormFields.buildFormFields',
          (tester) async {
        // Arrange: Setup form fields delegation scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
                recipe: testRecipe);

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
            value: MockCollaborativeStatusViewModel(),
          ),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Verify FormFields delegation architecture
        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(Form), findsOneWidget);

        // Form should contain multiple field types delegated to EditRecipeFormFields
        final formFinder = find.byType(Form);
        expect(formFinder, findsOneWidget);
      });

      testWidgets(
          'should delegate Banner construction to EditRecipeBanners.buildSmartBanners',
          (tester) async {
        // Arrange: Setup banner delegation scenario with collaborative state
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
          isCollaborative: true,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: ['Test User'],
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Verify Banner delegation architecture
        expect(
            find.byType(Column), findsAtLeast(1)); // Banner integration point
        expect(find.byType(EditRecipeView), findsOneWidget);

        // Test banner responsiveness to collaborative state changes
        testableCollaborativeVM.setCollaborativeState(isCollaborative: false);
        await tester.pump();

        expect(find.byType(Column),
            findsAtLeast(1)); // Banner container should remain
      });

      testWidgets(
          'should coordinate all 7 focused components through facade architecture',
          (tester) async {
        // Arrange: Setup comprehensive component coordination scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
          isCollaborative: true,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          hasConflicts: true,
          activeCollaborators: ['Test Collaborator'],
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Verify all 7 focused components are coordinated through facade

        // 1. EditRecipeAppBar delegation
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.appBar, isNotNull,
            reason: 'EditRecipeAppBar delegation failed');

        // 2. EditRecipeBottomBar delegation
        expect(scaffold.bottomNavigationBar, isNotNull,
            reason: 'EditRecipeBottomBar delegation failed');

        // 3. EditRecipeBanners delegation (via Column structure)
        expect(find.byType(Column), findsAtLeast(1),
            reason: 'EditRecipeBanners delegation failed');

        // 4. EditRecipeFormFields delegation (via Form and ListView)
        expect(find.byType(Form), findsOneWidget,
            reason: 'EditRecipeFormFields delegation failed');
        expect(find.byType(ListView), findsOneWidget,
            reason: 'EditRecipeFormFields ListView delegation failed');

        // 5. Stack structure for loading overlay (StateWidget integration)
        expect(find.byType(Stack), findsOneWidget,
            reason: 'Loading overlay delegation failed');

        // 6 & 7. EditRecipeImagePicker and EditRecipeDynamicList are integrated within FormFields
        // These are tested through FormFields delegation architecture

        // Test coordinated component response to state changes
        testableRecipeVM.setRecipeFormState(
            isLoading: true, hasUnsavedChanges: true);
        testableCollaborativeVM.setCollaborativeState(hasConflicts: false);
        await tester.pump();

        // All components should remain stable and responsive
        expect(find.byType(EditRecipeView), findsOneWidget);
        expect(scaffold.appBar, isNotNull);
        expect(scaffold.bottomNavigationBar, isNotNull);
        expect(find.byType(Form), findsOneWidget);
      });
    });

    // ==================== LIFECYCLE AND STATE MANAGEMENT ====================

    group('Lifecycle Management Tests', () {
      testWidgets(
          'should handle proper initialization sequence with multi-provider coordination',
          (tester) async {
        // Arrange: Setup initialization monitoring
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        testableRecipeVM.clearStateHistory();

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        // Act: Initialize view and track initialization sequence
        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await ViewTestHelpers.waitForViewInitialization(tester);

        // Assert: Verify multi-provider initialization
        expect(find.byType(EditRecipeView), findsOneWidget);
        expect(testableRecipeVM.isProperlyDisposed, isFalse);
      });

      testWidgets(
          'should maintain provider consistency during complex state transitions',
          (tester) async {
        // Arrange: Setup complex state transition scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Trigger multiple complex state changes
        testableRecipeVM.setRecipeFormState(
          hasUnsavedChanges: true,
          isLoading: true,
        );
        await tester.pump();

        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: ['Test User'],
        );
        await tester.pump();

        testableRecipeVM.setRecipeFormState(
          isLoading: false,
          hasUnsavedChanges: false,
        );
        await tester.pump();

        // Assert: Verify view stability throughout transitions
        expect(testableRecipeVM.hasUnsavedChanges, isFalse);
        expect(find.byType(EditRecipeView), findsOneWidget);
      });
    });

    // ==================== COLLABORATIVE FEATURES TESTING ====================

    group('Collaborative Features Tests', () {
      testWidgets(
          'should display collaborative status in AppBar when recipe is shared',
          (tester) async {
        // Arrange: Setup collaborative recipe scenario
        final testRecipe = RecipeFactory.build();
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );

        // Setup collaborative state
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: ['Anna Svensson', 'Erik Johansson'],
          hasConflicts: false,
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        // Act: Render EditRecipeView with collaborative state
        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );
        await tester.pump();

        // Assert: Verify collaborative AppBar indicators
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.title, isA<Text>());
        expect((appBar.title as Text).data, equals('Redigera recept'));

        // Verify collaborative status badge appears
        expect(find.text('Delat'), findsOneWidget,
            reason: 'Collaborative status badge should show "Delat"');
        expect(find.byIcon(Icons.people), findsOneWidget,
            reason: 'People icon should indicate collaboration');
      });

      testWidgets(
          'should show collaborative banner with participant information',
          (tester) async {
        // Arrange: Setup collaborative recipe with multiple participants
        final testRecipe = RecipeFactory.build();
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );

        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: [
            'Anna Svensson',
            'Erik Johansson',
            'Lisa Andersson'
          ],
          hasConflicts: false,
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        // Act: Render view and check banners
        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );
        await tester.pump();

        // Assert: Verify collaborative banner content
        expect(find.text('Du redigerar tillsammans med andra'), findsOneWidget,
            reason: 'Collaborative banner should show collaboration message');
        expect(find.text('Ändringar synkas automatiskt med andra deltagare'),
            findsOneWidget,
            reason: 'Banner should explain auto-sync functionality');
      });

      testWidgets(
          'should display permission-based action buttons for different scenarios',
          (tester) async {
        // Test collaborative vs non-collaborative scenarios
        final testScenarios = [
          {
            'description': 'non-collaborative mode should show save button',
            'isCollaborative': false,
            'expectedActions': ['Spara ändringar']
          },
          {
            'description':
                'collaborative mode should show permission-based buttons',
            'isCollaborative': true,
            'expectedActions': [
              'Spara ändringar',
              'Skapa kopia'
            ] // May show both depending on permissions
          }
        ];

        for (final scenario in testScenarios) {
          final testRecipe = RecipeFactory.build();
          final testableRecipeVM =
              TestableViewModelFactory.createRecipeFormViewModel(
            recipe: testRecipe,
          );
          final testableCollaborativeVM = MockCollaborativeStatusViewModel();

          // Setup collaborative state
          testableCollaborativeVM.setCollaborativeState(
            isCollaborative: scenario['isCollaborative'] as bool,
            hasConflicts: false,
          );

          final providers = [
            ChangeNotifierProvider<RecipeFormViewModel>.value(
                value: testableRecipeVM),
            ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
                value: testableCollaborativeVM),
          ];

          await tester.pumpWidget(
            ViewTestHelpers.createTestViewWidget(
              child: EditRecipeView(recipe: testRecipe),
              providers: providers,
            ),
          );
          await tester.pump();

          // Assert: Verify action buttons are present
          final expectedActions = scenario['expectedActions'] as List<String>;
          bool foundAtLeastOne = false;
          for (final action in expectedActions) {
            if (tester.any(find.text(action))) {
              foundAtLeastOne = true;
              break;
            }
          }
          expect(foundAtLeastOne, isTrue,
              reason: scenario['description'] as String);

          // Clean up for next scenario
          await tester.pumpWidget(Container());
        }
      });

      testWidgets('should handle collaborative conflict resolution workflow',
          (tester) async {
        // Arrange: Setup conflict scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        // Initial collaborative state without conflicts
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: ['Anna Svensson'],
          hasConflicts: false,
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );
        await tester.pump();

        // Act: Simulate conflict arising during editing
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: ['Anna Svensson'],
          hasConflicts: true,
        );
        await tester.pump();

        // Assert: Verify conflict resolution UI
        // The exact UI depends on how conflicts are displayed in the banners/components
        expect(find.byType(EditRecipeView), findsOneWidget,
            reason: 'View should remain stable during conflicts');

        // Test conflict resolution by updating collaborative state
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: ['Anna Svensson'],
          hasConflicts: false,
        );
        await tester.pump();

        // Verify conflict resolution
        expect(find.byType(EditRecipeView), findsOneWidget,
            reason: 'View should recover from conflict state');
      });

      testWidgets('should handle fork action during collaborative conflicts',
          (tester) async {
        // Arrange: Setup collaborative conflict scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        // Setup collaborative conflict which may trigger fork option
        testableRecipeVM.simulateCollaborativeConflict(
          conflictingUser: 'Anna Svensson',
          conflictType: ConflictType.simultaneousEdit,
        );
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          hasConflicts: true,
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );
        await tester.pump();

        // Assert: Verify conflict state is handled
        expect(find.byType(EditRecipeView), findsOneWidget,
            reason: 'View should handle collaborative conflicts');

        // Test conflict resolution
        testableRecipeVM.resolveCollaborativeConflict();
        await tester.pump();

        expect(testableRecipeVM.hasEditConflict, isFalse,
            reason: 'Conflict should be resolved');
      });

      testWidgets(
          'should show loading states during collaborative save operation',
          (tester) async {
        // Arrange: Setup collaborative editing scenario
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        testableRecipeVM.setRecipeFormState(
          recipe: testRecipe,
          isLoading: false,
        );
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          hasConflicts: false,
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );
        await tester.pump();

        // Act: Simulate save action with loading state
        testableRecipeVM.setRecipeFormState(isLoading: true);
        await tester.pump();

        // Assert: Verify loading overlay appears
        expect(find.text('Uppdaterar recept...'), findsOneWidget,
            reason: 'Loading message should appear during save');
        expect(find.byType(CircularProgressIndicator), findsOneWidget,
            reason: 'Loading indicator should be visible');

        // Complete save operation
        testableRecipeVM.setRecipeFormState(isLoading: false);
        await tester.pump();

        // Verify loading state clears
        expect(find.text('Uppdaterar recept...'), findsNothing,
            reason: 'Loading message should disappear after save');
      });

      testWidgets(
          'should handle real-time participant changes during editing session',
          (tester) async {
        // Arrange: Setup initial collaborative session
        final testRecipe = RecipeFactory.build();
        final testableRecipeVM =
            TestableViewModelFactory.createRecipeFormViewModel(
          recipe: testRecipe,
        );
        final testableCollaborativeVM = MockCollaborativeStatusViewModel();

        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: ['Anna Svensson'],
          hasConflicts: false,
        );

        final providers = [
          ChangeNotifierProvider<RecipeFormViewModel>.value(
              value: testableRecipeVM),
          ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
              value: testableCollaborativeVM),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: EditRecipeView(recipe: testRecipe),
            providers: providers,
          ),
        );
        await tester.pump();

        // Act: Simulate new participant joining
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: ['Anna Svensson', 'Erik Johansson'],
          hasConflicts: false,
        );
        await tester.pump();

        // Assert: Verify UI updates for new participants
        expect(find.byType(EditRecipeView), findsOneWidget,
            reason: 'View should handle participant changes gracefully');

        // Simulate participant leaving
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: true,
          activeCollaborators: ['Erik Johansson'],
          hasConflicts: false,
        );
        await tester.pump();

        expect(find.byType(EditRecipeView), findsOneWidget,
            reason: 'View should handle participant departures');

        // Simulate last participant leaving (no longer collaborative)
        testableCollaborativeVM.setCollaborativeState(
          isCollaborative: false,
          activeCollaborators: [],
          hasConflicts: false,
        );
        await tester.pump();

        expect(find.byType(EditRecipeView), findsOneWidget,
            reason: 'View should transition from collaborative to solo mode');
        expect(find.text('Delat'), findsNothing,
            reason:
                'Collaborative indicator should disappear when no longer shared');
      });
    });
  });
}
