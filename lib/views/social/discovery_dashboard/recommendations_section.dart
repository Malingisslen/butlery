// lib/views/social/discovery_dashboard/recommendations_section.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

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
        Row(
          children: [
            const Icon(
              Icons.auto_awesome,
              color: AppColors.secondary,
              size: 20,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Rekommenderat för dig',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _showAllRecommendations(context, viewModel),
              child: const Text('Se allt'),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        
        if (recommendations.isEmpty)
          _buildEmptyState()
        else
          Column(
            children: recommendations
                .take(4) // Show max 4 recommendations
                .map((recommendation) => _buildRecommendationCard(context, recommendation))
                .toList(),
          ),
      ],
    );
  }

  static Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.outline,
              size: 48,
            ),
            SizedBox(height: AppDimensions.spacingM),
            Text(
              'Bygger rekommendationer',
              style: AppTextStyles.titleSmall,
            ),
            SizedBox(height: AppDimensions.spacingS),
            Text(
              'Vi lär oss dina preferenser för att ge bättre rekommendationer.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildRecommendationCard(BuildContext context, Map<String, dynamic> recommendation) {
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
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _openRecommendation(context, recommendation),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingM),
          child: Row(
            children: [
              // Content image or icon
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                ),
                child: imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                        child: Image.network(
                          imageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildContentPlaceholder(),
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
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getRecommendationTypeLabel(type),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingS),
                    
                    // Title
                    Text(
                      title,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
                          color: AppColors.onSurface.withValues(alpha: 0.7),
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
                            size: 16,
                            color: AppColors.warning,
                          );
                        }),
                        const SizedBox(width: AppDimensions.spacingS),
                        Text(
                          '${(score * 100).round()}% match',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
                    onPressed: () => _likeRecommendation(context, recommendation),
                    icon: Icon(
                      Icons.favorite_border,
                      color: AppColors.error.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    tooltip: 'Gilla',
                  ),
                  IconButton(
                    onPressed: () => _dismissRecommendation(context, recommendation),
                    icon: Icon(
                      Icons.close,
                      color: AppColors.onSurface.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    tooltip: 'Dölj',
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
      color: AppColors.secondary.withValues(alpha: 0.6),
      size: 32,
    );
  }

  static String _getRecommendationTypeLabel(String type) {
    switch (type) {
      case 'similar_to_shared':
        return 'Liknar delat';
      case 'trending_for_you':
        return 'Populärt';
      case 'based_on_friends':
        return 'Vänners val';
      case 'seasonal':
        return 'Säsong';
      default:
        return 'Rekommenderat';
    }
  }

  static void _openRecommendation(BuildContext context, Map<String, dynamic> recommendation) {
    final String contentType = recommendation['contentType'] ?? '';
    final String contentId = recommendation['contentId'] ?? '';

    switch (contentType) {
      case 'recipe':
        Navigator.pushNamed(
          context,
          '/recipe-detail',
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

  static void _likeRecommendation(BuildContext context, Map<String, dynamic> recommendation) {
    // TODO: Implement recommendation feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tack för din feedback! Vi förbättrar rekommendationerna.'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void _dismissRecommendation(BuildContext context, Map<String, dynamic> recommendation) {
    // TODO: Implement recommendation dismissal
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Rekommendation dold. Vi visar inte liknande innehåll.'),
        backgroundColor: AppColors.info,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Ångra',
          onPressed: () {
            // TODO: Undo dismissal
          },
        ),
      ),
    );
  }

  static void _showAllRecommendations(BuildContext context, DiscoveryDashboardViewModel viewModel) {
    // TODO: Implement show all recommendations page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Visa alla rekommendationer kommer snart!'),
        backgroundColor: AppColors.info,
      ),
    );
  }
}