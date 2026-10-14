// lib/views/social/shared_with_me/shared_content_search_bar.dart

import 'package:butlery/widgets/common/chips/butlery_removable_chip.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// SharedContentSearchBar - Search bar for shared content
/// Handles search functionality for shared recipes and menus.
class SharedContentSearchBar {
  static Widget build(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    TextEditingController searchController,
  ) {
    if (!viewModel.hasAnyContent) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: ButleryPageBody.margin(context, bottom: AppDimensions.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ButlerySearchBox(
            controller: searchController,
            hintText: context.l10n.sharedSearchHint,
            onChanged: viewModel.performUnifiedSearch,
            onClear: viewModel.clearAllSearch,
            // Filter toggle for showing/hiding imported content
            trailing: AppIconButton(
              icon: ButleryIcons.filter,
              color: viewModel.showImported
                  ? Theme.of(context).colorScheme.onSurface
                  : null,
              semanticLabel: viewModel.showImported
                  ? context.l10n.sharedHideImported
                  : context.l10n.sharedShowImported,
              onPressed: () => viewModel.toggleShowImported(),
            ),
          ),
          // Visual chip indicator when showing imported content
          if (viewModel.showImported)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.space4),
              child: ButleryRemovableChip(
                label: context.l10n.sharedShowingImported,
                onRemove: () => viewModel.toggleShowImported(),
                removeLabel: context.l10n.sharedHideImported,
              ),
            ),
        ],
      ),
    );
  }
}
