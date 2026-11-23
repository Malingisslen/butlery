// Unread import lines: Spara asks before saving, and a tap outside a field
// puts the keyboard away.

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
import 'package:butlery/views/skriv_sjalv_recept_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/helpers/image_upload_service_from_get_it.dart';

import 'package:butlery/widgets/recipe/recipe_form/sectioned_ingredient_list_builder.dart';

void main() {
  group('skriv själv: unread import lines and the keyboard', () {
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
      TestServiceLocator.registerMock<ImageUploadService>(
        imageUploadServiceFromGetIt(),
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

    Future<RecipeFormViewModel> pump(
      WidgetTester tester, {
      required bool markFirstLine,
    }) async {
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SkrivSjalvReceptView(
            initialRecipe: RecipeFactory.build(
              id: 'recipe-unread',
              title: 'Pannkakor',
              ingredients: const ['3 dl'],
              instructions: const ['Blanda'],
            ),
            isTemplate: true,
          ),
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();
      final vm = tester
          .element(find.byType(SectionedIngredientListBuilder))
          .read<RecipeFormViewModel>();
      if (markFirstLine) {
        vm.state.ingredientSectionState.markLineUnread(0);
        // Any notifying edit rebuilds the list with the mark.
        vm.moveIngredientRow(0, 0);
        await tester.pumpAndSettle();
      }
      return vm;
    }

    final dialogTitle = find.text('En rad saknas');

    testWidgets('Spara asks about an unread line, Fyll i does not save', (
      tester,
    ) async {
      final vm = await pump(tester, markFirstLine: true);
      var saved = false;
      vm.addListener(() => saved = saved || vm.isSaving);

      await tester.tap(find.byKey(const ValueKey('test-skriv-sjalv-save')));
      await tester.pumpAndSettle();

      expect(dialogTitle, findsOneWidget);
      expect(
        find.text(
          'En ingrediensrad kunde inte läsas och är inte ifylld. Spara ändå?',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Fyll i'));
      await tester.pumpAndSettle();

      expect(dialogTitle, findsNothing);
      expect(saved, isFalse);
      expect(vm.unreadIngredientLinesLeft, 1);
    });

    testWidgets('"Spara ändå" goes on to save', (tester) async {
      final vm = await pump(tester, markFirstLine: true);
      var saved = false;
      vm.addListener(() => saved = saved || vm.isSaving);

      await tester.tap(find.byKey(const ValueKey('test-skriv-sjalv-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spara ändå'));
      await tester.pumpAndSettle();

      expect(dialogTitle, findsNothing);
      expect(saved, isTrue);
    });

    testWidgets('without an unread line Spara saves without asking', (
      tester,
    ) async {
      final vm = await pump(tester, markFirstLine: false);
      var saved = false;
      vm.addListener(() => saved = saved || vm.isSaving);

      await tester.tap(find.byKey(const ValueKey('test-skriv-sjalv-save')));
      await tester.pumpAndSettle();

      expect(dialogTitle, findsNothing);
      expect(saved, isTrue);
    });

    testWidgets('typing on the marked line takes its note away', (
      tester,
    ) async {
      final vm = await pump(tester, markFirstLine: true);
      expect(find.byKey(const ValueKey('ing_unread_note_0')), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, '3 dl'),
        '3 dl mjölk',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ing_unread_note_0')), findsNothing);
      expect(vm.unreadIngredientLinesLeft, 0);
    });

    bool inTextField() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;

    testWidgets('a tap outside the fields drops focus', (tester) async {
      await pump(tester, markFirstLine: false);
      await tester.tap(find.widgetWithText(TextFormField, 'Ingrediens 2'));
      await tester.pump();
      expect(inTextField(), isTrue);

      await tester.tap(
        find.descendant(
          of: find.byType(SectionedIngredientListBuilder),
          matching: find.text('Ingrediens'),
        ),
      );
      await tester.pump();

      expect(inTextField(), isFalse);
    });
  });
}
