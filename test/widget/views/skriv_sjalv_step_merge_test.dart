/// BUT-2455: on the form an import opens, two steps an import cut apart are
/// joined with the link between them, and the snackbar's Ångra undoes it.
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
import 'package:butlery/views/skriv_sjalv_recept_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../test_support/base_unit_test.dart';

void main() {
  group(
    'Skriv själv: joining two steps',
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
            child: SkrivSjalvReceptView(
              initialRecipe: RecipeFactory.build(
                id: 'imported-recipe',
                title: 'Krämig gryta',
                ingredients: const ['2 dl grädde', '1 gul lök'],
                instructions: const [
                  'Stek löken.',
                  'Häll i grädden.',
                  'Servera.',
                ],
              ),
              isTemplate: true,
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

      // The form is a lazy list: the steps are built only once scrolled near.
      Future<void> scrollToSteps(WidgetTester tester) =>
          tester.scrollUntilVisible(
            find.byKey(const ValueKey('step-merge-1')),
            200,
            scrollable: find.byType(Scrollable).first,
          );

      testWidgets('a step joins the next, and Ångra splits them again', (
        tester,
      ) async {
        // Tall enough that the steps clear the save bar at the bottom.
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpForm(tester);
        await scrollToSteps(tester);

        // Two links for three steps: none above the empty line the form keeps
        // last, and none among the ingredients.
        expect(find.byKey(const ValueKey('step-merge-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('step-merge-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('step-merge-2')), findsNothing);
        expect(find.text('Slå ihop med nästa'), findsNWidgets(2));

        final link = find.byKey(const ValueKey('step-merge-0'));
        await tester.ensureVisible(link);
        await tester.pumpAndSettle();
        await tester.tap(link);
        await tester.pump();

        expect(fieldTexts(tester), contains('Stek löken. Häll i grädden.'));
        expect(fieldTexts(tester), isNot(contains('Häll i grädden.')));
        expect(find.text('Slå ihop med nästa'), findsOneWidget);
        expect(find.text('Stegen slogs ihop'), findsOneWidget);

        // Let the snackbar finish sliding in before its action is tapped.
        await tester.pump(const Duration(milliseconds: 750));
        await tester.tap(find.text('Ångra'));
        await tester.pump();

        final texts = fieldTexts(tester);
        final first = texts.indexOf('Stek löken.');
        expect(first, isNonNegative);
        expect(texts.sublist(first, first + 3), [
          'Stek löken.',
          'Häll i grädden.',
          'Servera.',
        ]);
        expect(find.text('Slå ihop med nästa'), findsNWidgets(2));
      });
    },
  );
}
