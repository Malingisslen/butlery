// lib/views/recipe_detail/recipe_detail_content.dart

import 'package:flutter/material.dart';
import '../../viewmodels/recipe_detail_viewmodel.dart';
import '../../widgets/image/universal_image_manager.dart' as img;
import '../../widgets/common/input_components.dart';
import '../../theme/app_theme.dart';

/// Recipe detail content widget
///
/// This widget displays the main recipe content including:
/// - Recipe description
/// - Tags display
/// - Image carousel
/// - Instructions list
/// - Portion scaler integration
class RecipeDetailContent extends StatelessWidget {
  final RecipeDetailViewModel viewModel;
  final List<String> scaledIngredients;
  final Function(int, List<String>) onPortionChanged;
  final Function(List<String>, int) onImageTap;

  const RecipeDetailContent({
    super.key,
    required this.viewModel,
    required this.scaledIngredients,
    required this.onPortionChanged,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = viewModel.recipe;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description
        if (recipe.description.isNotEmpty) ...[
          _buildDescription(context),
          AppTheme.mediumGap,
        ],
        
        // Tags
        if (recipe.tags?.isNotEmpty ?? false) ...[
          _buildTags(context),
          AppTheme.mediumGap,
        ],
        
        // Images
        if (recipe.imageUrls.isNotEmpty) ...[
          _buildImageCarousel(context),
          AppTheme.mediumGap,
        ],
        
        // Portion scaler
        _buildPortionScaler(context),
        AppTheme.mediumGap,
        
        // Instructions
        if (recipe.instructions.isNotEmpty) ...[
          _buildInstructions(context),
          AppTheme.mediumGap,
        ],
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: AppTheme.cardBorderRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeAction,
              ),
              AppTheme.smallHorizontalGap,
              Text(
                'Beskrivning',
                style: AppTheme.cardTitleStyle,
              ),
            ],
          ),
          AppTheme.smallGap,
          Text(
            viewModel.recipe.description,
            style: AppTheme.bodyStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildTags(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: AppTheme.cardBorderRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeAction,
              ),
              AppTheme.smallHorizontalGap,
              Text(
                'Taggar',
                style: AppTheme.cardTitleStyle,
              ),
            ],
          ),
          AppTheme.smallGap,
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: (viewModel.recipe.tags ?? []).map((tag) => Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSm,
                vertical: AppTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.chipRadius,
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                tag,
                style: AppTheme.captionStyle.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: AppTheme.cardBorderRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: AppTheme.cardPadding,
            child: Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: AppTheme.primaryColor,
                  size: AppTheme.iconSizeAction,
                ),
                AppTheme.smallHorizontalGap,
                Text(
                  'Bilder',
                  style: AppTheme.cardTitleStyle,
                ),
                const Spacer(),
                Text(
                  '${viewModel.recipe.imageUrls.length} ${viewModel.recipe.imageUrls.length == 1 ? 'bild' : 'bilder'}',
                  style: AppTheme.captionStyle,
                ),
              ],
            ),
          ),
          
          // Image carousel
          GestureDetector(
            onTap: () => onImageTap(viewModel.recipe.imageUrls, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppTheme.radiusMedium),
                bottomRight: Radius.circular(AppTheme.radiusMedium),
              ),
              child: img.UniversalImageManager.carousel(
                imageUrls: viewModel.recipe.imageUrls,
                height: 250,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortionScaler(BuildContext context) {
    return InputComponents.portionScaler(
      originalPortions: viewModel.recipe.portions ?? 1,
      originalIngredients: viewModel.recipe.ingredients,
      onPortionChanged: onPortionChanged,
      minPortions: 1,
      maxPortions: 20,
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: AppTheme.cardBorderRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_list_numbered,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeAction,
              ),
              AppTheme.smallHorizontalGap,
              Text(
                'Instruktioner',
                style: AppTheme.cardTitleStyle,
              ),
            ],
          ),
          AppTheme.smallGap,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: viewModel.recipe.instructions.asMap().entries.map((entry) {
              final index = entry.key;
              final instruction = entry.value;
              
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < viewModel.recipe.instructions.length - 1
                      ? AppTheme.spacingSm
                      : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step number
                    Container(
                      width: 28,
                      height: 28,
                      margin: EdgeInsets.only(right: AppTheme.spacingSm),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: AppTheme.captionStyle.copyWith(
                            color: AppTheme.neutralLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    // Instruction text
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          instruction,
                          style: AppTheme.bodyStyle,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}