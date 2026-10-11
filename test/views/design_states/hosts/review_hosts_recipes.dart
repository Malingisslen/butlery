/// Hosts for the recipe, tag and cookbook views the register had not compared.
library;

import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/tagging/cookbook_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/cookbook_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/cookbooks/cookbook_detail_view.dart';
import 'package:butlery/views/personal_tags_view.dart';
import 'package:butlery/views/skriv_sjalv_recept_view.dart';
import 'package:butlery/views/tag_detail_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/cookbook_fixtures.dart';
import '../../../widget/views/recipe/fake_personal_tag_viewmodel.dart';
import '../state_host.dart';

class _MockCookbookService extends Mock implements CookbookService {}

final _tags = [
  PersonalTag(
    id: 'vardag',
    name: 'Vardagsmiddag',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    groupId: 'g1',
    rules: [
      PersonalTagRule(
        id: 'rule1',
        name: 'Snabba rätter',
        conditions: const [
          RuleCondition(
            type: ConditionType.time,
            operator: ConditionOperator.lessThan,
            value: 30.0,
          ),
        ],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ],
  ),
  PersonalTag(
    id: 'helg',
    name: 'Helgmys',
    createdAt: DateTime(2026, 1, 2),
    updatedAt: DateTime(2026, 1, 2),
    groupId: 'g1',
  ),
  PersonalTag(
    id: 'barnen',
    name: 'Barnens favoriter',
    createdAt: DateTime(2026, 1, 3),
    updatedAt: DateTime(2026, 1, 3),
  ),
  PersonalTag(
    id: 'jul',
    name: 'Julbordet',
    createdAt: DateTime(2026, 1, 4),
    updatedAt: DateTime(2026, 1, 4),
  ),
];

final _groups = [
  PersonalTagGroup(
    id: 'g1',
    name: 'Tillfälle',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
];

const _usage = {
  'Vardagsmiddag': 14,
  'Helgmys': 6,
  'Barnens favoriter': 9,
  'Julbordet': 0,
};

final reviewRecipeHosts = <String, StateHost>{
  'CookbookDetailView': StateHost(
    build: (ctx) async {
      final service = _MockCookbookService();
      registerFallbackValue(cookbookTag());
      registerFallbackValue(const CookbookDetails());
      when(service.watchTags).thenAnswer(
        (_) => Stream.value([cookbookTag(cookbook: const CookbookDetails())]),
      );
      when(
        () => service.libraryChanges,
      ).thenAnswer((_) => const Stream.empty());
      when(() => service.libraryRecipes).thenAnswer(
        (_) => <Recipe>[
          cookbookRecipe('r1', 'Kanelbullar', tagIds: ['book']),
          cookbookRecipe('r2', 'Köttbullar med gräddsås', tagIds: ['book']),
          cookbookRecipe('r3', 'Pannkakor', tagIds: ['book']),
          cookbookRecipe('r4', 'Äppelkaka', tagIds: ['book']),
        ],
      );
      final vm = CookbookViewModel(service: service)..start();
      ctx.disposers.add(vm.dispose);
      return ChangeNotifierProvider<CookbookViewModel>.value(
        value: vm,
        child: const CookbookDetailView(tagId: 'book'),
      );
    },
  ),
  'PersonalTagsView': StateHost(
    build: (ctx) async {
      final vm = FakePersonalTagViewModel()
        ..setState(tags: _tags, groups: _groups, usageCounts: _usage);
      TestServiceLocator.registerFactory<PersonalTagViewModel>(() => vm);
      return const PersonalTagsView(backTo: 'Mer');
    },
  ),
  'TagDetailView': StateHost(
    build: (ctx) async {
      final vm = FakePersonalTagViewModel()
        ..setState(tags: _tags, groups: _groups, usageCounts: _usage);
      TestServiceLocator.registerMock<PersonalTagViewModel>(vm);
      return const TagDetailView(tagId: 'vardag');
    },
  ),
  'SkrivSjalvReceptView': StateHost(
    build: (ctx) async {
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
        CollaborativeStatusViewModel.new,
      );
      TestServiceLocator.registerMock<ImageUploadService>(ImageUploadService());
      final tags = MockPersonalTagService();
      TestServiceLocator.registerMock<PersonalTagService>(tags);
      TestServiceLocator.registerFactory<PersonalTagViewModel>(
        () => PersonalTagViewModel(service: tags),
      );
      return const SkrivSjalvReceptView();
    },
  ),
};
