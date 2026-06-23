import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/onboarding/onboarding_allergen_page.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

Widget _testApp({required OnboardingViewModel viewModel}) {
  return ChangeNotifierProvider<OnboardingViewModel>.value(
    value: viewModel,
    child: createLocalizedTestApp(
      child: const OnboardingAllergenPage(),
    ),
  );
}

void main() {
  group('OnboardingAllergenPage', () {
    late OnboardingViewModel viewModel;

    setUp(() {
      viewModel = OnboardingViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    testWidgets('renders allergen cards in a GridView', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // GridView is present
      expect(find.byType(GridView), findsOneWidget);
      // At least some allergen cards are visible (GridView is lazy)
      expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(4));
    });

    testWidgets('initially no check icons visible', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('tapping a card shows check icon', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Tap the first allergen card (find AnimatedContainer's GestureDetector parent)
      await tester.tap(find.byType(AnimatedContainer).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(viewModel.isAllergenSelected('gluten'), isTrue);
    });

    testWidgets('tapping again deselects', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Select
      await tester.tap(find.byType(AnimatedContainer).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Deselect
      await tester.tap(find.byType(AnimatedContainer).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsNothing);
      expect(viewModel.isAllergenSelected('gluten'), isFalse);
    });

    testWidgets('semantics toggled property tracks selection state', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Before selection: Semantics widget has toggled=false
      expect(viewModel.isAllergenSelected('gluten'), isFalse);

      // The _AllergenToggleCard wraps with Semantics(toggled: isSelected)
      // Verify the Semantics ancestor has button=true
      final cardFinder = find.byType(AnimatedContainer).first;
      final semanticsAncestor = find.ancestor(
        of: cardFinder,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.button == true,
        ),
      );
      expect(semanticsAncestor, findsAtLeastNWidgets(1));

      // After selection: toggled changes to true
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(viewModel.isAllergenSelected('gluten'), isTrue);

      // The Semantics widget now has toggled=true
      final semanticsAfter = find.ancestor(
        of: find.byType(AnimatedContainer).first,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.toggled == true,
        ),
      );
      expect(semanticsAfter, findsAtLeastNWidgets(1));
    });
  });
}
