/// Public profile view showing a user's display name, avatar, bio, cooking skill, and public recipes.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/layout/page_rule.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_media_row.dart';
import 'package:butlery/widgets/common/recipe_row_meta.dart';
import 'package:butlery/widgets/common/recipe_thumb.dart';
import 'package:butlery/widgets/social/profile_header.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/viewmodels/public_profile_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/widgets/social/public_profile_friend_button.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';

class PublicProfileView extends StatefulWidget {
  final String userId;

  const PublicProfileView({super.key, required this.userId});

  @override
  State<PublicProfileView> createState() => _PublicProfileViewState();
}

class _PublicProfileViewState extends State<PublicProfileView> {
  late final PublicProfileViewModel _vm;
  late final FriendsViewModel _friends;
  late final UnifiedFriendsService _friendsService;

  @override
  void initState() {
    super.initState();
    _vm = PublicProfileViewModel(userId: widget.userId);
    _friends = ServiceLocator.get<FriendsViewModel>();
    _friendsService = ServiceLocator.get<UnifiedFriendsService>();
    if (!_friendsService.isInitialized) {
      // Until the lists load the friend button stays hidden.
      _friendsService.initialize().catchError(
        (Object e) => AppLogger.warning('Friends load for profile failed: $e'),
      );
    }
  }

  @override
  void dispose() {
    _vm.dispose();
    _friends.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PublicProfileViewModel>.value(value: _vm),
        ChangeNotifierProvider<FriendsViewModel>.value(value: _friends),
        Provider<UnifiedFriendsService>.value(value: _friendsService),
      ],
      child: const _PublicProfileContent(),
    );
  }
}

class _PublicProfileContent extends StatelessWidget {
  const _PublicProfileContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PublicProfileViewModel>();
    final friends = context.watch<FriendsViewModel>();
    final profile = vm.profile;
    final isOwnProfile = friends.currentUserId == vm.userId;

    return ButleryPage.undersida(
      // The sketch's bar holds the back arrow and the menu only; the name
      // is the page's own heading. A page reached from a link or a search
      // result has no tab to stand under, so the tab bar is left out.
      title: '',
      ruleUnderBar: false,
      showTabBar: false,
      actions: [
        if (profile != null && !isOwnProfile) _MoreActions(profile: profile),
      ],
      body: Column(
        children: [
          LayoutComponents.offlineIndicator(),
          Expanded(child: _buildBody(context, vm, friends)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PublicProfileViewModel vm,
    FriendsViewModel friends,
  ) {
    if (vm.isLoading) {
      return StateWidget.loading(message: context.l10n.loadingProfile);
    }

    if (vm.hasError) {
      return StateWidget.error(
        message: context.l10n.errorUnknown,
        actionLabel: context.l10n.commonRetry,
        onAction: vm.loadProfile,
      );
    }

    final profile = vm.profile;
    if (profile == null) {
      return StateWidget.error(
        message: context.l10n.publicProfileError,
        actionLabel: context.l10n.commonRetry,
        onAction: vm.loadProfile,
      );
    }

    final margin = ButleryTopBar.sideMargin(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppDimensions.space32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileHeader(
            displayName: profile.displayName,
            avatarUrl: profile.avatarUrl,
            subline: profile.memberSinceText,
            bio: profile.bio,
            statsLayout: ProfileStatsLayout.inline,
            stats: [
              ProfileStat(
                value: profile.friendsCount,
                label: context.l10n.profileFriendsLabel(profile.friendsCount),
              ),
              ProfileStat(
                value: profile.publicRecipeCount,
                label: context.l10n.profilePublicRecipesLabel(
                  profile.publicRecipeCount,
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (profile.cookingSkillLevel != null) ...[
                  const SizedBox(height: AppDimensions.space8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _CookingSkillBadge(
                      level: profile.cookingSkillLevel!,
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.space16),
                PublicProfileFriendButton(
                  profile: profile,
                  isSearchable: vm.isSearchable,
                  friends: friends,
                  friendsLoaded: context
                      .read<UnifiedFriendsService>()
                      .isInitialized,
                ),
                const AccentRule.inline(),
                _PublicRecipesSection(
                  recipes: vm.publicRecipes,
                  hasRecipes: vm.hasPublicRecipes,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Fler åtgärder" in the top bar, as #publikprofil draws it: Rapportera.
class _MoreActions extends StatelessWidget {
  final UserProfile profile;

  const _MoreActions({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ButleryMenu<String>(
      semanticLabel: context.l10n.bulkMoreActions,
      onSelected: (_) => ReportContentDialog.show(
        context: context,
        contentType: ContentType.profile,
        contentId: profile.uid,
        contentOwnerId: profile.uid,
      ),
      choices: [
        ButleryMenuChoice(value: 'report', label: context.l10n.reportContent),
      ],
    );
  }
}

class _CookingSkillBadge extends StatelessWidget {
  final CookingSkillLevel level;

  const _CookingSkillBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final label = switch (level) {
      CookingSkillLevel.beginner => context.l10n.profileCookingSkillBeginner,
      CookingSkillLevel.intermediate =>
        context.l10n.profileCookingSkillIntermediate,
      CookingSkillLevel.advanced => context.l10n.profileCookingSkillAdvanced,
    };

    return UnifiedBadge.status(label: label, icon: ButleryIcons.utensils);
  }
}

class _PublicRecipesSection extends StatelessWidget {
  final List<Recipe> recipes;
  final bool hasRecipes;

  const _PublicRecipesSection({
    required this.recipes,
    required this.hasRecipes,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasRecipes) {
      return StateWidget.empty(
        title: context.l10n.publicProfileEmpty,
        icon: ButleryIcons.utensils,
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.publicProfileRecipeCount(recipes.length),
          style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant),
        ),
        ButleryListSection(
          rows: [
            for (final recipe in recipes)
              _PublicRecipeRow(key: ValueKey(recipe.id), recipe: recipe),
          ],
        ),
      ],
    );
  }
}

class _PublicRecipeRow extends StatelessWidget {
  final Recipe recipe;

  const _PublicRecipeRow({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final minutes = recipe.timeMinutes;
    final rating = recipe.core.averageRating;
    return Semantics(
      label: context.l10n.a11yPublicProfileRecipeCard,
      container: true,
      child: ButleryMediaRow(
        leading: RecipeThumb(imageUrl: recipe.primaryImageUrl),
        title: recipe.title,
        meta: RecipeRowMeta(minutes: minutes, rating: rating),
        onTap: () => Navigator.of(
          context,
        ).pushNamed(Routes.recipeDetail, arguments: recipe),
      ),
    );
  }
}
