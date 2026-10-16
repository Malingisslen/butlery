/// The banner that says an import needs a second look can be dismissed with
/// a control that has a 48 dp target, a name and keyboard focus.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/butlery_tap_target.dart';
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
    'Skriv själv parse-quality banner: the dismiss × is a real button',
    () {
      setUpAll(() async {
        await BaseUnitTest.setupUnit();
        production.ServiceLocator.initialize(DIContainer());
      });

      setUp(() async {
        await TestServiceLocator.initialize();
        final cache = ParsedRecipeCache()
          ..store(
            'imported-recipe',
            ParsedRecipe.empty(
              metadata: ParseMetadata.cacheHit(
                source: ImportSource.url,
                parserVersion: '1.0.0',
              ),
            ).copyWith(title: FieldResult.low('Dålig titel')),
          );
        TestServiceLocator.registerMock<ParsedRecipeCache>(cache);
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

      Future<void> pumpBanner(WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SkrivSjalvReceptView(
              initialRecipe: RecipeFactory.build(
                id: 'imported-recipe',
                title: 'Dålig titel',
                ingredients: const ['Mjöl'],
                instructions: const ['Blanda'],
              ),
              isTemplate: true,
            ),
            wrapInScaffold: false,
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets(
        'the × has a 48 dp target and Enter on it dismisses the banner',
        (
          tester,
        ) async {
          await pumpBanner(tester);

          final close = find.byType(ButleryTapTarget);
          expect(close, findsOneWidget);
          expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
          expect(
            find.descendant(of: close, matching: find.byType(ButleryFocusRing)),
            findsOneWidget,
          );

          for (var i = 0; i < 40; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            final focus = FocusManager.instance.primaryFocus?.context;
            if (focus?.findAncestorWidgetOfExactType<ButleryTapTarget>() !=
                null) {
              break;
            }
          }
          expect(
            FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<ButleryTapTarget>(),
            isNotNull,
            reason: 'Tab must reach the ×',
          );
          expect(find.byType(ButleryTapTarget), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.byType(ButleryTapTarget), findsNothing);
        },
      );
    },
  );
}
