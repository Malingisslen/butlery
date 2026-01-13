// lib/views/social/shared_with_me/shared_content_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';

/// SharedContentAppBar - App bar for shared content view
/// Handles the app bar with notification badges and refresh functionality.
class SharedContentAppBar {
  static Widget build(
      BuildContext context, SharedContentCoordinatorViewModel viewModel) {
    return SliverAppBar(
      title: const Text('Delat innehåll'),
      floating: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        // Notification badge med unread count
        if (viewModel.totalUnreadCount > 0)
          Container(
            margin:
                const EdgeInsetsDirectional.only(end: AppDimensions.spacingS),
            child: Stack(
              children: [
                IconButton(
                  onPressed: () => viewModel.refreshAllContent(),
                  icon: const Icon(Icons.refresh),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spacingXs),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '${viewModel.totalUnreadCount}',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.neutralLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          IconButton(
            onPressed: () => viewModel.refreshAllContent(),
            icon: const Icon(Icons.refresh),
          ),
      ],
    );
  }
}
