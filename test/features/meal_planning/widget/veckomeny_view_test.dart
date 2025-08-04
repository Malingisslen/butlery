import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:butlery/views/veckomeny_view.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/unified_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';
import '../../../helpers/mock_factories.dart';

// Mocks
class MockMenuViewModel extends Mock implements MenuViewModel {}

class MockUnifiedRecipeViewModel extends Mock
    implements UnifiedRecipeViewModel {}

class MockUnifiedShoppingViewModel extends Mock
    implements UnifiedShoppingViewModel {}

class MockDiscoveryDashboardViewModel extends Mock
    implements DiscoveryDashboardViewModel {}

void main() {
  late MockMenuViewModel mockMenuViewModel;
  late MockUnifiedRecipeViewModel mockRecipeViewModel;
  late MockUnifiedShoppingViewModel mockShoppingViewModel;
  late MockDiscoveryDashboardViewModel mockDiscoveryViewModel;

  setUp(() {
    mockMenuViewModel = MockMenuViewModel();
    mockRecipeViewModel = MockUnifiedRecipeViewModel();
    mockShoppingViewModel = MockUnifiedShoppingViewModel();
    mockDiscoveryViewModel = MockDiscoveryDashboardViewModel();

    // Default mock behaviors
    when(() => mockMenuViewModel.menu).thenReturn({});
    when(() => mockMenuViewModel.isGenerating).thenReturn(false);
    when(() => mockMenuViewModel.error).thenReturn(null);
    when(() => mockMenuViewModel.hasMenu).thenReturn(false);
    when(() => mockMenuViewModel.hasError).thenReturn(false);
    when(() => mockMenuViewModel.lastPrompt).thenReturn('');
    when(() => mockMenuViewModel.savedMenus).thenReturn([]);
    when(() => mockMenuViewModel.totalRecipeCount).thenReturn(0);
    when(() => mockMenuViewModel.availableRecipes).thenReturn([]);
    when(() => mockMenuViewModel.hasAvailableRecipes).thenReturn(false);
    when(() => mockMenuViewModel.addListener(any())).thenReturn(null);
    when(() => mockMenuViewModel.removeListener(any())).thenReturn(null);

    when(() => mockRecipeViewModel.recipes).thenReturn([]);
    when(() => mockShoppingViewModel.addListener(any())).thenReturn(null);
    when(() => mockShoppingViewModel.removeListener(any())).thenReturn(null);
  });

  Widget createTestWidget({Widget? child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MenuViewModel>.value(value: mockMenuViewModel),
        ChangeNotifierProvider<UnifiedRecipeViewModel>.value(
            value: mockRecipeViewModel),
        ChangeNotifierProvider<UnifiedShoppingViewModel>.value(
            value: mockShoppingViewModel),
        ChangeNotifierProvider<DiscoveryDashboardViewModel>.value(
            value: mockDiscoveryViewModel),
      ],
      child: MaterialApp(
        home: child ?? const VeckomenyView(),
      ),
    );
  }

  group('VeckomenyView - Display', () {
    testWidgets('should display app bar with title', (tester) async {
      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.text('Veckomeny'), findsOneWidget);
    });

    testWidgets('should display empty state when no menu', (tester) async {
      // Given
      when(() => mockMenuViewModel.hasAvailableRecipes).thenReturn(true);

      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.text('Ingen meny genererad'), findsOneWidget);
      expect(find.text('Generera en meny för att komma igång'), findsOneWidget);
    });

    testWidgets('should display no recipes message when empty', (tester) async {
      // Given
      when(() => mockMenuViewModel.hasAvailableRecipes).thenReturn(false);

      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.text('Inga recept tillgängliga'), findsOneWidget);
      expect(find.text('Lägg till recept för att kunna generera menyer'),
          findsOneWidget);
    });

    testWidgets('should display loading indicator when generating',
        (tester) async {
      // Given
      when(() => mockMenuViewModel.isGenerating).thenReturn(true);

      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Genererar meny...'), findsOneWidget);
    });

    testWidgets('should display error message when error exists',
        (tester) async {
      // Given
      when(() => mockMenuViewModel.hasError).thenReturn(true);
      when(() => mockMenuViewModel.error).thenReturn('Ett fel uppstod');

      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.text('Ett fel uppstod'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('VeckomenyView - Menu Generation', () {
    testWidgets('should show generation prompt dialog', (tester) async {
      // Given
      when(() => mockMenuViewModel.hasAvailableRecipes).thenReturn(true);

      // When
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Generera meny'));
      await tester.pumpAndSettle();

      // Then
      expect(find.text('Beskriv din önskade meny'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Generera'), findsOneWidget);
    });

    testWidgets('should call generateMenu with prompt', (tester) async {
      // Given
      when(() => mockMenuViewModel.hasAvailableRecipes).thenReturn(true);
      when(() => mockMenuViewModel.generateMenu(any()))
          .thenAnswer((_) async {});

      // When
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Generera meny'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Vegetarisk veckomeny');
      await tester.tap(find.text('Generera'));
      await tester.pumpAndSettle();

      // Then
      verify(() => mockMenuViewModel.generateMenu('Vegetarisk veckomeny'))
          .called(1);
    });
  });

  group('VeckomenyView - Menu Display', () {
    testWidgets('should display generated menu', (tester) async {
      // Given
      final menu = {
        'Måndag': [
          RecipeFactory.build(title: 'Pasta Carbonara'),
          RecipeFactory.build(title: 'Sallad'),
        ],
        'Tisdag': [
          RecipeFactory.build(title: 'Köttbullar'),
        ],
      };

      when(() => mockMenuViewModel.hasMenu).thenReturn(true);
      when(() => mockMenuViewModel.menu).thenReturn(menu);
      when(() => mockMenuViewModel.totalRecipeCount).thenReturn(3);

      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.text('Måndag'), findsOneWidget);
      expect(find.text('Pasta Carbonara'), findsOneWidget);
      expect(find.text('Sallad'), findsOneWidget);
      expect(find.text('Tisdag'), findsOneWidget);
      expect(find.text('Köttbullar'), findsOneWidget);
    });

    testWidgets('should allow section regeneration', (tester) async {
      // Given
      final menu = {
        'Måndag': [RecipeFactory.build(title: 'Test Recipe')],
      };

      when(() => mockMenuViewModel.hasMenu).thenReturn(true);
      when(() => mockMenuViewModel.menu).thenReturn(menu);
      when(() => mockMenuViewModel.regenerateSection(any()))
          .thenAnswer((_) async {});

      // When
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byIcon(Icons.refresh).first);

      // Then
      verify(() => mockMenuViewModel.regenerateSection('Måndag')).called(1);
    });
  });

  group('VeckomenyView - Menu Actions', () {
    testWidgets('should save menu with name and comment', (tester) async {
      // Given
      final menu = {
        'Måndag': [RecipeFactory.build()],
      };

      when(() => mockMenuViewModel.hasMenu).thenReturn(true);
      when(() => mockMenuViewModel.menu).thenReturn(menu);
      when(() => mockMenuViewModel.saveMenuWithNameAndComment(
            any(),
            any(),
            shareWithFriends: any(named: 'shareWithFriends'),
            selectedFriendIds: any(named: 'selectedFriendIds'),
            shareMessage: any(named: 'shareMessage'),
          )).thenAnswer((_) async => true);

      // When
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Min Veckomeny');
      await tester.enterText(
          find.byType(TextField).at(1), 'Vegetarisk och god');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      // Then
      verify(() => mockMenuViewModel.saveMenuWithNameAndComment(
            'Min Veckomeny',
            'Vegetarisk och god',
            shareWithFriends: any(named: 'shareWithFriends'),
            selectedFriendIds: any(named: 'selectedFriendIds'),
            shareMessage: any(named: 'shareMessage'),
          )).called(1);
    });

    testWidgets('should show shopping list selector when tapping cart', (tester) async {
      // Given
      final menu = {
        'Måndag': [RecipeFactory.build()],
      };

      when(() => mockMenuViewModel.hasMenu).thenReturn(true);
      when(() => mockMenuViewModel.menu).thenReturn(menu);
      when(() => mockShoppingViewModel.lists).thenReturn([]);
      when(() => mockShoppingViewModel.isLoading).thenReturn(false);

      // When
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byIcon(Icons.shopping_cart));
      await tester.pumpAndSettle();

      // Then - the shopping list selector dialog should be shown
      expect(find.text('Välj inköpslista'), findsOneWidget);
    });

    testWidgets('should clear menu', (tester) async {
      // Given
      final menu = {
        'Måndag': [RecipeFactory.build()],
      };

      when(() => mockMenuViewModel.hasMenu).thenReturn(true);
      when(() => mockMenuViewModel.menu).thenReturn(menu);
      when(() => mockMenuViewModel.clearMenu()).thenReturn(null);

      // When
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rensa'));

      // Then
      verify(() => mockMenuViewModel.clearMenu()).called(1);
    });
  });

  group('VeckomenyView - Saved Menus', () {
    testWidgets('should display saved menus', (tester) async {
      // Given
      final savedMenus = [
        SavedMenuInfo(
          key: 'menu1',
          name: 'Vegetarisk Vecka',
          comment: 'Hälsosam meny',
          savedDate: DateTime.now(),
          recipeCount: 5,
        ),
        SavedMenuInfo(
          key: 'menu2',
          name: 'Barnvänlig Meny',
          comment: 'Enkla rätter',
          savedDate: DateTime.now(),
          recipeCount: 7,
        ),
      ];

      when(() => mockMenuViewModel.savedMenus).thenReturn(savedMenus);

      // When
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byIcon(Icons.folder));
      await tester.pumpAndSettle();

      // Then
      expect(find.text('Sparade menyer'), findsOneWidget);
      expect(find.text('Vegetarisk Vecka'), findsOneWidget);
      expect(find.text('Hälsosam meny'), findsOneWidget);
      expect(find.text('Barnvänlig Meny'), findsOneWidget);
      expect(find.text('Enkla rätter'), findsOneWidget);
    });

    testWidgets('should load saved menu', (tester) async {
      // Given
      final savedMenu = SavedMenuInfo(
        key: 'menu1',
        name: 'Test Menu',
        comment: 'Test',
        savedDate: DateTime.now(),
        recipeCount: 3,
      );

      when(() => mockMenuViewModel.savedMenus).thenReturn([savedMenu]);
      when(() => mockMenuViewModel.loadSavedMenu(any()))
          .thenAnswer((_) async => true);

      // When
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byIcon(Icons.folder));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Menu'));
      await tester.pumpAndSettle();

      // Then
      verify(() => mockMenuViewModel.loadSavedMenu(savedMenu.key)).called(1);
    });
  });
}