// lib/widgets/recipe/recipe_detail_metadata.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

class RecipeDetailMetadata extends StatefulWidget {
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
  State<RecipeDetailMetadata> createState() => _RecipeDetailMetadataState();
}

class _RecipeDetailMetadataState extends State<RecipeDetailMetadata> {
  // Helper method for safe context usage
  void _showSnackBarSafely(String message, {bool isError = false}) {
    if (mounted) {
      if (isError) {
        SnackBarUtils.showError(context, message);
      } else {
        SnackBarUtils.showSuccess(context, message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Metadata container
        _buildMetadata(context),
        const SizedBox(height: AppDimensions.spacingXl),
        
        // Source URL (if available)
        if (widget.viewModel.recipe.sourceUrl != null &&
            widget.viewModel.recipe.sourceUrl!.isNotEmpty) ...[
          _buildSourceUrl(context),
          const SizedBox(height: AppDimensions.spacingXl),
        ],
      ],
    );
  }

  /// Builds the main metadata container with portions, time, rating, and "Cooked today" button
  Widget _buildMetadata(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.backgroundTint,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Metadata items row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetadataItem(
                context,
                Icons.people,
                '${widget.currentPortions} ${widget.currentPortions == 1 ? 'portion' : 'portioner'}',
                isHighlighted: widget.isScaled,
              ),
              _buildMetadataItem(
                context,
                Icons.access_time,
                '${widget.viewModel.timeDisplay} min',
              ),
              if (widget.viewModel.hasRating)
                _buildMetadataItem(
                  context,
                  Icons.star,
                  widget.viewModel.ratingDisplay,
                ),
            ],
          ),
          
          // Rating stars display
          if (widget.viewModel.hasRating) ...[
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final rating = widget.viewModel.recipe.rating!;
                if (i + 1 <= rating) {
                  return const Icon(
                    Icons.star,
                    color: AppColors.starGold,
                    size: AppDimensions.iconSizeS,
                  );
                } else if (i + 0.5 <= rating) {
                  return const Icon(
                    Icons.star_half,
                    color: AppColors.starGold,
                    size: AppDimensions.iconSizeS,
                  );
                }
                return const Icon(
                  Icons.star_border,
                  color: AppColors.starGold,
                  size: AppDimensions.iconSizeS,
                );
              }),
            ),
          ],

          // "Cooked today" button
          const SizedBox(height: AppDimensions.spacingXl),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final success = await widget.viewModel.markAsCooked();
                if (success) {
                  final message = widget.viewModel.recipe.lastCookedText == null
                      ? 'Markerad som tillagad för första gången! 🎉'
                      : 'Uppdaterad som tillagad idag!';
                  _showSnackBarSafely(message);
                }
              },
              icon: Icon(
                widget.viewModel.recipe.wasCookedRecently
                    ? Icons.check_circle
                    : Icons.restaurant,
              ),
              label: Text(
                widget.viewModel.recipe.lastCookedText ?? 'Markera som tillagad',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.viewModel.recipe.wasCookedRecently
                    ? AppColors.success
                    : Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color: widget.viewModel.recipe.wasCookedRecently
                      ? AppColors.success
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds individual metadata items (portions, time, rating)
  Widget _buildMetadataItem(
    BuildContext context,
    IconData icon,
    String text, {
    bool isHighlighted = false,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: AppDimensions.iconSizeAction,
          color: isHighlighted
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(
            color: isHighlighted
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Builds the source URL section with clickable link or archive indicator
  Widget _buildSourceUrl(BuildContext context) {
    final sourceUrl = widget.viewModel.recipe.sourceUrl!;
    final isFromArchive = sourceUrl == 'Från Butlerys arkiv' ||
        sourceUrl == 'Importerat från Butlery-arkivet';

    return InkWell(
      onTap: isFromArchive
          ? null
          : () async {
              final uri = Uri.parse(sourceUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                _showSnackBarSafely(
                  'Kunde inte öppna länken: $sourceUrl',
                  isError: true,
                );
              }
            },
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        decoration: BoxDecoration(
        color: AppColors.backgroundTint,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
        child: Row(
          children: [
            Icon(
              isFromArchive ? Icons.archive : Icons.link,
              size: AppDimensions.iconSizeAction,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Källa',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    sourceUrl,
                    style: AppTextStyles.bodyMedium.copyWith(
                          color: isFromArchive
                              ? AppColors.textDark
                              : AppColors.primaryBlue,
                          decoration:
                              isFromArchive ? null : TextDecoration.underline,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isFromArchive)
              Icon(
                Icons.open_in_new,
                size: AppDimensions.iconSizeM,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}