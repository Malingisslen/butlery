// lib/views/recipe_detail/recipe_detail_content.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/widgets/image/universal_image_manager.dart' as img;
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/common/input_components.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

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
          const SizedBox(height: AppDimensions.spacingXl),
        ],
        
        // Tags
        if (recipe.tags?.isNotEmpty ?? false) ...[
          _buildTags(context),
          const SizedBox(height: AppDimensions.spacingXl),
        ],
        
        // Images
        if (recipe.imageUrls.isNotEmpty) ...[
          _buildImageCarousel(context),
          const SizedBox(height: AppDimensions.spacingXl),
        ],
        
        // Portion scaler
        _buildPortionScaler(context),
        const SizedBox(height: AppDimensions.spacingXl),
        
        // Instructions
        if (recipe.instructions.isNotEmpty) ...[
          _buildInstructions(context),
          const SizedBox(height: AppDimensions.spacingXl),
        ],
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: AppColors.primaryBlue,
                size: AppDimensions.iconSizeAction,
              ),
              SizedBox(width: AppDimensions.spacingM),
              Text(
                'Beskrivning',
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            viewModel.recipe.description,
            style: AppTextStyles.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildTags(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                color: AppColors.primaryBlue,
                size: AppDimensions.iconSizeAction,
              ),
              SizedBox(width: AppDimensions.spacingM),
              Text(
                'Taggar',
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Wrap(
            spacing: AppDimensions.spacingS,
            runSpacing: AppDimensions.spacingS,
            children: (viewModel.recipe.tags ?? []).map((tag) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingS,
                vertical: AppDimensions.spacingXs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                tag,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primaryBlue,
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
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Row(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primaryBlue,
                  size: AppDimensions.iconSizeAction,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                const Text(
                  'Bilder',
                  style: AppTextStyles.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${viewModel.recipe.imageUrls.length} ${viewModel.recipe.imageUrls.length == 1 ? 'bild' : 'bilder'}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          
          // Image carousel
          GestureDetector(
            onTap: () => onImageTap(viewModel.recipe.imageUrls, 0),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppDimensions.borderRadiusM),
                bottomRight: Radius.circular(AppDimensions.borderRadiusM),
              ),
              child: img.UniversalImageManager.recipeDetail(
                imageUrls: viewModel.recipe.imageUrls,
                size: ImageSize.large, // Now properly sized for recipe detail
                showNavigationDots: true,
                showImageCounter: true,
                onImageTap: (index) => onImageTap(viewModel.recipe.imageUrls, index),
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
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.format_list_numbered,
                color: AppColors.primaryBlue,
                size: AppDimensions.iconSizeAction,
              ),
              SizedBox(width: AppDimensions.spacingM),
              Text(
                'Instruktioner',
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: viewModel.recipe.instructions.asMap().entries.map((entry) {
              final index = entry.key;
              final instruction = entry.value;
              
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < viewModel.recipe.instructions.length - 1
                      ? AppDimensions.spacingS
                      : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step number
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: AppDimensions.spacingS),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.neutralLight,
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
                          style: AppTextStyles.bodyLarge,
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