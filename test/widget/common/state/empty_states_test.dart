import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/theme/app_dimensions.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('EmptyStates Widget Tests', () {
    Widget buildEmptyState({
      required EmptyStateVariant variant,
      String? title,
      String? subtitle,
      IconData? icon,
      String? actionLabel,
      VoidCallback? onAction,
      Widget? customAction,
      Color? iconColor,
      double? iconSize,
      EdgeInsets? padding,
      bool? useIllustration,
    }) {
      return createLocalizedTestApp(
        wrapInScaffold: true,
        child: Builder(
          builder: (context) => EmptyStates.buildEmptyState(
            context,
            variant: variant,
            title: title,
            subtitle: subtitle,
            icon: icon,
            actionLabel: actionLabel,
            onAction: onAction,
            customAction: customAction,
            iconColor: iconColor,
            iconSize: iconSize,
            padding: padding,
            useIllustration: useIllustration,
          ),
        ),
      );
    }

    group('Generic Empty State', () {
      testWidgets('renders with default values', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.generic),
        );
        await tester.pumpAndSettle();

        // Title uses l10n.emptyGenericTitle.
        expect(find.text('Inget innehåll finns att visa'), findsOneWidget);
        // Generic variant has no illustration, so shows icon
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('renders with custom title and subtitle', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(
            variant: EmptyStateVariant.generic,
            title: 'Custom Title',
            subtitle: 'Custom Subtitle',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Custom Title'), findsOneWidget);
        expect(find.text('Custom Subtitle'), findsOneWidget);
      });

      testWidgets('renders with custom icon', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(
            variant: EmptyStateVariant.generic,
            icon: Icons.warning,
            useIllustration: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.warning), findsOneWidget);
      });
    });

    group('No Recipes Variant', () {
      testWidgets('displays no recipes empty state', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.noRecipes),
        );
        await tester.pumpAndSettle();

        // Title uses l10n.emptyNoResults = 'Inga resultat hittades.'
        expect(find.text('Inga resultat hittades.'), findsOneWidget);
        // Has VegetableIllustration (broccoli) by default
        expect(find.byType(VegetableIllustration), findsOneWidget);
        // Subtitle uses l10n.emptyNoRecipesSubtitle('Lägg till') ->
        // 'Första receptet läggs till via "Lägg till".'
        expect(
            find.textContaining('Första receptet läggs till'), findsOneWidget);
      });

      testWidgets('shows action button when provided', (tester) async {
        bool actionCalled = false;

        await tester.pumpWidget(
          buildEmptyState(
            variant: EmptyStateVariant.noRecipes,
            actionLabel: 'Lägg till recept',
            onAction: () => actionCalled = true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lägg till recept'), findsOneWidget);
        await tester.tap(find.text('Lägg till recept'));
        expect(actionCalled, true);
      });
    });

    group('No Search Results Variant', () {
      testWidgets('displays no search results state', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.noSearchResults),
        );
        await tester.pumpAndSettle();

        expect(find.text('Inga resultat hittades.'), findsOneWidget);
        // Uses illustration (mushroom) by default
        expect(find.byType(VegetableIllustration), findsOneWidget);
        expect(
          find.text('Prova att söka på något annat eller rensa sökningen'),
          findsOneWidget,
        );
      });
    });

    group('No Friends Search Results', () {
      testWidgets('displays no friends search results', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.noFriendsSearchResults),
        );
        await tester.pumpAndSettle();

        expect(find.text('Inga vänner matchade din sökning'), findsOneWidget);
      });
    });

    group('No Groups Search Results', () {
      testWidgets('displays no groups search results', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.noGroupsSearchResults),
        );
        await tester.pumpAndSettle();

        expect(find.text('Inga grupper matchade din sökning'), findsOneWidget);
      });
    });

    group('No Menu Variant', () {
      testWidgets('displays no menu state', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.noMenu),
        );
        await tester.pumpAndSettle();

        // l10n.emptyNoMenuTitle / emptyNoMenuSubtitle.
        expect(find.text('Ingen meny är ännu uppdukad'), findsOneWidget);
        expect(
          find.text('Ange önskemål, eller använd knappen nedan'),
          findsOneWidget,
        );
      });
    });

    group('No Shopping List Variant', () {
      testWidgets('displays no shopping list state', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.noShoppingList),
        );
        await tester.pumpAndSettle();

        // l10n.emptyNoShoppingListTitle / emptyNoShoppingListSubtitle.
        expect(find.text('Ingen meny finns att avleda en inköpslista från'),
            findsOneWidget);
        expect(find.text('En veckomeny behövs först'), findsOneWidget);
      });
    });

    group('No Friends Variant', () {
      testWidgets('displays no friends state', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(
            variant: EmptyStateVariant.noFriends,
          ),
        );
        await tester.pumpAndSettle();

        // l10n.emptyNoFriendsTitle / emptyNoFriendsSubtitle.
        expect(find.text('Ingen är bjuden ännu'), findsOneWidget);
        expect(
          find.text('Vänner inbjuds för att dela recept och menyer'),
          findsOneWidget,
        );
        // No illustration for social states — shows icon
        expect(find.byType(VegetableIllustration), findsNothing);
      });
    });

    group('No Categories Variant', () {
      testWidgets('displays no categories state', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.noCategories),
        );
        await tester.pumpAndSettle();

        expect(find.text('Inga kategorier skapade'), findsOneWidget);
        expect(
          find.text('Skapa din första kategori för att organisera dina vänner'),
          findsOneWidget,
        );
      });
    });

    group('No Images Variant', () {
      testWidgets('displays no images state', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.noImages),
        );
        await tester.pumpAndSettle();

        expect(find.text('Inga bilder tillagda'), findsOneWidget);
        expect(
          find.text('Lägg till bilder för att göra ditt recept mer attraktivt'),
          findsOneWidget,
        );
      });
    });

    group('No Targets Variant', () {
      testWidgets('displays no targets state', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.noTargets),
        );
        await tester.pumpAndSettle();

        expect(find.text('Inga destinationer tillgängliga'), findsOneWidget);
        expect(
          find.text(
              'Lägg till vänner eller grupper för att kunna dela innehåll'),
          findsOneWidget,
        );
      });
    });

    group('No Saved Menus Variant', () {
      testWidgets('displays no saved menus state', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.noSavedMenus),
        );
        await tester.pumpAndSettle();

        expect(find.text('Inga sparade menyer'), findsOneWidget);
        expect(
          find.text('Skapa och spara menyer för att enkelt ladda dem senare'),
          findsOneWidget,
        );
      });
    });

    group('Custom Action', () {
      testWidgets('renders custom action widget', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(
            variant: EmptyStateVariant.generic,
            customAction: const Text('Custom Action Widget'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Custom Action Widget'), findsOneWidget);
      });

      testWidgets('prefers custom action over action label', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(
            variant: EmptyStateVariant.generic,
            actionLabel: 'Action Button',
            onAction: () {},
            customAction: const Text('Custom Widget'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Custom Widget'), findsOneWidget);
        expect(find.text('Action Button'), findsNothing);
      });
    });

    group('Styling', () {
      testWidgets('applies custom icon color when using icon mode',
          (tester) async {
        await tester.pumpWidget(
          buildEmptyState(
            variant: EmptyStateVariant.generic,
            iconColor: Colors.red,
            useIllustration: false,
          ),
        );
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
        expect(icon.color, equals(Colors.red));
      });

      testWidgets('applies custom icon size in icon mode', (tester) async {
        const customSize = 64.0;

        await tester.pumpWidget(
          buildEmptyState(
            variant: EmptyStateVariant.generic,
            iconSize: customSize,
            useIllustration: false,
          ),
        );
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
        expect(icon.size, equals(customSize));
      });

      testWidgets('applies custom padding', (tester) async {
        const customPadding = EdgeInsets.all(32.0);

        await tester.pumpWidget(
          buildEmptyState(
            variant: EmptyStateVariant.generic,
            padding: customPadding,
          ),
        );
        await tester.pumpAndSettle();

        // The outer Padding is inside Center. Find Padding widgets
        // within the Center widget.
        final paddingWidgets = tester.widgetList<Padding>(find.byType(Padding));
        final hasCustomPadding =
            paddingWidgets.any((p) => p.padding == customPadding);
        expect(hasCustomPadding, isTrue);
      });
    });

    group('Layout', () {
      testWidgets('is centered', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.generic),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Center), findsAtLeastNWidgets(1));
      });

      testWidgets('is scrollable', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(variant: EmptyStateVariant.generic),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });

      testWidgets('has correct spacing between elements', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(
            variant: EmptyStateVariant.generic,
            subtitle: 'Test subtitle',
          ),
        );
        await tester.pumpAndSettle();

        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(
          sizedBoxes.any((box) => box.height == AppDimensions.spacingLg),
          true,
        );
        expect(
          sizedBoxes.any((box) => box.height == AppDimensions.spacingM),
          true,
        );
      });
    });

    group('Icon Visibility', () {
      testWidgets('hides icon when Icons.clear is used', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(
            variant: EmptyStateVariant.generic,
            icon: Icons.clear,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Icon), findsNothing);
        expect(find.byType(VegetableIllustration), findsNothing);
      });

      testWidgets('shows icon for other icon types', (tester) async {
        await tester.pumpWidget(
          buildEmptyState(
            variant: EmptyStateVariant.generic,
            icon: Icons.star,
            useIllustration: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.star), findsOneWidget);
      });
    });

    group('Swedish Localization', () {
      testWidgets('all variants display Swedish text', (tester) async {
        final variants = [
          EmptyStateVariant.noRecipes,
          EmptyStateVariant.noFriends,
          EmptyStateVariant.noMenu,
          EmptyStateVariant.noShoppingList,
          EmptyStateVariant.noCategories,
          EmptyStateVariant.noImages,
          EmptyStateVariant.noTargets,
          EmptyStateVariant.noSavedMenus,
        ];

        for (final variant in variants) {
          await tester.pumpWidget(
            buildEmptyState(variant: variant),
          );
          await tester.pumpAndSettle();

          // Each variant should display Swedish text containing
          // common Swedish characters or words
          expect(
            find.textContaining(RegExp(
                r'[åäöÅÄÖ]|ingen|inga|första|eller|för att',
                caseSensitive: false)),
            findsWidgets,
            reason: 'Variant $variant should display Swedish text',
          );
        }
      });
    });
  });
}
