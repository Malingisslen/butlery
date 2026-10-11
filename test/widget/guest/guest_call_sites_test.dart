// BUT-920: the places that offer a guest an account instead of acting, and
// the Hem header that carries the guest band.

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/viewmodels/hem/hem_viewmodel.dart';
import 'package:butlery/views/hem/hem_section.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'guest_test_support.dart';

final _sv = AppLocalizationsSv();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(resetLocator);

  group('recipe detail sharing', () {
    final entries = <String, Future<void> Function(BuildContext)>{
      'share': (c) => RecipeDetailActions().shareRecipe(c),
      'share to friends': (c) => RecipeDetailActions().showSocialShareDialog(c),
    };

    Future<BuildContext> pumpHost(WidgetTester tester, {required bool guest}) {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: guest)));
      late BuildContext context;
      return tester
          .pumpWidget(
            guestApp(
              Builder(
                builder: (c) {
                  context = c;
                  return const SizedBox();
                },
              ),
            ),
          )
          .then((_) => context);
    }

    for (final entry in entries.entries) {
      testWidgets('${entry.key}: a guest is offered an account and the '
          'sharing never starts', (tester) async {
        final context = await pumpHost(tester, guest: true);

        // The handlers behind the gate read the recipe view model, which is
        // not in this tree: reaching them would throw.
        final done = entry.value(context);
        await tester.pumpAndSettle();
        await done;

        expect(find.text(_sv.guestSheetShareTitle), findsOneWidget);
      });

      testWidgets('${entry.key}: anyone else goes on to the sharing', (
        tester,
      ) async {
        final context = await pumpHost(tester, guest: false);

        await expectLater(
          entry.value(context),
          throwsA(isA<ProviderNotFoundException>()),
          reason: 'the gate let it through to the handler',
        );
        expect(find.text(_sv.guestSheetShareTitle), findsNothing);
      });
    }
  });

  group('Hem header', () {
    Future<void> pumpHem(WidgetTester tester, {required bool guest}) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: guest)));
      final viewModel = HemViewModel(
        readWeek: (_) => throw StateError('library is empty, no plan read'),
        recipeById: (_) => null,
        pantryIngredientIds: () async => {},
        isOnline: () => true,
      );
      await tester.pumpWidget(
        guestApp(
          SingleChildScrollView(
            child: HemSection(
              viewModel: viewModel,
              now: DateTime(2026, 7, 9, 18),
              firstName: null,
              libraryEmpty: true,
              isOnline: true,
              onStartCooking: (_) {},
              onOpenMenu: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a guest sees the band and the allergy card', (tester) async {
      await pumpHem(tester, guest: true);

      expect(find.text(_sv.guestBandLabel), findsOneWidget);
      expect(find.text(_sv.guestAllergyTitle), findsOneWidget);
    });

    testWidgets('anyone else sees neither', (tester) async {
      await pumpHem(tester, guest: false);

      expect(find.text(_sv.guestBandLabel), findsNothing);
      expect(find.text(_sv.guestAllergyTitle), findsNothing);
    });
  });
}
