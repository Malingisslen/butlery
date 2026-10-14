/// Friends and groups management view with a three-tab interface.

// lib/views/social/friends_list_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/navigation/underline_tabs.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
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

class _FriendsListViewContentState extends State<_FriendsListViewContent> {
  static const int _tabCount = 3;
  static const int _friendsTab = 1;

  late final bool _socialEnabled;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _socialEnabled = ServiceLocator.get<FeatureFlagService>().isEnabled(
      FeatureFlags.enableSocialFeatures,
    );

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
      if (mounted) setState(() => _currentTabIndex = tabIndex);
    });
  }

  void _openFindFriends(FriendsViewModel viewModel) =>
      showFindFriendsSheet(context, viewModel);

  String _tabLabel(int tab) => switch (tab) {
    0 => context.l10n.socialFeed,
    1 => context.l10n.socialFriends,
    _ => context.l10n.socialGroups,
  };

  Widget _page({required Widget body, List<Widget> actions = const []}) {
    return ButleryPage.undersida(
      title: context.l10n.socialFriendsAndGroups,
      backTo: context.l10n.moreTitle,
      actions: actions,
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_socialEnabled) {
      return _page(
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.layoutMarginOf(context),
              vertical: AppDimensions.space16,
            ),
            child: Text(
              context.l10n.friendsSocialDisabled,
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

        return _page(
          body: Column(
            children: [
              LayoutComponents.offlineIndicator(),
              Padding(
                padding: ButleryPageBody.margin(context),
                child: Row(
                  children: [
                    Expanded(
                      child: UnderlineTabs<int>(
                        values: const [0, _friendsTab, 2],
                        labelOf: _tabLabel,
                        selected: _currentTabIndex,
                        onChanged: (tab) =>
                            setState(() => _currentTabIndex = tab),
                      ),
                    ),
                    AppIconButton(
                      icon: ButleryIcons.search,
                      semanticLabel: context.l10n.socialFindFriends,
                      onPressed: () => _openFindFriends(viewModel),
                    ),
                  ],
                ),
              ),
              if (viewModel.hasError) ...[
                const SizedBox(height: AppDimensions.space12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space16,
                  ),
                  child: InlineError(
                    what: viewModel.error!,
                    actionLabel: context.l10n.commonClose,
                    onAction: viewModel.clearError,
                  ),
                ),
                const SizedBox(height: AppDimensions.space12),
              ],
              // Only the active tab is built.
              Expanded(
                child: switch (_currentTabIndex) {
                  0 => FeedTab.build(
                    context,
                    context.watch<ActivityFeedViewModel>(),
                    hasFriends: viewModel.friendsCount > 0,
                    onAddFriendsCta: () =>
                        setState(() => _currentTabIndex = _friendsTab),
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
