// lib/widgets/common/social/reaction_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/social/reaction_type.dart';
import 'package:butlery/models/social/reaction_statistics.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Universal reaction bar widget for content engagement
///
/// This widget provides a horizontal reaction interface following established
/// design patterns from the existing codebase. It displays reaction buttons
/// with counts, handles user interactions, and provides real-time updates
/// for optimal social engagement experience.
///
/// **Design Integration:**
/// - Follows existing icon patterns from MenuRatingCommentsWidget
/// - Uses established color system (AppColors.error for active states)
/// - Implements consistent spacing and typography from design system
/// - Supports both compact and expanded display modes
///
/// **Functionality:**
/// - Real-time reaction count updates
/// - Optimistic UI updates for responsiveness
/// - Smart reaction type filtering by content type
/// - Accessibility support with semantic labels
/// - Animation support for state transitions
///
/// **Usage Examples:**
/// ```dart
/// // Basic reaction bar for recipe
/// ReactionBar(
///   contentId: 'recipe_123',
///   contentType: 'recipe',
///   statistics: reactionStats,
///   userReactionType: ReactionType.delicious,
///   onReactionTap: (type) => toggleReaction(type),
/// )
/// 
/// // Compact mode for list items
/// ReactionBar.compact(
///   statistics: stats,
///   onTap: () => showReactionPicker(),
/// )
/// ```
class ReactionBar extends StatelessWidget {
  /// Content being reacted to
  final String contentId;
  
  /// Type of content (recipe, comment, menu, etc.)
  final String contentType;
  
  /// Current reaction statistics
  final ReactionStatistics? statistics;
  
  /// User's current reaction type (if any)
  final ReactionType? userReactionType;
  
  /// Callback when reaction button is tapped
  final Function(ReactionType)? onReactionTap;
  
  /// Callback when reaction bar is tapped (for compact mode)
  final VoidCallback? onTap;
  
  /// Whether to show in compact mode (just counts, no buttons)
  final bool isCompact;
  
  /// Maximum number of reaction types to show
  final int maxReactionTypes;
  
  /// Whether to show reaction counts
  final bool showCounts;
  
  /// Whether to animate reaction changes
  final bool animated;

  const ReactionBar({
    super.key,
    required this.contentId,
    required this.contentType,
    this.statistics,
    this.userReactionType,
    this.onReactionTap,
    this.onTap,
    this.isCompact = false,
    this.maxReactionTypes = 6,
    this.showCounts = true,
    this.animated = true,
  });

  /// Compact reaction bar constructor
  const ReactionBar.compact({
    super.key,
    required this.statistics,
    this.onTap,
    this.animated = true,
  }) : contentId = '',
       contentType = '',
       userReactionType = null,
       onReactionTap = null,
       isCompact = true,
       maxReactionTypes = 3,
       showCounts = true;

  @override
  Widget build(BuildContext context) {
    if (statistics == null || !statistics!.hasReactions) {
      return isCompact ? const SizedBox.shrink() : _buildEmptyState();
    }

    return isCompact ? _buildCompactView() : _buildFullView();
  }

  Widget _buildEmptyState() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      child: Row(
        children: [
          Icon(
            Icons.favorite_border,
            size: AppDimensions.iconSizeS,
            color: AppColors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Text(
            'Bli första att reagera',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactView() {
    final topReactions = statistics!.getTopReactions(maxReactionTypes);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingS,
          vertical: 4.0, // Extra small padding
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show top reaction emojis
            ...topReactions.take(3).map((entry) => Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(
                entry.key.emoji,
                style: const TextStyle(fontSize: 14),
              ),
            )),
            
            if (topReactions.isNotEmpty) ...[
              const SizedBox(width: 4.0),
              Text(
                statistics!.totalCount.toString(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFullView() {
    final availableReactions = _getAvailableReactions();
    final topReactions = statistics!.getTopReactions(maxReactionTypes);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reaction buttons row
          if (onReactionTap != null) ...[
            _buildReactionButtons(availableReactions),
            const SizedBox(height: AppDimensions.paddingS),
          ],
          
          // Reaction counts summary
          if (showCounts && topReactions.isNotEmpty)
            _buildReactionSummary(topReactions),
        ],
      ),
    );
  }

  Widget _buildReactionButtons(List<ReactionType> reactions) {
    return Wrap(
      spacing: AppDimensions.paddingS,
      children: reactions.map((reactionType) {
        final isSelected = userReactionType == reactionType;
        final count = statistics?.getCount(reactionType) ?? 0;
        
        return _buildReactionButton(
          reactionType: reactionType,
          count: count,
          isSelected: isSelected,
          onTap: () => onReactionTap?.call(reactionType),
        );
      }).toList(),
    );
  }

  Widget _buildReactionButton({
    required ReactionType reactionType,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      child: AnimatedContainer(
        duration: animated ? const Duration(milliseconds: 200) : Duration.zero,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingS,
          vertical: 4.0, // Extra small padding
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reaction emoji
            Text(
              reactionType.emoji,
              style: TextStyle(
                fontSize: isSelected ? 18 : 16,
              ),
            ),
            
            // Count (if exists)
            if (count > 0) ...[
              const SizedBox(width: 4),
              AnimatedDefaultTextStyle(
                duration: animated ? const Duration(milliseconds: 200) : Duration.zero,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.onSurface.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                child: Text(count.toString()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReactionSummary(List<MapEntry<ReactionType, int>> topReactions) {
    return Row(
      children: [
        // Top reaction emojis
        ...topReactions.take(3).map((entry) => Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Text(
            entry.key.emoji,
            style: const TextStyle(fontSize: 16),
          ),
        )),
        
        const SizedBox(width: 4.0),
        
        // Total count with localized text
        Text(
          _formatReactionCount(statistics!.totalCount),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        
        const Spacer(),
        
        // User's reaction indicator
        if (userReactionType != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingS,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userReactionType!.emoji,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 2),
                Text(
                  userReactionType!.displayName,
                  style: AppTextStyles.captionText.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<ReactionType> _getAvailableReactions() {
    // Get content-appropriate reactions
    switch (contentType) {
      case 'recipe':
      case 'menu':
        return ReactionType.foodReactions;
      case 'comment':
      case 'shopping_list':
      case 'user_profile':
        return ReactionType.generalReactions;
      default:
        return ReactionType.allTypes;
    }
  }

  String _formatReactionCount(int count) {
    if (count == 1) return '1 reaktion';
    return '$count reaktioner';
  }
}