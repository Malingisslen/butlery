import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/onboarding/onboarding_dietary_page.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

// Gluten and lactose are allergens on the allergen page, not diets here
// (BUT-2307, one list).
const _dietaryKeys = {
  'vegetarisk',
  'vegansk',
  'pescetarian',
  'halalanpassad',
  'kosheranpassad',
};

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

    testWidgets('the cards select exactly the five diets, and gluten-free '
        'and lactose-free are not offered', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      final cards = _findDietaryCards();
      final count = tester.widgetList(cards).length;
      for (var i = 0; i < count; i++) {
        await tester.ensureVisible(cards.at(i));
        await tester.tap(cards.at(i));
        await tester.pumpAndSettle();
      }

      expect(viewModel.selectedDietaryPrefs, _dietaryKeys);
      final context = tester.element(find.byType(OnboardingDietaryPage));
      expect(find.text(context.l10n.onboardingDietaryGlutenFree), findsNothing);
      expect(
        find.text(context.l10n.onboardingDietaryLactoseFree),
        findsNothing,
      );
    });

    testWidgets('initially no check_circle icons', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(find.byIcon(ButleryIcons.circleCheck), findsNothing);
    });

    testWidgets('tapping shows check_circle icon', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Tap the first dietary card (Vegetarisk)
      await tester.tap(_findDietaryCards().first);
      await tester.pumpAndSettle();

      expect(find.byIcon(ButleryIcons.circleCheck), findsOneWidget);
      expect(viewModel.isDietaryPrefSelected('vegetarisk'), isTrue);
    });

    testWidgets('each card shows label and description', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      final cards = tester.widgetList(_findDietaryCards());
      expect(cards.length, _dietaryKeys.length);

      // Each card has label + description; page has title + description.
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(
        textWidgets.length,
        greaterThanOrEqualTo(_dietaryKeys.length * 2 + 2),
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

      expect(find.byIcon(ButleryIcons.circleCheck), findsNWidgets(2));
      expect(viewModel.isDietaryPrefSelected('vegetarisk'), isTrue);
      expect(viewModel.isDietaryPrefSelected('vegansk'), isTrue);
    });
  });
}
