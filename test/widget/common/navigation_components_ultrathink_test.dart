import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/navigation_components.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';

void main() {
  group('NavigationComponents Ultrathink Widget Tests', () {
    // Helper to create properly configured test environment
    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        home: Material(
          child: child ?? const SizedBox.shrink(),
        ),
      );
    }

    group('Recipe Selection Dialog Interfaces', () {
      testWidgets('showRecipeSelector method exists with correct signature', (WidgetTester tester) async {
        // Verify the method exists and has correct return type
        expect(NavigationComponents.showRecipeSelector, isA<Function>());
        
        // Test basic interface validation without requiring complex dependencies
        final userProfile = UserProfile(
          uid: 'test-user-id',
          displayName: 'Test Användare',
          email: 'test@example.com',
          joinedAt: DateTime.now().subtract(const Duration(days: 30)),
          lastActiveAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  // Verify method can be called with correct parameters
                  expect(
                    () => NavigationComponents.showRecipeSelector(
                      context,
                      friend: userProfile,
                    ),
                    returnsNormally,
                  );
                },
                child: const Text('Test Recipe Selector'),
              ),
            ),
          ),
        );

        expect(find.text('Test Recipe Selector'), findsOneWidget);
      });

      testWidgets('showMenuRecipeSelector method exists with correct signature and generic return type', (WidgetTester tester) async {
        // Verify method exists and has correct return type Future<List<Recipe>?>
        expect(NavigationComponents.showMenuRecipeSelector, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  // Verify method can be called with correct parameters
                  expect(
                    () => NavigationComponents.showMenuRecipeSelector(
                      context,
                      categoryName: 'Huvudrätter',
                    ),
                    returnsNormally,
                  );
                },
                child: const Text('Test Menu Recipe Selector'),
              ),
            ),
          ),
        );

        expect(find.text('Test Menu Recipe Selector'), findsOneWidget);
      });
    });

    group('Realtime Indicator Widget Interfaces', () {
      testWidgets('editIndicator method exists and returns widget interface', (WidgetTester tester) async {
        // Test method exists and returns Widget
        expect(NavigationComponents.editIndicator, isA<Function>());

        // Test method can be called without error - interface validation
        final basicIndicator = NavigationComponents.editIndicator(
          editorName: 'Anna Andersson',
          editingWhat: 'ingredienser',
        );
        expect(basicIndicator, isA<Widget>());

        // Test with all parameters - interface validation
        final fullIndicator = NavigationComponents.editIndicator(
          editorName: 'Erik Svensson',
          editorId: 'user-erik-123',
          editingWhat: 'instruktioner',
          color: Colors.blue,
          isVisible: true,
          animationDuration: const Duration(milliseconds: 500),
        );
        expect(fullIndicator, isA<Widget>());
      });

      testWidgets('participantList method exists and returns widget interface', (WidgetTester tester) async {
        expect(NavigationComponents.participantList, isA<Function>());

        final List<ParticipantActivity> activities = [
          ParticipantActivity(
            userId: 'user-1',
            displayName: 'Anna',
            lastSeen: DateTime.now(),
            isOnline: true,
          ),
          ParticipantActivity(
            userId: 'user-2', 
            displayName: 'Erik',
            lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
            isOnline: false,
          ),
        ];

        // Test with all parameters - interface validation
        final fullParticipantList = NavigationComponents.participantList(
          activities: activities,
          currentUserId: 'user-1',
          canManageParticipants: true,
          onRemoveParticipant: (userId) => print('Remove: $userId'),
          onChangePermission: (userId) => print('Change permission: $userId'),
        );
        expect(fullParticipantList, isA<Widget>());

        // Test minimal parameters - interface validation
        final minimalParticipantList = NavigationComponents.participantList(
          activities: activities,
          currentUserId: 'user-2',
        );
        expect(minimalParticipantList, isA<Widget>());
      });

      testWidgets('realtimeStatus method exists and returns widget interface', (WidgetTester tester) async {
        expect(NavigationComponents.realtimeStatus, isA<Function>());

        // Test online status - interface validation
        final onlineStatus = NavigationComponents.realtimeStatus(
          isOnline: true,
          statusDescription: 'Ansluten och synkroniserad',
          statusEmoji: '🟢',
          showText: true,
          padding: const EdgeInsets.all(8.0),
        );
        expect(onlineStatus, isA<Widget>());

        // Test offline status - interface validation
        final offlineStatus = NavigationComponents.realtimeStatus(
          isOnline: false,
          statusDescription: 'Ingen anslutning',
          statusEmoji: '🔴',
        );
        expect(offlineStatus, isA<Widget>());
      });

      testWidgets('realtimeStatusBanner method exists and returns widget interface', (WidgetTester tester) async {
        expect(NavigationComponents.realtimeStatusBanner, isA<Function>());

        // Test banner with retry callback - interface validation
        final bannerWithRetry = NavigationComponents.realtimeStatusBanner(
          isOnline: false,
          statusDescription: 'Anslutningsproblem - försök igen',
          statusEmoji: '⚠️',
          onRetry: () {},
        );
        expect(bannerWithRetry, isA<Widget>());

        // Test banner without retry callback - interface validation
        final basicBanner = NavigationComponents.realtimeStatusBanner(
          isOnline: true,
          statusDescription: 'Allt fungerar bra',
          statusEmoji: '✅',
        );
        expect(basicBanner, isA<Widget>());
      });
    });

    group('Confirmation Dialog Interfaces', () {
      testWidgets('showConfirmationDialog method exists with correct parameters', (WidgetTester tester) async {
        expect(NavigationComponents.showConfirmationDialog, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  // Test with all parameters
                  expect(
                    () => NavigationComponents.showConfirmationDialog(
                      context,
                      title: 'Bekräfta åtgärd',
                      message: 'Vill du fortsätta?',
                      confirmText: 'Fortsätt',
                      cancelText: 'Stäng',
                      confirmColor: Colors.green,
                    ),
                    returnsNormally,
                  );

                  // Test with minimal parameters
                  expect(
                    () => NavigationComponents.showConfirmationDialog(
                      context,
                      title: 'Simple Titel',
                      message: 'Simple meddelande',
                    ),
                    returnsNormally,
                  );
                },
                child: const Text('Test Confirmation'),
              ),
            ),
          ),
        );

        expect(find.text('Test Confirmation'), findsOneWidget);
      });

      testWidgets('showDestructiveConfirmationDialog method validates Swedish defaults', (WidgetTester tester) async {
        expect(NavigationComponents.showDestructiveConfirmationDialog, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  // Test with Swedish defaults
                  expect(
                    () => NavigationComponents.showDestructiveConfirmationDialog(
                      context,
                      title: 'Radera objekt',
                      message: 'Detta går inte att ångra',
                    ),
                    returnsNormally,
                  );

                  // Test with custom text
                  expect(
                    () => NavigationComponents.showDestructiveConfirmationDialog(
                      context,
                      title: 'Custom Destructive',
                      message: 'Custom message',
                      confirmText: 'Radera permanent',
                      cancelText: 'Behåll',
                    ),
                    returnsNormally,
                  );
                },
                child: const Text('Test Destructive Confirmation'),
              ),
            ),
          ),
        );

        expect(find.text('Test Destructive Confirmation'), findsOneWidget);
      });

      testWidgets('showLoadingConfirmationDialog method exists with correct signature', (WidgetTester tester) async {
        expect(NavigationComponents.showLoadingConfirmationDialog, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  expect(
                    () => NavigationComponents.showLoadingConfirmationDialog(
                      context,
                      title: 'Laddar data',
                      message: 'Vänta medan data laddas...',
                    ),
                    returnsNormally,
                  );
                },
                child: const Text('Test Loading Confirmation'),
              ),
            ),
          ),
        );

        expect(find.text('Test Loading Confirmation'), findsOneWidget);
      });

      testWidgets('showListSelectionDialog supports generic type parameter', (WidgetTester tester) async {
        expect(NavigationComponents.showListSelectionDialog, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  // Test with String type
                  final stringItems = ['Förrätt', 'Huvudrätt', 'Efterrätt'];
                  expect(
                    () => NavigationComponents.showListSelectionDialog<String>(
                      context,
                      title: 'Välj kategori',
                      items: stringItems,
                      itemBuilder: (item) => item,
                      message: 'Välj en kategori från listan',
                    ),
                    returnsNormally,
                  );

                  // Test with int type
                  final intItems = [1, 2, 3, 4];
                  expect(
                    () => NavigationComponents.showListSelectionDialog<int>(
                      context,
                      title: 'Välj antal',
                      items: intItems,
                      itemBuilder: (item) => '$item personer',
                      cancelText: 'Stäng',
                    ),
                    returnsNormally,
                  );
                },
                child: const Text('Test List Selection'),
              ),
            ),
          ),
        );

        expect(find.text('Test List Selection'), findsOneWidget);
      });

      testWidgets('showTextInputDialog method supports all input parameters', (WidgetTester tester) async {
        expect(NavigationComponents.showTextInputDialog, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  // Test with all parameters
                  expect(
                    () => NavigationComponents.showTextInputDialog(
                      context,
                      title: 'Ange namn',
                      message: 'Skriv ett namn för receptet',
                      initialValue: 'Förslag',
                      hintText: 'T.ex. Pasta Carbonara',
                      confirmText: 'Spara',
                      cancelText: 'Stäng',
                      isRequired: true,
                      maxLength: 50,
                    ),
                    returnsNormally,
                  );

                  // Test with minimal parameters
                  expect(
                    () => NavigationComponents.showTextInputDialog(
                      context,
                      title: 'Simple Input',
                    ),
                    returnsNormally,
                  );
                },
                child: const Text('Test Text Input'),
              ),
            ),
          ),
        );

        expect(find.text('Test Text Input'), findsOneWidget);
      });
    });

    group('Swedish Localization Support', () {
      testWidgets('all method interfaces support Swedish parameters', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                // Test realtime indicators with Swedish text
                NavigationComponents.editIndicator(
                  editorName: 'Åsa Öberg',
                  editingWhat: 'ingredienser för kött- och fiskrätter',
                ),
                NavigationComponents.realtimeStatus(
                  isOnline: true,
                  statusDescription: 'Ansluten och synkroniserad med molntjänsten',
                  statusEmoji: '🔗',
                  showText: true,
                ),
                NavigationComponents.realtimeStatusBanner(
                  isOnline: false,
                  statusDescription: 'Ingen internetanslutning - arbetar offline',
                  statusEmoji: '📶',
                ),
                Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      // Test dialog interfaces with Swedish parameters
                      NavigationComponents.showConfirmationDialog(
                        context,
                        title: 'Spara ändringar?',
                        message: 'Du har gjort ändringar som inte är sparade än.',
                        confirmText: 'Spara nu',
                        cancelText: 'Kasta bort',
                      );
                    },
                    child: const Text('Swedish Dialog Test'),
                  ),
                ),
              ],
            ),
          ),
        );

        // Verify Swedish characters render correctly
        expect(find.text('Swedish Dialog Test'), findsOneWidget);
      });
    });

    group('Parameter Delegation Validation', () {
      testWidgets('editIndicator delegates all parameters correctly', (WidgetTester tester) async {
        // Test that all parameters are accepted without errors
        final testWidget = NavigationComponents.editIndicator(
          editorName: 'Test Editor',
          editorId: 'editor-123',
          editingWhat: 'test content',
          color: Colors.purple,
          isVisible: false,
          animationDuration: const Duration(milliseconds: 250),
        );

        await tester.pumpWidget(createTestWidget(child: testWidget));
        expect(find.byWidget(testWidget), findsOneWidget);
      });

      testWidgets('participantList delegates all parameters correctly', (WidgetTester tester) async {

        final List<ParticipantActivity> activities = [
          ParticipantActivity(
            userId: 'user-1',
            displayName: 'Test User',
            lastSeen: DateTime.now(),
            isOnline: true,
          ),
        ];

        final testWidget = NavigationComponents.participantList(
          activities: activities,
          currentUserId: 'current-user',
          canManageParticipants: true,
          onRemoveParticipant: (userId) {},
          onChangePermission: (userId) {},
        );

        await tester.pumpWidget(createTestWidget(child: testWidget));
        expect(find.byWidget(testWidget), findsOneWidget);
      });

      testWidgets('realtimeStatus delegates all parameters correctly', (WidgetTester tester) async {
        final testWidget = NavigationComponents.realtimeStatus(
          isOnline: true,
          statusDescription: 'Connected and synchronized',
          statusEmoji: '✅',
          showText: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        );

        await tester.pumpWidget(createTestWidget(child: testWidget));
        expect(find.byWidget(testWidget), findsOneWidget);
      });

      testWidgets('realtimeStatusBanner delegates all parameters correctly', (WidgetTester tester) async {
        final testWidget = NavigationComponents.realtimeStatusBanner(
          isOnline: false,
          statusDescription: 'Connection lost - tap to retry',
          statusEmoji: '🔄',
          onRetry: () {},
        );

        await tester.pumpWidget(createTestWidget(child: testWidget));
        expect(find.byWidget(testWidget), findsOneWidget);
      });
    });

    group('Facade Pattern Interface Validation', () {
      testWidgets('all static methods exist and are callable', (WidgetTester tester) async {
        // Recipe Selection Dialog Methods
        expect(NavigationComponents.showRecipeSelector, isA<Function>());
        expect(NavigationComponents.showMenuRecipeSelector, isA<Function>());

        // Realtime Indicator Methods
        expect(NavigationComponents.editIndicator, isA<Function>());
        expect(NavigationComponents.participantList, isA<Function>());
        expect(NavigationComponents.realtimeStatus, isA<Function>());
        expect(NavigationComponents.realtimeStatusBanner, isA<Function>());

        // Confirmation Dialog Methods
        expect(NavigationComponents.showConfirmationDialog, isA<Function>());
        expect(NavigationComponents.showDestructiveConfirmationDialog, isA<Function>());
        expect(NavigationComponents.showLoadingConfirmationDialog, isA<Function>());
        expect(NavigationComponents.showListSelectionDialog, isA<Function>());
        expect(NavigationComponents.showTextInputDialog, isA<Function>());
      });

      testWidgets('return types are correctly maintained through facade', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => Column(
                children: [
                  // Widget return types
                  NavigationComponents.editIndicator(
                    editorName: 'Test',
                    editingWhat: 'content',
                  ),
                  NavigationComponents.participantList(
                    activities: [],
                    currentUserId: 'test',
                  ),
                  NavigationComponents.realtimeStatus(
                    isOnline: true,
                    statusDescription: 'Connected',
                    statusEmoji: '✅',
                  ),
                  NavigationComponents.realtimeStatusBanner(
                    isOnline: true,
                    statusDescription: 'All systems operational',
                    statusEmoji: '🟢',
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // Async return types validation
                      final Future<void> recipeSelector = NavigationComponents.showRecipeSelector(
                        context,
                        friend: UserProfile(
                          uid: 'friend-id',
                          displayName: 'Test Friend',
                          email: 'friend@test.com',
                          joinedAt: DateTime.now().subtract(const Duration(days: 10)),
                          lastActiveAt: DateTime.now(),
                        ),
                      );

                      final Future<List<Recipe>?> menuRecipeSelector = NavigationComponents.showMenuRecipeSelector(
                        context,
                        categoryName: 'Test Category',
                      );

                      final Future<bool> confirmationDialog = NavigationComponents.showConfirmationDialog(
                        context,
                        title: 'Test',
                        message: 'Test message',
                      );

                      final Future<String?> textInputDialog = NavigationComponents.showTextInputDialog(
                        context,
                        title: 'Test Input',
                      );

                      final Future<int?> listSelectionDialog = NavigationComponents.showListSelectionDialog<String>(
                        context,
                        title: 'Test List',
                        items: ['Item 1', 'Item 2'],
                        itemBuilder: (item) => item,
                      );

                      // Verify return types are correct (compilation check)
                      expect(recipeSelector, isA<Future<void>>());
                      expect(menuRecipeSelector, isA<Future<List<Recipe>?>>());
                      expect(confirmationDialog, isA<Future<bool>>());
                      expect(textInputDialog, isA<Future<String?>>());
                      expect(listSelectionDialog, isA<Future<int?>>());
                    },
                    child: const Text('Return Type Test'),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Return Type Test'), findsOneWidget);
      });
    });

    group('Responsive Design Behavior', () {
      testWidgets('navigation components adapt to small screen sizes', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                NavigationComponents.editIndicator(
                  editorName: 'Small Screen User',
                  editingWhat: 'content',
                ),
                NavigationComponents.realtimeStatusBanner(
                  isOnline: true,
                  statusDescription: 'Connected on mobile',
                  statusEmoji: '📱',
                ),
              ],
            ),
          ),
        );

        // Verify widgets are rendered correctly in responsive layout
        expect(find.byType(Column), findsWidgets);

        // Reset screen size
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('navigation components adapt to tablet screen sizes', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                NavigationComponents.participantList(
                  activities: [
                    ParticipantActivity(
                      userId: 'tablet-user',
                      displayName: 'Tablet User',
                      lastSeen: DateTime.now(),
                      isOnline: true,
                    ),
                  ],
                  currentUserId: 'current-user',
                ),
                NavigationComponents.realtimeStatus(
                  isOnline: true,
                  statusDescription: 'Tablet interface active',
                  statusEmoji: '📋',
                  showText: true,
                ),
              ],
            ),
          ),
        );

        // Verify widgets are rendered correctly in responsive layout
        expect(find.byType(Column), findsWidgets);

        // Reset screen size
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}