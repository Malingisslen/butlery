// lib/views/social/discovery_dashboard/discovery_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Discovery App Bar - Styled app bar for discovery dashboard
class DiscoveryAppBar {
  static Widget build(
    BuildContext context, 
    DiscoveryDashboardViewModel viewModel,
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
          'Upptäck',
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
                    const Icon(
                      Icons.explore,
                      color: AppColors.onPrimary,
                      size: 32,
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upptäck nytt innehåll',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Hitta populära recept, menyer och listor',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.onPrimary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDiscoveryStats(viewModel),
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
          onSelected: (value) => _handleMenuAction(context, value, viewModel),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'filter',
              child: ListTile(
                leading: Icon(Icons.filter_list),
                title: Text('Filtrera innehåll'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('Upptäcktsinställningar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'feedback',
              child: ListTile(
                leading: Icon(Icons.feedback),
                title: Text('Ge feedback'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _buildDiscoveryStats(DiscoveryDashboardViewModel viewModel) {
    final stats = viewModel.discoveryStats;
    final totalContent = stats['totalDiscoverableContent'] as int;
    
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
            '$totalContent',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'att upptäcka',
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
    DiscoveryDashboardViewModel viewModel,
  ) {
    switch (action) {
      case 'filter':
        _showFilterDialog(context, viewModel);
        break;
      case 'settings':
        _showDiscoverySettings(context, viewModel);
        break;
      case 'feedback':
        _showFeedbackDialog(context);
        break;
    }
  }

  static void _showFilterDialog(
    BuildContext context,
    DiscoveryDashboardViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.filter_list,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(
                    'Filtrera innehåll',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingL),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    const Text(
                      'Innehållstyp',
                      style: AppTextStyles.titleSmall,
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    // TODO: Implement content type filters
                    ...viewModel.discoveryCategories.map((category) {
                      return CheckboxListTile(
                        title: Text(category['name']),
                        subtitle: Text('${category['count']} objekt'),
                        value: viewModel.selectedCategory == category['id'] || 
                               viewModel.selectedCategory == 'all',
                        onChanged: (value) {
                          viewModel.setSelectedCategory(category['id']);
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showDiscoverySettings(
    BuildContext context,
    DiscoveryDashboardViewModel viewModel,
  ) {
    // TODO: Implement discovery settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Upptäcktsinställningar kommer snart!'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  static void _showFeedbackDialog(BuildContext context) {
    // TODO: Implement feedback dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feedback-funktion kommer snart!'),
        backgroundColor: AppColors.info,
      ),
    );
  }
}