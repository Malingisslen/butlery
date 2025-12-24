// lib/views/recipe_detail/recipe_detail_metadata.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Recipe detail metadata widget
/// This widget displays recipe metadata including:
/// - Portions, cooking time, and rating
/// - "Cooked today" button functionality
/// - Source URL with archive detection
/// - Proper styling and responsive layout
class RecipeDetailMetadata extends StatelessWidget {
  final RecipeDetailViewModel viewModel;
  final int currentPortions;
  final bool isScaled;

  const RecipeDetailMetadata({
    super.key,
    required this.viewModel,
    required this.currentPortions,
    required this.isScaled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main metadata
        _buildMetadata(context),

        // Source URL (if available)
        if (viewModel.recipe.sourceUrl != null &&
            viewModel.recipe.sourceUrl!.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingM),
          _buildSourceUrl(context),
        ],
      ],
    );
  }

  Widget _buildMetadata(BuildContext context) {
    final recipe = viewModel.recipe;

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
          // Header
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.primaryBlue,
                size: AppDimensions.iconSizeAction,
              ),
              SizedBox(width: AppDimensions.spacingM),
              Text(
                'Recept information',
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacingXl),

          // Metadata items
          Row(
            children: [
              // Portions (only show if portions are specified)
              if (currentPortions > 0)
                Expanded(
                  child: _buildMetadataItem(
                    context,
                    Icons.restaurant_menu,
                    'Portioner',
                    '$currentPortions ${currentPortions == 1 ? 'portion' : 'portioner'}',
                    isHighlighted: isScaled,
                  ),
                ),

              // Cooking time
              if ((recipe.timeMinutes ?? 0) > 0) ...[
                if (currentPortions > 0)
                  const SizedBox(width: AppDimensions.spacingXs),
                Expanded(
                  child: _buildMetadataItem(
                    context,
                    Icons.schedule,
                    'Tid',
                    _formatTime(recipe.timeMinutes ?? 0),
                  ),
                ),
              ],

              // Rating
              if ((recipe.rating ?? 0) > 0) ...[
                if (currentPortions > 0 || (recipe.timeMinutes ?? 0) > 0)
                  const SizedBox(width: AppDimensions.spacingXs),
                Expanded(
                  child: _buildMetadataItem(
                    context,
                    Icons.star,
                    'Betyg',
                    (recipe.rating ?? 0).toStringAsFixed(1),
                  ),
                ),
              ],
            ],
          ),

          // Rating stars (if rating exists)
          if ((recipe.rating ?? 0) > 0) ...[
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                const SizedBox(
                    width:
                        AppDimensions.iconSizeAction + AppDimensions.spacingS),
                _buildStarRating(recipe.rating ?? 0),
              ],
            ),
          ],

          const SizedBox(height: AppDimensions.spacingXl),

          // "Cooked today" button
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _markAsCooked(context),
              icon: const Icon(
                Icons.check_circle_outline,
                size: AppDimensions.iconSizeAction,
              ),
              label: const Text(
                'Lagat idag',
                style: AppTextStyles.labelLarge,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success.withValues(alpha: 0.1),
                foregroundColor: AppColors.success,
                minimumSize:
                    const Size(double.infinity, AppDimensions.buttonHeight),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingL,
                    vertical: AppDimensions.paddingM),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusL),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataItem(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.primaryBlue.withValues(alpha: 0.1)
            : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: isHighlighted
              ? AppColors.primaryBlue.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isHighlighted
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: AppDimensions.iconSizeAction,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: isHighlighted
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              color: isHighlighted ? AppColors.primaryBlue : AppColors.textDark,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceUrl(BuildContext context) {
    final sourceUrl = viewModel.recipe.sourceUrl!;
    final isArchiveUrl = sourceUrl.contains('archive.today') ||
        sourceUrl.contains('web.archive.org') ||
        sourceUrl.contains('archive.org');

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
          // Header
          Row(
            children: [
              Icon(
                isArchiveUrl ? Icons.archive : Icons.link,
                color: AppColors.primaryBlue,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Text(
                isArchiveUrl ? 'Arkiverad källa' : 'Källa',
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacingM),

          // URL
          InkWell(
            onTap: () => _launchUrl(context, sourceUrl),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusM),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sourceUrl,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.primaryBlue,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingM),
                  const Icon(
                    Icons.open_in_new,
                    color: AppColors.primaryBlue,
                    size: AppDimensions.iconSizeM,
                  ),
                ],
              ),
            ),
          ),

          // Archive notice
          if (isArchiveUrl) ...[
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.warning,
                  size: AppDimensions.iconSizeM,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: Text(
                    'Denna länk leder till en arkiverad version av receptet',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    final fullStars = rating.floor();
    final hasHalfStar = rating - fullStars >= 0.5;
    final emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Full stars
        ...List.generate(
            fullStars,
            (index) => const Icon(
                  Icons.star,
                  color: AppColors.warning,
                  size: AppDimensions.iconSizeM,
                )),

        // Half star
        if (hasHalfStar)
          const Icon(
            Icons.star_half,
            color: AppColors.warning,
            size: AppDimensions.iconSizeM,
          ),

        // Empty stars
        ...List.generate(
            emptyStars,
            (index) => const Icon(
                  Icons.star_border,
                  color: AppColors.textMedium,
                  size: AppDimensions.iconSizeM,
                )),
      ],
    );
  }

  String _formatTime(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours h';
      } else {
        return '$hours h $remainingMinutes min';
      }
    }
  }

  Future<void> _markAsCooked(BuildContext context) async {
    try {
      await viewModel.markAsCooked();
      if (!context.mounted) return;
      _showSnackBarSafely(
        context,
        'Recept markerat som lagat idag!',
        backgroundColor: AppColors.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBarSafely(
        context,
        'Kunde inte markera som lagat',
        backgroundColor: AppColors.error,
      );
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        _showSnackBarSafely(
          context,
          'Kunde inte öppna länk',
          backgroundColor: AppColors.error,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBarSafely(
        context,
        'Ogiltig länk',
        backgroundColor: AppColors.error,
      );
    }
  }

  void _showSnackBarSafely(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    if (context.mounted) {
      if (backgroundColor == AppColors.error) {
        SnackBarUtils.showError(context, message);
      } else {
        SnackBarUtils.showSuccess(context, message);
      }
    }
  }
}
