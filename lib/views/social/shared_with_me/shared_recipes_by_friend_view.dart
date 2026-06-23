/// Per-friend filtered view of shared recipes (BUT-1000).
/// Shows only the recipes a single friend has shared with the current user,
/// reusing the same coordinator ViewModel, card scaffold, and pull-to-refresh
/// as the main "Shared with me" list — just scoped to one sharer.

// lib/views/social/shared_with_me/shared_recipes_by_friend_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/views/social/shared_with_me/shared_recipe_card.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
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
    timeago.setLocaleMessages('sv', timeago.SvMessages());
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
    return Scaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.sharedRecipesByFriendTitle(friendDisplayName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                Expanded(
                  child: Consumer<SharedContentCoordinatorViewModel>(
                    builder: (context, viewModel, _) =>
                        _buildBody(context, viewModel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
  ) {
    if (viewModel.isGloballyLoading || viewModel.recipeViewModel.isLoading) {
      return const Center(
        child: LoadingIndicator(size: AppDimensions.iconSizeL),
      );
    }

    if (viewModel.recipeViewModel.hasError) {
      return StateWidget.error(
        message: viewModel.recipeViewModel.error!,
        onAction: viewModel.refreshAllContent,
      );
    }

    final recipes = viewModel.recipeViewModel.recipesSharedBy(friendId);

    if (recipes.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.sharedNoRecipesFromFriend(friendDisplayName),
        subtitle: context.l10n.sharedNoRecipesDescription,
        icon: Icons.restaurant_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refreshAllContent,
      child: ListView.separated(
        padding: AppDimensions.screenPadding,
        itemCount: recipes.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          final sharedRecipe = recipes[index];
          return KeyedSubtree(
            key: ValueKey(sharedRecipe.id),
            child: SharedRecipeCard.build(context, viewModel, sharedRecipe),
          );
        },
      ),
    );
  }
}
