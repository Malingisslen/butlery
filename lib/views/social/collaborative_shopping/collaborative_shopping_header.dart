// lib/views/social/collaborative_shopping/collaborative_shopping_header.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/collaborative_shopping_viewmodel.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_dimensions.dart';

/// Focused widget for collaborative shopping list header
/// 
/// This widget handles ONLY header display responsibilities:
/// - List title and status badge display
/// - Description and metadata display
/// - Progress tracking and visualization
/// - Member count and activity summary
/// 
/// ❌ DOES NOT CONTAIN: Item management, actions, business logic
class CollaborativeShoppingHeader extends StatelessWidget {
  final CollaborativeShoppingViewModel viewModel;

  const CollaborativeShoppingHeader({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: AppDimensions.borderWidthThin,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleSection(context),
          if (viewModel.hasDescription) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            _buildDescriptionSection(context),
          ],
          const SizedBox(height: AppDimensions.spacingM),
          _buildProgressSection(context),
          const SizedBox(height: AppDimensions.spacingM),
          _buildMetadataSection(context),
        ],
      ),
    );
  }

  // ===== TITLE AND STATUS =====

  Widget _buildTitleSection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            viewModel.listTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        _buildStatusBadge(context),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final color = viewModel.getStatusColor();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        viewModel.statusText,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ===== DESCRIPTION =====

  Widget _buildDescriptionSection(BuildContext context) {
    return Text(
      viewModel.listDescription,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ===== PROGRESS TRACKING =====

  Widget _buildProgressSection(BuildContext context) {
    final progress = viewModel.completionPercentage / 100;
    final progressColor = viewModel.getProgressColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProgressStats(context, progressColor),
        const SizedBox(height: AppDimensions.spacingXs),
        _buildProgressBar(context, progress, progressColor),
      ],
    );
  }

  Widget _buildProgressStats(BuildContext context, Color progressColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${viewModel.completedItems} av ${viewModel.totalItems} klara',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          '${viewModel.completionPercentage.toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: progressColor,
              ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context, double progress, Color progressColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor:
            Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
        minHeight: 8,
      ),
    );
  }

  // ===== METADATA AND ACTIVITY =====

  Widget _buildMetadataSection(BuildContext context) {
    return Row(
      children: [
        _buildMemberCount(context),
        const SizedBox(width: AppDimensions.spacingM),
        _buildActivitySummary(context),
      ],
    );
  }

  Widget _buildMemberCount(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.group,
          color: AppColors.textMedium,
          size: AppDimensions.iconSizeM,
        ),
        SizedBox(width: AppDimensions.spacingXs),
        Text(
          viewModel.memberCountText,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
        ),
      ],
    );
  }

  Widget _buildActivitySummary(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          color: AppColors.textMedium,
          size: AppDimensions.iconSizeM,
        ),
        SizedBox(width: AppDimensions.spacingXs),
        Expanded(
          child: Text(
            viewModel.activitySummary,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ===== UTILITY METHODS =====

  /// Check if header should show expanded view
  bool get shouldShowExpandedView => viewModel.hasDescription;

  /// Get estimated header height for layout calculations
  double getEstimatedHeight(BuildContext context) {
    double baseHeight = AppDimensions.paddingL * 2; // Top and bottom padding
    baseHeight += Theme.of(context).textTheme.headlineSmall?.height ?? 24; // Title
    
    if (viewModel.hasDescription) {
      baseHeight += AppDimensions.spacingXs;
      baseHeight += (Theme.of(context).textTheme.bodyMedium?.height ?? 16) * 3; // Max 3 lines
    }
    
    baseHeight += AppDimensions.spacingM; // Before progress
    baseHeight += 40; // Progress section
    baseHeight += AppDimensions.spacingM; // Before metadata
    baseHeight += 20; // Metadata section
    
    return baseHeight;
  }

  /// Get header theme data for consistent styling
  static BoxDecoration getHeaderDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: Border(
        bottom: BorderSide(
          color: Theme.of(context).dividerColor,
          width: AppDimensions.borderWidthThin,
        ),
      ),
    );
  }
}