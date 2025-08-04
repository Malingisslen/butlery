import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';
import 'package:butlery/main.dart' as app;
import '../helpers/integration_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Offline Sync E2E Tests', () {
    setUpAll(() async {
      await IntegrationTestHelpers.initializeTestFirebase();
    });
    
    tearDownAll(() async {
      await IntegrationTestHelpers.cleanup();
    });
    
    patrolTest(
      'Offline mode - queue operations and sync when online',
      ($) async {
        await app.main();
        await $.pumpAndSettle();
        
        // Login
        await IntegrationTestHelpers.signInTestUser();
        await $.pumpAndSettle();
        
        // Enable offline mode
        await $.tap(find.byIcon(Icons.menu));
        await $.pumpAndSettle();
        await $.tap(find.text('Inställningar'));
        await $.pumpAndSettle();
        await $.tap(find.byKey(const Key('offline_mode_switch')));
        await $.pumpAndSettle();
        
        // Verify offline indicator
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        
        // Create multiple recipes offline
        for (int i = 0; i < 3; i++) {
          await $.tap(find.byIcon(Icons.add));
          await $.pumpAndSettle();
          await $.tap(find.text('Skriv själv'));
          await $.pumpAndSettle();
          
          await $.enterText(
            find.byKey(const Key('recipe_title_field')),
            'Offline Recipe $i',
          );
          await $.tap(find.text('Spara recept'));
          await $.pumpAndSettle();
        }
        
        // Verify recipes are saved locally
        expect(find.text('Offline Recipe 0'), findsOneWidget);
        expect(find.text('Offline Recipe 1'), findsOneWidget);
        expect(find.text('Offline Recipe 2'), findsOneWidget);
        
        // Verify sync queue indicator
        expect(find.byKey(const Key('sync_queue_badge')), findsOneWidget);
        expect(find.text('3'), findsOneWidget); // Queue count
        
        // Edit a recipe offline
        await $.tap(find.text('Offline Recipe 0'));
        await $.pumpAndSettle();
        await $.tap(find.byIcon(Icons.edit));
        await $.pumpAndSettle();
        
        await $.enterText(
          find.byKey(const Key('recipe_title_field')),
          'Updated Offline Recipe 0',
        );
        await $.tap(find.text('Spara ändringar'));
        await $.pumpAndSettle();
        
        // Delete a recipe offline
        await $.tap(find.byType(BackButton));
        await $.pumpAndSettle();
        await $.longPress(find.text('Offline Recipe 2'));
        await $.pumpAndSettle();
        await $.tap(find.text('Ta bort'));
        await $.pumpAndSettle();
        await $.tap(find.text('Bekräfta'));
        await $.pumpAndSettle();
        
        // Verify queue has grown
        expect(find.text('5'), findsOneWidget); // 3 creates + 1 update + 1 delete
        
        // Go back online
        await $.tap(find.byIcon(Icons.menu));
        await $.pumpAndSettle();
        await $.tap(find.text('Inställningar'));
        await $.pumpAndSettle();
        await $.tap(find.byKey(const Key('offline_mode_switch')));
        await $.pumpAndSettle();
        
        // Wait for sync to complete
        await $.waitUntilVisible(find.byIcon(Icons.cloud_done));
        
        // Verify sync completed
        expect(find.byIcon(Icons.cloud_off), findsNothing);
        expect(find.byKey(const Key('sync_queue_badge')), findsNothing);
        
        // Verify final state
        expect(find.text('Updated Offline Recipe 0'), findsOneWidget);
        expect(find.text('Offline Recipe 1'), findsOneWidget);
        expect(find.text('Offline Recipe 2'), findsNothing); // Deleted
      },
    );
    
    patrolTest(
      'Conflict resolution during sync',
      ($) async {
        await app.main();
        await $.pumpAndSettle();
        
        // Create a recipe online
        await IntegrationTestHelpers.signInTestUser();
        await $.pumpAndSettle();
        
        await $.tap(find.byIcon(Icons.add));
        await $.pumpAndSettle();
        await $.tap(find.text('Skriv själv'));
        await $.pumpAndSettle();
        
        await $.enterText(
          find.byKey(const Key('recipe_title_field')),
          'Conflict Test Recipe',
        );
        await $.tap(find.text('Spara recept'));
        await $.pumpAndSettle();
        
        // Go offline
        await $.tap(find.byIcon(Icons.menu));
        await $.pumpAndSettle();
        await $.tap(find.text('Inställningar'));
        await $.pumpAndSettle();
        await $.tap(find.byKey(const Key('offline_mode_switch')));
        await $.pumpAndSettle();
        
        // Edit recipe offline
        await $.tap(find.text('Conflict Test Recipe'));
        await $.pumpAndSettle();
        await $.tap(find.byIcon(Icons.edit));
        await $.pumpAndSettle();
        
        await $.enterText(
          find.byKey(const Key('recipe_description_field')),
          'Offline edit description',
        );
        await $.tap(find.text('Spara ändringar'));
        await $.pumpAndSettle();
        
        // Simulate server-side change (mock scenario)
        // In a real test, this would modify data on the server
        
        // Go back online
        await $.tap(find.byType(BackButton));
        await $.pumpAndSettle();
        await $.tap(find.byIcon(Icons.menu));
        await $.pumpAndSettle();
        await $.tap(find.text('Inställningar'));
        await $.pumpAndSettle();
        await $.tap(find.byKey(const Key('offline_mode_switch')));
        await $.pumpAndSettle();
        
        // Wait for conflict dialog
        await $.waitUntilVisible(find.text('Synkroniseringskonflikt'));
        
        // Choose to keep local version
        await $.tap(find.text('Behåll lokal version'));
        await $.pumpAndSettle();
        
        // Verify local version was kept
        await $.tap(find.text('Conflict Test Recipe'));
        await $.pumpAndSettle();
        expect(find.text('Offline edit description'), findsOneWidget);
      },
    );
    
    patrolTest(
      'Offline shopping list collaboration',
      ($) async {
        await app.main();
        await $.pumpAndSettle();
        
        await IntegrationTestHelpers.signInTestUser();
        await $.pumpAndSettle();
        
        // Create shopping list
        await $.tap(find.byIcon(Icons.shopping_cart));
        await $.pumpAndSettle();
        await $.tap(find.byIcon(Icons.add));
        await $.pumpAndSettle();
        
        await $.enterText(
          find.byKey(const Key('list_name_field')),
          'Weekly Shopping',
        );
        await $.tap(find.text('Skapa'));
        await $.pumpAndSettle();
        
        // Add items online
        await $.tap(find.text('Lägg till vara'));
        await $.enterText(find.byKey(const Key('item_name_field')), 'Mjölk');
        await $.tap(find.text('Lägg till'));
        await $.pumpAndSettle();
        
        // Go offline
        await $.tap(find.byIcon(Icons.menu));
        await $.pumpAndSettle();
        await $.tap(find.text('Inställningar'));
        await $.pumpAndSettle();
        await $.tap(find.byKey(const Key('offline_mode_switch')));
        await $.pumpAndSettle();
        
        // Add more items offline
        await $.tap(find.text('Lägg till vara'));
        await $.enterText(find.byKey(const Key('item_name_field')), 'Bröd');
        await $.tap(find.text('Lägg till'));
        await $.pumpAndSettle();
        
        await $.tap(find.text('Lägg till vara'));
        await $.enterText(find.byKey(const Key('item_name_field')), 'Ägg');
        await $.tap(find.text('Lägg till'));
        await $.pumpAndSettle();
        
        // Check items offline
        await $.tap(find.text('Mjölk').first);
        await $.pumpAndSettle();
        
        // Verify offline indicator on items
        expect(find.byIcon(Icons.cloud_off), findsWidgets);
        
        // Go back online and sync
        await $.tap(find.byIcon(Icons.menu));
        await $.pumpAndSettle();
        await $.tap(find.text('Inställningar'));
        await $.pumpAndSettle();
        await $.tap(find.byKey(const Key('offline_mode_switch')));
        await $.pumpAndSettle();
        
        // Verify all items synced
        await $.waitUntilVisible(find.byIcon(Icons.cloud_done));
        expect(find.text('Mjölk'), findsOneWidget);
        expect(find.text('Bröd'), findsOneWidget);
        expect(find.text('Ägg'), findsOneWidget);
      },
    );
  });
}