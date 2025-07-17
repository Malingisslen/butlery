// lib/views/recipe_detail/recipe_detail_metadata.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/recipe_detail_viewmodel.dart';
import '../../theme/app_theme.dart';
import '../../core/utils/snackbar_utils.dart';

/// Recipe detail metadata widget
///
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
          AppTheme.smallGap,
          _buildSourceUrl(context),
        ],
      ],
    );
  }

  Widget _buildMetadata(BuildContext context) {
    final recipe = viewModel.recipe;
    
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
          // Header
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeAction,
              ),
              AppTheme.smallHorizontalGap,
              Text(
                'Recept information',
                style: AppTheme.cardTitleStyle,
              ),
            ],
          ),
          
          AppTheme.mediumGap,
          
          // Metadata items
          Row(
            children: [
              // Portions
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
                AppTheme.smallHorizontalGap,
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
                AppTheme.smallHorizontalGap,
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
            AppTheme.smallGap,
            Row(
              children: [
                SizedBox(width: AppTheme.iconSizeAction + AppTheme.spacingSm),
                _buildStarRating(recipe.rating ?? 0),
              ],
            ),
          ],
          
          AppTheme.mediumGap,
          
          // "Cooked today" button
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _markAsCooked(context),
              icon: Icon(
                Icons.check_circle_outline,
                size: AppTheme.iconSizeAction,
              ),
              label: Text(
                'Lagat idag',
                style: AppTheme.buttonTextStyle,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.successColor.withValues(alpha: 0.1),
                foregroundColor: AppTheme.successColor,
                minimumSize: Size(double.infinity, AppTheme.buttonHeight),
                padding: AppTheme.buttonPadding,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.largeRadius,
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
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : AppTheme.cardColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: isHighlighted
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : AppTheme.dividerColor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isHighlighted ? AppTheme.primaryColor : AppTheme.textSecondary,
            size: AppTheme.iconSizeAction,
          ),
          AppTheme.tinyGap,
          Text(
            label,
            style: AppTheme.captionStyle.copyWith(
              color: isHighlighted ? AppTheme.primaryColor : AppTheme.textSecondary,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          AppTheme.tinyGap,
          Text(
            value,
            style: AppTheme.bodyStyle.copyWith(
              color: isHighlighted ? AppTheme.primaryColor : AppTheme.textPrimary,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
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
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: AppTheme.cardBorderRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                isArchiveUrl ? Icons.archive : Icons.link,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeAction,
              ),
              AppTheme.smallHorizontalGap,
              Text(
                isArchiveUrl ? 'Arkiverad källa' : 'Källa',
                style: AppTheme.cardTitleStyle,
              ),
            ],
          ),
          
          AppTheme.smallGap,
          
          // URL
          InkWell(
            onTap: () => _launchUrl(context, sourceUrl),
            borderRadius: AppTheme.mediumRadius,
            child: Container(
              width: double.infinity,
              padding: AppTheme.cardPadding,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.mediumRadius,
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sourceUrl,
                      style: AppTheme.bodyStyle.copyWith(
                        color: AppTheme.primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppTheme.smallHorizontalGap,
                  Icon(
                    Icons.open_in_new,
                    color: AppTheme.primaryColor,
                    size: AppTheme.iconSizeInfo,
                  ),
                ],
              ),
            ),
          ),
          
          // Archive notice
          if (isArchiveUrl) ...[
            AppTheme.smallGap,
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.warningColor,
                  size: AppTheme.iconSizeInfo,
                ),
                AppTheme.smallHorizontalGap,
                Expanded(
                  child: Text(
                    'Denna länk leder till en arkiverad version av receptet',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.warningColor,
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
        ...List.generate(fullStars, (index) => Icon(
          Icons.star,
          color: AppTheme.warningColor,
          size: AppTheme.iconSizeInfo,
        )),
        
        // Half star
        if (hasHalfStar)
          Icon(
            Icons.star_half,
            color: AppTheme.warningColor,
            size: AppTheme.iconSizeInfo,
          ),
        
        // Empty stars
        ...List.generate(emptyStars, (index) => Icon(
          Icons.star_border,
          color: AppTheme.textSecondary,
          size: AppTheme.iconSizeInfo,
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
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBarSafely(
        context,
        'Kunde inte markera som lagat',
        backgroundColor: AppTheme.errorColor,
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
          backgroundColor: AppTheme.errorColor,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBarSafely(
        context,
        'Ogiltig länk',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  void _showSnackBarSafely(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    if (context.mounted) {
      if (backgroundColor == AppTheme.errorColor) {
        SnackBarUtils.showError(context, message);
      } else {
        SnackBarUtils.showSuccess(context, message);
      }
    }
  }
}