/// Hosts for the profile, group and shared-content views the register had not
/// compared.
library;

import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social/ping_service.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/modules/social_shopping/social_shopping_coordinator.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/social_sharing_viewmodel.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/views/social/friend_profile_view.dart';
import 'package:butlery/views/social/group_detail_view.dart';
import 'package:butlery/views/social/menu_preview_view.dart';
import 'package:butlery/views/social/public_profile_view.dart';
import 'package:butlery/views/social/shared_with_me/shared_recipes_by_friend_view.dart';
import 'package:butlery/views/social/shared_with_me_view.dart';
import 'package:butlery/views/social/user_profile_edit_view.dart';

import '../../../helpers/user_profile_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../state_host.dart';

class _FakePermission extends Fake implements PermissionService {
  @override
  String? get currentUserId => 'me';
}

class _FakeSocialRecipeCoordinator extends Fake
    implements SocialRecipeCoordinator {}

class _FakeSocialMenuCoordinator extends Fake
    implements SocialMenuCoordinator {}

class _FakeSocialShoppingCoordinator extends Fake
    implements SocialShoppingCoordinator {}

class _FakeFriendsService extends Fake implements UnifiedFriendsService {
  @override
  bool get isInitialized => true;

  @override
  List<UserProfile> get friends => const [];

  @override
  Set<String> get blockedUsers => const {};
}

class _FakeMenuService extends Fake implements UnifiedMenuService {}

class _FakeShoppingService extends Fake implements UnifiedShoppingService {}

class _FakeMessaging extends Fake implements MessagingService {}

class _FakeRecipeViewModel extends SharedRecipeViewModel {
  _FakeRecipeViewModel(this.recipes)
    : super(
        socialRecipeCoordinator: _FakeSocialRecipeCoordinator(),
        permissionService: _FakePermission(),
      );

  final List<SharedRecipe> recipes;

  @override
  bool get isLoading => false;

  @override
  bool get hasError => false;

  @override
  String? get error => null;

  @override
  List<SharedRecipe> recipesSharedBy(String friendId) => recipes;

  @override
  List<SharedRecipe> get filteredContent => recipes;

  @override
  bool isRecipeViewed(SharedRecipe recipe) => false;

  @override
  bool isRecipeImported(SharedRecipe recipe) => false;

  @override
  Future<void> refreshContent() async {}
}

class _FakeCoordinator extends SharedContentCoordinatorViewModel {
  _FakeCoordinator(this._recipeVm)
    : super(
        recipeViewModel: _recipeVm,
        menuViewModel: SharedMenuViewModel(
          socialMenuCoordinator: _FakeSocialMenuCoordinator(),
          permissionService: _FakePermission(),
        ),
        shoppingViewModel: SharedShoppingViewModel(
          socialShoppingCoordinator: _FakeSocialShoppingCoordinator(),
          shoppingService: _FakeShoppingService(),
          permissionService: _FakePermission(),
        ),
        socialSharingViewModel: SocialSharingViewModel(
          friendsService: _FakeFriendsService(),
          recipeCoordinator: _FakeSocialRecipeCoordinator(),
          menuCoordinator: _FakeSocialMenuCoordinator(),
          shoppingCoordinator: _FakeSocialShoppingCoordinator(),
          menuService: _FakeMenuService(),
          shoppingService: _FakeShoppingService(),
        ),
      );

  final _FakeRecipeViewModel _recipeVm;

  @override
  bool get isGloballyLoading => false;

  @override
  bool get hasAnyContent => _recipeVm.recipes.isNotEmpty;

  @override
  SharedRecipeViewModel get recipeViewModel => _recipeVm;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refreshAllContent() async {}
}

SharedRecipe _shared(String id, String title, {int minutes = 30}) =>
    SharedRecipe(
      id: id,
      sharedByUserId: 'friend-1',
      sharedByDisplayName: 'Erik',
      sharedAt: DateTime.now().subtract(const Duration(days: 2)),
      shareMessage: 'Den här måste du prova!',
      originalRecipeId: 'orig-$id',
      recipeTitle: title,
      recipePortions: 4,
      recipeTimeMinutes: minutes,
    );

