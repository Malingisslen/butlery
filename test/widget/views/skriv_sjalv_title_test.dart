import 'package:flutter_test/flutter_test.dart';
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
import 'package:butlery/views/skriv_sjalv_recept_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../test_support/base_unit_test.dart';

void main() {
  group(
    'Skriv själv top bar names the screen by whether a recipe is stored',
    () {
      setUpAll(() async {
        await BaseUnitTest.setupUnit();
        production.ServiceLocator.initialize(DIContainer());
      });

      setUp(() async {
        await TestServiceLocator.initialize();
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
        TestServiceLocator.registerMock<ImageUploadService>(
          ImageUploadService(),
        );
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

      Future<void> pumpView(WidgetTester tester, {Recipe? recipe}) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SkrivSjalvReceptView(initialRecipe: recipe),
            wrapInScaffold: false,
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets(
        'a new recipe says "Skriv nytt recept", not "Redigera recept"',
        (
          tester,
        ) async {
          await pumpView(tester);

          expect(find.text('Skriv nytt recept'), findsOneWidget);
          expect(find.text('Redigera recept'), findsNothing);
        },
      );

      testWidgets('a stored recipe says "Redigera recept"', (tester) async {
        await pumpView(
          tester,
          recipe: RecipeFactory.build(
            id: 'stored-recipe',
            title: 'Testrecept',
            description: 'Beskrivning',
            ingredients: const ['Mjöl'],
            instructions: const ['Blanda'],
          ),
        );

        expect(find.text('Redigera recept'), findsOneWidget);
        expect(find.text('Skriv nytt recept'), findsNothing);
      });
    },
  );
}
