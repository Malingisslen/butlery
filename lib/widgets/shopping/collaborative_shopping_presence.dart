// lib/widgets/shopping/collaborative_shopping_presence.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Collaborative Shopping Presence Widget
/// 
/// Shows active shoppers, conflict indicators, and real-time collaboration status
class CollaborativeShoppingPresence extends StatelessWidget {
  final List<Map<String, dynamic>> activeShoppers;
  final bool hasConflicts;
  final VoidCallback? onResolveConflicts;
  final VoidCallback? onStartShopping;
  final VoidCallback? onEndShopping;
  final bool isCurrentUserShopping;

  const CollaborativeShoppingPresence({
    super.key,
    required this.activeShoppers,
    this.hasConflicts = false,
    this.onResolveConflicts,
    this.onStartShopping,
    this.onEndShopping,
    this.isCurrentUserShopping = false,
  });

  @override
  Widget build(BuildContext context) {
    if (activeShoppers.isEmpty && !hasConflicts) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: hasConflicts ? AppColors.error.withValues(alpha: 0.1) : AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: hasConflicts ? AppColors.error.withValues(alpha: 0.3) : AppColors.info.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasConflicts) _buildConflictIndicator(),
            if (activeShoppers.isNotEmpty) _buildActiveShoppers(),
            if (!isCurrentUserShopping) _buildStartShoppingButton(),
            if (isCurrentUserShopping) _buildEndShoppingButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictIndicator() {
    return Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.error,
          size: 20,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Text(
            'Konflikt upptäckt - ändringar synkroniseras',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (onResolveConflicts != null)
          TextButton(
            onPressed: onResolveConflicts,
            child: Text(
              'Lös nu',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveShoppers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasConflicts) const SizedBox(height: AppDimensions.spacingM),
        Row(
          children: [
            const Icon(
              Icons.people,
              color: AppColors.success,
              size: 18,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Handlar nu (${activeShoppers.length})',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingS),
        Wrap(
          spacing: AppDimensions.spacingS,
          runSpacing: AppDimensions.spacingXs,
          children: activeShoppers.map((shopper) => _buildShopperChip(shopper)).toList(),
        ),
      ],
    );
  }

  Widget _buildShopperChip(Map<String, dynamic> shopper) {
    final displayName = shopper['displayName'] as String? ?? 'Okänd';
    final status = shopper['status'] as String? ?? 'shopping';
    final currentSection = shopper['currentSection'] as String?;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'shopping':
        statusColor = AppColors.success;
        statusIcon = Icons.shopping_cart;
        break;
      case 'checking_out':
        statusColor = AppColors.warning;
        statusIcon = Icons.payment;
        break;
      case 'done':
        statusColor = AppColors.info;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = AppColors.onSurface.withValues(alpha: 0.6);
        statusIcon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 14,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            displayName,
            style: AppTextStyles.bodySmall.copyWith(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (currentSection != null) ...[
            const SizedBox(width: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              currentSection,
              style: AppTextStyles.bodySmall.copyWith(
                color: statusColor.withValues(alpha: 0.8),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStartShoppingButton() {
    return Column(
      children: [
        if (activeShoppers.isNotEmpty || hasConflicts) 
          const SizedBox(height: AppDimensions.spacingM),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onStartShopping,
            icon: const Icon(
              Icons.shopping_cart_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            label: Text(
              'Börja handla',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEndShoppingButton() {
    return Column(
      children: [
        if (activeShoppers.length > 1 || hasConflicts) 
          const SizedBox(height: AppDimensions.spacingM),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onEndShopping,
            icon: const Icon(
              Icons.check_circle,
              size: 18,
              color: AppColors.onSuccess,
            ),
            label: Text(
              'Avsluta shopping',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSuccess,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.onSuccess,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shopping Conflict Resolution Dialog
class ShoppingConflictDialog extends StatelessWidget {
  final String listName;
  final int conflictCount;
  final VoidCallback onResolve;
  final VoidCallback onCancel;

  const ShoppingConflictDialog({
    super.key,
    required this.listName,
    required this.conflictCount,
    required this.onResolve,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
          ),
          SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              'Konflikt i lista',
              style: AppTextStyles.titleMedium,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Det finns $conflictCount osynkroniserade ändringar i "$listName".',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            'Detta kan hända när flera personer redigerar listan samtidigt. Vi kan lösa konflikten automatiskt genom att slå samman ändringarna.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingM),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
              border: Border.all(
                color: AppColors.info.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.info,
                  size: 20,
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: Text(
                    'Ändringar slås samman automatiskt och ingen data försvinner.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text(
            'Avbryt',
            style: AppTextStyles.bodyMedium,
          ),
        ),
        ElevatedButton(
          onPressed: onResolve,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: Text(
            'Lös konflikt',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}