void _sharedServices(List<SharedRecipe> recipes) {
  final offline = MockOfflineService();
  when(() => offline.isOnline).thenReturn(true);
  when(() => offline.addListener(any())).thenReturn(null);
  when(() => offline.removeListener(any())).thenReturn(null);
  TestServiceLocator.registerMock<OfflineService>(offline);
  TestServiceLocator.registerMock<MessagingService>(_FakeMessaging());
  TestServiceLocator.registerMock<SharedContentCoordinatorViewModel>(
    _FakeCoordinator(_FakeRecipeViewModel(recipes)),
  );
}

final _me = testUserProfile(uid: 'me-uid', displayName: 'Malin Gisslén');

final reviewSocial2Hosts = <String, StateHost>{
  'FriendProfileView': StateHost(
    build: (ctx) async {
      final vm = MockFriendsViewModel();
      TestServiceLocator.registerMock<FriendsViewModel>(vm);
      TestServiceLocator.registerMock<MessagingService>(_FakeMessaging());
      final offline = MockOfflineService();
      when(() => offline.isOnline).thenReturn(true);
      TestServiceLocator.registerMock<OfflineService>(offline);
      return FriendProfileView(
        friend: testUserProfile(uid: 'user-them', displayName: 'Anna Svensson'),
      );
    },
  ),
  'PublicProfileView': StateHost(
    build: (ctx) async {
      Provider.debugCheckInvalidValueType = null;
      final users = MockUserRepository();
      when(() => users.fetchProfile('them-uid')).thenAnswer(
        (_) async => MockFactory.createUserProfile(
          userId: 'them-uid',
          displayName: 'Lovisa Hägg',
          publicRecipeCount: 12,
          friendsCount: 8,
        ),
      );
      when(
        () => users.fetchPersistedSearchable('them-uid'),
      ).thenAnswer((_) async => true);
      TestServiceLocator.registerMock<UserRepository>(users);
      final recipes = MockRecipeRepository();
      when(() => recipes.fetchPublicUserRecipes('them-uid')).thenAnswer(
        (_) async => [
          RecipeFactory.build(id: 'p1', title: 'Rabarberpaj'),
          RecipeFactory.build(id: 'p2', title: 'Kanelbullar'),
        ],
      );
      TestServiceLocator.registerMock<RecipeRepository>(recipes);
      (TestServiceLocator.get<UnifiedFriendsService>()
              as MockUnifiedFriendsService)
          .setFriendsState(isInitialized: true);
      final friends = MockFriendsViewModel()
        ..setFriendshipStatus('them-uid', FriendshipStatus.none);
      when(() => friends.currentUserId).thenReturn('me-uid');
      TestServiceLocator.registerMock<FriendsViewModel>(friends);
      final offline = MockOfflineService();
      when(() => offline.isOnline).thenReturn(true);
      when(() => offline.addListener(any())).thenReturn(null);
      when(() => offline.removeListener(any())).thenReturn(null);
      TestServiceLocator.registerMock<OfflineService>(offline);
      return const PublicProfileView(userId: 'them-uid');
    },
  ),
  'GroupDetailView': StateHost(
    build: (ctx) async {
      final friends = MockUnifiedFriendsService();
      when(() => friends.refresh()).thenAnswer((_) async {});
      when(() => friends.getCategoryById(any())).thenReturn(
        FriendCategory(
          id: 'g1',
          ownerId: 'test-user-123',
          name: 'Familjen Andersson',
          description: 'Söndagsmiddagar och veckomenyn',
          friendUserIds: const ['u-anna', 'u-per'],
        ),
      );
      when(() => friends.sentInvitations).thenReturn(const <GroupInvitation>[]);
      TestServiceLocator.registerMock<UnifiedFriendsService>(friends);
      TestServiceLocator.registerMock<UserService>(
        MockUserService()..setUserState(
          users: {
            'u-anna': testUserProfile(
              uid: 'u-anna',
              displayName: 'Anna Lindqvist',
            ),
            'u-per': testUserProfile(
              uid: 'u-per',
              displayName: 'Per Andersson',
            ),
          },
        ),
      );
      TestServiceLocator.registerMock<PermissionService>(
        _OwnerPermissions()..setPermissionState(currentUserId: 'test-user-123'),
      );
      final pings = _MockPings();
      when(() => pings.watchGroup(any())).thenAnswer((_) => Stream.value([]));
      TestServiceLocator.registerMock<PingService>(pings);
      final content = _MockGroupContent();
      final shared = [
        SharedContentItem(
          id: 'c1',
          title: 'Fiskgratäng',
          type: 'recipe',
          sharedByUserId: 'u-anna',
          sharedByDisplayName: 'Anna Lindqvist',
          sharedAt: DateTime.now().subtract(const Duration(days: 2)),
          data: const {},
        ),
      ];
      when(
        () => content.streamSharedRecipes(any()),
      ).thenAnswer((_) => Stream.value(shared));
      when(
        () => content.streamSharedMenus(any()),
      ).thenAnswer((_) => Stream.value(<SharedContentItem>[]));
      when(
        () => content.streamSharedShoppingLists(any()),
      ).thenAnswer((_) => Stream.value(<SharedContentItem>[]));
      TestServiceLocator.registerMock<GroupSharedContentService>(content);
      return const GroupDetailView(groupId: 'g1');
    },
  ),
  'MenuPreviewView': StateHost(
    build: (ctx) async {
      TestServiceLocator.registerMock<PermissionService>(
        FakePermissionService()..setPermissionState(currentUserId: 'viewer'),
      );
      final menuVm = _MockMenuVm();
      when(() => menuVm.isMenuImported(any())).thenReturn(false);
      when(() => menuVm.isItemOperating(any())).thenReturn(false);
      final coordinator = _MockCoordinator();
      when(() => coordinator.menuViewModel).thenReturn(menuVm);
      final menu = SharedMenu(
        id: 'menu-1',
        sharedByUserId: 'u1',
        sharedByDisplayName: 'Anna',
        sharedAt: DateTime.now().subtract(const Duration(days: 2)),
        menuTitle: 'Veckomeny vecka 40',
        menuSnapshot: {
          'Måndag': [RecipeFactory.build(id: 'm1', title: 'Pannkakor')],
          'Tisdag': [RecipeFactory.build(id: 'm2', title: 'Fiskgratäng')],
          'Onsdag': [RecipeFactory.build(id: 'm3', title: 'Linsgryta')],
        },
      );
      return ChangeNotifierProvider<SharedContentCoordinatorViewModel>.value(
        value: coordinator,
        child: MenuPreviewView(sharedMenu: menu),
      );
    },
  ),
  'SharedRecipesByFriendView': StateHost(
    build: (ctx) async {
      _sharedServices([
        _shared('s1', 'Kycklinggryta med citron'),
        _shared('s2', 'Rabarberpaj', minutes: 60),
      ]);
      return const SharedRecipesByFriendView(
        friendId: 'friend-1',
        friendDisplayName: 'Erik',
      );
    },
  ),
  'SharedWithMeView': StateHost(
    build: (ctx) async {
      _sharedServices([
        _shared('s1', 'Kycklinggryta med citron'),
        _shared('s2', 'Rabarberpaj', minutes: 60),
      ]);
      return const SharedWithMeView();
    },
  ),
  'UserProfileEditView': StateHost(
    build: (ctx) async {
      final vm = MockFactory.createUserProfileViewModel(
        displayName: _me.displayName,
        bio: 'Lagar mest husmanskost och bakar på helgerna.',
      );
      when(() => vm.isSaving).thenReturn(false);
      when(() => vm.shareActivityToFeed).thenReturn(true);
      when(() => vm.showOnlineStatus).thenReturn(true);
      when(() => vm.showNameOnSharedDishes).thenReturn(true);
      when(() => vm.isMinor).thenReturn(false);
      registerFallbackValue(ActivityEventType.values.first);
      when(() => vm.isActivityEventTypeEnabled(any())).thenReturn(true);
      TestServiceLocator.registerMock<UserProfileViewModel>(vm);
      TestServiceLocator.registerMock<AuthRepository>(FakeAuthRepository());
      TestServiceLocator.registerMock<UserService>(MockUserService());
      return const UserProfileEditView();
    },
  ),
};

class _OwnerPermissions extends FakePermissionService {
  @override
  bool isOwner(String ownerId) => ownerId == currentUserId;

  @override
  bool canInviteToGroup(String groupId) => true;
}

class _MockPings extends Mock implements PingService {}

class _MockGroupContent extends Mock implements GroupSharedContentService {}

class _MockMenuVm extends Mock implements SharedMenuViewModel {}

class _MockCoordinator extends Mock
    implements SharedContentCoordinatorViewModel {}
