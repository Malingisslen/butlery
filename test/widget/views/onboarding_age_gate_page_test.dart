// Widget tests for the onboarding age-gate step (floor 15 — ADR-0001 /
// Dataskyddslag 2 kap. 4 §).

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

    testWidgets('does not auto-select a year on render (age gate)', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Compliance: the gate must not pre-fill an adult default that would let
      // the user pass without an explicit age declaration.
      expect(viewModel.selectedBirthYear, isNull);
      expect(viewModel.isAgeGatePassed, isFalse);
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

        // No value is pre-selected now (GDPR gate), so the menu opens scrolled
        // to the top (youngest years first). Pick an adult year near the top so
        // it renders without scrolling. age 16 >= 15 -> passes the gate.
        final adultYear = DateTime.now().year - 16;
        await tester.tap(find.text(adultYear.toString()).last);
        await tester.pumpAndSettle();

        expect(viewModel.selectedBirthYear, equals(adultYear));
        expect(viewModel.isAgeGatePassed, isTrue);
      },
    );

    testWidgets(
      'selecting a too-young year fails the gate without touching birthYear rules',
      (tester) async {
        await tester.pumpWidget(_testApp(viewModel: viewModel));
        await tester.pumpAndSettle();

        // Drive the gate directly via the viewmodel — any year that maps to an
        // age under the 15 floor (ADR-0001) must fail the gate. age 13 is one
        // such case and is reachable via the picker.
        final tooYoung = DateTime.now().year - 13; // age 13, under the 15 floor
        viewModel.setBirthYear(tooYoung);
        await tester.pumpAndSettle();

        expect(viewModel.selectedBirthYear, equals(tooYoung));
        expect(viewModel.isAgeGatePassed, isFalse);
      },
    );
  });
}
