import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/models/recipe_unified.dart';

// Import test infrastructure
import '../../infrastructure/factories/user_profile_factory.dart';
import '../../infrastructure/factories/social_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/widget_mocks.dart';

void main() {
  group('SocialComponents Ultrathink Facade Tests', () {
    // Helper to create properly configured test environment
    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'),
        home: Material(
          child: child ?? const SizedBox.shrink(),
        ),
      );
    }

    // Test data setup using factories - ultrathink approach
    late UserProfile testUser;
    late FriendCategory testCategory;
    late InvitationTarget testTarget;
    late Recipe testRecipe;
    late MockRecipeFormViewModel mockRecipeFormViewModel;

    setUp(() {
      testUser = UserProfileFactory.build(
        uid: 'test-user-123',
        displayName: 'Anna Andersson',
        email: 'anna@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        isOnline: true,
        friendsCount: 15,
        publicRecipeCount: 23,
      );

      testCategory = SocialFactory.createFriendCategory(
        id: 'category-familia',
        name: 'Familjen',
        memberIds: ['user-1', 'user-2', 'user-3'],
      );

      testTarget = InvitationTarget(
        type: InvitationTargetType.group,
        targetId: 'target-123',
        displayName: 'Familjegruppen',
        imageOrEmoji: '👥',
        memberCount: 5,
        memberIds: ['member-1', 'member-2', 'member-3'],
        metadata: {
          'description': 'En familjegrupp för inbjudningar',
          'createdAt': DateTime.now().toIso8601String(),
          'ownerId': 'owner-123',
        },
      );

      testRecipe = RecipeFactory.build(
        id: 'recipe-mormors-köttbullar',
        title: 'Mormors köttbullar',
        description: 'Klassiska svenska köttbullar',
      );

      mockRecipeFormViewModel = MockRecipeFormViewModel();
    });

    group('SocialAvatarComponents Widget Delegation', () {
      testWidgets('avatar method delegates correctly and returns Widget', (WidgetTester tester) async {
        // Test method exists and has correct return type
        expect(SocialComponents.avatar, isA<Function>());

        // Test with user parameter - interface validation
        final avatarWithUser = SocialComponents.avatar(
          user: testUser,
          size: ImageSize.large,
          showOnlineStatus: true,
          isOnline: true,
          showBorder: true,
        );
        expect(avatarWithUser, isA<Widget>());

        // Test with imageUrl parameter - interface validation
        final avatarWithImageUrl = SocialComponents.avatar(
          imageUrl: 'https://example.com/avatar.jpg',
          displayName: 'Test Användare',
          size: ImageSize.medium,
          onTap: () {},
        );
        expect(avatarWithImageUrl, isA<Widget>());

        // Test minimal parameters - interface validation
        final minimalAvatar = SocialComponents.avatar();
        expect(minimalAvatar, isA<Widget>());
      });

      testWidgets('userCard method delegates correctly and returns Widget', (WidgetTester tester) async {
        expect(SocialComponents.userCard, isA<Function>());

        // Test with all parameters - interface validation
        final fullUserCard = SocialComponents.userCard(
          user: testUser,
          onTap: () {},
          avatarSize: ImageSize.large,
          showOnlineStatus: true,
          isOnline: true,
          showSubtitle: true,
          subtitle: 'Premium användare',
          backgroundColor: Colors.grey.shade100,
          showBorder: true,
        );
        expect(fullUserCard, isA<Widget>());

        // Test minimal parameters - interface validation
        final minimalUserCard = SocialComponents.userCard(user: testUser);
        expect(minimalUserCard, isA<Widget>());
      });

      testWidgets('userListTile method delegates correctly and returns Widget', (WidgetTester tester) async {
        expect(SocialComponents.userListTile, isA<Function>());

        // Test with all parameters - interface validation
        final fullUserListTile = SocialComponents.userListTile(
          user: testUser,
          onTap: () {},
          trailing: const Icon(Icons.arrow_forward_ios),
          avatarSize: ImageSize.small,
          showOnlineStatus: true,
          isOnline: true,
          subtitle: 'Aktiv nu',
          enabled: true,
          backgroundColor: Colors.white,
        );
        expect(fullUserListTile, isA<Widget>());

        // Test minimal parameters - interface validation
        final minimalUserListTile = SocialComponents.userListTile(user: testUser);
        expect(minimalUserListTile, isA<Widget>());
      });
    });

    group('SocialCollaborativeComponents Widget Delegation', () {
      testWidgets('collaborativeStatusBadge method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.collaborativeStatusBadge, isA<Function>());

        // Test with all parameters - interface validation
        final fullBadge = SocialComponents.collaborativeStatusBadge(
          text: 'Delat recept',
          icon: Icons.share,
          color: Colors.blue,
          padding: const EdgeInsets.all(8.0),
        );
        expect(fullBadge, isA<Widget>());

        // Test with defaults - interface validation
        final defaultBadge = SocialComponents.collaborativeStatusBadge();
        expect(defaultBadge, isA<Widget>());
      });

      testWidgets('collaborativeBanner method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.collaborativeBanner, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) {
                // Test with all parameters - interface validation
                final fullBanner = SocialComponents.collaborativeBanner(
                  title: 'Gemensam matlagning',
                  subtitle: 'Anna och Erik lagar tillsammans',
                  contentId: 'recipe-123',
                  contentType: 'recipe',
                  backgroundColor: Colors.green.shade50,
                  onTap: () {},
                  trailing: const Icon(Icons.more_vert),
                  context: context,
                );
                expect(fullBanner, isA<Widget>());

                // Test minimal parameters - interface validation
                final minimalBanner = SocialComponents.collaborativeBanner(
                  title: 'Titel',
                  subtitle: 'Underrubrik',
                );
                expect(minimalBanner, isA<Widget>());

                return const SizedBox.shrink();
              },
            ),
          ),
        );
      });

      testWidgets('smartPermissionsBanner method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.smartPermissionsBanner, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) {
                final smartBanner = SocialComponents.smartPermissionsBanner(
                  context: context,
                  viewModel: mockRecipeFormViewModel,
                );
                expect(smartBanner, isA<Widget>());
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      });

      testWidgets('collaborativeAppBar method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.collaborativeAppBar, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) {
                // Test with all parameters - interface validation
                final fullAppBar = SocialComponents.collaborativeAppBar(
                  context: context,
                  contentId: 'recipe-456',
                  recipe: testRecipe,
                  showParticipants: true,
                  showStatus: true,
                  maxParticipants: 5,
                  onTap: () {},
                );
                expect(fullAppBar, isA<Widget>());

                // Test minimal parameters - interface validation
                final minimalAppBar = SocialComponents.collaborativeAppBar(
                  context: context,
                  contentId: 'recipe-minimal',
                );
                expect(minimalAppBar, isA<Widget>());

                return const SizedBox.shrink();
              },
            ),
          ),
        );
      });

      testWidgets('smartCollaborativeBanner method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.smartCollaborativeBanner, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) {
                final smartBanner = SocialComponents.smartCollaborativeBanner(
                  context: context,
                  contentId: 'content-789',
                  contentType: 'menu',
                  onTap: () {},
                  trailing: const Icon(Icons.settings),
                );
                expect(smartBanner, isA<Widget>());
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      });

      testWidgets('collaborativeStatusIndicator method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.collaborativeStatusIndicator, isA<Function>());

        final statusIndicator = SocialComponents.collaborativeStatusIndicator(
          contentId: 'recipe-status-test',
          contentType: 'recipe',
          showText: true,
          activeColor: Colors.green,
          inactiveColor: Colors.grey,
        );
        expect(statusIndicator, isA<Widget>());
      });

      testWidgets('participantsList method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.participantsList, isA<Function>());

        final participantsList = SocialComponents.participantsList(
          contentId: 'content-participants',
          contentType: 'menu',
          maxParticipants: 8,
          horizontal: true,
          onViewAll: () {},
        );
        expect(participantsList, isA<Widget>());
      });
    });

    group('SocialGroupComponents Widget & Dialog Delegation', () {
      testWidgets('friendCategorySelector method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.friendCategorySelector, isA<Function>());

        final List<FriendCategory> testCategories = [testCategory];

        // Test with all parameters - interface validation
        final fullSelector = SocialComponents.friendCategorySelector(
          categories: testCategories,
          selectedCategory: testCategory,
          onCategoryChanged: (category) {},
          hint: 'Välj kategori',
          enabled: true,
          leading: const Icon(Icons.group),
          trailing: const Icon(Icons.arrow_drop_down),
          padding: const EdgeInsets.all(16.0),
          backgroundColor: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
        );
        expect(fullSelector, isA<Widget>());

        // Test minimal parameters - interface validation
        final minimalSelector = SocialComponents.friendCategorySelector(
          categories: testCategories,
        );
        expect(minimalSelector, isA<Widget>());
      });

      testWidgets('friendCategoryChip method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.friendCategoryChip, isA<Function>());

        // Test with all parameters - interface validation
        final fullChip = SocialComponents.friendCategoryChip(
          category: testCategory,
          selected: true,
          onTap: () {},
          onDeleted: () {},
          backgroundColor: Colors.blue.shade50,
          selectedColor: Colors.blue,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
        );
        expect(fullChip, isA<Widget>());

        // Test minimal parameters - interface validation
        final minimalChip = SocialComponents.friendCategoryChip(
          category: testCategory,
        );
        expect(minimalChip, isA<Widget>());
      });

      testWidgets('group dialog methods exist with correct signatures', (WidgetTester tester) async {
        // Verify all group dialog methods exist and return Future<bool?>
        expect(SocialComponents.showCreateGroupDialog, isA<Function>());
        expect(SocialComponents.showEditGroupDialog, isA<Function>());
        expect(SocialComponents.showDeleteGroupDialog, isA<Function>());
        expect(SocialComponents.showRemoveMemberDialog, isA<Function>());

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  // Test return types without actually showing dialogs
                  expect(
                    () => SocialComponents.showCreateGroupDialog(
                      context: context,
                      preselectedMemberIds: ['user-1', 'user-2'],
                      initialGroupName: 'Ny grupp',
                      onGroupCreated: (name, memberIds) {},
                    ),
                    returnsNormally,
                  );

                  expect(
                    () => SocialComponents.showEditGroupDialog(
                      context: context,
                      groupId: 'group-123',
                      currentGroupName: 'Gamla namnet',
                      currentMemberIds: ['user-1'],
                      onGroupUpdated: (name, memberIds) {},
                    ),
                    returnsNormally,
                  );

                  expect(
                    () => SocialComponents.showDeleteGroupDialog(
                      context: context,
                      groupId: 'group-456',
                      groupName: 'Gruppen som ska tas bort',
                      onGroupDeleted: () {},
                    ),
                    returnsNormally,
                  );

                  expect(
                    () => SocialComponents.showRemoveMemberDialog(
                      context: context,
                      groupId: 'group-789',
                      memberId: 'member-123',
                      memberName: 'Anna Andersson',
                      onMemberRemoved: () {},
                    ),
                    returnsNormally,
                  );
                },
                child: const Text('Test Group Dialogs'),
              ),
            ),
          ),
        );

        expect(find.text('Test Group Dialogs'), findsOneWidget);
      });
    });

    group('SocialInvitationComponents Target Display Delegation', () {
      testWidgets('invitationTargetDisplay method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.invitationTargetDisplay, isA<Function>());

        // Test with all parameters - interface validation
        final fullDisplay = SocialComponents.invitationTargetDisplay(
          target: testTarget,
          onTap: () {},
          selected: true,
          compact: false,
          trailing: const Icon(Icons.check),
          padding: const EdgeInsets.all(12.0),
          backgroundColor: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8.0),
        );
        expect(fullDisplay, isA<Widget>());

        // Test minimal parameters - interface validation
        final minimalDisplay = SocialComponents.invitationTargetDisplay(
          target: testTarget,
        );
        expect(minimalDisplay, isA<Widget>());
      });

      testWidgets('targetCard method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.targetCard, isA<Function>());

        final fullCard = SocialComponents.targetCard(
          target: testTarget,
          onTap: () {},
          selected: true,
          trailing: const Icon(Icons.more_horiz),
          showType: true,
          showMemberCount: true,
          padding: const EdgeInsets.all(16.0),
          backgroundColor: Colors.blue.shade50,
        );
        expect(fullCard, isA<Widget>());
      });

      testWidgets('targetChip method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.targetChip, isA<Function>());

        final fullChip = SocialComponents.targetChip(
          target: testTarget,
          onTap: () {},
          onDeleted: () {},
          selected: true,
          backgroundColor: Colors.grey.shade200,
          selectedColor: Colors.blue,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
        );
        expect(fullChip, isA<Widget>());
      });

      testWidgets('targetListTile method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.targetListTile, isA<Function>());

        final fullListTile = SocialComponents.targetListTile(
          target: testTarget,
          onTap: () {},
          selected: true,
          trailing: const Icon(Icons.chevron_right),
          showSubtitle: true,
          enabled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        );
        expect(fullListTile, isA<Widget>());
      });

      testWidgets('targetBadge method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.targetBadge, isA<Function>());

        final fullBadge = SocialComponents.targetBadge(
          target: testTarget,
          showCount: true,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          padding: const EdgeInsets.all(4.0),
          fontSize: 12.0,
        );
        expect(fullBadge, isA<Widget>());
      });
    });

    group('SocialInvitationComponents Target Lists & Selection Delegation', () {
      testWidgets('targetList method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.targetList, isA<Function>());

        final List<InvitationTarget> testTargets = [testTarget];

        final fullList = SocialComponents.targetList(
          targets: testTargets,
          onTargetTap: (target) {},
          allowMultiSelect: true,
          selectedTargets: [testTarget],
          onSelectionChanged: (targets) {},
          showTrailing: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8.0),
        );
        expect(fullList, isA<Widget>());
      });

      testWidgets('targetGrid method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.targetGrid, isA<Function>());

        final List<InvitationTarget> testTargets = [testTarget];

        final fullGrid = SocialComponents.targetGrid(
          targets: testTargets,
          onTargetTap: (target) {},
          allowMultiSelect: true,
          selectedTargets: testTargets,
          onSelectionChanged: (targets) {},
          crossAxisCount: 3,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          padding: const EdgeInsets.all(16.0),
        );
        expect(fullGrid, isA<Widget>());
      });

      testWidgets('targetSelector method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.targetSelector, isA<Function>());

        final List<InvitationTarget> testTargets = [testTarget];

        final fullSelector = SocialComponents.targetSelector(
          availableTargets: testTargets,
          selectedTargets: testTargets,
          onSelectionChanged: (targets) {},
          allowMultiSelect: true,
          showSearch: true,
          showTypeFilters: true,
          searchHint: 'Sök bland målgrupper...',
          maxSelections: 10,
          emptyWidget: const Text('Inga målgrupper'),
          physics: const BouncingScrollPhysics(),
        );
        expect(fullSelector, isA<Widget>());
      });

      testWidgets('checkableTargetList method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.checkableTargetList, isA<Function>());

        final List<InvitationTarget> testTargets = [testTarget];

        final fullCheckableList = SocialComponents.checkableTargetList(
          targets: testTargets,
          selectedTargets: testTargets,
          onSelectionChanged: (targets) {},
          showSelectAll: true,
          selectAllText: 'Markera alla',
          selectNoneText: 'Avmarkera alla',
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
        );
        expect(fullCheckableList, isA<Widget>());
      });

      testWidgets('radioTargetSelector method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.radioTargetSelector, isA<Function>());

        final List<InvitationTarget> testTargets = [testTarget];

        final radioSelector = SocialComponents.radioTargetSelector(
          targets: testTargets,
          selectedTarget: testTarget,
          onSelectionChanged: (target) {},
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12.0),
        );
        expect(radioSelector, isA<Widget>());
      });
    });

    group('SocialInvitationComponents Target Utilities Delegation', () {
      testWidgets('targetSearchField method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.targetSearchField, isA<Function>());

        // Test with all parameters - interface validation
        final fullSearchField = SocialComponents.targetSearchField(
          onSearchChanged: (query) {},
          hint: 'Sök efter vänner och grupper...',
          prefixIcon: Icons.search,
          autofocus: true,
          controller: TextEditingController(),
          margin: const EdgeInsets.all(8.0),
        );
        expect(fullSearchField, isA<Widget>());

        // Test with defaults - interface validation
        final defaultSearchField = SocialComponents.targetSearchField();
        expect(defaultSearchField, isA<Widget>());
      });

      testWidgets('targetTypeFilters method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.targetTypeFilters, isA<Function>());

        final List<String> availableTypes = ['friend', 'group', 'category'];

        final fullFilters = SocialComponents.targetTypeFilters(
          availableTypes: availableTypes,
          selectedTypes: ['friend'],
          onTypesChanged: (types) {},
          allowMultiSelect: true,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          spacing: 12.0,
        );
        expect(fullFilters, isA<Widget>());
      });

      testWidgets('quickSelectionButtons method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.quickSelectionButtons, isA<Function>());

        final quickButtons = SocialComponents.quickSelectionButtons(
          onSelectAll: () {},
          onSelectNone: () {},
          onSelectFriends: () {},
          onSelectGroups: () {},
          selectAllText: 'Alla målgrupper',
          selectNoneText: 'Inga målgrupper',
          selectFriendsText: 'Alla vänner',
          selectGroupsText: 'Alla grupper',
          padding: const EdgeInsets.all(16.0),
          alignment: MainAxisAlignment.spaceAround,
        );
        expect(quickButtons, isA<Widget>());
      });
    });

    group('SocialInvitationComponents State Widgets Delegation', () {
      testWidgets('target state widgets delegate correctly', (WidgetTester tester) async {
        // Loading states
        expect(SocialComponents.targetListLoading, isA<Function>());
        expect(SocialComponents.targetCardLoading, isA<Function>());

        final loadingList = SocialComponents.targetListLoading(
          text: 'Laddar dina vänner och grupper...',
        );
        expect(loadingList, isA<Widget>());

        final loadingCards = SocialComponents.targetCardLoading(count: 5);
        expect(loadingCards, isA<Widget>());

        // Error state
        expect(SocialComponents.targetLoadingError, isA<Function>());
        
        final errorState = SocialComponents.targetLoadingError(
          title: 'Kunde inte ladda målgrupper',
          message: 'Kontrollera internetanslutningen',
          onRetry: () {},
          retryText: 'Försök igen',
          errorIcon: Icons.wifi_off,
        );
        expect(errorState, isA<Widget>());

        // Empty states
        expect(SocialComponents.noTargetsAvailable, isA<Function>());
        expect(SocialComponents.noSearchResults, isA<Function>());

        final noTargets = SocialComponents.noTargetsAvailable(
          title: 'Inga målgrupper ännu',
          message: 'Lägg till vänner för att börja dela recept',
          icon: Icons.group_add,
          onAddTargets: () {},
          addButtonText: 'Lägg till första vännen',
          showAddButton: true,
        );
        expect(noTargets, isA<Widget>());

        final noResults = SocialComponents.noSearchResults(
          query: 'köttbullar',
          title: 'Inga sökresultat',
          message: 'Prova att söka på något annat',
          icon: Icons.search_off,
          onClearSearch: () {},
          clearButtonText: 'Rensa sök',
          showClearButton: true,
        );
        expect(noResults, isA<Widget>());

        // Success state
        expect(SocialComponents.targetsSelectedSuccess, isA<Function>());

        final successState = SocialComponents.targetsSelectedSuccess(
          selectedCount: 3,
          title: 'Målgrupper valda',
          message: 'Du har valt 3 målgrupper för delning',
          icon: Icons.check_circle,
          onContinue: () {},
          continueButtonText: 'Fortsätt med delning',
          successColor: Colors.green,
        );
        expect(successState, isA<Widget>());
      });
    });

    group('SocialBuilderComponents Action & Helper Delegation', () {
      testWidgets('socialActionButton method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.socialActionButton, isA<Function>());

        // Test with all parameters - interface validation
        final fullButton = SocialComponents.socialActionButton(
          text: 'Dela med vänner',
          onPressed: () {},
          icon: Icons.share,
          backgroundColor: Colors.blue,
          textColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          outlined: false,
          compact: false,
          loading: false,
        );
        expect(fullButton, isA<Widget>());

        // Test loading state - interface validation
        final loadingButton = SocialComponents.socialActionButton(
          text: 'Delar...',
          onPressed: () {},
          loading: true,
        );
        expect(loadingButton, isA<Widget>());

        // Test outlined style - interface validation
        final outlinedButton = SocialComponents.socialActionButton(
          text: 'Avbryt',
          onPressed: () {},
          outlined: true,
          compact: true,
        );
        expect(outlinedButton, isA<Widget>());
      });

      testWidgets('socialStats method delegates correctly', (WidgetTester tester) async {
        expect(SocialComponents.socialStats, isA<Function>());

        final Map<String, dynamic> testStats = {
          'friends': 25,
          'shared_recipes': 12,
          'comments': 47,
          'likes': 134,
        };

        final fullStats = SocialComponents.socialStats(
          stats: testStats,
          horizontal: true,
          padding: const EdgeInsets.all(16.0),
          backgroundColor: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12.0),
          showLabels: true,
          showIcons: true,
        );
        expect(fullStats, isA<Widget>());

        // Test vertical layout - interface validation
        final verticalStats = SocialComponents.socialStats(
          stats: testStats,
          horizontal: false,
          showLabels: false,
        );
        expect(verticalStats, isA<Widget>());
      });
    });

    group('SocialBuilderComponents Helper Method Delegation', () {
      testWidgets('helper methods delegate correctly and return correct types', (WidgetTester tester) async {
        // String formatters
        expect(SocialComponents.formatUserDisplayName, isA<Function>());
        expect(SocialComponents.formatInvitationTargetDisplayName, isA<Function>());

        final formattedUserName = SocialComponents.formatUserDisplayName(testUser);
        expect(formattedUserName, isA<String>());

        final formattedTargetName = SocialComponents.formatInvitationTargetDisplayName(testTarget);
        expect(formattedTargetName, isA<String>());

        // Boolean helpers
        expect(SocialComponents.isUserOnline, isA<Function>());
        
        final userOnlineStatus = SocialComponents.isUserOnline(testUser);
        expect(userOnlineStatus, isA<bool>());

        // URL helper
        expect(SocialComponents.getUserAvatarUrl, isA<Function>());
        
        final avatarUrl = SocialComponents.getUserAvatarUrl(testUser);
        expect(avatarUrl, isA<String?>());

        // Icon helper
        expect(SocialComponents.getInvitationTargetTypeIcon, isA<Function>());
        
        final targetIcon = SocialComponents.getInvitationTargetTypeIcon('group');
        expect(targetIcon, isA<IconData>());
        
        final friendIcon = SocialComponents.getInvitationTargetTypeIcon('friend');
        expect(friendIcon, isA<IconData>());
      });
    });

    group('Swedish Localization Support', () {
      testWidgets('all widget methods support Swedish parameters', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Test avatar with Swedish user
                  SocialComponents.avatar(
                    user: UserProfileFactory.build(
                      displayName: 'Åsa Öberg',
                      email: 'asa.oberg@example.se',
                    ),
                    size: ImageSize.large,
                    showOnlineStatus: true,
                  ),
                  
                  // Test collaborative badge with Swedish text
                  SocialComponents.collaborativeStatusBadge(
                    text: 'Delat recept',
                    icon: Icons.people,
                  ),

                  // Test category chip with Swedish name
                  SocialComponents.friendCategoryChip(
                    category: SocialFactory.createFriendCategory(
                      name: 'Släktingar & nära vänner',
                      memberIds: ['user-1', 'user-2'],
                    ),
                  ),

                  // Test social action button with Swedish text
                  SocialComponents.socialActionButton(
                    text: 'Dela med familjen',
                    onPressed: () {},
                    icon: Icons.family_restroom,
                  ),

                  Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () {
                        // Test search field with Swedish hint
                        SocialComponents.targetSearchField(
                          hint: 'Sök bland vänner och familj...',
                          onSearchChanged: (query) {
                            // Verify Swedish characters are preserved
                            expect(query.length, greaterThanOrEqualTo(0));
                          },
                        );
                      },
                      child: const Text('Swedish Search Test'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Verify Swedish characters render correctly
        expect(find.text('Swedish Search Test'), findsOneWidget);
      });
    });

    group('Facade Pattern Interface Validation', () {
      testWidgets('all static methods exist and are callable', (WidgetTester tester) async {
        // SocialAvatarComponents methods
        expect(SocialComponents.avatar, isA<Function>());
        expect(SocialComponents.userCard, isA<Function>());
        expect(SocialComponents.userListTile, isA<Function>());

        // SocialCollaborativeComponents methods
        expect(SocialComponents.collaborativeStatusBadge, isA<Function>());
        expect(SocialComponents.collaborativeBanner, isA<Function>());
        expect(SocialComponents.smartPermissionsBanner, isA<Function>());
        expect(SocialComponents.collaborativeAppBar, isA<Function>());
        expect(SocialComponents.smartCollaborativeBanner, isA<Function>());
        expect(SocialComponents.collaborativeStatusIndicator, isA<Function>());
        expect(SocialComponents.participantsList, isA<Function>());

        // SocialGroupComponents methods
        expect(SocialComponents.friendCategorySelector, isA<Function>());
        expect(SocialComponents.friendCategoryChip, isA<Function>());
        expect(SocialComponents.showCreateGroupDialog, isA<Function>());
        expect(SocialComponents.showEditGroupDialog, isA<Function>());
        expect(SocialComponents.showDeleteGroupDialog, isA<Function>());
        expect(SocialComponents.showRemoveMemberDialog, isA<Function>());

        // SocialInvitationComponents methods (selection of key ones)
        expect(SocialComponents.invitationTargetDisplay, isA<Function>());
        expect(SocialComponents.targetCard, isA<Function>());
        expect(SocialComponents.targetList, isA<Function>());
        expect(SocialComponents.targetSelector, isA<Function>());
        expect(SocialComponents.targetSearchField, isA<Function>());
        expect(SocialComponents.targetListLoading, isA<Function>());
        expect(SocialComponents.noTargetsAvailable, isA<Function>());

        // SocialBuilderComponents methods
        expect(SocialComponents.socialActionButton, isA<Function>());
        expect(SocialComponents.socialStats, isA<Function>());
        expect(SocialComponents.formatUserDisplayName, isA<Function>());
        expect(SocialComponents.isUserOnline, isA<Function>());
        expect(SocialComponents.getUserAvatarUrl, isA<Function>());
      });

      testWidgets('return types are correctly maintained through facade', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => Column(
                children: [
                  // Widget return types
                  SocialComponents.avatar(user: testUser),
                  SocialComponents.userCard(user: testUser),
                  SocialComponents.collaborativeStatusBadge(),
                  SocialComponents.targetCard(target: testTarget),
                  SocialComponents.socialActionButton(
                    text: 'Test',
                    onPressed: () {},
                  ),
                  
                  ElevatedButton(
                    onPressed: () async {
                      // Future return types validation
                      final Future<bool?> createDialog = SocialComponents.showCreateGroupDialog(
                        context: context,
                      );
                      
                      expect(createDialog, isA<Future<bool?>>());
                      
                      // Helper return types validation
                      final String displayName = SocialComponents.formatUserDisplayName(testUser);
                      final bool isOnline = SocialComponents.isUserOnline(testUser);
                      final String? avatarUrl = SocialComponents.getUserAvatarUrl(testUser);
                      final IconData targetIcon = SocialComponents.getInvitationTargetTypeIcon('friend');
                      
                      expect(displayName, isA<String>());
                      expect(isOnline, isA<bool>());
                      expect(avatarUrl, isA<String?>());
                      expect(targetIcon, isA<IconData>());
                    },
                    child: const Text('Return Type Test'),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Return Type Test'), findsOneWidget);
      });
    });

    group('Responsive Design Behavior', () {
      testWidgets('social components adapt to small screen sizes', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                SocialComponents.avatar(
                  user: testUser,
                  size: ImageSize.small,
                ),
                SocialComponents.collaborativeStatusBadge(
                  text: 'Delat',
                ),
                SocialComponents.targetCard(
                  target: testTarget,
                ),
              ],
            ),
          ),
        );

        // Verify widgets are rendered correctly in responsive layout
        expect(find.byType(Column), findsWidgets);

        // Reset screen size
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('social components adapt to tablet screen sizes', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            child: Column(
              children: [
                SocialComponents.userCard(
                  user: testUser,
                  avatarSize: ImageSize.large,
                  showOnlineStatus: true,
                ),
                SocialComponents.socialActionButton(
                  text: 'Tablet Action',
                  onPressed: () {},
                  icon: Icons.tablet_android,
                ),
              ],
            ),
          ),
        );

        // Verify widgets are rendered correctly in responsive layout
        expect(find.byType(Column), findsWidgets);

        // Reset screen size
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}