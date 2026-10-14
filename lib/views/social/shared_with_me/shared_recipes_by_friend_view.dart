/// Per-friend filtered view of shared recipes (BUT-1000).
/// Shows only the recipes a single friend has shared with the current user,
/// reusing the same coordinator ViewModel, row and pull-to-refresh as the main
/// "Shared with me" list, scoped to one sharer.

// lib/views/social/shared_with_me/shared_recipes_by_friend_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/views/social/shared_with_me/shared_recipe_card.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// View listing recipes shared with the current user by one specific friend.
class SharedRecipesByFriendView extends StatefulWidget {
  final String friendId;
  final String friendDisplayName;

  const SharedRecipesByFriendView({
    super.key,
    required this.friendId,
    required this.friendDisplayName,
  });

  @override
  State<SharedRecipesByFriendView> createState() =>
      _SharedRecipesByFriendViewState();
}

class _SharedRecipesByFriendViewState extends State<SharedRecipesByFriendView> {
  late final SharedContentCoordinatorViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<SharedContentCoordinatorViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewModel.initialize();
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SharedContentCoordinatorViewModel>.value(
      value: _viewModel,
      child: _SharedRecipesByFriendContent(
        friendId: widget.friendId,
        friendDisplayName: widget.friendDisplayName,
      ),
    );
  }
}

class _SharedRecipesByFriendContent extends StatelessWidget {
  final String friendId;
  final String friendDisplayName;

  const _SharedRecipesByFriendContent({
    required this.friendId,
    required this.friendDisplayName,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SharedContentCoordinatorViewModel>();
    final recipes = viewModel.recipeViewModel.recipesSharedBy(friendId);
    return ButleryPage.undersida(
      title: context.l10n.sharedFromHeading(friendDisplayName),
      backTo: friendDisplayName,
      secondaryLine: recipes.isEmpty
          ? null
          : context.l10n.sharedFromSummary(
              recipes.length,
              ContextualTimeFormatter.standard(
                recipes
                    .map((r) => r.sharedAt)
                    .reduce(
                      (a, b) => a.isAfter(b) ? a : b,
                    ),
                localeName: Localizations.localeOf(context).toString(),
              ),
            ),
      body: Column(
        children: [
          LayoutComponents.offlineIndicator(),
          Expanded(child: _buildBody(context, viewModel, recipes)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    List<SharedRecipe> recipes,
  ) {
    if (viewModel.isGloballyLoading || viewModel.recipeViewModel.isLoading) {
      return StateWidget.loading(message: context.l10n.loadingRecipes);
    }

    if (viewModel.recipeViewModel.hasError) {
      return StateWidget.error(
        message: viewModel.recipeViewModel.error!,
        onAction: viewModel.refreshAllContent,
      );
    }

    if (recipes.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.sharedNoRecipesFromFriend(friendDisplayName),
        subtitle: context.l10n.sharedNoRecipesDescription,
        icon: ButleryIcons.utensils,
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refreshAllContent,
      child: ListView.separated(
        padding: ButleryPageBody.margin(
          context,
          top: AppDimensions.space16,
          bottom: AppDimensions.space32,
        ),
        itemCount: recipes.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppDimensions.space12),
        itemBuilder: (context, index) {
          final sharedRecipe = recipes[index];
          return KeyedSubtree(
            key: ValueKey(sharedRecipe.id),
            child: SharedRecipeCard.build(
              context,
              viewModel,
              sharedRecipe,
              byFriend: true,
            ),
          );
        },
      ),
    );
  }
}
