import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Widget under test
import 'package:butlery/widgets/social/group_shared_shopping_list_card.dart';

// Dependencies - ultrathink production code analysis
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/widgets/common/user_avatar.dart';

// Test infrastructure 
import '../../infrastructure/helpers/base_widget_test.dart';
import '../../infrastructure/factories/shopping_list_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  // Initialize test environment  
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('GroupSharedShoppingListCard Ultrathink Widget Tests', () {
    late MockGroupContentViewModel mockGroupViewModel;
    late MockUnifiedShoppingService mockShoppingService;
    
    // Swedish test data - ultrathink realistic patterns
    final testShoppingList = ShoppingListFactory.build(
      id: 'list_kottbullar_123',
      name: 'Veckans inköpslista',
      description: 'Ingredienser för svenska klassiker hela veckan',
      ownerDisplayName: 'Anna Andersson',
      type: ListType.collaborative,
      items: [
        ShoppingListFactory.buildItem(
          id: 'item_kott_123',
          name: 'Köttfärs',
          amount: 500.0,
          unit: 'g',
          bought: false,
        ),
        ShoppingListFactory.buildItem(
          id: 'item_potatis_456',
          name: 'Potatis',
          amount: 1.0,
          unit: 'kg',
          bought: true,
        ),
        ShoppingListFactory.buildItem(
          id: 'item_graddde_789',
          name: 'Grädde',
          amount: 3.0,
          unit: 'dl',
          bought: false,
        ),
      ],
    );

    void setupDefaultMocks() {
      // Mock GroupContentViewModel
      when(() => mockGroupViewModel.isLoading).thenReturn(false);
      when(() => mockGroupViewModel.error).thenReturn(null);
      
      // Mock UnifiedShoppingService
      when(() => mockShoppingService.createPersonalList(
        any(),
        items: any(named: 'items'),
      )).thenAnswer((_) async => 'new_personal_list_123');
    }

    setUp(() async {
      await BaseWidgetTest.setupWidget();
      await TestServiceLocator.initialize();
      
      mockGroupViewModel = MockGroupContentViewModel();
      mockShoppingService = MockUnifiedShoppingService();

      // Register service mock
      TestServiceLocator.registerMock<UnifiedShoppingService>(mockShoppingService);

      // Default mock setup - comprehensive state coverage
      setupDefaultMocks();
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create properly sized widget - ultrathink layout solution
    Widget createTestWidget({
      UnifiedShoppingList? shoppingList,
    }) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'), // Swedish locale
        home: Scaffold(
          body: Builder(
            builder: (context) => SingleChildScrollView(
              child: GroupSharedShoppingListCard.build(
                context,
                mockGroupViewModel,
                shoppingList ?? testShoppingList,
              ),
            ),
          ),
        ),
      );
    }

    group('Basic Widget Rendering - Facade Pattern', () {
      testWidgets('renders complete shopping list card with Swedish text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Core UI elements - Swedish localization
        expect(find.text('Veckans inköpslista'), findsOneWidget);
        expect(find.text('Ingredienser för svenska klassiker hela veckan'), findsOneWidget);
        expect(find.text('Delad av Anna Andersson'), findsOneWidget);
        expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
      });

      testWidgets('shows collaborative badge when list is collaborative', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Kollaborativ'), findsOneWidget);
        expect(find.text('Inköpslista'), findsOneWidget);
      });

      testWidgets('hides collaborative badge for non-collaborative lists', (WidgetTester tester) async {
        final personalList = ShoppingListFactory.build(
          id: 'personal_list_123',
          name: 'Personlig lista',
          type: ListType.personal,
          ownerDisplayName: 'Anna Andersson',
          items: testShoppingList.items,
        );
        
        await tester.pumpWidget(createTestWidget(shoppingList: personalList));

        expect(find.text('Kollaborativ'), findsNothing);
        expect(find.text('Inköpslista'), findsOneWidget);
      });

      testWidgets('displays owner avatar and info correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Delad av Anna Andersson'), findsOneWidget);
        // Avatar is rendered through UserAvatar widget
        expect(find.byType(UserAvatar), findsOneWidget);
      });
    });

    group('Shopping List Statistics - Swedish UX', () {
      testWidgets('shows correct Swedish statistics chips', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Statistics with Swedish labels
        expect(find.text('3'), findsOneWidget); // Total items
        expect(find.text('totalt'), findsOneWidget);
        expect(find.text('1'), findsOneWidget); // Bought items (potato is bought)
        expect(find.text('köpta'), findsOneWidget);
        expect(find.text('2'), findsOneWidget); // Remaining items
        expect(find.text('kvar'), findsOneWidget);
      });

      testWidgets('displays correct progress bar value', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        
        // 1 out of 3 items bought = 1/3 ≈ 0.33
        expect(progressIndicator.value, closeTo(1.0 / 3.0, 0.01));
      });

      testWidgets('shows success color when all items completed', (WidgetTester tester) async {
        final completedList = testShoppingList.copyWith(
          items: testShoppingList.items.map((item) => 
            item.copyWith(bought: true)
          ).toList(),
        );

        await tester.pumpWidget(createTestWidget(shoppingList: completedList));

        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        
        expect(progressIndicator.value, equals(1.0));
        expect(
          (progressIndicator.valueColor as AlwaysStoppedAnimation).value,
          equals(AppColors.success),
        );
      });
    });

    group('Swedish Time Formatting', () {
      testWidgets('shows "Delad just nu" for very recent lists', (WidgetTester tester) async {
        final recentList = ShoppingListFactory.build(
          name: testShoppingList.name,
          type: testShoppingList.type,
          ownerDisplayName: testShoppingList.ownerDisplayName,
          items: testShoppingList.items,
          createdAt: DateTime.now().subtract(const Duration(seconds: 30)),
        );

        await tester.pumpWidget(createTestWidget(shoppingList: recentList));

        expect(find.text('Delad just nu'), findsOneWidget);
      });

      testWidgets('shows minutes for recent sharing', (WidgetTester tester) async {
        final minutesAgoList = ShoppingListFactory.build(
          name: testShoppingList.name,
          type: testShoppingList.type,
          ownerDisplayName: testShoppingList.ownerDisplayName,
          items: testShoppingList.items,
          createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        );

        await tester.pumpWidget(createTestWidget(shoppingList: minutesAgoList));

        expect(find.text('Delad 15 min sedan'), findsOneWidget);
      });

      testWidgets('shows hours for same day sharing', (WidgetTester tester) async {
        final hoursAgoList = ShoppingListFactory.build(
          name: testShoppingList.name,
          type: testShoppingList.type,
          ownerDisplayName: testShoppingList.ownerDisplayName,
          items: testShoppingList.items,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        );

        await tester.pumpWidget(createTestWidget(shoppingList: hoursAgoList));

        expect(find.text('Delad 3 tim sedan'), findsOneWidget);
      });

      testWidgets('shows days for recent sharing within week', (WidgetTester tester) async {
        final daysAgoList = ShoppingListFactory.build(
          name: testShoppingList.name,
          type: testShoppingList.type,
          ownerDisplayName: testShoppingList.ownerDisplayName,
          items: testShoppingList.items,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        );

        await tester.pumpWidget(createTestWidget(shoppingList: daysAgoList));

        expect(find.text('Delad 2 dagar sedan'), findsOneWidget);
      });
    });

    group('Action Buttons - Swedish UX', () {
      testWidgets('shows all action buttons with Swedish text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Visa lista'), findsOneWidget);
        expect(find.text('Importera'), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsOneWidget);
        expect(find.byIcon(Icons.download), findsOneWidget);
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      });

      testWidgets('handles view list button tap', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text('Visa lista'));
        await tester.pump();

        // Navigation would be handled by the app router
        // Verify the button responds to tap
        expect(find.text('Visa lista'), findsOneWidget);
      });

      testWidgets('shows import confirmation dialog', (WidgetTester tester) async {
        // Mock DialogFactory.showConfirmation to return true
        when(() => DialogFactory.showConfirmation(
          any(),
          title: any(named: 'title'),
          message: any(named: 'message'),
          confirmText: any(named: 'confirmText'),
        )).thenAnswer((_) async => true);

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.text('Importera'));
        await tester.pump();

        // Verify service was called for import
        verify(() => mockShoppingService.createPersonalList(
          'Veckans inköpslista (Kopia)',
          items: any(named: 'items'),
        )).called(1);
      });
    });

    group('More Actions Menu - Swedish UX', () {
      testWidgets('shows more actions bottom sheet with Swedish options', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300)); // Animation

        expect(find.text('Kopiera lista'), findsOneWidget);
        expect(find.text('Dela vidare'), findsOneWidget);
        expect(find.text('Rapportera'), findsOneWidget);
        expect(find.byIcon(Icons.copy), findsOneWidget);
        expect(find.byIcon(Icons.share), findsOneWidget);
        expect(find.byIcon(Icons.report), findsOneWidget);
      });

      testWidgets('handles copy to clipboard action', (WidgetTester tester) async {
        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter/platform'), 
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              return null;
            }
            return null;
          }
        );

        await tester.pumpWidget(createTestWidget());

        // Open more actions menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap copy action
        await tester.tap(find.text('Kopiera lista'));
        await tester.pump();

        // Should show success snackbar
        expect(find.text('Inköpslista kopierad till urklipp!'), findsOneWidget);
      });

      testWidgets('shows sharing options when share is tapped', (WidgetTester tester) async {
        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter/platform'), 
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              return null;
            }
            return null;
          }
        );

        await tester.pumpWidget(createTestWidget());

        // Open more actions menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap share action
        await tester.tap(find.text('Dela vidare'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Dela inköpslista'), findsOneWidget);
        expect(find.text('Kopierat till urklipp'), findsOneWidget);
        expect(find.text('Dela med vänner i Butlery'), findsOneWidget);
      });
    });

    group('Report Functionality - Swedish Moderation', () {
      testWidgets('shows Swedish report dialog with reason options', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Open more actions menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap report action
        await tester.tap(find.text('Rapportera'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Rapportera innehåll'), findsOneWidget);
        expect(find.text('Varför vill du rapportera denna inköpslista?'), findsOneWidget);
        expect(find.text('Olämpligt innehåll'), findsOneWidget);
        expect(find.text('Spam eller reklam'), findsOneWidget);
        expect(find.text('Felaktig information'), findsOneWidget);
        expect(find.text('Upphovsrättsintrång'), findsOneWidget);
        expect(find.text('Annat'), findsOneWidget);
      });

      testWidgets('enables report button when reason is selected', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Open more actions menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap report action
        await tester.tap(find.text('Rapportera'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Initially button should be disabled
        final reportButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Rapportera'),
        );
        expect(reportButton.onPressed, isNull);

        // Select a reason
        await tester.tap(find.text('Spam eller reklam'));
        await tester.pump();

        // Button should now be enabled
        final enabledButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Rapportera'),
        );
        expect(enabledButton.onPressed, isNotNull);
      });
    });

    group('Layout and Styling', () {
      testWidgets('applies correct container styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decoration = container.decoration as BoxDecoration;
        
        expect(decoration.color, equals(AppColors.surface));
        expect(decoration.borderRadius, 
          equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
      });

      testWidgets('displays stat chips with correct styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Find stat chip containers
        final statContainers = tester.widgetList<Container>(
          find.descendant(
            of: find.byType(Row),
            matching: find.byType(Container),
          ),
        ).where((container) => 
          container.decoration is BoxDecoration &&
          (container.decoration as BoxDecoration).color != null &&
          ((container.decoration as BoxDecoration).color!.a * 255.0).round() < 255
        );

        expect(statContainers.length, greaterThanOrEqualTo(3)); // At least 3 stat chips
      });

      testWidgets('handles missing description gracefully', (WidgetTester tester) async {
        final listNoDescription = testShoppingList.copyWith(description: null);

        await tester.pumpWidget(createTestWidget(shoppingList: listNoDescription));

        expect(find.text('Veckans inköpslista'), findsOneWidget);
        expect(find.text('Ingredienser för svenska klassiker hela veckan'), findsNothing);
      });

      testWidgets('handles empty description gracefully', (WidgetTester tester) async {
        final listEmptyDescription = testShoppingList.copyWith(description: '');

        await tester.pumpWidget(createTestWidget(shoppingList: listEmptyDescription));

        expect(find.text('Veckans inköpslista'), findsOneWidget);
        expect(find.text(''), findsNothing); // Empty description should not be shown
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles empty shopping list gracefully', (WidgetTester tester) async {
        final emptyList = testShoppingList.copyWith(items: []);

        await tester.pumpWidget(createTestWidget(shoppingList: emptyList));

        expect(find.text('0'), findsNWidgets(3)); // All stat chips show 0
        expect(find.text('totalt'), findsOneWidget);
        expect(find.text('köpta'), findsOneWidget);
        expect(find.text('kvar'), findsOneWidget);

        // Progress bar should be 0
        final progressIndicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressIndicator.value, equals(0.0));
      });

      testWidgets('handles very long list names with ellipsis', (WidgetTester tester) async {
        final longNameList = testShoppingList.copyWith(
          name: 'Mycket lång inköpslista för hela veckan med massa detaljer och information',
        );

        await tester.pumpWidget(createTestWidget(shoppingList: longNameList));

        final titleText = tester.widget<Text>(
          find.text('Mycket lång inköpslista för hela veckan med massa detaljer och information'),
        );
        expect(titleText.overflow, equals(TextOverflow.ellipsis));
        expect(titleText.maxLines, equals(2));
      });

      testWidgets('handles unknown owner gracefully', (WidgetTester tester) async {
        final unknownOwnerList = ShoppingListFactory.build(
          id: testShoppingList.id,
          name: testShoppingList.name,
          type: testShoppingList.type,
          items: testShoppingList.items,
          ownerDisplayName: '',
        );

        await tester.pumpWidget(createTestWidget(shoppingList: unknownOwnerList));

        expect(find.text('Delad av Okänd användare'), findsOneWidget);
      });

      testWidgets('handles import service error gracefully', (WidgetTester tester) async {
        // Mock service to throw error
        when(() => mockShoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        )).thenThrow(Exception('Network error'));

        // Mock DialogFactory.showConfirmation to return true
        when(() => DialogFactory.showConfirmation(
          any(),
          title: any(named: 'title'),
          message: any(named: 'message'),
          confirmText: any(named: 'confirmText'),
        )).thenAnswer((_) async => true);

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.text('Importera'));
        await tester.pump();

        // Should show error snackbar
        expect(find.textContaining('Kunde inte importera listan'), findsOneWidget);
      });

      testWidgets('handles clipboard error gracefully', (WidgetTester tester) async {
        // Mock clipboard to throw error
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter/platform'), 
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              throw PlatformException(code: 'error', message: 'Clipboard error');
            }
            return null;
          }
        );

        await tester.pumpWidget(createTestWidget());

        // Open more actions menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap copy action
        await tester.tap(find.text('Kopiera lista'));
        await tester.pump();

        // Should show error snackbar
        expect(find.textContaining('Kunde inte kopiera listan'), findsOneWidget);
      });
    });

    group('Swedish Friend Sharing Flow', () {
      testWidgets('shows friend sharing options dialog', (WidgetTester tester) async {
        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter/platform'), 
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              return null;
            }
            return null;
          }
        );

        await tester.pumpWidget(createTestWidget());

        // Open more actions menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap share action
        await tester.tap(find.text('Dela vidare'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap share with friends
        await tester.tap(find.text('Dela med vänner i Butlery'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Dela inköpslista'), findsAtLeastNWidgets(1));
        expect(find.text('Vänner'), findsOneWidget);
        expect(find.text('Grupper'), findsOneWidget);
        expect(find.text('Kopiera länk'), findsOneWidget);
      });

      testWidgets('handles friend sharing selection', (WidgetTester tester) async {
        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter/platform'), 
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              return null;
            }
            return null;
          }
        );

        await tester.pumpWidget(createTestWidget());

        // Navigate to friend sharing dialog
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Dela vidare'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Dela med vänner i Butlery'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Select friends option
        await tester.tap(find.text('Vänner'));
        await tester.pump();

        // Should show coming soon message
        expect(find.textContaining('Delning via friends kommer snart!'), findsOneWidget);
      });
    });
  });
}

// Mock classes - use existing production mocks
class MockGroupContentViewModel extends Mock implements GroupContentViewModel {}
class MockUnifiedShoppingService extends Mock implements UnifiedShoppingService {}
class MockDialogFactory extends Mock {
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message, 
    required String confirmText,
  }) async {
    return true;
  }
}