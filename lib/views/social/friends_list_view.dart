/// Friends and groups management view with a three-tab interface.

// lib/views/social/friends_list_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/constants/routes.dart';

// Import focused components
import 'package:butlery/views/social/friends_list/friends_tab.dart';
import 'package:butlery/views/social/friends_list/find_friends_sheet.dart';
import 'package:butlery/views/social/friends_list/groups_tab.dart';
import 'package:butlery/views/social/friends_list/feed_tab.dart';
import 'package:butlery/viewmodels/social/activity_feed_viewmodel.dart';

/// Friends and groups management view with tabs for the feed, friends and groups.
class FriendsListView extends StatefulWidget {
  const FriendsListView({super.key});

  @override
  State<FriendsListView> createState() => _FriendsListViewState();
}

class _FriendsListViewState extends State<FriendsListView> {
  late final FriendsViewModel _vm;
  late final ActivityFeedViewModel _feedVm;

  @override
  void initState() {
    super.initState();
    _vm = ServiceLocator.get<FriendsViewModel>();
    _feedVm = ServiceLocator.get<ActivityFeedViewModel>();
    _feedVm.loadFeed();
    _fireSocialOnboardingIfFirstEntry();
  }

  /// BUT-1046: once-per-install funnel-entry signal. Fire-and-forget so the
  /// analytics path never blocks the friends view from rendering. The
  /// tracker no-ops on repeated entries via SharedPreferences dedupe.
  void _fireSocialOnboardingIfFirstEntry() {
    final userId = ServiceLocator.get<PermissionService>().currentUserId;
    if (userId == null) return;
    ServiceLocator.get<AnalyticsService>().social
        .logSocialOnboardingStartedIfFirstEntry(
          userId: userId,
          entryPoint: 'friends_tab',
        );
  }

  @override
  void dispose() {
    _vm.dispose();
    _feedVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FriendsViewModel>.value(value: _vm),
        ChangeNotifierProvider<ActivityFeedViewModel>.value(value: _feedVm),
        Provider.value(value: ServiceLocator.get<UnifiedFriendsService>()),
      ],
      child: const _FriendsListViewContent(),
    );
  }
}

class _FriendsListViewContent extends StatefulWidget {
  const _FriendsListViewContent();

  @override
  State<_FriendsListViewContent> createState() =>
      _FriendsListViewContentState();
}

