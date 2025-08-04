import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';
import 'package:butlery/main.dart' as app;
import '../helpers/integration_test_helpers.dart';

/// Comprehensive integration tests for the meal planning workflow
/// Tests the complete user journey from selecting recipes to generating shopping lists
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  // Firebase instances are managed by IntegrationTestHelpers
  
  setUpAll(() async {
    await IntegrationTestHelpers.initializeTestFirebase();
  });
  
  setUp(() async {
    await IntegrationTestHelpers.signInTestUser();
  });
  
  tearDown(() async {
    await IntegrationTestHelpers.cleanup();
  });

  group('Meal Planning Workflow Integration Tests', () {
    patrolTest(
      'Complete meal planning journey - weekly plan creation',
      ($) async {
        // Given - App is started and user is logged in
        await $.pumpWidgetAndSettle(const app.ButleryApp());
        // Login is handled automatically in test setup

        // Navigate to meal planning
        await $.tap(find.byIcon(Icons.calendar_today));
        await $.pumpAndSettle();

        // Verify we're on meal planning view
        expect(find.text('Veckomeny'), findsOneWidget);
        expect(find.text('Planera din vecka'), findsOneWidget);

        // When - Create a new weekly plan
        await $.tap(find.byKey(const Key('create_meal_plan_button')));
        await $.pumpAndSettle();

        // Select week
        final nextWeekButton = find.text('Nästa vecka');
        await $.tap(nextWeekButton);
        await $.pumpAndSettle();

        // Plan Monday meals
        await _planDayMeals($, 'Måndag', [
          'Spaghetti Carbonara',
          'Caesar Sallad',
          'Fruktsallad',
        ]);

        // Plan Tuesday meals
        await _planDayMeals($, 'Tisdag', [
          'Köttbullar med potatismos',
          'Tomatsoppa',
          'Chokladmousse',
        ]);

        // Plan Wednesday meals
        await _planDayMeals($, 'Onsdag', [
          'Lax med dillsås',
          'Grekisk sallad',
          'Vaniljglass',
        ]);

        // Save the meal plan
        await $.tap(find.byKey(const Key('save_meal_plan_button')));
        await $.pumpAndSettle();

        // Then - Verify plan is saved
        expect(find.text('Veckomeny sparad!'), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);

        // Navigate to saved plan
        await Future.delayed(const Duration(seconds: 2));
        await $.pumpAndSettle();
        expect(find.text('Måndag'), findsOneWidget);
        expect(find.text('Spaghetti Carbonara'), findsOneWidget);
      },
    );

    patrolTest(
      'Edit existing meal plan - swap and remove meals',
      ($) async {
        // Given - User has an existing meal plan
        await $.pumpWidgetAndSettle(const app.ButleryApp());
        // Login is handled automatically in test setup
        await _navigateToExistingMealPlan($);

        // When - Edit Monday's dinner
        await $.tap(find.descendant(
          of: find.byKey(const Key('monday_meals')),
          matching: find.byIcon(Icons.edit),
        ).first);
        await $.pumpAndSettle();

        // Remove current recipe
        await $.tap(find.byIcon(Icons.remove_circle));
        await $.pumpAndSettle();

        // Add new recipe
        await $.tap(find.byKey(const Key('add_recipe_button')));
        await $.pumpAndSettle();

        // Search and select new recipe
        await $.enterText(
          find.byKey(const Key('recipe_search_field')),
          'Pizza Margherita',
        );
        await $.pumpAndSettle();

        await $.tap(find.text('Pizza Margherita').first);
        await $.pumpAndSettle();

        // Save changes
        await $.tap(find.byKey(const Key('save_changes_button')));
        await $.pumpAndSettle();

        // Then - Verify changes are reflected
        expect(find.text('Pizza Margherita'), findsOneWidget);
        expect(find.text('Spaghetti Carbonara'), findsNothing);
      },
    );

    patrolTest(
      'Copy meal plan to different week',
      ($) async {
        // Given - User has a meal plan for current week
        await $.pumpWidgetAndSettle(const app.ButleryApp());
        // Login is handled automatically in test setup
        await _navigateToExistingMealPlan($);

        // When - Copy to next week
        await $.tap(find.byKey(const Key('meal_plan_menu_button')));
        await $.pumpAndSettle();

        await $.tap(find.text('Kopiera till annan vecka'));
        await $.pumpAndSettle();

        // Select target week
        await $.tap(find.text('Vecka 52'));
        await $.pumpAndSettle();

        await $.tap(find.text('Kopiera'));
        await $.pumpAndSettle();

        // Then - Verify copy was successful
        expect(find.text('Veckomeny kopierad!'), findsOneWidget);

        // Navigate to copied week
        await $.tap(find.byKey(const Key('week_selector')));
        await $.pumpAndSettle();
        await $.tap(find.text('Vecka 52'));
        await $.pumpAndSettle();

        // Verify meals are copied
        expect(find.text('Pizza Margherita'), findsOneWidget);
      },
    );

    patrolTest(
      'Share meal plan with family members',
      ($) async {
        // Given - User has a meal plan
        await $.pumpWidgetAndSettle(const app.ButleryApp());
        // Login is handled automatically in test setup
        await _navigateToExistingMealPlan($);

        // When - Share with family
        await $.tap(find.byKey(const Key('share_meal_plan_button')));
        await $.pumpAndSettle();

        // Select family members
        await $.tap(find.text('Partner'));
        await $.tap(find.text('Barn 1'));
        await $.pumpAndSettle();

        // Add message
        await $.enterText(
          find.byKey(const Key('share_message_field')),
          'Här är veckans meny! Låt mig veta om ni vill ändra något.',
        );

        // Send
        await $.tap(find.text('Dela'));
        await $.pumpAndSettle();

        // Then - Verify sharing was successful
        expect(find.text('Veckomeny delad!'), findsOneWidget);
        expect(find.byIcon(Icons.people), findsWidgets);
      },
    );

    patrolTest(
      'Generate shopping list from meal plan',
      ($) async {
        // Given - User has a complete meal plan
        await $.pumpWidgetAndSettle(const app.ButleryApp());
        // Login is handled automatically in test setup
        await _createCompleteMealPlan($);

        // When - Generate shopping list
        await $.tap(find.byKey(const Key('generate_shopping_list_button')));
        await $.pumpAndSettle();

        // Configure generation options
        await $.tap(find.text('Inkludera kryddor'));
        await $.tap(find.text('Gruppera efter butik'));
        await $.pumpAndSettle();

        // Check existing ingredients
        await $.tap(find.text('Kontrollera skafferi'));
        await $.pumpAndSettle();

        // Mark items already at home
        await $.tap(find.text('Salt'));
        await $.tap(find.text('Peppar'));
        await $.tap(find.text('Olivolja'));
        await $.pumpAndSettle();

        await $.tap(find.text('Generera lista'));
        await $.pumpAndSettle();

        // Then - Verify shopping list is created
        expect(find.text('Inköpslista'), findsOneWidget);
        expect(find.text('ICA'), findsOneWidget); // Store grouping
        expect(find.text('Willys'), findsOneWidget);

        // Verify items are grouped correctly
        final icaSection = find.ancestor(
          of: find.text('ICA'),
          matching: find.byType(ExpansionTile),
        );
        expect(
          find.descendant(
            of: icaSection,
            matching: find.text('Mjölk 2L'),
          ),
          findsOneWidget,
        );

        // Verify quantities are aggregated
        expect(find.text('Tomater (2 kg)'), findsOneWidget);
      },
    );

    patrolTest(
      'Adjust portions for entire meal plan',
      ($) async {
        // Given - User has a meal plan for 4 people
        await $.pumpWidgetAndSettle(const app.ButleryApp());
        // Login is handled automatically in test setup
        await _navigateToExistingMealPlan($);

        // When - Adjust to 6 people
        await $.tap(find.byKey(const Key('adjust_portions_button')));
        await $.pumpAndSettle();

        // Current: 4, New: 6
        await $.enterText(
          find.byKey(const Key('new_portions_field')),
          '6',
        );

        await $.tap(find.text('Justera alla recept'));
        await $.pumpAndSettle();

        // Then - Verify all recipes are scaled
        await $.tap(find.text('Pizza Margherita'));
        await $.pumpAndSettle();

        expect(find.text('6 portioner'), findsOneWidget);
        expect(find.text('600g vetemjöl'), findsOneWidget); // Was 400g
      },
    );

    patrolTest(
      'Filter meal plan by dietary restrictions',
      ($) async {
        // Given - User needs vegetarian options
        await $.pumpWidgetAndSettle(const app.ButleryApp());
        // Login is handled automatically in test setup
        
        // Navigate to meal planning
        await $.tap(find.byIcon(Icons.calendar_today));
        await $.pumpAndSettle();

        // When - Apply dietary filter
        await $.tap(find.byKey(const Key('dietary_filter_button')));
        await $.pumpAndSettle();

        await $.tap(find.text('Vegetarisk'));
        await $.tap(find.text('Laktosfri'));
        await $.pumpAndSettle();

        await $.tap(find.text('Tillämpa filter'));
        await $.pumpAndSettle();

        // Then - Only see compatible recipes
        expect(find.text('Vegetarisk lasagne'), findsOneWidget);
        expect(find.text('Quinoasallad'), findsOneWidget);
        expect(find.text('Köttbullar'), findsNothing);

        // When planning meals, only compatible recipes are suggested
        await $.tap(find.byKey(const Key('monday_lunch_slot')));
        await $.pumpAndSettle();

        final suggestions = find.byType(ListTile);
        expect(suggestions, findsWidgets);
        
        // Verify all suggestions are vegetarian
        for (int i = 0; i < 3; i++) {
          expect(
            find.descendant(
              of: suggestions.at(i),
              matching: find.byIcon(Icons.eco), // Vegetarian icon
            ),
            findsOneWidget,
          );
        }
      },
    );

    patrolTest(
      'Meal plan templates - use and customize',
      ($) async {
        // Given - User wants to use a template
        await $.pumpWidgetAndSettle(const app.ButleryApp());
        // Login is handled automatically in test setup
        
        await $.tap(find.byIcon(Icons.calendar_today));
        await $.pumpAndSettle();

        // When - Select template
        await $.tap(find.byKey(const Key('use_template_button')));
        await $.pumpAndSettle();

        await $.tap(find.text('Medelhavsvecka'));
        await $.pumpAndSettle();

        // Preview template
        expect(find.text('Måndag: Grekisk moussaka'), findsOneWidget);
        expect(find.text('Tisdag: Italiensk risotto'), findsOneWidget);

        // Customize template
        await $.tap(find.text('Anpassa mall'));
        await $.pumpAndSettle();

        // Replace Thursday's meal
        await $.tap(find.descendant(
          of: find.byKey(const Key('thursday_meals')),
          matching: find.byIcon(Icons.swap_horiz),
        ));
        await $.pumpAndSettle();

        await $.enterText(
          find.byKey(const Key('recipe_search_field')),
          'Paella',
        );
        await $.pumpAndSettle();

        await $.tap(find.text('Paella').first);
        await $.pumpAndSettle();

        // Use customized template
        await $.tap(find.text('Använd anpassad mall'));
        await $.pumpAndSettle();

        // Then - Verify template is applied with customization
        expect(find.text('Veckomall tillämpad!'), findsOneWidget);
        expect(find.text('Paella'), findsOneWidget);
      },
    );

    patrolTest(
      'Nutritional overview for meal plan',
      ($) async {
        // Given - User has a complete meal plan
        await $.pumpWidgetAndSettle(const app.ButleryApp());
        // Login is handled automatically in test setup
        await _navigateToExistingMealPlan($);

        // When - View nutritional summary
        await $.tap(find.byKey(const Key('nutrition_overview_button')));
        await $.pumpAndSettle();

        // Then - See daily and weekly nutrition
        expect(find.text('Näringsöversikt'), findsOneWidget);
        
        // Daily averages
        expect(find.text('Genomsnitt per dag'), findsOneWidget);
        expect(find.textContaining('2100 kcal'), findsOneWidget);
        expect(find.textContaining('75g protein'), findsOneWidget);
        expect(find.textContaining('260g kolhydrater'), findsOneWidget);
        expect(find.textContaining('80g fett'), findsOneWidget);

        // Weekly totals
        await $.tap(find.text('Veckototal'));
        await $.pumpAndSettle();
        
        expect(find.textContaining('14,700 kcal'), findsOneWidget);

        // Nutritional balance chart
        expect(find.byType(CustomPaint), findsWidgets); // Charts

        // Recommendations
        expect(find.text('Näringsrekommendationer'), findsOneWidget);
        expect(
          find.textContaining('Bra balans mellan makronäringsämnen'),
          findsOneWidget,
        );
      },
    );

    patrolTest(
      'Export meal plan as PDF',
      ($) async {
        // Given - User has a meal plan to export
        await $.pumpWidgetAndSettle(const app.ButleryApp());
        // Login is handled automatically in test setup
        await _navigateToExistingMealPlan($);

        // When - Export as PDF
        await $.tap(find.byKey(const Key('export_menu_button')));
        await $.pumpAndSettle();

        await $.tap(find.text('Exportera som PDF'));
        await $.pumpAndSettle();

        // Configure export options
        await $.tap(find.text('Inkludera recept'));
        await $.tap(find.text('Inkludera inköpslista'));
        await $.tap(find.text('Inkludera näringsinfo'));
        await $.pumpAndSettle();

        await $.tap(find.text('Skapa PDF'));
        await $.pumpAndSettle();

        // Then - Verify PDF is generated
        expect(find.text('PDF skapad!'), findsOneWidget);
        expect(find.byIcon(Icons.share), findsOneWidget);
        expect(find.byIcon(Icons.download), findsOneWidget);
      },
    );
  });
}

