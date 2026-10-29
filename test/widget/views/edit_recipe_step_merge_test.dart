/// BUT-2455: on Redigera recept, too, two steps are joined with the link
/// between them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
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

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../test_support/base_unit_test.dart';

void main() {
  group(
    'Redigera recept: joining two steps',
    () {
      setUpAll(() async {
        await BaseUnitTest.setupUnit();
        production.ServiceLocator.initialize(DIContainer());
      });

      setUp(() async {
        await TestServiceLocator.initialize();
        TestServiceLocator.registerMock<ParsedRecipeCache>(ParsedRecipeCache());
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

      Future<void> pumpForm(WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: EditRecipeView(
              recipe: RecipeFactory.build(
                id: 'saved-recipe',
                title: 'Krämig gryta',
                createdBy: 'test-user-123',
                ingredients: const ['2 dl grädde', '1 gul lök'],
                instructions: const [
                  'Stek löken.',
                  'Häll i grädden.',
                  'Servera.',
                ],
              ),
            ),
            wrapInScaffold: false,
          ),
        );
        await tester.pumpAndSettle();
      }

      List<String> fieldTexts(WidgetTester tester) => tester
          .widgetList<EditableText>(find.byType(EditableText))
          .map((e) => e.controller.text)
          .toList();

      testWidgets('a step joins the next', (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpForm(tester);

        final link = find.byKey(const ValueKey('step-merge-0'));
        await tester.scrollUntilVisible(
          link,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(link);
        await tester.pump();

        expect(fieldTexts(tester), contains('Stek löken. Häll i grädden.'));
        expect(fieldTexts(tester), isNot(contains('Häll i grädden.')));
        expect(find.text('Stegen slogs ihop'), findsOneWidget);
      });
    },
  );
}
