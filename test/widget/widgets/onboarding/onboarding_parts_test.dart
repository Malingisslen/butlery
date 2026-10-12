import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/onboarding/onboarding_setup_page.dart';
import 'package:butlery/widgets/onboarding/onboarding_parts.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _SetupVm extends OnboardingViewModel {
  _SetupVm(
    this.phase, {
    this.recipes = 0,
    this.allergens = false,
    this.week = false,
  });

  final OnboardingSetupPhase phase;
  final int recipes;
  final bool allergens;
  final bool week;

  @override
  OnboardingSetupPhase get setupPhase => phase;
  @override
  int get starterRecipeCount => recipes;
  @override
  bool get hasAllergens => allergens;
  @override
  bool get weekSeeded => week;
}

void main() {
  group('OnboardingNavButtons', () {
    Widget app({
      VoidCallback? onNext,
      VoidCallback? onBack,
      bool busy = false,
    }) => createLocalizedTestApp(
      child: OnboardingNavButtons(
        nextLabel: 'Nästa',
        onNext: onNext,
        onBack: onBack,
        busy: busy,
      ),
    );

    testWidgets('without an answer, Nästa is an empty frame that cannot be '
        'pressed', (tester) async {
      await tester.pumpWidget(app());
      expect(find.byType(FilledButton), findsNothing);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    });

    testWidgets('with an answer, Nästa is filled and calls back', (
      tester,
    ) async {
      var next = 0;
      var back = 0;
      await tester.pumpWidget(app(onNext: () => next++, onBack: () => back++));
      await tester.tap(find.text('Nästa'));
      await tester.tap(find.text('Tillbaka'));
      expect(next, 1);
      expect(back, 1);
    });

    testWidgets('busy keeps the name, ignores taps on both buttons', (
      tester,
    ) async {
      var next = 0;
      var back = 0;
      await tester.pumpWidget(
        app(onNext: () => next++, onBack: () => back++, busy: true),
      );
      expect(find.text('Nästa'), findsOneWidget);
      await tester.tap(find.text('Nästa'), warnIfMissed: false);
      await tester.tap(find.text('Tillbaka'), warnIfMissed: false);
      expect(next, 0);
      expect(back, 0);
    });
  });

  group('OnboardingStepDashes', () {
    testWidgets('names the step it stands on', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const OnboardingStepDashes(count: 4, current: 1),
        ),
      );
      final context = tester.element(find.byType(OnboardingStepDashes));
      expect(
        find.bySemanticsLabel(context.l10n.onboardingStepOf(2, 4)),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('onboardingCountKey', () {
    test('names 0..10 and prints larger counts as digits', () {
      expect(onboardingCountKey(0), 'zero');
      expect(onboardingCountKey(6), 'six');
      expect(onboardingCountKey(10), 'ten');
      expect(onboardingCountKey(11), 'other');
    });
  });

  group('OnboardingSetupPage', () {
    Widget app(OnboardingViewModel vm) =>
        ChangeNotifierProvider<OnboardingViewModel>.value(
          value: vm,
          child: createLocalizedTestApp(child: const OnboardingSetupPage()),
        );

    testWidgets('while the allergens are saved, the first row names the job', (
      tester,
    ) async {
      final vm = _SetupVm(OnboardingSetupPhase.preferences);
      addTearDown(vm.dispose);
      await tester.pumpWidget(app(vm));
      await tester.pump();
      final context = tester.element(find.byType(OnboardingSetupPage));

      expect(find.text(context.l10n.onboardingSetupTitle), findsOneWidget);
      expect(find.text(context.l10n.onboardingSetupSaving), findsOneWidget);
      expect(find.text(context.l10n.onboardingDoneTitle), findsNothing);
    });

    testWidgets('when done, it says the table is set and that Hem is next', (
      tester,
    ) async {
      final vm = _SetupVm(
        OnboardingSetupPhase.done,
        recipes: 6,
        allergens: true,
        week: true,
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(app(vm));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(OnboardingSetupPage));

      expect(find.text(context.l10n.onboardingDoneTitle), findsOneWidget);
      expect(find.text(context.l10n.onboardingSetupSaved), findsOneWidget);
      expect(
        find.text(context.l10n.onboardingSetupRecipesDone('six', 6)),
        findsOneWidget,
      );
      expect(find.text(context.l10n.onboardingSetupWeekDone), findsOneWidget);
      expect(find.text(context.l10n.onboardingDoneRedirect), findsOneWidget);
    });

    testWidgets('recipes that could not be laid out are said so, not hidden', (
      tester,
    ) async {
      final vm = _SetupVm(OnboardingSetupPhase.done);
      addTearDown(vm.dispose);
      await tester.pumpWidget(app(vm));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(OnboardingSetupPage));

      expect(
        find.text(context.l10n.onboardingSetupRecipesFailed),
        findsOneWidget,
      );
      expect(find.text(context.l10n.onboardingSetupSavedNone), findsOneWidget);
      expect(
        find.text(context.l10n.onboardingSetupWeekFailed),
        findsOneWidget,
      );
    });
  });
}
