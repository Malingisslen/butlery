// BUT-1910: the rating field lost a Swedish decimal comma without saying so.
//
// The field offers a decimal keyboard, so the comma is typeable, but the value
// was read with `double.tryParse`, which returns null on a comma. Typing "4,5"
// therefore set no rating at all — no error, nothing on screen, just no effect.
// The sibling of BUT-1891, where the same root cause produced a VISIBLE wrong
// number ("1,5" became "15") instead of a silent nothing.
//
// A note on the number. The ticket's worked example is "8,5", but the field is
// labelled "Betyg (0–5)" and `FormValidators.rating()` bounds it to 0–5, so 8,5
// is out of range whichever separator is typed. The defect is the separator,
// not the magnitude, so these cases use an in-range 4,5 — the value a user
// actually enters.
//
// The validator was never the problem and is not what these pin:
// `FormValidators.rating()` delegates to `numberRange`, which does its OWN
// comma-aware parse. So the field reported itself VALID while the value was
// being dropped — the two halves disagreed, which is why nothing looked wrong.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/views/edit_recipe_view.dart';
import 'package:butlery/views/skriv_sjalv_recept_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../test_support/base_unit_test.dart';

void main() {
  group('the rating field reads a Swedish decimal comma', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      production.ServiceLocator.initialize(DIContainer());
    });

    // Same seam as recipe_form_meal_type_dropdown_test.dart: the view builds a
    // real RecipeFormViewModel, so its dependencies have to be resolvable.
    setUp(() async {
      await TestServiceLocator.initialize();
      TestServiceLocator.registerMock<AuthService>(
        MockFactory.createAuthService(
          isAuthenticated: true,
          userId: 'test-user-123',
        ),
      );
      TestServiceLocator.registerMock<PermissionService>(
        MockFactory.createPermissionService(currentUserId: 'test-user-123'),
      );
      TestServiceLocator.registerMock<SocialRecipeService>(
        MockFactory.createSocialRecipeService(),
      );
      TestServiceLocator.registerFactory<CollaborativeStatusViewModel>(
        () => CollaborativeStatusViewModel(),
      );
      TestServiceLocator.registerMock<ImageUploadService>(ImageUploadService());
      final mockTagService = mocks.MockPersonalTagService();
      TestServiceLocator.registerMock<PersonalTagService>(mockTagService);
      TestServiceLocator.registerMock<OfflineService>(
        OfflineService(
          firestoreRepository: TestServiceLocator.get<FirestoreRepository>(),
          authRepository: TestServiceLocator.get<AuthRepository>(),
        ),
      );
      TestServiceLocator.registerFactory<PersonalTagViewModel>(
        () => PersonalTagViewModel(service: mockTagService),
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    Recipe ratedRecipe(double? rating) => RecipeFactory.build(
      id: 'recipe-but-1910',
      title: 'Testrecept',
      description: 'Beskrivning',
      ingredients: const ['Mjöl', 'Socker'],
      instructions: const ['Blanda', 'Grädda'],
      rating: rating,
    );

    Future<void> pumpForm(WidgetTester tester, {Recipe? initialRecipe}) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SkrivSjalvReceptView(initialRecipe: initialRecipe),
          // The view ships its own Scaffold.
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder ratingField() => find.widgetWithText(TextFormField, 'Betyg (0–5)');

    RecipeFormViewModel viewModel(WidgetTester tester) =>
        tester.element(ratingField()).read<RecipeFormViewModel>();

    /// The form body is a lazy `ListView`, so the rating field is not built
    /// until it is scrolled near. Finding it without this returns nothing and
    /// the failure reads like a missing widget rather than an unbuilt one.
    Future<void> revealRatingField(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        ratingField(),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> typeRating(WidgetTester tester, String text) async {
      await tester.enterText(ratingField(), text);
      await tester.pump();
    }

    testWidgets('a comma decimal sets the rating', (tester) async {
      await pumpForm(tester);
      await revealRatingField(tester);
      await typeRating(tester, '4,5');

      // The whole defect in one assertion: this was null.
      expect(viewModel(tester).rating, 4.5);
    });

    testWidgets('the form opens with a comma, not a period', (tester) async {
      // The half a parse-only fix leaves behind, and it shipped unpinned on
      // this screen until the testing gate said so: the field would READ a
      // comma while still OPENING with "4.5", which the first keystroke then
      // rewrites wholesale. Its twin on the edit screen has the same case.
      await pumpForm(tester, initialRecipe: ratedRecipe(4.5));
      await revealRatingField(tester);

      final field = tester.widget<TextFormField>(ratingField());
      expect(field.controller!.text, '4,5');
    });

    testWidgets('a period decimal still sets the rating', (tester) async {
      await pumpForm(tester);
      await revealRatingField(tester);
      await typeRating(tester, '4.5');

      // Whichever separator the keyboard offers, the value must land. The
      // formatter rewrites the period to a comma in the FIELD; the parser
      // reads both, so the stored value is the same either way.
      expect(viewModel(tester).rating, 4.5);
      final field = tester.widget<TextFormField>(ratingField());
      expect(field.controller!.text, '4,5');
    });

    // A CONTROL, not a regression test: `double.tryParse('4')` already worked.
    // It guards the direction this fix could overshoot in — a parser that
    // starts demanding a separator.
    testWidgets('a whole number is unaffected', (tester) async {
      await pumpForm(tester);
      await revealRatingField(tester);
      await typeRating(tester, '4');

      expect(viewModel(tester).rating, 4.0);
    });

    // Guards the direction the fix could overshoot in: `parseSwedishDecimal`
    // returns null rather than a default precisely so an empty or unreadable
    // field does not invent a rating. A parser with a fallback would store one.
    testWidgets('an empty field leaves the rating unset', (tester) async {
      await pumpForm(tester);
      await revealRatingField(tester);
      await typeRating(tester, '4,5');
      expect(viewModel(tester).rating, 4.5);

      await typeRating(tester, '');
      expect(viewModel(tester).rating, isNull);
    });
    // ── The TWIN ──────────────────────────────────────────────────────────
    //
    // `EditRecipeView` carried the same defect in its rating field, and it is
    // the one reached by editing a saved recipe. Fixing one screen without the
    // other leaves the bug on the other — the same split BUT-1845 had to cover
    // in both views, for the same reason. Found by the integration-reviewer
    // gate.
    //
    // The two FIELDS are not identical, and the difference is load-bearing
    // below: this one is a bare `TextFormField` seeded with `initialValue`, its
    // twin a `StyledInput` driven by a controller. Copying an assertion across
    // without noticing gets you a null-controller crash.
    group("the edit screen's rating field", () {
      Future<void> pumpEdit(WidgetTester tester, double? rating) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: EditRecipeView(recipe: ratedRecipe(rating)),
            wrapInScaffold: false,
          ),
        );
        await tester.pumpAndSettle();
      }

      Finder editRatingField() =>
          find.widgetWithText(TextFormField, 'Betyg (0–5)');

      Future<void> revealEditRatingField(WidgetTester tester) async {
        await tester.scrollUntilVisible(
          editRatingField(),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }

      testWidgets('a comma decimal sets the rating on the edit screen', (
        tester,
      ) async {
        await pumpEdit(tester, null);
        await revealEditRatingField(tester);
        await tester.enterText(editRatingField(), '4,5');
        await tester.pump();

        expect(
          tester.element(editRatingField()).read<RecipeFormViewModel>().rating,
          4.5,
        );
      });

      // M2 from the code-reviewer gate: the formatter line on this screen was
      // MUTATION-DEAD. The parse case and the seed case both survive deleting
      // it, because `parseSwedishDecimal` reads "4,5" and "4.5" alike and
      // `initialValue` is untouched by formatters. Without it, "1,5,5" makes
      // the parse return null and the rating silently vanishes, i.e. the
      // original defect, back.
      testWidgets('the edit screen refuses a second separator', (
        tester,
      ) async {
        await pumpEdit(tester, null);
        await revealEditRatingField(tester);
        await tester.enterText(editRatingField(), '1,5,5');
        await tester.pump();

        // Read off the EditableText, not `TextFormField.controller`: this field
        // is seeded with `initialValue` and has no controller of its own, so
        // that property is null. This spelling also survives the field being
        // converted to a controller later, which its twin already uses.
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: editRatingField(),
                  matching: find.byType(EditableText),
                ),
              )
              .controller
              .text,
          '1,55',
        );
        expect(
          tester.element(editRatingField()).read<RecipeFormViewModel>().rating,
          1.55,
          reason: 'a rejected second separator must not leave the rating unset',
        );
      });

      testWidgets('the edit screen opens with a comma, not a period', (
        tester,
      ) async {
        // The seed half, on this screen. Same rationale as its twin above.
        await pumpEdit(tester, 4.5);
        await revealEditRatingField(tester);

        expect(
          tester.widget<TextFormField>(editRatingField()).initialValue,
          '4,5',
        );
      });
    });
  });
}
