// lib/views/social/collaborative_shopping/collaborative_shopping_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Focused widget for collaborative shopping list header
/// This widget handles ONLY header display responsibilities:
/// - List title and status badge display
/// - Description and metadata display
/// - Progress tracking and visualization
/// - Member count and activity summary
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
          if (viewModel.hasActiveShoppers) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            _buildPresenceSection(context),
          ],
          const SizedBox(height: AppDimensions.spacingM),
          _buildProgressSection(context),
          const SizedBox(height: AppDimensions.spacingM),
          _buildMetadataSection(context),
        ],
      ),
    );
  }

  /// BUT-238: "Anna handlar nu" + green dot per active peer.
  Widget _buildPresenceSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shoppers = viewModel.activeShoppers;
    return Wrap(
      spacing: AppDimensions.spacingS,
      runSpacing: AppDimensions.spacingXs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final shopper in shoppers)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Text(
                context.l10n.handlarNu(
                  (shopper['displayName'] as String?).orEmpty(),
                ),
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            viewModel.listTitle,
            style: AppTextStyles.sectionHeader,
          ),
        ),
        _buildStatusBadge(context),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final butlery = context.butleryColors;
    final color = viewModel.getStatusColor(cs, butlery);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.zero,
        border: Border.all(
            color: color.withValues(alpha: AppDimensions.opacityMediumLight)),
      ),
      child: Text(
        viewModel.statusText,
        style: AppTextStyles.labelLarge.copyWith(
          color: color,
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    return Text(
      viewModel.listDescription,
      style: AppTextStyles.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    final progress = viewModel.completionPercentage / 100;
    final cs = Theme.of(context).colorScheme;
    final butlery = context.butleryColors;
    final progressColor = viewModel.getProgressColor(cs, butlery);

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
          context.l10n.collaborativeCompletedOf(
              viewModel.completedItems, viewModel.totalItems),
          style: AppTextStyles.bodyBold,
        ),
        Text(
          '${viewModel.completionPercentage.toStringAsFixed(0)}%',
          style: AppTextStyles.bodyBold.copyWith(
            color: progressColor,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(
      BuildContext context, double progress, Color progressColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Theme.of(context)
            .colorScheme
            .outline
            .withValues(alpha: AppDimensions.opacityLight),
        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
        minHeight: 8,
      ),
    );
  }

  Widget _buildMetadataSection(BuildContext context) {
    return Row(
      children: [
        _buildMemberCount(context),
        const SizedBox(width: AppDimensions.spacingM),
        Expanded(
          child: _buildActivitySummary(context),
        ),
      ],
    );
  }

  Widget _buildMemberCount(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.group,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: AppDimensions.iconSizeM,
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        Text(
          viewModel.memberCountText,
          style: AppTextStyles.metadataEmphasized,
        ),
      ],
    );
  }

  Widget _buildActivitySummary(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: AppDimensions.iconSizeM,
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        Expanded(
          child: Text(
            viewModel.activitySummary,
            style: AppTextStyles.metadataEmphasized,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  bool get shouldShowExpandedView => viewModel.hasDescription;

  /// Get estimated header height for layout calculations
  double getEstimatedHeight(BuildContext context) {
    double baseHeight = AppDimensions.paddingL * 2; // Top and bottom padding
    baseHeight += 24; // Title (headlineSmall height)

    if (viewModel.hasDescription) {
      baseHeight += AppDimensions.spacingXs;
      baseHeight += 16 * 3; // Max 3 lines (bodyMedium height)
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
