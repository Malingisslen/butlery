import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';
import 'package:butlery/main.dart' as app;
import '../helpers/integration_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() async {
    // Initialize test Firebase
    await IntegrationTestHelpers.initializeTestFirebase();
  });
  
  tearDownAll(() async {
    await IntegrationTestHelpers.cleanup();
  });
  
  group('Complete Recipe Journey E2E Tests', () {
    patrolTest(
      'User can create, view, edit, and delete a recipe',
      ($) async {
        // Start the app
        await app.main();
        await $.pumpAndSettle();
        
        // Step 1: Login
        await $.tap(find.text('Logga in'));
        await $.enterText(find.byKey(const Key('email_field')), 'test@example.com');
        await $.enterText(find.byKey(const Key('password_field')), 'password123');
        await $.tap(find.text('Logga in'));
        await $.pumpAndSettle();
        
        // Verify we're on the home screen
        expect(find.text('Mina recept'), findsOneWidget);
        
        // Step 2: Navigate to create recipe
        await $.tap(find.byIcon(Icons.add));
        await $.pumpAndSettle();
        
        // Choose to write recipe manually
        await $.tap(find.text('Skriv själv'));
        await $.pumpAndSettle();
        
        // Step 3: Fill in recipe form
        // Title
        await $.enterText(
          find.byKey(const Key('recipe_title_field')),
          'Amazing Chocolate Cake',
        );
        
        // Description
        await $.enterText(
          find.byKey(const Key('recipe_description_field')),
          'A delicious and moist chocolate cake perfect for any occasion',
        );
        
        // Servings
        await $.tap(find.byKey(const Key('servings_decrease')));
        await $.tap(find.byKey(const Key('servings_increase')));
        await $.tap(find.byKey(const Key('servings_increase')));
        // Should be 4 servings now
        
        // Cook time
        await $.enterText(
          find.byKey(const Key('cook_time_field')),
          '45',
        );
        
        // Add ingredients
        await $.tap(find.text('Lägg till ingrediens'));
        await $.enterText(
          find.byKey(const Key('ingredient_name_0')),
          'Mjöl',
        );
        await $.enterText(
          find.byKey(const Key('ingredient_amount_0')),
          '300',
        );
        await $.tap(find.byKey(const Key('ingredient_unit_0')));
        await $.tap(find.text('g'));
        
        // Add another ingredient
        await $.tap(find.text('Lägg till ingrediens'));
        await $.enterText(
          find.byKey(const Key('ingredient_name_1')),
          'Kakao',
        );
        await $.enterText(
          find.byKey(const Key('ingredient_amount_1')),
          '50',
        );
        await $.tap(find.byKey(const Key('ingredient_unit_1')));
        await $.tap(find.text('g'));
        
        // Add instructions
        await $.scrollUntilVisible(finder: find.text('Instruktioner'));
        await $.tap(find.text('Lägg till instruktion'));
        await $.enterText(
          find.byKey(const Key('instruction_0')),
          'Blanda alla torra ingredienser i en skål',
        );
        
        await $.tap(find.text('Lägg till instruktion'));
        await $.enterText(
          find.byKey(const Key('instruction_1')),
          'Tillsätt de våta ingredienserna och blanda väl',
        );
        
        // Add tags
        await $.scrollUntilVisible(finder: find.text('Taggar'));
        await $.tap(find.byKey(const Key('tag_Dessert')));
        await $.tap(find.byKey(const Key('tag_Bakning')));
        
        // Step 4: Save the recipe
        await $.scrollUntilVisible(finder: find.text('Spara recept'));
        await $.tap(find.text('Spara recept'));
        await $.pumpAndSettle();
        
        // Verify success message
        expect(find.text('Recept sparat!'), findsOneWidget);
        await $.pumpAndSettle();
        
        // Step 5: Verify recipe appears in list
        expect(find.text('Amazing Chocolate Cake'), findsOneWidget);
        
        // Step 6: View recipe details
        await $.tap(find.text('Amazing Chocolate Cake'));
        await $.pumpAndSettle();
        
        // Verify all details are displayed
        expect(find.text('Amazing Chocolate Cake'), findsOneWidget);
        expect(find.text('A delicious and moist chocolate cake perfect for any occasion'), findsOneWidget);
        expect(find.text('4 portioner'), findsOneWidget);
        expect(find.text('45 min'), findsOneWidget);
        expect(find.text('Mjöl'), findsOneWidget);
        expect(find.text('300 g'), findsOneWidget);
        expect(find.text('Kakao'), findsOneWidget);
        expect(find.text('50 g'), findsOneWidget);
        expect(find.text('Blanda alla torra ingredienser i en skål'), findsOneWidget);
        expect(find.text('Dessert'), findsOneWidget);
        expect(find.text('Bakning'), findsOneWidget);
        
        // Step 7: Edit the recipe
        await $.tap(find.byIcon(Icons.edit));
        await $.pumpAndSettle();
        
        // Change title
        await $.enterText(
          find.byKey(const Key('recipe_title_field')),
          'Ultimate Chocolate Cake',
        );
        
        // Add one more ingredient
        await $.scrollUntilVisible(
          finder: find.text('Lägg till ingrediens'),
          view: find.byType(Scrollable).first,
        );
        await $.tap(find.text('Lägg till ingrediens'));
        await $.enterText(
          find.byKey(const Key('ingredient_name_2')),
          'Vaniljsocker',
        );
        await $.enterText(
          find.byKey(const Key('ingredient_amount_2')),
          '1',
        );
        await $.tap(find.byKey(const Key('ingredient_unit_2')));
        await $.tap(find.text('tsk'));
        
        // Save changes
        await $.scrollUntilVisible(
          finder: find.text('Spara ändringar'),
          view: find.byType(Scrollable).first,
        );
        await $.tap(find.text('Spara ändringar'));
        await $.pumpAndSettle();
        
        // Verify changes
        expect(find.text('Ultimate Chocolate Cake'), findsOneWidget);
        expect(find.text('Vaniljsocker'), findsOneWidget);
        
        // Step 8: Test favorite functionality
        await $.tap(find.byIcon(Icons.favorite_border));
        await $.pumpAndSettle();
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        
        // Step 9: Share the recipe (test share dialog)
        await $.tap(find.byIcon(Icons.share));
        await $.pumpAndSettle();
        
        // Verify share dialog appears
        expect(find.text('Dela recept'), findsOneWidget);
        
        // Cancel share
        await $.tap(find.text('Avbryt'));
        await $.pumpAndSettle();
        
        // Step 10: Add to shopping list
        await $.tap(find.byIcon(Icons.shopping_cart));
        await $.pumpAndSettle();
        
        // Verify shopping list dialog
        expect(find.text('Lägg till i inköpslista'), findsOneWidget);
        await $.tap(find.text('Lägg till'));
        await $.pumpAndSettle();
        
        // Step 11: Navigate back to list
        await $.tap(find.byType(BackButton));
        await $.pumpAndSettle();
        
        // Step 12: Delete the recipe
        await $.longPress(find.text('Ultimate Chocolate Cake'));
        await $.pumpAndSettle();
        
        // Confirm deletion
        await $.tap(find.text('Ta bort'));
        await $.pumpAndSettle();
        await $.tap(find.text('Bekräfta'));
        await $.pumpAndSettle();
        
        // Verify recipe is gone
        expect(find.text('Ultimate Chocolate Cake'), findsNothing);
      },
    );
    
    patrolTest(
      'User can import recipe from URL',
      ($) async {
        // Start the app
        await app.main();
        await $.pumpAndSettle();
        
        // Login
        await $.tap(find.text('Logga in'));
        await $.enterText(find.byKey(const Key('email_field')), 'test@example.com');
        await $.enterText(find.byKey(const Key('password_field')), 'password123');
        await $.tap(find.text('Logga in'));
        await $.pumpAndSettle();
        
        // Navigate to import
        await $.tap(find.byIcon(Icons.add));
        await $.pumpAndSettle();
        await $.tap(find.text('Från sociala medier'));
        await $.pumpAndSettle();
        
        // Enter URL
        await $.enterText(
          find.byKey(const Key('url_input_field')),
          'https://example.com/recipe/pasta-carbonara',
        );
        
        // Import
        await $.tap(find.text('Importera'));
        await $.pumpAndSettle();
        
        // Wait for import to complete
        await $.waitUntilVisible(find.text('Import slutförd!'));
        
        // Verify imported recipe appears
        expect(find.textContaining('Carbonara'), findsOneWidget);
      },
    );
    
    patrolTest(
      'User can search and filter recipes',
      ($) async {
        // Start the app with some test recipes
        await IntegrationTestHelpers.seedTestRecipes(10);
        await app.main();
        await $.pumpAndSettle();
        
        // Login
        await $.tap(find.text('Logga in'));
        await $.enterText(find.byKey(const Key('email_field')), 'test@example.com');
        await $.enterText(find.byKey(const Key('password_field')), 'password123');
        await $.tap(find.text('Logga in'));
        await $.pumpAndSettle();
        
        // Open search
        await $.tap(find.byIcon(Icons.search));
        await $.pumpAndSettle();
        
        // Search for pasta
        await $.enterText(
          find.byKey(const Key('search_field')),
          'pasta',
        );
        await $.pumpAndSettle();
        
        // Verify search results
        expect(find.textContaining('pasta', findRichText: true), findsWidgets);
        
        // Apply filter
        await $.tap(find.byIcon(Icons.filter_list));
        await $.pumpAndSettle();
        
        // Select vegetarian filter
        await $.tap(find.text('Vegetarisk'));
        await $.tap(find.text('Tillämpa filter'));
        await $.pumpAndSettle();
        
        // Verify filtered results
        expect(find.byKey(const Key('filter_chip_vegetarian')), findsOneWidget);
      },
    );
    
    patrolTest(
      'Offline mode - can create and sync recipe',
      ($) async {
        await app.main();
        await $.pumpAndSettle();
        
        // Login
        await $.tap(find.text('Logga in'));
        await $.enterText(find.byKey(const Key('email_field')), 'test@example.com');
        await $.enterText(find.byKey(const Key('password_field')), 'password123');
        await $.tap(find.text('Logga in'));
        await $.pumpAndSettle();
        
        // Enable offline mode
        await $.tap(find.byIcon(Icons.menu));
        await $.pumpAndSettle();
        await $.tap(find.text('Inställningar'));
        await $.pumpAndSettle();
        await $.tap(find.byKey(const Key('offline_mode_switch')));
        await $.pumpAndSettle();
        
        // Navigate back
        await $.tap(find.byType(BackButton));
        await $.pumpAndSettle();
        
        // Create recipe in offline mode
        await $.tap(find.byIcon(Icons.add));
        await $.pumpAndSettle();
        await $.tap(find.text('Skriv själv'));
        await $.pumpAndSettle();
        
        // Fill minimal recipe
        await $.enterText(
          find.byKey(const Key('recipe_title_field')),
          'Offline Recipe',
        );
        await $.tap(find.text('Spara recept'));
        await $.pumpAndSettle();
        
        // Verify offline indicator
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        
        // Disable offline mode to sync
        await $.tap(find.byIcon(Icons.menu));
        await $.pumpAndSettle();
        await $.tap(find.text('Inställningar'));
        await $.pumpAndSettle();
        await $.tap(find.byKey(const Key('offline_mode_switch')));
        await $.pumpAndSettle();
        
        // Wait for sync
        await $.waitUntilVisible(find.byIcon(Icons.cloud_done));
        
        // Verify recipe is synced
        expect(find.byIcon(Icons.cloud_off), findsNothing);
      },
    );
  });
  
  group('Performance Tests', () {
    patrolTest(
      'App startup performance',
      ($) async {
        final stopwatch = Stopwatch()..start();
        
        await app.main();
        await $.pumpAndSettle();
        
        stopwatch.stop();
        
        // App should start in less than 3 seconds
        expect(stopwatch.elapsedMilliseconds, lessThan(3000));
        debugPrint('[INTEGRATION] App startup time: ${stopwatch.elapsedMilliseconds}ms');
      },
    );
    
    patrolTest(
      'Recipe list scrolling performance',
      ($) async {
        // Seed many recipes
        await IntegrationTestHelpers.seedTestRecipes(100);
        await app.main();
        await $.pumpAndSettle();
        
        // Login
        await $.tap(find.text('Logga in'));
        await $.enterText(find.byKey(const Key('email_field')), 'test@example.com');
        await $.enterText(find.byKey(const Key('password_field')), 'password123');
        await $.tap(find.text('Logga in'));
        await $.pumpAndSettle();
        
        // Measure scrolling performance
        final stopwatch = Stopwatch()..start();
        
        // Scroll to bottom
        await $.scrollUntilVisible(
          finder: find.byKey(const Key('recipe_99')),
          view: find.byType(Scrollable).first,
        );
        
        stopwatch.stop();
        
        // Scrolling should be smooth (less than 2 seconds for 100 items)
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
        debugPrint('[INTEGRATION] Scroll time for 100 recipes: ${stopwatch.elapsedMilliseconds}ms');
      },
    );
  });
}