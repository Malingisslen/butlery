import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/onboarding/onboarding_allergen_page.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

Widget _testApp({required OnboardingViewModel viewModel}) {
  return ChangeNotifierProvider<OnboardingViewModel>.value(
    value: viewModel,
    child: createLocalizedTestApp(
      child: const OnboardingAllergenPage(),
    ),
  );
}

Finder _showAllToggle(BuildContext context) => find.byWidgetPredicate(
  (w) =>
      w is Semantics &&
      w.properties.label == context.l10n.onboardingShowAllAllergens,
);

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

      expect(find.byIcon(ButleryIcons.check), findsNothing);
    });

    testWidgets('tapping a card shows check icon', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Tap the first allergen card (find AnimatedContainer's GestureDetector parent)
      await tester.tap(find.byType(AnimatedContainer).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(ButleryIcons.check), findsOneWidget);
      expect(viewModel.isAllergenSelected('gluten'), isTrue);
    });

    testWidgets('tapping again deselects', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Select
      await tester.tap(find.byType(AnimatedContainer).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(ButleryIcons.check), findsOneWidget);

      // Deselect
      await tester.tap(find.byType(AnimatedContainer).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(ButleryIcons.check), findsNothing);
      expect(viewModel.isAllergenSelected('gluten'), isFalse);
    });

    testWidgets('collapsed, the page offers the primary allergens and the '
        'show-all toggle', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(
        find.byType(AnimatedContainer),
        findsNWidgets(AllergenPreferenceOptions.primaryAllergenKeys.length),
      );
      final context = tester.element(find.byType(OnboardingAllergenPage));
      expect(
        _showAllToggle(context),
        findsOneWidget,
      );
    });

    testWidgets('show all offers exactly the Settings allergen list, '
        'crustaceans and molluscs included', (tester) async {
      // Tall enough that the lazy grid builds every card at once.
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(OnboardingAllergenPage));
      await tester.tap(
        _showAllToggle(context),
      );
      await tester.pumpAndSettle();

      final cards = find.byType(AnimatedContainer);
      final count = tester.widgetList(cards).length;
      for (var i = 0; i < count; i++) {
        await tester.tap(cards.at(i));
        await tester.pumpAndSettle();
      }

      expect(
        viewModel.selectedAllergens,
        AllergenPreferenceOptions.allergens.keys.toSet(),
      );
      expect(
        viewModel.selectedAllergens,
        containsAll(['kräftdjur', 'blötdjur']),
      );
      expect(
        find.text(context.l10n.onboardingAllergenCrustacean),
        findsOneWidget,
      );
      expect(find.text(context.l10n.onboardingAllergenMollusc), findsOneWidget);
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
