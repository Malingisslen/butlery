// lib/views/social/discovery_dashboard/discovery_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';

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
          ),
        ),
        background: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.forestGreen,
                AppColors.forestGreen.withValues(alpha: AppDimensions.opacityVeryDark),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimensions.height40), // Space for back button
                Row(
                  children: [
                    const Icon(
                      Icons.explore,
                      color: AppColors.onPrimary,
                      size: AppDimensions.iconSizeXl,
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upptäck nytt innehåll',
                            style: AppTextStyles.titleBold.copyWith(
                              color: AppColors.onPrimary,
                            ),
                          ),
                          Text(
                            'Hitta populära recept, menyer och listor',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.onPrimary.withValues(alpha: AppDimensions.opacityVeryDark),
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
        color: AppColors.onPrimary.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$totalContent',
            style: AppTextStyles.titleBold.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
          Text(
            'att upptäcka',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onPrimary.withValues(alpha: AppDimensions.opacityVeryDark),
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
                    style: AppTextStyles.titleMedium,
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
                    Text(
                      'Innehållstyp',
                      style: AppTextStyles.titleSmall,
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    // Content type filters
                    CheckboxListTile(
                      title: const Text('Recept'),
                      subtitle: const Text('Visa receptresultat'),
                      value: viewModel.recipesFilterEnabled,
                      onChanged: (value) {
                        viewModel.toggleContentTypeFilter('recipes');
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Menyer'),
                      subtitle: const Text('Visa menyresultat'),
                      value: viewModel.menusFilterEnabled,
                      onChanged: (value) {
                        viewModel.toggleContentTypeFilter('menus');
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Inköpslistor'),
                      subtitle: const Text('Visa inköpslistor'),
                      value: viewModel.shoppingListsFilterEnabled,
                      onChanged: (value) {
                        viewModel.toggleContentTypeFilter('shopping_lists');
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingL),
                    Text(
                      'Kategorier',
                      style: AppTextStyles.titleSmall,
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
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
    DialogFactory.showInteractive(
      context,
      title: 'Upptäcktsinställningar',
      content: _buildSettingsContent(viewModel),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Stäng'),
        ),
        ElevatedButton(
          onPressed: () {
            viewModel.saveDiscoverySettings();
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Inställningar sparade!'),
                backgroundColor: AppColors.success,
              ),
            );
          },
          child: const Text('Spara'),
        ),
      ],
    );
  }

  static Widget _buildSettingsContent(DiscoveryDashboardViewModel viewModel) {
    return StatefulBuilder(
      builder: (context, setState) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anpassa din upptäcktsupplevelse',
              style: AppTextStyles.text16Medium,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            SwitchListTile(
              title: const Text('Visa trender'),
              subtitle: const Text('Visa populärt innehåll från communityn'),
              value: viewModel.showTrendingContent,
              onChanged: (value) {
                setState(() => viewModel.setShowTrendingContent(value));
              },
              activeThumbColor: AppColors.primary,
            ),
            SwitchListTile(
              title: const Text('Visa vänaktivitet'),
              subtitle: const Text('Visa vad dina vänner gör'),
              value: viewModel.showFriendActivity,
              onChanged: (value) {
                setState(() => viewModel.setShowFriendActivity(value));
              },
              activeThumbColor: AppColors.primary,
            ),
            SwitchListTile(
              title: const Text('Visa rekommendationer'),
              subtitle: const Text('Visa personliga rekommendationer'),
              value: viewModel.showRecommendations,
              onChanged: (value) {
                setState(() => viewModel.setShowRecommendations(value));
              },
              activeThumbColor: AppColors.primary,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            const Divider(),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Aviseringar',
              style: AppTextStyles.text16Medium,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            SwitchListTile(
              title: const Text('Push-aviseringar'),
              subtitle: const Text('Få aviseringar om nytt innehåll'),
              value: viewModel.enablePushNotifications,
              onChanged: (value) {
                setState(() => viewModel.setEnablePushNotifications(value));
              },
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showFeedbackDialog(BuildContext context) async {
    final feedback = await DialogFactory.showFeedback(
      context,
      title: 'Skicka feedback',
      hint: 'Hjälp oss att förbättra Butlery! Beskriv din feedback här...',
    );

    if (feedback != null && feedback.trim().isNotEmpty && context.mounted) {
      _submitFeedback(context, feedback.trim());
    }
  }

  static void _submitFeedback(BuildContext context, String feedback) {
    // Log feedback using AppLogger for production tracking
    AppLogger.info('Discovery Dashboard Feedback submitted: $feedback');

    // In a full implementation, this would send to a feedback service
    // For now, we log it properly for monitoring and future integration

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tack för din feedback! Vi kommer att granska den.'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
