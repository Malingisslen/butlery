// lib/views/social/group_content_feed/group_content_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Group Content App Bar - Styled app bar for group content feed
class GroupContentAppBar {
  static Widget build(
    BuildContext context, 
    GroupContentViewModel viewModel,
    FriendCategory group,
  ) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          group.displayName,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        background: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40), // Space for back button
                Row(
                  children: [
                    if (group.emoji != null && group.emoji!.isNotEmpty) ...[
                      Text(
                        group.emoji!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: AppDimensions.spacingS),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (group.description != null && group.description!.isNotEmpty)
                            Text(
                              group.description!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.onPrimary.withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildContentStats(viewModel),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: viewModel.refresh,
          tooltip: 'Uppdatera',
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value, viewModel, group),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share_to_group',
              child: ListTile(
                leading: Icon(Icons.share),
                title: Text('Dela till grupp'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'group_settings',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('Gruppinställningar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'export_content',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Exportera innehåll'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _buildContentStats(GroupContentViewModel viewModel) {
    final stats = viewModel.groupContentStats;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${stats['totalContent']}',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'delade',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  static void _handleMenuAction(
    BuildContext context,
    String action,
    GroupContentViewModel viewModel,
    FriendCategory group,
  ) {
    switch (action) {
      case 'share_to_group':
        _showShareToGroupDialog(context, viewModel, group);
        break;
      case 'group_settings':
        Navigator.pushNamed(
          context,
          '/group-detail',
          arguments: {'groupId': group.id},
        );
        break;
      case 'export_content':
        _exportGroupContent(context, viewModel, group);
        break;
    }
  }

  static void _showShareToGroupDialog(
    BuildContext context,
    GroupContentViewModel viewModel,
    FriendCategory group,
  ) {
    // TODO: Implement share to group dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delningsfunktion kommer snart!'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  static void _exportGroupContent(
    BuildContext context,
    GroupContentViewModel viewModel,
    FriendCategory group,
  ) {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exportfunktion kommer snart!'),
        backgroundColor: AppColors.info,
      ),
    );
  }
}