// BUT-2503: on a phone-width screen the banners' action button sat beside the
// message and squeezed it into a column so narrow that words broke mid-word.
// The message must keep most of the banner's width at a large text size.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/views/mina_recept/empty_state_widgets.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockRecipeListViewModel extends Mock implements RecipeListViewModel {}

final _sv = AppLocalizationsSv();

void main() {
  late _MockRecipeListViewModel vm;

  setUp(() => vm = _MockRecipeListViewModel());

  Future<double> messageWidthShare(
    WidgetTester tester,
    Widget banner,
    String message,
  ) async {
    const screenWidth = 360.0;
    tester.view.physicalSize = const Size(screenWidth, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(screenWidth, 800),
            textScaler: TextScaler.linear(1.5),
          ),
          child: banner,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.text(message)).width / screenWidth;
  }

  testWidgets('onboarding banner keeps the message wide at large text', (
    tester,
  ) async {
    final share = await messageWidthShare(
      tester,
      MinaReceptOnboardingBanner(viewModel: vm),
      _sv.onboardingSkippedBanner,
    );
    expect(share, greaterThan(0.6));
    expect(find.text(_sv.onboardingSkippedBannerAction), findsOneWidget);
  });

  testWidgets('welcome banner keeps the message wide at large text', (
    tester,
  ) async {
    final share = await messageWidthShare(
      tester,
      MinaReceptWelcomeBanner(viewModel: vm),
      _sv.onboardingWelcomeBanner,
    );
    expect(share, greaterThan(0.6));
    expect(find.text(_sv.onboardingWelcomeBannerAction), findsOneWidget);
  });
}
