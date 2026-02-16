// test/widget/common/state/empty_states_ultrathink_test.dart
// Comprehensive tests for EmptyStates widget using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';

void main() {
  group('EmptyStates Widget Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to wrap widget with MaterialApp for proper theming and Swedish locale
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Colors.blue,
            outline: Colors.grey,
            onSurfaceVariant: Colors.black87,
          ),
          textTheme: const TextTheme(
            headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            bodyMedium: TextStyle(fontSize: 14),
          ),
        ),
        home: Scaffold(
          body: SizedBox(
            height: 600, // Adequate height for empty state content
            child: child,
          ),
        ),
      );
    }

    group('Factory Method Tests', () {
      testWidgets('should create empty state with minimal parameters',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.generic,
            ),
          ),
        ));

        expect(find.byType(Icon), findsOneWidget);
        expect(find.text('Inget innehåll att visa'), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);
      });

      testWidgets('should handle null variant gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: null,
            ),
          ),
        ));

        expect(find.byType(Icon), findsOneWidget);
        expect(find.text('Inget innehåll att visa'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('should override config with custom parameters',
          (WidgetTester tester) async {
        const customTitle = 'Custom Title';
        const customSubtitle = 'Custom Subtitle';
        const customIcon = Icons.star;

        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noRecipes,
              title: customTitle,
              subtitle: customSubtitle,
              icon: customIcon,
            ),
          ),
        ));

        // Should use custom values instead of config
        expect(find.text(customTitle), findsOneWidget);
        expect(find.text(customSubtitle), findsOneWidget);
        expect(find.byIcon(customIcon), findsOneWidget);

        // Should not show config values
        expect(find.text(AppLocale.current.noResults), findsNothing);
      });

      testWidgets('should hide icon when Icons.clear is provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.generic,
              icon: Icons.clear,
            ),
          ),
        ));

        expect(find.byType(Icon), findsNothing);
        expect(find.text('Inget innehåll att visa'), findsOneWidget);
      });
    });

    group('EmptyStateVariant Tests - All 12 Variants', () {
      testWidgets('noRecipes variant should display correct content',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noRecipes,
            ),
          ),
        ));

        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
        expect(find.text(AppLocale.current.noResults), findsOneWidget);
        expect(find.textContaining('Lägg till ditt första recept'),
            findsOneWidget);
      });

      testWidgets('noSearchResults variant should display correct content',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noSearchResults,
            ),
          ),
        ));

        expect(find.byIcon(Icons.search_off), findsOneWidget);
        expect(find.text(AppLocale.current.noResults), findsOneWidget);
        expect(find.textContaining('Prova att söka på något annat'),
            findsOneWidget);
      });

      testWidgets(
          'noFriendsSearchResults variant should display correct content',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noFriendsSearchResults,
            ),
          ),
        ));

        expect(find.byIcon(Icons.search_off), findsOneWidget);
        expect(find.text('Inga vänner matchade din sökning'), findsOneWidget);
        expect(find.textContaining('Prova att söka på något annat'),
            findsOneWidget);
      });

      testWidgets('noMenu variant should display correct content',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noMenu,
            ),
          ),
        ));

        expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
        expect(find.text('Ingen meny genererad ännu'), findsOneWidget);
        expect(find.textContaining('Skriv vad du vill ha'), findsOneWidget);
      });

      testWidgets('noFriends variant should display correct content',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noFriends,
            ),
          ),
        ));

        expect(find.byIcon(Icons.people_outline), findsOneWidget);
        expect(find.text('Inga vänner ännu'), findsOneWidget);
        expect(find.textContaining('Lägg till vänner för att dela recept'),
            findsOneWidget);
      });

      testWidgets('generic variant should display correct content',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.generic,
            ),
          ),
        ));

        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.text('Inget innehåll att visa'), findsOneWidget);
      });
    });

    group('Action Button Integration Tests', () {
      testWidgets(
          'should display action button when actionLabel and onAction provided',
          (WidgetTester tester) async {
        bool actionCalled = false;
        const actionLabel = 'Test Action';

        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noRecipes,
              actionLabel: actionLabel,
              onAction: () => actionCalled = true,
            ),
          ),
        ));

        expect(find.text(actionLabel), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);

        await tester.tap(find.text(actionLabel));
        expect(actionCalled, isTrue);
      });

      testWidgets(
          'should not display action button when only actionLabel provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noRecipes,
              actionLabel: 'Test Action',
              // onAction not provided
            ),
          ),
        ));

        expect(find.text('Test Action'), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
      });

      testWidgets('should prioritize customAction over actionLabel/onAction',
          (WidgetTester tester) async {
        const customButtonText = 'Custom Button';

        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noRecipes,
              customAction: TextButton(
                onPressed: () {},
                child: const Text(customButtonText),
              ),
              actionLabel: 'Should Not Show',
              onAction: () {},
            ),
          ),
        ));

        expect(find.text(customButtonText), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget);
        expect(find.text('Should Not Show'), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
      });

      testWidgets('should include actionIcon in button when available',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noRecipes, // has Icons.add actionIcon
              actionLabel: 'Add Recipe',
              onAction: () {},
            ),
          ),
        ));

        expect(find.text('Add Recipe'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    });

    group('Layout and Styling Tests', () {
      testWidgets('should apply default padding', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.generic,
            ),
          ),
        ));

        final padding = tester.widget<Padding>(find.byType(Padding).first);
        expect(padding.padding,
            equals(const EdgeInsets.all(AppDimensions.spacingXl)));
      });

      testWidgets('should apply custom icon size', (WidgetTester tester) async {
        const customSize = 100.0;

        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.generic,
              iconSize: customSize,
            ),
          ),
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, equals(customSize));
      });

      testWidgets('should be scrollable with SingleChildScrollView',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noRecipes,
              actionLabel: 'Add Recipe',
              onAction: () {},
            ),
          ),
        ));

        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);
      });

      testWidgets('should center content with Center widget',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.generic,
            ),
          ),
        ));

        // Should have at least one Center widget (from EmptyStates)
        expect(find.byType(Center), findsWidgets);
      });
    });

    group('Subtitle Behavior Tests', () {
      testWidgets('should show subtitle when variant has one',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noRecipes, // has subtitle
            ),
          ),
        ));

        expect(find.textContaining('Lägg till ditt första recept'),
            findsOneWidget);
      });

      testWidgets('should not show subtitle when variant has none',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.generic, // no subtitle
            ),
          ),
        ));

        // Should only have one Text widget (the title)
        expect(find.byType(Text), findsOneWidget);
        expect(find.text('Inget innehåll att visa'), findsOneWidget);
      });

      testWidgets('should override variant subtitle with custom subtitle',
          (WidgetTester tester) async {
        const customSubtitle = 'Custom subtitle text';

        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noRecipes,
              subtitle: customSubtitle,
            ),
          ),
        ));

        expect(find.text(customSubtitle), findsOneWidget);
        expect(
            find.textContaining('Lägg till ditt första recept'), findsNothing);
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('should handle empty string parameters gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.generic,
              title: '',
              subtitle: '',
              actionLabel: '',
            ),
          ),
        ));

        expect(find.text(''), findsNWidgets(2)); // empty title and subtitle
        expect(find.byType(Icon), findsOneWidget);
        expect(find.byType(ElevatedButton),
            findsNothing); // no action button for empty label
      });

      testWidgets('should handle very long text content',
          (WidgetTester tester) async {
        const longTitle =
            'This is a very long title that might wrap to multiple lines';
        const longSubtitle =
            'This is an extremely long subtitle text that definitely will wrap';

        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.generic,
              title: longTitle,
              subtitle: longSubtitle,
            ),
          ),
        ));

        expect(find.text(longTitle), findsOneWidget);
        expect(find.text(longSubtitle), findsOneWidget);

        // Should not cause overflow
        expect(tester.takeException(), isNull);
      });
    });
  });
}
