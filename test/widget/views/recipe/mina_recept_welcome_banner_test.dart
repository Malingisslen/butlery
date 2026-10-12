// The welcome banner's action takes a new user to the add sheet and
// dismisses the banner as it does.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/views/mina_recept/empty_state_widgets.dart';
import 'package:butlery/widgets/common/navigation/add_sheet.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockRecipeListViewModel extends Mock implements RecipeListViewModel {}

void main() {
  testWidgets(
    'the banner action opens the add sheet and dismisses the banner',
    (
      tester,
    ) async {
      final vm = _MockRecipeListViewModel();
      final sv = AppLocalizationsSv();

      await tester.pumpWidget(
        createLocalizedTestApp(child: MinaReceptWelcomeBanner(viewModel: vm)),
      );
      await tester.pumpAndSettle();
      // Positive anchor: the banner and its action are on screen, no sheet yet.
      expect(find.text(sv.onboardingWelcomeBannerAction), findsOneWidget);
      expect(find.byType(ButleryAddSheet), findsNothing);

      await tester.tap(find.text(sv.onboardingWelcomeBannerAction));
      await tester.pumpAndSettle();

      expect(find.byType(ButleryAddSheet), findsOneWidget);
      verify(vm.dismissWelcomeBanner).called(1);
    },
  );
}
