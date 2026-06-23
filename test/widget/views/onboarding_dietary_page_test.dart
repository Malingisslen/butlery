import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/onboarding/onboarding_dietary_page.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// The page now renders 7 dietary options (vegetarisk, vegansk, pescetarian,
/// glutenfri, laktosfri, halalanpassad, kosheranpassad).
const _dietaryOptionCount = 7;

Widget _testApp({required OnboardingViewModel viewModel}) {
  return ChangeNotifierProvider<OnboardingViewModel>.value(
    value: viewModel,
    // Page now wraps its own SingleChildScrollView (BUT-725 landscape fix);
    // do not wrap again here or constraints become unbounded.
    child: createLocalizedTestApp(
      child: const OnboardingDietaryPage(),
    ),
  );
}

/// Find the dietary toggle cards by their GestureDetector inside Semantics
/// (each _DietaryToggleCard wraps GestureDetector in a Semantics widget
/// with `button: true`).
Finder _findDietaryCards() {
  return find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.button == true,
  );
}

void main() {
  group('OnboardingDietaryPage', () {
    late OnboardingViewModel viewModel;

    setUp(() {
      viewModel = OnboardingViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    testWidgets('renders all dietary cards', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(_findDietaryCards(), findsNWidgets(_dietaryOptionCount));
    });

    testWidgets('initially no check_circle icons', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('tapping shows check_circle icon', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Tap the first dietary card (Vegetarisk)
      await tester.tap(_findDietaryCards().first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(viewModel.isDietaryPrefSelected('vegetarisk'), isTrue);
    });

    testWidgets('each card shows label and description', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      final cards = tester.widgetList(_findDietaryCards());
      expect(cards.length, _dietaryOptionCount);

      // Each card has label + description; page has title + description
      // So at minimum _dietaryOptionCount*2 + 2 Text widgets
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(
        textWidgets.length,
        greaterThanOrEqualTo(_dietaryOptionCount * 2 + 2),
      );
    });

    testWidgets('can select multiple simultaneously', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Select first (vegetarisk)
      await tester.tap(_findDietaryCards().first);
      await tester.pumpAndSettle();

      // Select second (vegansk)
      await tester.tap(_findDietaryCards().at(1));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(viewModel.isDietaryPrefSelected('vegetarisk'), isTrue);
      expect(viewModel.isDietaryPrefSelected('vegansk'), isTrue);
    });
  });
}