// Helper functions
Future<void> _planDayMeals(
  PatrolIntegrationTester $,
  String day,
  List<String> meals,
) async {
  // Find the day section
  final daySection = find.text(day);
  await $.scrollUntilVisible(finder: daySection);
  
  // Add breakfast
  await $.tap(find.descendant(
    of: find.byKey(Key('${day.toLowerCase()}_breakfast')),
    matching: find.byIcon(Icons.add),
  ));
  await $.pumpAndSettle();
  
  await $.tap(find.text(meals[0]));
  await $.pumpAndSettle();

  // Add lunch
  await $.tap(find.descendant(
    of: find.byKey(Key('${day.toLowerCase()}_lunch')),
    matching: find.byIcon(Icons.add),
  ));
  await $.pumpAndSettle();
  
  await $.tap(find.text(meals[1]));
  await $.pumpAndSettle();

  // Add dinner
  await $.tap(find.descendant(
    of: find.byKey(Key('${day.toLowerCase()}_dinner')),
    matching: find.byIcon(Icons.add),
  ));
  await $.pumpAndSettle();
  
  await $.tap(find.text(meals[2]));
  await $.pumpAndSettle();
}

Future<void> _navigateToExistingMealPlan(PatrolIntegrationTester $) async {
  await $.tap(find.byIcon(Icons.calendar_today));
  await $.pumpAndSettle();
  
  // Assuming there's already a meal plan for current week
  expect(find.text('Nuvarande vecka'), findsOneWidget);
}

Future<void> _createCompleteMealPlan(PatrolIntegrationTester $) async {
  await $.tap(find.byIcon(Icons.calendar_today));
  await $.pumpAndSettle();
  
  await $.tap(find.byKey(const Key('create_meal_plan_button')));
  await $.pumpAndSettle();
  
  // Quick fill entire week
  await $.tap(find.text('Snabbfyll vecka'));
  await $.pumpAndSettle();
  
  await $.tap(find.text('Balanserad vecka'));
  await $.pumpAndSettle();
  
  await $.tap(find.text('Skapa'));
  await $.pumpAndSettle();
}