// Widget tests for the onboarding age-gate step (GDPR Art 8).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/onboarding/onboarding_age_gate_page.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

Widget _testApp({required OnboardingViewModel viewModel}) {
  return ChangeNotifierProvider<OnboardingViewModel>.value(
    value: viewModel,
    child: createLocalizedTestApp(
      child: const OnboardingAgeGatePage(),
    ),
  );
}

void main() {
  group('OnboardingAgeGatePage', () {
    late OnboardingViewModel viewModel;

    setUp(() {
      viewModel = OnboardingViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    testWidgets('renders the birth-year dropdown', (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('onboarding_age_gate_birth_year_dropdown')),
        findsOneWidget,
      );
    });

    testWidgets(
        'selecting an adult year updates the viewmodel and clears the gate',
        (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Open the dropdown.
      await tester.tap(
        find.byKey(const Key('onboarding_age_gate_birth_year_dropdown')),
      );
      await tester.pumpAndSettle();

      final adultYear = DateTime.now().year - 25;
      // Menu items render multiple matches (selected + option rows). The
      // last() one is the menu entry; tapping it commits the selection.
      await tester.tap(find.text(adultYear.toString()).last);
      await tester.pumpAndSettle();

      expect(viewModel.selectedBirthYear, equals(adultYear));
      expect(viewModel.isAgeGatePassed, isTrue);
    });

    testWidgets(
        'selecting a too-young year fails the gate without touching birthYear rules',
        (tester) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Drive the gate directly via the viewmodel — the dropdown only offers
      // years >= currentYear-13, but the under-15 case is
      // currentYear-14 ... currentYear-13. Both are reachable via the picker.
      final tooYoung = DateTime.now().year - 13; // age 13, under 15
      viewModel.setBirthYear(tooYoung);
      await tester.pumpAndSettle();

      expect(viewModel.selectedBirthYear, equals(tooYoung));
      expect(viewModel.isAgeGatePassed, isFalse);
    });
  });
}
