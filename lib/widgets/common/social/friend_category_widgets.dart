// lib/widgets/common/social/friend_category_widgets.dart

import 'package:flutter/material.dart';
import '../../../models/friend_category.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';

class FriendCategoryWidgets {
  /// Build friend category selector
  static Widget friendCategorySelector({
    required List<FriendCategory> categories,
    required Set<String> selectedCategoryIds,
    required Function(String) onCategoryToggled,
    bool allowMultipleSelection = true,
    String? title,
    EdgeInsets? padding,
    bool showSelectAll = true,
    bool showCreateNew = true,
    VoidCallback? onCreateNew,
  }) {
    return Padding(
      padding: padding ?? EdgeInsets.all(AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppDimensions.spacingS),
          ],
          Wrap(
            spacing: AppDimensions.spacingS,
            children: categories.map((category) => FilterChip(
              label: Text(category.name),
              selected: selectedCategoryIds.contains(category.id),
              onSelected: (_) => onCategoryToggled(category.id),
            )).toList(),
          ),
          if (showCreateNew && onCreateNew != null) ...[
            SizedBox(height: AppDimensions.spacingS),
            TextButton.icon(
              onPressed: onCreateNew,
              icon: const Icon(Icons.add),
              label: const Text('Skapa ny kategori'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build friend category chip
  static Widget friendCategoryChip({
    required FriendCategory category,
    required bool isSelected,
    required VoidCallback onTap,
    bool showCount = true,
    bool enabled = true,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(category.name),
          if (showCount && category.friendUserIds.isNotEmpty) ...[
            SizedBox(width: AppDimensions.spacingXs),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingXs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${category.friendUserIds.length}',
                style: TextStyle(
                  color: isSelected ? AppColors.primaryBlue : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: enabled ? (_) => onTap() : null,
    );
  }

  /// Build category list
  static Widget categoryList({
    required List<FriendCategory> categories,
    required Set<String> selectedCategoryIds,
    required Function(String) onCategoryToggled,
    bool showMemberCount = true,
    bool shrinkWrap = false,
  }) {
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = selectedCategoryIds.contains(category.id);
        
        return ListTile(
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? AppColors.success : AppColors.neutralMedium,
          ),
          title: Text(category.name),
          subtitle: showMemberCount
              ? Text('${category.friendUserIds.length} medlemmar')
              : null,
          onTap: () => onCategoryToggled(category.id),
        );
      },
    );
  }

  /// Build category grid
  static Widget categoryGrid({
    required List<FriendCategory> categories,
    required Set<String> selectedCategoryIds,
    required Function(String) onCategoryToggled,
    bool showMemberCount = true,
    bool shrinkWrap = false,
  }) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: AppDimensions.spacingL,
        mainAxisSpacing: AppDimensions.spacingL,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = selectedCategoryIds.contains(category.id);
        
        return Card(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.1)
              : null,
          child: InkWell(
            onTap: () => onCategoryToggled(category.id),
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.spacingL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group,
                    color: isSelected
                        ? AppColors.primaryBlue
                        : AppColors.neutralMedium,
                  ),
                  SizedBox(height: AppDimensions.spacingS),
                  Text(
                    category.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primaryBlue : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (showMemberCount) ...[
                    SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      '${category.friendUserIds.length} medlemmar',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.neutralMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build category statistics
  static Widget categoryStatistics({
    required List<FriendCategory> categories,
    EdgeInsets? padding,
  }) {
    final totalCategories = categories.length;
    final totalMembers = categories.fold<int>(
      0,
      (sum, category) => sum + category.friendUserIds.length,
    );
    
    return Padding(
      padding: padding ?? EdgeInsets.all(AppDimensions.spacingL),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatisticItem(
            icon: Icons.category,
            label: 'Kategorier',
            value: totalCategories.toString(),
          ),
          _buildStatisticItem(
            icon: Icons.people,
            label: 'Medlemmar',
            value: totalMembers.toString(),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatisticItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primaryBlue),
        SizedBox(height: AppDimensions.spacingXs),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.neutralMedium,
          ),
        ),
      ],
    );
  }
}