class _FriendsListViewContentState extends State<_FriendsListViewContent>
    with TickerProviderStateMixin {
  static const int _tabCount = 3;
  static const int _friendsTab = 1;

  late TabController _tabController;
  late final bool _socialEnabled;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _socialEnabled = ServiceLocator.get<FeatureFlagService>().isEnabled(
      FeatureFlags.enableSocialFeatures,
    );
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging && mounted) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final requested = args?['tabIndex'];
      if (requested is! int) return;
      // The old fourth tab (find friends) moved into a sheet opened from the
      // Vänner tab, so a caller that still asks for index 3 lands there.
      final tabIndex = requested >= _tabCount
          ? _friendsTab
          : requested.clamp(0, _tabCount - 1);
      _tabController.animateTo(tabIndex);
      if (mounted) setState(() => _currentTabIndex = tabIndex);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openFindFriends(FriendsViewModel viewModel) =>
      showFindFriendsSheet(context, viewModel);

  PreferredSizeWidget _appBar({List<Widget> actions = const []}) {
    return ButleryTopBar.undersida(
      title: context.l10n.socialFriendsAndGroups,
      backTo: context.l10n.moreTitle,
      actions: actions,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_socialEnabled) {
      return Scaffold(
        appBar: _appBar(),
        bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.layoutMarginOf(context),
              vertical: AppDimensions.space16,
            ),
            child: Text(
              'Sociala funktioner är tillfälligt inaktiverade.',
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Consumer<FriendsViewModel>(
      builder: (context, viewModel, child) {
        final friendsService = context.read<UnifiedFriendsService>();

        return Scaffold(
          appBar: _appBar(
            actions: [
              IconButton(
                icon: const ButleryIcon(ButleryIcons.search),
                tooltip: context.l10n.socialFindFriends,
                onPressed: () => _openFindFriends(viewModel),
              ),
            ],
          ),
          bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: LayoutComponents.valueFor(
                    context: context,
                    mobile: double.infinity,
                    tablet: 700,
                    desktop: 800,
                  ),
                ),
                child: Column(
                  children: [
                    LayoutComponents.offlineIndicator(),
                    ColoredBox(
                      color: Theme.of(context).colorScheme.surface,
                      child: TabBar(
                        // Tabs carry the canonical ring (ButleryTab), never a focus tint
                        // (Grafisk manual v6:209; block288 CSR::ROLE::tab::FOCUSED).
                        overlayColor: ButleryControlFocus.withoutFocusTint(
                          null,
                        ),
                        controller: _tabController,
                        isScrollable: false,
                        tabAlignment: TabAlignment.fill,
                        labelColor: Theme.of(context).colorScheme.onSurface,
                        unselectedLabelColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                        indicatorColor: Theme.of(context).colorScheme.onSurface,
                        indicatorWeight: AppDimensions.borderWidthThick,
                        tabs: [
                          ButleryTab(
                            icon: const ButleryIcon(ButleryIcons.activity),
                            text: context.l10n.socialFeed,
                          ),
                          ButleryTab(
                            icon: Badge(
                              isLabelVisible:
                                  viewModel.incomingRequests.isNotEmpty,
                              label: Text(
                                '${viewModel.incomingRequests.length}',
                              ),
                              child: const ButleryIcon(ButleryIcons.users),
                            ),
                            text: context.l10n.socialFriends,
                          ),
                          ButleryTab(
                            icon: Badge(
                              isLabelVisible: friendsService
                                  .invitations
                                  .pendingReceivedInvitations
                                  .isNotEmpty,
                              label: Text(
                                '${friendsService.invitations.pendingReceivedInvitations.length}',
                              ),
                              child: const ButleryIcon(ButleryIcons.users),
                            ),
                            text: context.l10n.socialGroups,
                          ),
                        ],
                      ),
                    ),
                    if (viewModel.hasError) ...[
                      const SizedBox(height: AppDimensions.spacingL),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingL,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppDimensions.paddingL),
                          decoration: BoxDecoration(
                            color: context.modeColors.surfaceTintDanger,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusControl,
                            ),
                          ),
                          child: Row(
                            children: [
                              ButleryIcon(
                                ButleryIcons.triangleAlert,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: AppDimensions.space4),
                              Expanded(
                                child: Text(
                                  viewModel.error!,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                              ActionButtons.secondaryButton(
                                context,
                                label: context.l10n.commonClose,
                                onPressed: viewModel.clearError,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingL),
                    ],
                    // Only the active tab is built.
                    Expanded(
                      child: switch (_currentTabIndex) {
                        0 => FeedTab.build(
                          context,
                          context.watch<ActivityFeedViewModel>(),
                          hasFriends: viewModel.friendsCount > 0,
                          onAddFriendsCta: () =>
                              _tabController.animateTo(_friendsTab),
                        ),
                        1 => _buildFriendsTab(viewModel),
                        2 => GroupsTab.build(
                          context,
                          friendsService,
                          onCreateGroup: () => _showCreateGroupDialog(),
                        ),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendsTab(FriendsViewModel viewModel) {
    final margin = ButleryTopBar.sideMargin(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          child: ButleryListSection(
            rows: [
              ButleryListRow(
                label: context.l10n.socialFriendRequestsTitle,
                leading: ButleryIcons.userPlus,
                count: viewModel.incomingRequests.length,
                countLabel: context.l10n.socialPendingRequestsCount(
                  viewModel.incomingRequests.length,
                ),
                onTap: () =>
                    Navigator.pushNamed(context, Routes.friendRequests),
              ),
            ],
          ),
        ),
        Expanded(
          child: FriendsTab.build(
            context,
            viewModel,
            onFindByUsername: () => _openFindFriends(viewModel),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateGroupDialog() async {
    try {
      final createdGroup = await SocialGroupComponents.showCreateGroupDialog(
        context: context,
      );

      if (createdGroup != null && mounted) {
        SnackBarUtils.showSuccess(context, context.l10n.groupCreatedSuccess);
        if (mounted) {
          Navigator.pushNamed(
            context,
            Routes.groupDetail,
            arguments: createdGroup.id,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppLogger.error('Failed to create group', e);
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.groupCreateFailed,
        );
      }
    }
  }
}
