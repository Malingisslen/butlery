// P5-U09 (matlagningsläge ERROR): a swap that cannot be saved says so, says
// the recipe is unchanged, and Försök igen saves the same swap again
// (content-style-guide.md:87-97). It used to be a bare snackbar with no
// action.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/views/cooking_mode_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  late MockUnifiedRecipeService recipes;
  late BuildContext ctx;
  late AppLocalizations l10n;

  setUp(() {
    recipes = MockUnifiedRecipeService();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (c) {
            ctx = c;
            l10n = AppLocalizations.of(c);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Future<void> swap(WidgetTester tester) async {
    await persistCookingSubstitution(
      ctx,
      recipes,
      recipeId: 'r1',
      index: 2,
      name: 'havremjölk',
    );
    await tester.pumpAndSettle();
  }

  String failure() => SnackBarUtils.failureMessage(
    l10n.cookingModeSubstitutionFailed,
    l10n.cookingModeRecipeUnchanged,
  );

  testWidgets('a thrown save shows the three parts and retries the swap', (
    tester,
  ) async {
    var calls = 0;
    when(() => recipes.updateIngredient(any(), any(), any())).thenAnswer((
      _,
    ) async {
      calls++;
      if (calls == 1) throw Exception('unavailable');
      return true;
    });
    await pump(tester);
    await swap(tester);

    expect(find.text(failure()), findsOneWidget);
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();

    verify(() => recipes.updateIngredient('r1', 2, 'havremjölk')).called(2);
    expect(find.text(l10n.cookingModeSubstitutionApplied), findsOneWidget);
  });

  testWidgets('a save that returns false is a failure, not a success', (
    tester,
  ) async {
    when(
      () => recipes.updateIngredient(any(), any(), any()),
    ).thenAnswer((_) async => false);
    await pump(tester);
    await swap(tester);

    expect(find.text(failure()), findsOneWidget);
    expect(find.text(l10n.cookingModeSubstitutionApplied), findsNothing);
  });
}
