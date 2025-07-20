// lib/views/recipe_detail_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe_unified.dart';
import '../viewmodels/recipe_detail_viewmodel.dart';
import '../viewmodels/social_recipe_viewmodel.dart';
import '../widgets/common/layout_components.dart';
import '../widgets/common/social_components.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../core/injection.dart';

// Import all recipe detail modules
import 'recipe_detail/recipe_detail_actions.dart';
import 'recipe_detail/recipe_detail_metadata.dart';
import 'recipe_detail/recipe_detail_content.dart';
import '../widgets/recipe/recipe_detail_comments.dart';

/// Recipe Detail View
///
/// This view displays detailed information about a recipe including:
/// - Recipe metadata (portions, time, rating)
/// - Recipe content (description, tags, instructions)
/// - Image carousel with fullscreen viewing
/// - Portion scaling functionality
/// - Comments and social features
/// - Action buttons (delete, share, etc.)
class RecipeDetailView extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailView({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => sl<RecipeDetailViewModel>(param1: recipe),
        ),
        ChangeNotifierProvider(
          create: (_) => sl<SocialRecipeViewModel>(param1: recipe),
        ),
      ],
      child: _RecipeDetailViewContent(recipe: recipe),
    );
  }
}

class _RecipeDetailViewContent extends StatefulWidget {
  final Recipe recipe;

  const _RecipeDetailViewContent({required this.recipe});

  @override
  State<_RecipeDetailViewContent> createState() => _RecipeDetailViewContentState();
}

class _RecipeDetailViewContentState extends State<_RecipeDetailViewContent> {
  final RecipeDetailActions _actions = RecipeDetailActions();
  
  @override
  void initState() {
    super.initState();
    _actions.initializeActions(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeDetailViewModel>(
      builder: (context, viewModel, child) {
        final recipe = viewModel.recipe;
        
        return LayoutComponents.mainMenu(
          body: SingleChildScrollView(
            padding: AppDimensions.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipe title
                _buildHeader(context, viewModel),
                SizedBox(height: AppDimensions.spacingXl),
                
                // Recipe metadata (portions, time, rating, source)
                RecipeDetailMetadata(
                  viewModel: viewModel,
                  currentPortions: _actions.currentPortions,
                  isScaled: _actions.currentPortions != recipe.portions,
                ),
                SizedBox(height: AppDimensions.spacingXl),
                
                // Recipe content (description, tags, images, instructions)
                RecipeDetailContent(
                  viewModel: viewModel,
                  scaledIngredients: _actions.scaledIngredients,
                  onPortionChanged: _actions.onPortionChanged,
                  onImageTap: (imageUrls, index) => _actions.showFullscreenImages(
                    context,
                    imageUrls,
                    initialIndex: index,
                  ),
                ),
                
                // Comments section
                Consumer<SocialRecipeViewModel>(
                  builder: (context, socialViewModel, child) {
                    return RecipeDetailComments(
                      socialViewModel: socialViewModel,
                      onCommentPosted: () {
                        // Optional: Add any post-comment actions
                      },
                    );
                  },
                ),
                
                // Bottom spacing
                SizedBox(height: AppDimensions.spacingXxxl),
              ],
            ),
          ),
          title: recipe.title,
          actions: [
            // Collaborative status
            SocialComponents.collaborativeAppBar(
              context: context,
              contentId: recipe.id,
              recipe: recipe,
            ),
            
            // More actions menu
            PopupMenuButton<String>(
              onSelected: (action) => _handleAction(context, action, viewModel),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: AppDimensions.iconSizeAction),
                      SizedBox(width: AppDimensions.spacingM),
                      Text('Dela'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'share_social',
                  child: Row(
                    children: [
                      Icon(Icons.people, size: AppDimensions.iconSizeAction),
                      SizedBox(width: AppDimensions.spacingM),
                      Text('Dela med vänner'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete,
                        size: AppDimensions.iconSizeAction,
                        color: AppColors.error,
                      ),
                      SizedBox(width: AppDimensions.spacingM),
                      Text(
                        'Ta bort',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, RecipeDetailViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe title
          Text(
            viewModel.recipe.title,
            style: AppTextStyles.sectionTitleStyle.copyWith(
              fontSize: AppTextStyles.displaySmall.fontSize,
            ),
          ),
          
          // Collaborative banner (if applicable)
          SocialComponents.smartCollaborativeBanner(
            context: context,
            contentId: viewModel.recipe.id,
            recipe: viewModel.recipe,
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    RecipeDetailViewModel viewModel,
  ) async {
    switch (action) {
      case 'share':
        await _actions.shareRecipe(context);
        break;
      case 'share_social':
        await _actions.showSocialShareDialog(context);
        break;
      case 'delete':
        await _actions.deleteRecipe(context);
        break;
    }
  }
}