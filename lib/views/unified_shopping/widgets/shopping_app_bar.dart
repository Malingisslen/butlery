// lib/views/unified_shopping/widgets/shopping_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';

/// App bar actions for shopping view
class ShoppingAppBar {
  static List<Widget> buildActions(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    VoidCallback onCreateList,
    VoidCallback onShowShareDialog,
    VoidCallback onShareExternally,
    VoidCallback onShowSyncStatus,
  ) {
    final canShare = viewModel.hasItems;

    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ny lista-knapp
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: onCreateList,
            tooltip: 'Ny lista',
          ),

          // Dela med vänner-knapp (social)
          IconButton(
            icon: Icon(
              Icons.people_outline,
              color: canShare ? null : AppColors.textTertiary,
            ),
            onPressed: canShare ? onShowShareDialog : null,
            tooltip: canShare ? 'Dela med vänner' : 'Inga artiklar att dela',
          ),

          // Dela externt-knapp
          IconButton(
            icon: Icon(
              Icons.share,
              color: canShare ? null : AppColors.textTertiary,
            ),
            onPressed: canShare ? onShareExternally : null,
            tooltip: canShare ? 'Dela externt' : 'Inga artiklar att dela',
          ),

          // Sync status indicator
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: IconButton(
              icon: Icon(
                viewModel.isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: viewModel.isOnline ? AppColors.success : AppColors.neutralMedium,
              ),
              onPressed: () => onShowSyncStatus(),
              tooltip: viewModel.isOnline ? 'Online' : 'Offline',
            ),
          ),
        ],
      ),
    ];
  }

  static Widget buildFloatingActionButton(
    BuildContext context,
    VoidCallback onAddItem,
  ) {
    return FloatingActionButton.extended(
      onPressed: onAddItem,
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: AppColors.neutralLight,
      elevation: AppDimensions.elevationHigh,
      icon: const Icon(
        Icons.add,
        color: AppColors.neutralLight,
      ),
      label: Text(
        'Lägg till vara',
        style: AppTextStyles.labelLarge.copyWith(color: AppColors.neutralLight),
      ),
    );
  }
}