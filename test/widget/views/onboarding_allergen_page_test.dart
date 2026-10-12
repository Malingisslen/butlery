import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/onboarding/onboarding_allergen_page.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/onboarding/onboarding_parts.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

Widget _testApp({required OnboardingViewModel viewModel}) {
  return ChangeNotifierProvider<OnboardingViewModel>.value(
    value: viewModel,
    child: createLocalizedTestApp(child: const OnboardingAllergenPage()),
  );
}

Finder _showAllToggle(BuildContext context, int moreCount) =>
    find.bySemanticsLabel(
      context.l10n.onboardingShowAllAllergens(
        onboardingCountKey(moreCount),
        moreCount,
      ),
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

    testWidgets('collapsed, the page offers the primary allergens as ruled '
        'rows', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(
        find.byType(OnboardingCheckRow),
        findsNWidgets(AllergenPreferenceOptions.primaryAllergenKeys.length),
      );
    });

    testWidgets('initially no check icons visible', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(find.byIcon(ButleryIcons.check), findsNothing);
    });

    testWidgets('tapping a row ticks it and tapping again clears it', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(OnboardingCheckRow).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(ButleryIcons.check), findsOneWidget);
      expect(viewModel.isAllergenSelected('gluten'), isTrue);

      await tester.tap(find.byType(OnboardingCheckRow).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(ButleryIcons.check), findsNothing);
      expect(viewModel.isAllergenSelected('gluten'), isFalse);
    });

    testWidgets('show all offers exactly the Settings allergen list, '
        'crustaceans and molluscs included', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(OnboardingAllergenPage));
      final moreCount = AllergenPreferenceOptions.extendedAllergenKeys.length;
      await tester.tap(_showAllToggle(context, moreCount));
      await tester.pumpAndSettle();

      final rows = find.byType(OnboardingCheckRow);
      final count = tester.widgetList(rows).length;
      for (var i = 0; i < count; i++) {
        await tester.tap(rows.at(i));
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

    testWidgets('a row announces itself as a toggle that follows the '
        'selection', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(OnboardingAllergenPage));
      final label = context.l10n.allergenToggleSemantics(
        context.l10n.onboardingAllergenGluten,
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(
          label: label,
          isButton: true,
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(
          label: label,
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
