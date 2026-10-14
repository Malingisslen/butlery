// Megagenomgång B (09): Android's back used to be swallowed on every
// onboarding step (PopScope with no handler). It now goes one step back, like
// the Tillbaka button, and stays put on the first step.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/onboarding/onboarding_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    GetIt.instance.registerFactory<OnboardingViewModel>(
      () => OnboardingViewModel(),
    );
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  OnboardingViewModel vmOf(WidgetTester tester) =>
      Provider.of<OnboardingViewModel>(
        tester.element(find.byType(Scaffold).first),
        listen: false,
      );

  testWidgets('back goes one step back, and stays on the first step', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const OnboardingView(initialPage: 2),
      ),
    );
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(vmOf(tester).currentPage, 2);

    unawaited(navigator.maybePop());
    await tester.pumpAndSettle();
    expect(vmOf(tester).currentPage, 1);

    unawaited(navigator.maybePop());
    await tester.pumpAndSettle();
    expect(vmOf(tester).currentPage, 0);

    unawaited(navigator.maybePop());
    await tester.pumpAndSettle();
    expect(vmOf(tester).currentPage, 0);
  });
}
