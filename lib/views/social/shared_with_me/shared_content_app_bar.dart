// lib/views/social/shared_with_me/shared_content_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// SharedContentAppBar - App bar for shared content view
/// Handles the app bar with notification badges and refresh functionality.
class SharedContentAppBar {
  static Widget build(
      BuildContext context, SharedContentCoordinatorViewModel viewModel) {
    // BUT-706: stays a Material SliverAppBar for now. A CupertinoSliverNavigationBar
    // (iOS large-title) is possible here but is a visual/UX decision, not a
    // mechanical swap — deferred (see BUT-1362).
    return SliverAppBar(
      title: Text(context.l10n.sharedContent),
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
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '${viewModel.totalUnreadCount}',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Theme.of(context).colorScheme.onError,
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
