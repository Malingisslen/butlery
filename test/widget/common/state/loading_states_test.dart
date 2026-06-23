// test/widget/common/state/loading_states_test.dart
// Comprehensive tests for LoadingStates using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/state/loading_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('LoadingStates Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Spinner Loading', () {
      testWidgets('should render spinner with no message', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.spinner,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(Center), findsOneWidget);
      });

      testWidgets('should render spinner with message', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.spinner,
                  message: 'Laddar...',
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Laddar...'), findsOneWidget);
      });

      testWidgets('should render default spinner when variant is null', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: null,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should have correct spacing with message', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.spinner,
                  message: 'Loading message',
                ),
              ),
            ),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.height, equals(AppDimensions.spacingM));
      });

      testWidgets('should be centered', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.spinner,
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
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.spinner,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });
    });

    group('Skeleton Recipe List', () {
      testWidgets('should render skeleton recipe list with default count', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.skeletonRecipeList,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(ListView), findsOneWidget);
        // Default count is 5
        expect(find.byType(Card), findsNWidgets(5));
      });

      testWidgets('should render skeleton recipe list with custom count', (
        WidgetTester tester,
      ) async {
        const customCount = 3;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.skeletonRecipeList,
                  skeletonItemCount: customCount,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Card), findsNWidgets(customCount));
      });

      testWidgets('should have correct ListView properties', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.skeletonRecipeList,
                ),
              ),
            ),
          ),
        );

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.shrinkWrap, true);
        expect(listView.physics, isA<NeverScrollableScrollPhysics>());
      });

      testWidgets('should have correct padding on ListView', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.skeletonRecipeList,
                ),
              ),
            ),
          ),
        );

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(
          listView.padding,
          equals(const EdgeInsets.symmetric(vertical: AppDimensions.spacingS)),
        );
      });
    });

    group('Skeleton Recipe Card', () {
      testWidgets('should render single skeleton recipe card', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.skeletonRecipeCard,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Card), findsOneWidget);
      });

      testWidgets('should have correct card properties', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.skeletonRecipeCard,
                ),
              ),
            ),
          ),
        );

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, equals(2));

        final shape = card.shape as RoundedRectangleBorder;
        expect(
          shape.borderRadius,
          equals(BorderRadius.circular(AppDimensions.borderRadiusM)),
        );
      });

      testWidgets('should have padding inside card', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.skeletonRecipeCard,
                ),
              ),
            ),
          ),
        );

        // Find the Padding widget inside the Card
        final paddings = tester.widgetList<Padding>(find.byType(Padding));
        expect(paddings, isNotEmpty);
      });

      testWidgets('should contain Row for layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.skeletonRecipeCard,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Row), findsWidgets);
      });
    });

    group('Skeleton Generic', () {
      testWidgets('should render generic skeleton', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.skeletonGeneric,
                ),
              ),
            ),
          ),
        );

        // Should render something (exact implementation may vary)
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('Shimmer Box', () {
      testWidgets('should render shimmer box', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.shimmerBox,
                ),
              ),
            ),
          ),
        );

        // Should render something (exact implementation may vary)
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish loading message', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.spinner,
                  message: 'Laddar recept...',
                ),
              ),
            ),
          ),
        );

        expect(find.text('Laddar recept...'), findsOneWidget);
      });

      testWidgets('should display Swedish processing message', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.spinner,
                  message: 'Bearbetar data...',
                ),
              ),
            ),
          ),
        );

        expect(find.text('Bearbetar data...'), findsOneWidget);
      });

      testWidgets('should display Swedish fetching message', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.spinner,
                  message: 'Hämtar information...',
                ),
              ),
            ),
          ),
        );

        expect(find.text('Hämtar information...'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle zero skeleton items', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.skeletonRecipeList,
                  skeletonItemCount: 0,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(Card), findsNothing);
      });

      testWidgets('should handle very large skeleton count', (
        WidgetTester tester,
      ) async {
        const largeCount = 20;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Builder(
                  builder: (context) => LoadingStates.buildLoadingState(
                    context,
                    variant: LoadingVariant.skeletonRecipeList,
                    skeletonItemCount: largeCount,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Card), findsNWidgets(largeCount));
      });

      testWidgets('should handle empty message', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.spinner,
                  message: '',
                ),
              ),
            ),
          ),
        );

        expect(find.text(''), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should handle very long message', (
        WidgetTester tester,
      ) async {
        final longMessage = 'A' * 200;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.spinner,
                  message: longMessage,
                ),
              ),
            ),
          ),
        );

        expect(find.text(longMessage), findsOneWidget);
      });
    });

    group('Theme Integration', () {
      testWidgets('should work with light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.spinner,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingStates.buildLoadingState(
                  context,
                  variant: LoadingVariant.spinner,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}
