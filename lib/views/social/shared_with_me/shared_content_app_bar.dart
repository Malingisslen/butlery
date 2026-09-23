// lib/views/social/shared_with_me/shared_content_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

/// SharedContentAppBar - App bar for shared content view
/// Handles the app bar with notification badges and refresh functionality.
class SharedContentAppBar {
  /// The subpage bar (Komponentark v1 §01 pattern 2; Skarmar v12 del 2
  /// 'Delat med mig' draws the back arrow; B-45). It is the scaffold's own
  /// bar, pinned, instead of a floating Material SliverAppBar.
  static PreferredSizeWidget build(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
  ) {
    final cs = Theme.of(context).colorScheme;
    final refresh = IconButton(
      onPressed: () => viewModel.refreshAllContent(),
      icon: const Icon(Icons.refresh),
      tooltip: context.l10n.commonRefresh,
    );
    return ButleryTopBar.undersida(
      title: context.l10n.sharedContent,
      actions: [
        // The unread count on the refresh action. On the ink bar it is a
        // paper plate with ink figures (onPrimary / primary, the same in
        // both schemes): a count, not an alarm, so never error red.
        if (viewModel.totalUnreadCount > 0)
          Stack(
            children: [
              refresh,
              PositionedDirectional(
                end: AppDimensions.spacingXs,
                top: AppDimensions.spacingXs,
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.spacingXxs),
                  decoration: BoxDecoration(
                    color: cs.onPrimary,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: AppDimensions.iconSizeS,
                    minHeight: AppDimensions.iconSizeS,
                  ),
                  child: Text(
                    '${viewModel.totalUnreadCount}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: cs.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          )
        else
          refresh,
      ],
    );
  }
}
