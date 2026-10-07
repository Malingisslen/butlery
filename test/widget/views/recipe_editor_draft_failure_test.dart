// BUT-2224 = A: a failed draft write shows the warning triangle and the
// failure snackbar in both editors. The write ends without a keystroke, so
// these pin the whole chain from the auto-save manager to the top bar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/views/edit_recipe_view.dart';
import 'package:butlery/views/skriv_sjalv_recept_view.dart';
import 'package:butlery/widgets/recipe/recipe_form/draft_save_indicator.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../test_support/base_unit_test.dart';

void main() {
  group('a failed draft write reaches the editor without a keystroke', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      production.ServiceLocator.initialize(DIContainer());
    });

    // Same seam as recipe_form_meal_type_dropdown_test.dart: the view builds a
    // real RecipeFormViewModel, so its dependencies have to be resolvable.
    setUp(() async {
      await TestServiceLocator.initialize();
      // The draft write reaches SharedPreferences, whose platform channel
      // never answers in a widget test without a mock.
      SharedPreferences.setMockInitialValues({});
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

    const snackbarText =
        'Utkastet kunde inte sparas. Det du skrivit finns kvar här. '
        'Tryck Spara för att spara receptet.';

    // `jsonEncode` throws on an [Object], so the draft write fails inside the
    // manager's try, as a throwing storage write does.
    Map<String, dynamic> unwritable() => {'title': 'Soppa', 'extra': Object()};

    Future<void> failDraftWrite(WidgetTester tester) async {
      final vm = tester
          .element(find.byType(DraftSaveIndicator))
          .read<RecipeFormViewModel>();
      await vm.state.autoSaveManager.saveNow(unwritable());
      // One frame redraws the top bar, the next shows the snackbar.
      await tester.pump();
      await tester.pump();
    }

    testWidgets('Skriv själv shows the triangle and the snackbar', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const SkrivSjalvReceptView(),
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('draft-save-failed')), findsNothing);

      await failDraftWrite(tester);

      expect(find.byKey(const ValueKey('draft-save-failed')), findsOneWidget);
      expect(find.text(snackbarText), findsOneWidget);
    });

    testWidgets('the recipe editor shows the triangle and the snackbar', (
      tester,
    ) async {
      final recipe = RecipeFactory.build(
        id: 'recipe-but-2224',
        title: 'Testrecept',
        ingredients: const ['Mjöl'],
        instructions: const ['Blanda'],
        createdBy: 'test-user-123',
      );
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: EditRecipeView(recipe: recipe),
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('draft-save-failed')), findsNothing);

      await failDraftWrite(tester);

      expect(find.byKey(const ValueKey('draft-save-failed')), findsOneWidget);
      expect(find.text(snackbarText), findsOneWidget);
    });
  });
}
