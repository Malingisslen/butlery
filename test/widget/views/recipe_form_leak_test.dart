// BUT-1687: opening and closing a recipe form leaves no TextEditingController
// behind (BUT-1667 restored the three missing dispose calls).
//
// What closing the form also does, on purpose: it abandons a save still waiting
// on an image upload (`RecipeFormViewModel.dispose` kills the persistence
// manager first, `RecipeFormState.createRecipe` throws once disposed), because
// a half-saved recipe from a screen the user walked away from is worse than
// none. That path is pinned in recipe_form_state_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/edit_recipe_view.dart';
import 'package:butlery/views/skriv_sjalv_recept_view.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../test_support/base_unit_test.dart';

void main() {
  LeakTesting.enable();
  group('closing a recipe form leaks nothing', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      production.ServiceLocator.initialize(DIContainer());
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      // The editor writes a draft from the first edit (P6-U08a),
      // so the real auto-save manager reaches SharedPreferences in every test.
      SharedPreferences.setMockInitialValues({});
      // Both views build a real RecipeFormViewModel; EditRecipeView also
      // resolves CollaborativeStatusViewModel in initState. Same seam the
      // BUT-1309 tab-order suite uses (focus_traversal_group_test.dart).
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
      final offline = OfflineService(
        authRepository: TestServiceLocator.get<AuthRepository>(),
      );
      TestServiceLocator.registerMock<OfflineService>(offline);
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

    Recipe recipe() => RecipeFactory.build(
      id: 'recipe-but-1687',
      title: 'Testrecept',
      description: 'Beskrivning',
      ingredients: const ['Mjöl', 'Socker'],
      instructions: const ['Blanda', 'Grädda'],
    );

    Future<void> openAndClose(WidgetTester tester, Widget form) async {
      await tester.pumpWidget(
        createLocalizedTestApp(child: form, wrapInScaffold: false),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    // The offline service is a fixture the locator tears down after the leak
    // check runs; it is not part of the form.
    final settings = LeakTesting.settings.withIgnored(
      classes: const ['OfflineService'],
    );

    testWidgets(
      'SkrivSjalvReceptView',
      (tester) =>
          openAndClose(tester, SkrivSjalvReceptView(initialRecipe: recipe())),
      experimentalLeakTesting: settings,
    );

    testWidgets(
      'EditRecipeView',
      (tester) => openAndClose(tester, EditRecipeView(recipe: recipe())),
      experimentalLeakTesting: settings,
    );
  });
}
