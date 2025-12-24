// test/widget/common/state/empty_states_test.dart
// Comprehensive tests for EmptyStates using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/core/constants/app_strings.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('EmptyStates Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Generic Empty State', () {
      testWidgets('should render generic empty state with default values',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                ),
              ),
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Inget innehåll att visa'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('should render with custom title and subtitle',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                  title: 'Custom Title',
                  subtitle: 'Custom Subtitle',
                ),
              ),
            ),
          ),
        );

        expect(find.text('Custom Title'), findsOneWidget);
        expect(find.text('Custom Subtitle'), findsOneWidget);
      });

      testWidgets('should render with custom icon',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                  icon: Icons.warning,
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.warning), findsOneWidget);
      });
    });

    group('No Recipes Variant', () {
      testWidgets('should display no recipes empty state',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.noRecipes,
                ),
              ),
            ),
          ),
        );

        expect(find.text(AppStrings.noResults), findsOneWidget);
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
        expect(find.textContaining('Lägg till ditt första recept'),
            findsOneWidget);
      });

      testWidgets('should show action button when provided',
          (WidgetTester tester) async {
        bool actionCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.noRecipes,
                  actionLabel: 'Lägg till recept',
                  onAction: () {
                    actionCalled = true;
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('Lägg till recept'), findsOneWidget);

        await tester.tap(find.text('Lägg till recept'));
        expect(actionCalled, true);
      });
    });

    group('No Search Results Variant', () {
      testWidgets('should display no search results state',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.noSearchResults,
                ),
              ),
            ),
          ),
        );

        expect(find.text(AppStrings.noResults), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
        expect(find.text('Prova att söka på något annat eller rensa sökningen'),
            findsOneWidget);
      });
    });

    group('No Friends Search Results', () {
      testWidgets('should display no friends search results',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.noFriendsSearchResults,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Inga vänner matchade din sökning'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
      });
    });

    group('No Groups Search Results', () {
      testWidgets('should display no groups search results',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.noGroupsSearchResults,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Inga grupper matchade din sökning'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
      });
    });

    group('No Menu Variant', () {
      testWidgets('should display no menu state', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.noMenu,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Ingen meny genererad ännu'), findsOneWidget);
        expect(find.text('Skriv vad du vill ha eller tryck på knappen nedan'),
            findsOneWidget);
        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
      });
    });

    group('No Shopping List Variant', () {
      testWidgets('should display no shopping list state',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.noShoppingList,
                ),
              ),
            ),
          ),
        );

        expect(
            find.text('Ingen meny att skapa inköpslista från'), findsOneWidget);
        expect(find.text('Gå tillbaka och skapa en veckomeny först'),
            findsOneWidget);
        expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      });
    });

    group('No Friends Variant', () {
      testWidgets('should display no friends state',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.noFriends,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Inga vänner ännu'), findsOneWidget);
        expect(find.text('Lägg till vänner för att dela recept och menyer'),
            findsOneWidget);
        expect(find.byIcon(Icons.people_outline), findsOneWidget);
      });
    });

    group('No Categories Variant', () {
      testWidgets('should display no categories state',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.noCategories,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Inga kategorier skapade'), findsOneWidget);
        expect(
            find.text(
                'Skapa din första kategori för att organisera dina vänner'),
            findsOneWidget);
        expect(find.byIcon(Icons.category), findsOneWidget);
      });
    });

    group('No Images Variant', () {
      testWidgets('should display no images state',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.noImages,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Inga bilder tillagda'), findsOneWidget);
        expect(
            find.text(
                'Lägg till bilder för att göra ditt recept mer attraktivt'),
            findsOneWidget);
        expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      });
    });

    group('No Targets Variant', () {
      testWidgets('should display no targets state',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.noTargets,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Inga destinationer tillgängliga'), findsOneWidget);
        expect(
            find.text(
                'Lägg till vänner eller grupper för att kunna dela innehåll'),
            findsOneWidget);
        expect(find.byIcon(Icons.group_add), findsOneWidget);
      });
    });

    group('No Saved Menus Variant', () {
      testWidgets('should display no saved menus state',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.noSavedMenus,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Inga sparade menyer'), findsOneWidget);
        expect(
            find.text('Skapa och spara menyer för att enkelt ladda dem senare'),
            findsOneWidget);
        expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
      });
    });

    group('Custom Action', () {
      testWidgets('should render custom action widget',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                  customAction: const Text('Custom Action Widget'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Custom Action Widget'), findsOneWidget);
      });

      testWidgets('should prefer custom action over action label',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                  actionLabel: 'Action Button',
                  onAction: () {},
                  customAction: const Text('Custom Widget'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Custom Widget'), findsOneWidget);
        expect(find.text('Action Button'), findsNothing);
      });
    });

    group('Styling', () {
      testWidgets('should apply custom icon color',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                  iconColor: Colors.red,
                ),
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
        expect(icon.color, equals(Colors.red));
      });

      testWidgets('should apply custom icon size', (WidgetTester tester) async {
        const customSize = 64.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                  iconSize: customSize,
                ),
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
        expect(icon.size, equals(customSize));
      });

      testWidgets('should apply custom padding', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(32.0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                  padding: customPadding,
                ),
              ),
            ),
          ),
        );

        final padding = tester.widget<Padding>(find.byType(Padding).first);
        expect(padding.padding, equals(customPadding));
      });

      testWidgets('should use theme colors for text',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                onSurfaceVariant: Colors.purple,
              ),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                ),
              ),
            ),
          ),
        );

        final titleText =
            tester.widget<Text>(find.text('Inget innehåll att visa'));
        expect(titleText.style?.color, equals(Colors.purple));
      });
    });

    group('Layout', () {
      testWidgets('should be centered', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Center), findsOneWidget);
      });

      testWidgets('should be scrollable', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });

      testWidgets('should have correct spacing between elements',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                  subtitle: 'Test subtitle',
                ),
              ),
            ),
          ),
        );

        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(sizedBoxes.any((box) => box.height == AppDimensions.spacingXl),
            true);
        expect(sizedBoxes.any((box) => box.height == AppDimensions.spacingM),
            true);
      });
    });

    group('Icon Visibility', () {
      testWidgets('should hide icon when Icons.clear is used',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                  icon: Icons.clear,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Icon), findsNothing);
      });

      testWidgets('should show icon for other icon types',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: EmptyStateVariant.generic,
                  icon: Icons.star,
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.star), findsOneWidget);
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish text correctly',
          (WidgetTester tester) async {
        final swedishVariants = [
          EmptyStateVariant.noRecipes,
          EmptyStateVariant.noFriends,
          EmptyStateVariant.noMenu,
          EmptyStateVariant.noShoppingList,
          EmptyStateVariant.noCategories,
          EmptyStateVariant.noImages,
          EmptyStateVariant.noTargets,
          EmptyStateVariant.noSavedMenus,
        ];

        for (final variant in swedishVariants) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => EmptyStates.buildEmptyState(
                    context,
                    variant: variant,
                  ),
                ),
              ),
            ),
          );

          // Each variant should display some Swedish text
          expect(
              find.textContaining(RegExp(
                  r'[åäöÅÄÖ]|ingen|inga|första|eller|för att',
                  caseSensitive: false)),
              findsWidgets);
        }
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}
