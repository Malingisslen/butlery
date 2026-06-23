// Widget tests for BUT-725: onboarding pages must not overflow at landscape
// phone height (~360-400dp). Cooking-mode is intentionally landscape-optimized
// and out of scope; these guard the standard onboarding wizard pages.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/onboarding/onboarding_welcome_page.dart';
import 'package:butlery/views/onboarding/onboarding_dietary_page.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// Landscape phone size — narrowest realistic surface where overflow shows up.
/// Matches a portrait-360dp device rotated, with browser chrome ignored.
const Size _landscapePhone = Size(800, 360);

Future<void> _pumpAtSize(WidgetTester tester, Widget app, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Widget _wrap(Widget page, OnboardingViewModel vm) {
  return ChangeNotifierProvider<OnboardingViewModel>.value(
    value: vm,
    child: createLocalizedTestApp(child: page),
  );
}

void main() {
  group('Onboarding landscape overflow (BUT-725)', () {
    late OnboardingViewModel viewModel;

    setUp(() {
      viewModel = OnboardingViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    testWidgets(
      'OnboardingWelcomePage scrolls instead of overflowing at landscape',
      (tester) async {
        await _pumpAtSize(
          tester,
          _wrap(const OnboardingWelcomePage(), viewModel),
          _landscapePhone,
        );

        // No RenderFlex overflow exception was thrown during pumpAndSettle.
        expect(tester.takeException(), isNull);
        // SingleChildScrollView is now the page's outermost layout widget.
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      },
    );

    testWidgets(
      'OnboardingDietaryPage scrolls instead of overflowing at landscape',
      (tester) async {
        await _pumpAtSize(
          tester,
          _wrap(const OnboardingDietaryPage(), viewModel),
          _landscapePhone,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      },
    );
  });
}
