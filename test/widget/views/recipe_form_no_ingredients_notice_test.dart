// BUT-2285: an import that found no ingredients explains the empty list.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:butlery/views/skriv_sjalv_recept_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../test_support/base_unit_test.dart';

void main() {
  group('BUT-2285 no-ingredients notice', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      production.ServiceLocator.initialize(DIContainer());
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      // The editor writes a draft from the first edit (P6-U08a, ux-beslut D-02),
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

    Future<void> pump(
      WidgetTester tester, {
      required bool importedWithoutIngredients,
    }) async {
      // Tall enough that the lazy ListView builds the ingredient section.
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SkrivSjalvReceptView(
            initialRecipe: RecipeFactory.build(
              id: 'recipe-but-2285',
              title: 'Importerat',
              ingredients: const [],
              instructions: const ['Blanda'],
            ),
            isTemplate: true,
            importedWithoutIngredients: importedWithoutIngredients,
          ),
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();
    }

    final notice = find.text(
      'Vi hittade inga ingredienser. Lägg till dem själv nedan.',
    );

    testWidgets('is shown when the import found no ingredients', (
      tester,
    ) async {
      await pump(tester, importedWithoutIngredients: true);
      expect(notice, findsOneWidget);
    });

    testWidgets('is hidden when the form did not come from such an import', (
      tester,
    ) async {
      await pump(tester, importedWithoutIngredients: false);
      expect(notice, findsNothing);
    });

    testWidgets('disappears once an ingredient exists', (tester) async {
      await pump(tester, importedWithoutIngredients: true);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ingrediens 1'),
        '6 dl mjölk',
      );
      await tester.pumpAndSettle();
      expect(notice, findsNothing);
    });
  });
}
