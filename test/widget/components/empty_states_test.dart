import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/core/constants/app_strings.dart';
import 'package:butlery/theme/app_dimensions.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  group('EmptyStates', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    group('buildEmptyState', () {
      testWidgets('should display custom title and subtitle', (tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: null,
                  title: 'Custom Title',
                  subtitle: 'Custom Subtitle',
                ),
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('Custom Title'), findsOneWidget);
        expect(find.text('Custom Subtitle'), findsOneWidget);
      });

      testWidgets('should display custom icon when provided', (tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: null,
                  title: 'Test',
                  icon: Icons.favorite,
                ),
              ),
            ),
          ),
        );

        // Assert
        expect(find.byIcon(Icons.favorite), findsOneWidget);
      });

      testWidgets('should hide icon when Icons.clear is used', (tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: null,
                  title: 'No Icon Test',
                  icon: Icons.clear,
                ),
              ),
            ),
          ),
        );

        // Assert
        expect(find.byType(Icon), findsNothing);
        expect(find.text('No Icon Test'), findsOneWidget);
      });

      testWidgets('should display action button when provided', (tester) async {
        // Arrange
        bool actionCalled = false;

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: null,
                  title: 'Test',
                  actionLabel: 'Retry',
                  onAction: () {
                    actionCalled = true;
                  },
                ),
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('Retry'), findsOneWidget);

        // Tap the button
        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(actionCalled, isTrue);
      });

      testWidgets('should display custom action widget when provided',
          (tester) async {
        // Arrange
        const customWidget = Text('Custom Action Widget');

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: null,
                  title: 'Test',
                  customAction: customWidget,
                ),
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('Custom Action Widget'), findsOneWidget);
      });

      group('EmptyStateVariant.noRecipes', () {
        testWidgets('should display correct text for no recipes',
            (tester) async {
          // Act
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

          // Assert
          expect(find.text(AppStrings.noResults), findsOneWidget);
          expect(
            find.text(
                'Lägg till ditt första recept genom att trycka på "${AppStrings.add}"'),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
        });
      });

      group('EmptyStateVariant.noSearchResults', () {
        testWidgets('should display correct text for no search results',
            (tester) async {
          // Act
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

          // Assert
          expect(find.text(AppStrings.noResults), findsOneWidget);
          expect(find.byIcon(Icons.search_off), findsOneWidget);
        });
      });

      testWidgets('should use custom padding when provided', (tester) async {
        // Arrange
        const customPadding = EdgeInsets.all(50.0);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: null,
                  title: 'Test',
                  padding: customPadding,
                ),
              ),
            ),
          ),
        );

        // Assert
        final padding = tester.widget<Padding>(
          find.byType(Padding).first,
        );
        expect(padding.padding, equals(customPadding));
      });

      testWidgets('should use default padding when not provided',
          (tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: null,
                  title: 'Test',
                ),
              ),
            ),
          ),
        );

        // Assert
        final padding = tester.widget<Padding>(
          find.byType(Padding).first,
        );
        expect(padding.padding,
            equals(const EdgeInsets.all(AppDimensions.spacingXl)));
      });

      testWidgets('should be scrollable for long content', (tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: null,
                  title: 'Very Long Title That Might Need Scrolling',
                  subtitle:
                      'Very long subtitle that provides a lot of context and explanation '
                      'about why this state is empty and what the user can do about it. '
                      'This text is intentionally long to test scrolling behavior.',
                ),
              ),
            ),
          ),
        );

        // Assert
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });

      testWidgets('should center content', (tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: null,
                  title: 'Centered Content',
                ),
              ),
            ),
          ),
        );

        // Assert - Check that Center widgets exist (may be nested)
        expect(find.byType(Center), findsWidgets);

        // Check text alignment
        final titleText = tester.widget<Text>(
          find.text('Centered Content'),
        );
        expect(titleText.textAlign, equals(TextAlign.center));
      });

      testWidgets('should apply custom icon color and size', (tester) async {
        // Arrange
        const customColor = Colors.red;
        const customSize = 100.0;

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: null,
                  title: 'Test',
                  icon: Icons.error,
                  iconColor: customColor,
                  iconSize: customSize,
                ),
              ),
            ),
          ),
        );

        // Assert
        final icon = tester.widget<Icon>(find.byIcon(Icons.error));
        expect(icon.color, equals(customColor));
        expect(icon.size, equals(customSize));
      });

      testWidgets('should not show subtitle when not provided', (tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: null,
                  title: 'Title Only',
                ),
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('Title Only'), findsOneWidget);
        // Should only find one Text widget (the title)
        expect(find.byType(Text), findsOneWidget);
      });

      testWidgets('should not show action when onAction is null',
          (tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => EmptyStates.buildEmptyState(
                  context,
                  variant: null,
                  title: 'Test',
                  actionLabel: 'This should not appear',
                  onAction: null, // No callback provided
                ),
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('This should not appear'), findsNothing);
      });
    });
  });
}
