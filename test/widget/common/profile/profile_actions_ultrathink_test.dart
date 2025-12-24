import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Widget under test
import 'package:butlery/widgets/common/profile/profile_actions.dart';

// Dependencies - ultrathink production code analysis
import 'package:butlery/services/backup_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

// Test infrastructure
import '../../../infrastructure/helpers/base_widget_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  // Initialize test environment
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ProfileActions Ultrathink Widget Tests', () {
    late MockBackupService mockBackupService;
    late MockAuthRepository mockAuthRepository;
    late MockAuthService mockAuthService;
    late MockUserService mockUserService;
    late MockUnifiedRecipeService mockRecipeService;
    late MockOfflineService mockOfflineService;
    late MockAnalyticsService mockAnalyticsService;

    void setupDefaultMocks() {
      // Mock BackupService
      when(() => mockBackupService.exportToFile()).thenAnswer((_) async =>
          BackupResult.success(
              message: 'Mock backup complete',
              filePath: 'mock/path',
              recipeCount: 10));
      when(() => mockBackupService.importFromFile()).thenAnswer(
          (_) async => const ImportResult(successCount: 5, skipCount: 0));

      // Mock AuthRepository
      when(() => mockAuthRepository.signOut()).thenAnswer((_) async {});

      // Mock all other services
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockUserService.currentUserProfile).thenReturn(null);
    }

    setUp(() async {
      await BaseWidgetTest.setupWidget();
      await TestServiceLocator.initialize();

      mockBackupService = MockBackupService();
      mockAuthRepository = MockAuthRepository();
      mockAuthService = MockAuthService();
      mockUserService = MockUserService();
      mockRecipeService = MockUnifiedRecipeService();
      mockOfflineService = MockOfflineService();
      mockAnalyticsService = MockAnalyticsService();

      // Register service mocks
      TestServiceLocator.registerMock<BackupService>(mockBackupService);
      TestServiceLocator.registerMock<AuthRepository>(mockAuthRepository);
      TestServiceLocator.registerMock<AuthService>(mockAuthService);
      TestServiceLocator.registerMock<UserService>(mockUserService);
      TestServiceLocator.registerMock<UnifiedRecipeService>(mockRecipeService);
      TestServiceLocator.registerMock<OfflineService>(mockOfflineService);
      TestServiceLocator.registerMock<AnalyticsService>(mockAnalyticsService);

      // Default mock setup
      setupDefaultMocks();
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create properly sized widget - ultrathink layout solution
    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'), // Swedish locale
        home: Scaffold(
          body: SingleChildScrollView(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
    }

    // Helper to get BuildContext from rendered widget
    BuildContext getContext(WidgetTester tester) {
      return tester.element(find.byType(Scaffold));
    }

    // Helper to create test widget with ProfileActions method
    Future<void> pumpProfileWidget(
      WidgetTester tester,
      Widget Function(BuildContext) builder,
    ) async {
      await tester.pumpWidget(createTestWidget());
      final context = getContext(tester);
      final widget = builder(context);
      await tester.pumpWidget(createTestWidget(child: widget));
    }

    group('Basic Menu Items - Foundation UI', () {
      testWidgets('renders basic menu item with Swedish text and styling',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildMenuItem(
            context,
            title: 'Notifikationer',
            subtitle: 'Hantera dina meddelanden',
            icon: Icons.notifications,
            onTap: () {},
          ),
        );

        // Core UI elements - Swedish localization
        expect(find.text('Notifikationer'), findsOneWidget);
        expect(find.text('Hantera dina meddelanden'), findsOneWidget);
        expect(find.byIcon(Icons.notifications), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);

        // Styling verification
        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
      });

      testWidgets('renders notification menu item with badge count',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildNotificationMenuItem(
            context,
            title: 'Meddelanden',
            subtitle: 'Du har nya meddelanden',
            icon: Icons.message,
            count: 5,
            onTap: () {},
          ),
        );

        // Core UI elements
        expect(find.text('Meddelanden'), findsOneWidget);
        expect(find.text('Du har nya meddelanden'), findsOneWidget);
        expect(find.byIcon(Icons.message), findsOneWidget);
        expect(find.text('5'), findsOneWidget);

        // Badge styling
        final badgeContainer = tester
            .widgetList<Container>(
              find.byType(Container),
            )
            .firstWhere((container) =>
                container.decoration is BoxDecoration &&
                (container.decoration as BoxDecoration).color ==
                    AppColors.error);
        expect(badgeContainer, isNotNull);
      });

      testWidgets('handles notification badge count over 99',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildNotificationMenuItem(
            context,
            title: 'Meddelanden',
            subtitle: 'Många meddelanden',
            icon: Icons.message,
            count: 150,
          ),
        );

        expect(find.text('99+'), findsOneWidget);
        expect(find.text('150'), findsNothing);
      });

      testWidgets('hides badge when count is zero',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildNotificationMenuItem(
            context,
            title: 'Meddelanden',
            subtitle: 'Inga nya meddelanden',
            icon: Icons.message,
            count: 0,
          ),
        );

        // No badge should be visible
        expect(find.text('0'), findsNothing);
        final containers = tester.widgetList<Container>(find.byType(Container));
        final badgeContainers = containers.where((container) =>
            container.decoration is BoxDecoration &&
            (container.decoration as BoxDecoration).color == AppColors.error);
        expect(badgeContainers, isEmpty);
      });
    });

    group('Data Backup Section - Swedish UX', () {
      testWidgets('renders complete backup section with Swedish text',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildDataBackupSection(context),
        );

        // Section header
        expect(find.text('Data & Backup'), findsOneWidget);

        // Backup and restore buttons
        expect(find.text('Ladda ner backup'), findsOneWidget);
        expect(find.text('Spara alla recept som JSON'), findsOneWidget);
        expect(find.text('Återställ från backup'), findsOneWidget);
        expect(find.text('Importera recept från JSON'), findsOneWidget);

        // Icons
        expect(find.byIcon(Icons.download), findsOneWidget);
        expect(find.byIcon(Icons.upload), findsOneWidget);

        // Divider styling
        expect(find.byType(Divider), findsOneWidget);
        final divider = tester.widget<Divider>(find.byType(Divider));
        expect(divider.color, equals(AppColors.divider));
      });

      testWidgets('handles successful backup operation',
          (WidgetTester tester) async {
        when(() => mockBackupService.exportToFile()).thenAnswer((_) async =>
            BackupResult.success(
                message: 'Backup complete',
                filePath: 'mock/path',
                recipeCount: 10));

        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildDataBackupSection(context),
        );

        // Tap backup button
        await tester.tap(find.text('Ladda ner backup'));
        await tester.pumpAndSettle();

        // Verify service was called
        verify(() => mockBackupService.exportToFile()).called(1);

        // Check for success snackbar
        expect(find.text('Backup skapad framgångsrikt!'), findsOneWidget);
      });

      testWidgets('handles backup failure with error message',
          (WidgetTester tester) async {
        when(() => mockBackupService.exportToFile())
            .thenAnswer((_) async => BackupResult.error('Network error'));

        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildDataBackupSection(context),
        );

        await tester.tap(find.text('Ladda ner backup'));
        await tester.pumpAndSettle();

        // Additional pump for async operations
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Check for error snackbar
        expect(find.textContaining('Backup misslyckades'), findsOneWidget);
      });

      testWidgets('handles successful restore operation',
          (WidgetTester tester) async {
        when(() => mockBackupService.importFromFile()).thenAnswer(
            (_) async => const ImportResult(successCount: 5, skipCount: 0));

        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildDataBackupSection(context),
        );

        await tester.tap(find.text('Återställ från backup'));
        await tester.pumpAndSettle();

        verify(() => mockBackupService.importFromFile()).called(1);
        expect(find.text('Återställning genomförd!'), findsOneWidget);
      });

      testWidgets('handles restore failure with error message',
          (WidgetTester tester) async {
        when(() => mockBackupService.importFromFile())
            .thenAnswer((_) async => ImportResult.error('File error'));

        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildDataBackupSection(context),
        );

        await tester.tap(find.text('Återställ från backup'));
        await tester.pumpAndSettle();

        // Additional pump for async operations
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
            find.textContaining('Återställning misslyckades'), findsOneWidget);
      });
    });

    group('Logout Section - Security Flow', () {
      testWidgets('renders logout section with Swedish button',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildLogoutSection(context),
        );

        // Logout button
        expect(find.text('Logga ut'), findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);

        // Divider
        expect(find.byType(Divider), findsOneWidget);
      });

      testWidgets('shows logout confirmation dialog',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildLogoutSection(context),
        );

        await tester.tap(find.text('Logga ut'));
        await tester.pumpAndSettle();

        // Check dialog content
        expect(
            find.text('Logga ut'),
            findsNWidgets(
                3)); // Original button + dialog title + confirmation button
        expect(
            find.text('Är du säker på att du vill logga ut?'), findsOneWidget);
        expect(find.text('Avbryt'), findsOneWidget);
      });

      testWidgets('handles logout cancellation', (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildLogoutSection(context),
        );

        await tester.tap(find.text('Logga ut'));
        await tester.pumpAndSettle();

        // Cancel logout
        await tester.tap(find.text('Avbryt'));
        await tester.pumpAndSettle();

        // Verify no logout was performed
        verifyNever(() => mockAuthRepository.signOut());
      });

      testWidgets('handles successful logout', (WidgetTester tester) async {
        when(() => mockAuthRepository.signOut()).thenAnswer((_) async {});

        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildLogoutSection(context),
        );

        await tester.tap(find.text('Logga ut'));
        await tester.pumpAndSettle();

        // Confirm logout
        final logoutButtons = find.text('Logga ut');
        await tester.tap(logoutButtons.last); // The confirmation button
        await tester.pumpAndSettle();

        // Verify logout was called
        verify(() => mockAuthRepository.signOut()).called(1);
      });

      testWidgets('handles logout failure with error message',
          (WidgetTester tester) async {
        when(() => mockAuthRepository.signOut())
            .thenThrow(Exception('Network error'));

        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildLogoutSection(context),
        );

        await tester.tap(find.text('Logga ut'));
        await tester.pumpAndSettle();

        // Confirm logout
        final logoutButtons = find.text('Logga ut');
        await tester.tap(logoutButtons.last);
        await tester.pumpAndSettle();

        // Additional pump for async operations
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Check for error snackbar
        expect(find.textContaining('Utloggning misslyckades'), findsOneWidget);
      });
    });

    group('Account Management Section - GDPR Compliance', () {
      testWidgets('renders account management section with warning',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildAccountManagementSection(context),
        );

        // Section header
        expect(find.text('Kontohantering'), findsOneWidget);

        // Delete account button
        expect(find.text('Radera konto'), findsOneWidget);
        expect(find.text('Ta bort ditt konto och all data permanent'),
            findsOneWidget);
        expect(find.byIcon(Icons.delete_forever), findsOneWidget);

        // Styling verification - check for error-colored container
        final containers = tester.widgetList<Container>(find.byType(Container));
        final deleteContainer = containers.where((container) {
          if (container.decoration is BoxDecoration) {
            final decoration = container.decoration as BoxDecoration;
            final color = decoration.color;
            // Check if color has error-like properties (red channel high, alpha modified)
            return color != null &&
                (color.r * 255.0).round() > 200 &&
                (color.g * 255.0).round() < 100 &&
                (color.b * 255.0).round() < 100;
          }
          return false;
        }).isNotEmpty;
        expect(deleteContainer, isTrue);
      });

      testWidgets('shows comprehensive delete account confirmation dialog',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildAccountManagementSection(context),
        );

        await tester.tap(find.text('Radera konto'));
        await tester.pumpAndSettle();

        // Check dialog content - comprehensive warnings
        expect(find.text('Radera konto permanent'), findsOneWidget);
        expect(find.text('VARNING: Detta kommer att:'), findsOneWidget);
        expect(find.text('• Ta bort alla dina recept'), findsOneWidget);
        expect(find.text('• Ta bort alla dina menyer'), findsOneWidget);
        expect(find.text('• Ta bort alla dina shoppinglistor'), findsOneWidget);
        expect(
            find.text('• Ta bort alla vänner och meddelanden'), findsOneWidget);
        expect(find.text('• Ta bort all delad innehåll'), findsOneWidget);
        expect(find.text('Denna åtgärd kan INTE ångras!'), findsOneWidget);

        // Action buttons
        expect(find.text('Avbryt'), findsOneWidget);
        expect(find.text('Jag förstår, radera mitt konto'), findsOneWidget);
      });

      testWidgets('handles account deletion cancellation',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildAccountManagementSection(context),
        );

        await tester.tap(find.text('Radera konto'));
        await tester.pumpAndSettle();

        // Cancel deletion
        await tester.tap(find.text('Avbryt'));
        await tester.pumpAndSettle();

        // No further dialogs should appear
        expect(find.text('Bekräfta med lösenord'), findsNothing);
      });
    });

    group('Button Styling and Layout', () {
      testWidgets('applies correct styling to data buttons',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildDataBackupSection(context),
        );

        // Check container styling for backup button
        final containers = tester.widgetList<Container>(find.byType(Container));
        final dataButtonContainers = containers.where((container) =>
            container.decoration is BoxDecoration &&
            (container.decoration as BoxDecoration).borderRadius != null);

        expect(dataButtonContainers.length, greaterThanOrEqualTo(2));

        // Check that containers have proper border radius
        for (final container in dataButtonContainers) {
          final decoration = container.decoration as BoxDecoration;
          if (decoration.borderRadius != null) {
            expect(decoration.borderRadius,
                equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
          }
        }
      });

      testWidgets('displays correct text styles throughout sections',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => Column(
            children: [
              ProfileActions.buildDataBackupSection(context),
              ProfileActions.buildAccountManagementSection(context),
            ],
          ),
        );

        // Check section headers use correct style
        final dataBackupText = tester.widget<Text>(find.text('Data & Backup'));
        expect(dataBackupText.style?.fontSize,
            equals(AppTextStyles.displaySmall.fontSize));

        final accountMgmtText =
            tester.widget<Text>(find.text('Kontohantering'));
        expect(accountMgmtText.style?.fontSize,
            equals(AppTextStyles.displaySmall.fontSize));
      });

      testWidgets('handles InkWell interactions correctly',
          (WidgetTester tester) async {
        bool tapped = false;

        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildMenuItem(
            context,
            title: 'Test Item',
            subtitle: 'Test Description',
            icon: Icons.settings,
            onTap: () => tapped = true,
          ),
        );

        // Tap the menu item
        await tester.tap(find.text('Test Item'));
        await tester.pumpAndSettle();

        // Verify tap was handled
        expect(tapped, isTrue);
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles null onTap callbacks gracefully',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildMenuItem(
            context,
            title: 'Disabled Item',
            subtitle: 'This item is disabled',
            icon: Icons.block,
            onTap: null, // Null callback
          ),
        );

        // Should render without issues
        expect(find.text('Disabled Item'), findsOneWidget);
        expect(find.text('This item is disabled'), findsOneWidget);

        // InkWell should be disabled
        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.onTap, isNull);
      });

      testWidgets('handles very long text content with proper overflow',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildMenuItem(
            context,
            title: 'Very Long Title That Should Handle Overflow Correctly',
            subtitle:
                'This is a very long subtitle that tests how the widget handles text overflow and wrapping behavior in different screen sizes',
            icon: Icons.text_fields,
            onTap: () {},
          ),
        );

        // Should render without overflow errors
        expect(find.textContaining('Very Long Title'), findsOneWidget);
        expect(find.textContaining('This is a very long subtitle'),
            findsOneWidget);
      });

      testWidgets('maintains proper spacing and dimensions',
          (WidgetTester tester) async {
        await pumpProfileWidget(
          tester,
          (context) => ProfileActions.buildDataBackupSection(context),
        );

        // Check for proper spacing elements
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(sizedBoxes.length, greaterThan(3)); // Multiple spacing elements

        // Verify some standard spacing values
        final spacingBoxes = sizedBoxes.where((box) =>
            box.height == AppDimensions.spacingXl ||
            box.height == AppDimensions.spacingM ||
            box.width == AppDimensions.spacingL);
        expect(spacingBoxes.length, greaterThan(0));
      });
    });
  });
}

// Mock classes - use existing production mocks
class MockBackupService extends Mock implements BackupService {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthService extends Mock implements AuthService {}

class MockUserService extends Mock implements UserService {}

class MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class MockOfflineService extends Mock implements OfflineService {}

class MockAnalyticsService extends Mock implements AnalyticsService {}
