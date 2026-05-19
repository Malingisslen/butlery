/// Public profile view showing a user's display name, avatar, bio, cooking skill, and public recipes.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/public_profile_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/stat_item_widget.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/layout_components.dart';

class PublicProfileView extends StatefulWidget {
  final String userId;

  const PublicProfileView({super.key, required this.userId});

  @override
  State<PublicProfileView> createState() => _PublicProfileViewState();
}

class _PublicProfileViewState extends State<PublicProfileView> {
  late final PublicProfileViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = PublicProfileViewModel(userId: widget.userId);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PublicProfileViewModel>.value(
      value: _vm,
      child: const _PublicProfileContent(),
    );
  }
}

class _PublicProfileContent extends StatelessWidget {
  const _PublicProfileContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PublicProfileViewModel>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          vm.profile?.displayName ?? context.l10n.publicProfileTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 600,
                desktop: 700,
              ),
            ),
            child: Column(
              children: [
                LayoutComponents.offlineIndicator(),
                Expanded(child: _buildBody(context, vm)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PublicProfileViewModel vm) {
    if (vm.isLoading) {
      return StateWidget.loading(message: context.l10n.commonLoading);
    }

    if (vm.hasError) {
      return StateWidget.error(
        message: vm.error!,
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          children: [
            _ProfileHeader(profile: profile),
            const SizedBox(height: AppDimensions.spacingL),
            _ProfileStats(profile: profile),
            const SizedBox(height: AppDimensions.spacingL),
            _PublicRecipesSection(
              recipes: vm.publicRecipes,
              hasRecipes: vm.hasPublicRecipes,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          UserDisplayWidgets.avatar(
            imageUrl: profile.avatarUrl,
            displayName: profile.displayName,
            size: ImageSize.extraLarge,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            profile.displayName,
            style: AppTextStyles.headlineMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              profile.bio!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (profile.cookingSkillLevel != null) ...[
            const SizedBox(height: AppDimensions.spacingM),
            _CookingSkillBadge(level: profile.cookingSkillLevel!),
          ],
        ],
      ),
    );
  }
}

class _CookingSkillBadge extends StatelessWidget {
  final CookingSkillLevel level;

  const _CookingSkillBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = switch (level) {
      CookingSkillLevel.beginner => context.l10n.profileCookingSkillBeginner,
      CookingSkillLevel.intermediate =>
        context.l10n.profileCookingSkillIntermediate,
      CookingSkillLevel.advanced => context.l10n.profileCookingSkillAdvanced,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant, size: 16, color: cs.onPrimaryContainer),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: cs.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  final UserProfile profile;

  const _ProfileStats({required this.profile});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CardContent.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.socialStatistics,
            style: AppTextStyles.titleBold,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatItemWidget(
                label: context.l10n.socialFriends,
                value: '${profile.friendsCount}',
                icon: Icons.people,
                color: cs.primary,
                labelColor: cs.onSurfaceVariant,
              ),
              StatItemWidget(
                label: context.l10n.publicProfilePublicRecipes,
                value: '${profile.publicRecipeCount}',
                icon: Icons.restaurant_menu,
                color: cs.primary,
                labelColor: cs.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
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
        icon: Icons.restaurant_menu,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.publicProfilePublicRecipes,
          style: AppTextStyles.titleBold,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        ...recipes.map((recipe) => _PublicRecipeCard(
              key: ValueKey(recipe.id),
              recipe: recipe,
            )),
      ],
    );
  }
}

class _PublicRecipeCard extends StatelessWidget {
  final Recipe recipe;

  const _PublicRecipeCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      child: CardContent(
        padding: EdgeInsets.zero,
        child: Semantics(
          label: context.l10n.a11yPublicProfileRecipeCard(recipe.title),
          button: true,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pushNamed(
                Routes.receptDetalj,
                arguments: recipe,
              );
            },
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingM),
              child: Row(
                children: [
                  // Recipe image or placeholder
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusS),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: recipe.primaryImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: recipe.primaryImageUrl!,
                              cacheKey: FirebaseUrlUtils.stableCacheKey(
                                  recipe.primaryImageUrl!),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _imagePlaceholder(cs),
                              errorWidget: (_, __, ___) =>
                                  _imagePlaceholder(cs),
                            )
                          : _imagePlaceholder(cs),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingM),
                  // Title and meal type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.title,
                          style: AppTextStyles.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (recipe.mealType.isNotEmpty) ...[
                          const SizedBox(height: AppDimensions.spacingXs),
                          Text(
                            recipe.mealType,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder(ColorScheme cs) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.restaurant_menu,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
