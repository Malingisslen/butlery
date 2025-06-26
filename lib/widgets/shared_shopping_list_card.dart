// lib/widgets/shared_shopping_list_card.dart
import 'package:flutter/material.dart';
import '../models/shared_shopping_list.dart';
import '../theme/app_theme.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Shared Shopping List Card Display
/// File: widgets/shared_shopping_list_card.dart
/// Quick Guide: Beautiful card för shared shopping lists med progress och activity
/// Dependencies IN: SharedShoppingList model, AppTheme
/// Dependencies OUT: Collaborative shopping list UI, sharing views
/// Data flow: SharedShoppingList data → Visual card → User interaction
/// State management: Stateless display component
/// Purpose: Elegant shared shopping list display med progress och metadata
/// Performance: ⚡ Optimized rendering, efficient progress calculations
/// Connected to: SocialShoppingService, collaborative shopping views
/// Used in phases: 18.4

class SharedShoppingListCard extends StatelessWidget {
  final SharedShoppingList list;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final bool showMembers;
  final bool compact;

  const SharedShoppingListCard({
    super.key,
    required this.list,
    this.onTap,
    this.onShare,
    this.showMembers = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: compact
          ? EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs)
          : EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.mediumRadius,
        child: Padding(
          padding:
              EdgeInsets.all(compact ? AppTheme.spacingSm : AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header med titel och status
              _buildHeader(context),

              if (!compact) ...[
                AppTheme.smallGap,

                // Description om den finns
                if (list.description != null &&
                    list.description!.isNotEmpty) ...[
                  Text(
                    list.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppTheme.smallGap,
                ],
              ],

              // Progress bar
              _buildProgressBar(context),

              AppTheme.smallGap,

              // Footer med metadata
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                list.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!compact &&
                  list.description != null &&
                  list.description!.isNotEmpty) ...[
                AppTheme.tinyGap,
                Text(
                  list.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        AppTheme.smallHorizontalGap,
        // Status badge
        _buildStatusBadge(context),
        if (onShare != null) ...[
          AppTheme.tinyGap,
          IconButton(
            icon: Icon(
              Icons.share,
              size: AppTheme.iconSizeInfo,
            ),
            onPressed: onShare,
            constraints: BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.all(AppTheme.spacingXs),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final color = _getStatusColor();
    final text = _getStatusText();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final progress =
        list.totalItems > 0 ? list.completionPercentage / 100 : 0.0;
    final progressColor = _getProgressColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${list.completedItems} av ${list.totalItems} klara',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            Text(
              '${list.completionPercentage.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
            ),
          ],
        ),
        AppTheme.tinyGap,
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        // Members count
        if (showMembers) ...[
          Icon(
            Icons.group,
            size: AppTheme.iconSizeInfo,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: AppTheme.spacingXs),
          Text(
            '${list.memberCount} medlem${list.memberCount != 1 ? 'mar' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          AppTheme.smallHorizontalGap,
        ],

        // Activity indicator
        Icon(
          list.hasRecentActivity ? Icons.access_time_filled : Icons.access_time,
          size: AppTheme.iconSizeInfo,
          color: list.hasRecentActivity
              ? AppTheme.successColor
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: AppTheme.spacingXs),

        Expanded(
          child: Text(
            list.activitySummary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: list.hasRecentActivity
                      ? AppTheme.successColor
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (list.status) {
      case SharedListStatus.active:
        return AppTheme.primaryColor;
      case SharedListStatus.completed:
        return AppTheme.successColor;
      case SharedListStatus.archived:
        return Colors.grey;
      case SharedListStatus.cancelled:
        return AppTheme.errorColor;
    }
  }

  String _getStatusText() {
    switch (list.status) {
      case SharedListStatus.active:
        return 'AKTIV';
      case SharedListStatus.completed:
        return 'KLAR';
      case SharedListStatus.archived:
        return 'ARKIVERAD';
      case SharedListStatus.cancelled:
        return 'AVBRUTEN';
    }
  }

  Color _getProgressColor() {
    if (list.completionPercentage >= 100) return AppTheme.successColor;
    if (list.completionPercentage >= 75) {
      return AppTheme.successColor.withValues(alpha: 0.8);
    }
    if (list.completionPercentage >= 50) return AppTheme.warningColor;
    return AppTheme.primaryColor;
  }
}
