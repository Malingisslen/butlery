// lib/views/social/discovery_dashboard/recommendations_section.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/services/recommendation_service.dart';
import 'package:butlery/models/recommendation.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/views/social/discovery_dashboard/discovery_section_header.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Recommendations Section - Shows personalized content recommendations
class RecommendationsSection {
  static Widget build(
    BuildContext context,
    DiscoveryDashboardViewModel viewModel,
  ) {
    final recommendations = viewModel.personalizedRecommendations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiscoverySectionHeader(
          title: context.l10n.discoveryRecommendedForYou,
          icon: Icons.auto_awesome,
          iconColor: AppColors.secondary,
          actionLabel: context.l10n.discoverySeeAll,
          onActionPressed: () => _showAllRecommendations(context, viewModel),
          count: recommendations.length,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        if (recommendations.isEmpty)
          _buildEmptyState(context)
        else
          Column(
            children: recommendations
                .take(4) // Show max 4 recommendations
                .map((recommendation) =>
                    _buildRecommendationCard(context, recommendation))
                .toList(),
          ),
      ],
    );
  }

  static Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant
            .withValues(alpha: AppDimensions.opacityMediumLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color:
              AppColors.outline.withValues(alpha: AppDimensions.opacityLight),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.outline,
              size: AppDimensions.iconSizeXxl,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              context.l10n.discoveryBuildingRecommendations,
              style: AppTextStyles.titleSmall,
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              context.l10n.discoveryLearningPreferences,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildRecommendationCard(
      BuildContext context, Map<String, dynamic> recommendation) {
    final String title = recommendation['title'] ?? '';
    final String description = recommendation['description'] ?? '';
    final String reason = recommendation['reason'] ?? '';
    final String? imageUrl = recommendation['imageUrl'];
    final String type = recommendation['type'] ?? '';
    final double score = recommendation['score'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        boxShadow: AppShadows.card,
        border: Border.all(
          color:
              AppColors.secondary.withValues(alpha: AppDimensions.opacityLight),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _openRecommendation(context, recommendation),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingM),
          child: Row(
            children: [
              // Content image or icon
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer
                      .withValues(alpha: AppDimensions.opacityMediumLight),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: imageUrl != null
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.borderRadiusS),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => ColoredBox(
                            color: AppColors.secondaryContainer.withValues(
                                alpha: AppDimensions.opacityMediumLight),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              _buildContentPlaceholder(),
                        ),
                      )
                    : _buildContentPlaceholder(),
              ),
              const SizedBox(width: AppDimensions.spacingM),

              // Recommendation details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recommendation badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingS,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary
                            .withValues(alpha: AppDimensions.opacityVeryLight),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.borderRadiusS),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: AppDimensions.iconSizeXs,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: AppDimensions.spacingXs),
                          Text(
                            _getRecommendationTypeLabel(context, type),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingS),

                    // Title
                    Text(
                      title,
                      style: AppTextStyles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),

                    // Reason
                    Text(
                      reason,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.secondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),

                    // Description (if available)
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.onSurface
                              .withValues(alpha: AppDimensions.opacityDark),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                    ],

                    // Match score indicator
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          final starValue = (index + 1) * 0.2;
                          return Icon(
                            starValue <= score ? Icons.star : Icons.star_border,
                            size: AppDimensions.iconSizeS,
                            color: AppColors.warning,
                          );
                        }),
                        const SizedBox(width: AppDimensions.spacingS),
                        Text(
                          '${(score * 100).round()}% match',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () =>
                        _likeRecommendation(context, recommendation),
                    icon: Icon(
                      Icons.favorite_border,
                      color: AppColors.error
                          .withValues(alpha: AppDimensions.opacityDark),
                      size: AppDimensions.iconSizeM,
                    ),
                    tooltip: context.l10n.discoveryLike,
                  ),
                  IconButton(
                    onPressed: () =>
                        _dismissRecommendation(context, recommendation),
                    icon: Icon(
                      Icons.close,
                      color: AppColors.onSurface
                          .withValues(alpha: AppDimensions.opacityMedium),
                      size: AppDimensions.iconSizeM,
                    ),
                    tooltip: context.l10n.commonHide,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildContentPlaceholder() {
    return Icon(
      Icons.auto_awesome,
      color: AppColors.secondary
          .withValues(alpha: AppDimensions.opacityMediumDark),
      size: AppDimensions.iconSizeXl,
    );
  }

  static String _getRecommendationTypeLabel(BuildContext context, String type) {
    switch (type) {
      case 'similar_to_shared':
        return context.l10n.discoverySimilarToShared;
      case 'trending_for_you':
        return context.l10n.discoveryPopular;
      case 'based_on_friends':
        return context.l10n.discoveryFriendsChoice;
      case 'seasonal':
        return context.l10n.discoverySeasonal;
      default:
        return context.l10n.discoveryRecommended;
    }
  }

  static void _openRecommendation(
      BuildContext context, Map<String, dynamic> recommendation) {
    final String contentType = recommendation['contentType'] ?? '';
    final String contentId = recommendation['contentId'] ?? '';

    switch (contentType) {
      case 'recipe':
        Navigator.pushNamed(
          context,
          Routes.receptDetalj,
          arguments: {'recipeId': contentId},
        );
        break;
      case 'menu':
        Navigator.pushNamed(
          context,
          '/menu-detail',
          arguments: {'menuId': contentId},
        );
        break;
      case 'shopping_list':
        Navigator.pushNamed(
          context,
          '/shopping-list-detail',
          arguments: {'listId': contentId},
        );
        break;
    }
  }

  static Future<void> _likeRecommendation(
      BuildContext context, Map<String, dynamic> recommendation) async {
    try {
      // Send feedback to recommendation service
      final recommendationId = recommendation['id'] as String?;
      if (recommendationId != null) {
        // Here we would call the recommendation service to record the feedback
        // For now, we'll show success feedback to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.discoveryFeedbackThanksImproving),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        // Provide like feedback through recommendation service
        final recommendationService =
            ServiceLocator.get<RecommendationService>();
        await recommendationService.provideFeedback(
            recommendationId, FeedbackType.like);
      }
    } catch (e) {
      // Check if context is still valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.discoveryCouldNotSendFeedback),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  static Future<void> _dismissRecommendation(
      BuildContext context, Map<String, dynamic> recommendation) async {
    try {
      final recommendationId = recommendation['id'] as String?;
      if (recommendationId != null) {
        // Record dismissal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.discoveryRecommendationHidden),
            backgroundColor: AppColors.info,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: context.l10n.commonUndo,
              onPressed: () => _undoDismissal(context, recommendationId),
            ),
          ),
        );

        // Dismiss recommendation through recommendation service
        final recommendationService =
            ServiceLocator.get<RecommendationService>();
        await recommendationService.dismissRecommendation(recommendationId);
      }
    } catch (e) {
      // Check if context is still valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.discoveryCouldNotHideRecommendation),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  static Future<void> _undoDismissal(
      BuildContext context, String recommendationId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.discoveryRecommendationRestored),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );

      // Undo dismissal through recommendation service
      final recommendationService = ServiceLocator.get<RecommendationService>();
      await recommendationService.undoDismissal(recommendationId);
    } catch (e) {
      // Check if context is still valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.discoveryCouldNotRestoreRecommendation),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  static void _showAllRecommendations(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    Navigator.pushNamed(
      context,
      '/recommendations',
      arguments: {
        'viewModel': viewModel,
      },
    ).catchError((error) {
      // Fallback if route doesn't exist yet
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.discoveryAllRecommendationsComingSoon),
            backgroundColor: AppColors.info,
          ),
        );
      }
      return null; // Return value for catchError
    });
  }
}
