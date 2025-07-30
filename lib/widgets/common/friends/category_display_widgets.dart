// lib/widgets/common/friends/category_display_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Category Display Widgets
/// 
/// Handles ONLY category display and presentation components.
/// This includes list views, grid views, statistics, and read-only displays.
class CategoryDisplayWidgets {
  /// Build category list view
  static Widget categoryList({
    required List<FriendCategory> categories,
    required Function(FriendCategory) onCategoryTap,
    bool showMemberCount = true,
    EdgeInsets? padding,
  }) {
    return ListView.builder(
      padding: padding,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return ListTile(
          leading: Icon(
            category.emoji != null ? Icons.emoji_emotions : Icons.group,
            color: AppColors.primaryBlue,
          ),
          title: Text(category.name),
          subtitle: showMemberCount ? Text('${category.friendUserIds.length} medlemmar') : null,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => onCategoryTap(category),
        );
      },
    );
  }

  /// Build category grid view
  static Widget categoryGrid({
    required List<FriendCategory> categories,
    required Function(FriendCategory) onCategoryTap,
    int crossAxisCount = 2,
    EdgeInsets? padding,
  }) {
    return GridView.builder(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingMd),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.5,
        crossAxisSpacing: AppDimensions.spacingMd,
        mainAxisSpacing: AppDimensions.spacingMd,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          child: InkWell(
            onTap: () => onCategoryTap(category),
            borderRadius: BorderRadius.circular(AppDimensions.smallRadius),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    category.emoji != null ? Icons.emoji_emotions : Icons.group,
                    size: AppDimensions.iconSizeXl,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(height: AppDimensions.spacingS),
                  Text(
                    category.name,
                    style: AppTextStyles.cardTitleStyle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${category.friendUserIds.length} medlemmar',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build category statistics widget
  static Widget categoryStatistics({
    required List<FriendCategory> categories,
    EdgeInsets? padding,
  }) {
    final totalMembers = categories.fold<int>(0, (sum, cat) => sum + cat.memberIds.length);
    final averageSize = categories.isNotEmpty ? (totalMembers / categories.length).round() : 0;
    final largestCategory = categories.isNotEmpty 
        ? categories.reduce((a, b) => a.memberIds.length > b.memberIds.length ? a : b)
        : null;

    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kategoristatistik',
              style: AppTextStyles.sectionTitleStyle,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.category,
                    label: 'Kategorier',
                    value: categories.length.toString(),
                    color: AppColors.primaryBlue,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.people,
                    label: 'Totalt medlemmar',
                    value: totalMembers.toString(),
                    color: AppColors.success,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.analytics,
                    label: 'Genomsnitt',
                    value: averageSize.toString(),
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            if (largestCategory != null) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'Största kategori: ${largestCategory.name} (${largestCategory.memberIds.length} medlemmar)',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build compact category card
  static Widget categoryCard({
    required FriendCategory category,
    required VoidCallback onTap,
    bool showMemberCount = true,
    bool showDescription = true,
    double? width,
    double? height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      category.emoji != null ? Icons.emoji_emotions : Icons.group,
                      color: AppColors.primaryBlue,
                      size: AppDimensions.iconSizeM,
                    ),
                    const SizedBox(width: AppDimensions.spacingS),
                    Expanded(
                      child: Text(
                        category.name,
                        style: AppTextStyles.cardTitleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (showDescription && category.description != null && category.description!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingS),
                  Text(
                    category.description!,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Spacer(),
                if (showMemberCount) ...[
                  const SizedBox(height: AppDimensions.spacingS),
                  Row(
                    children: [
                      const Icon(
                        Icons.people,
                        size: 16,
                        color: AppColors.textMedium,
                      ),
                      const SizedBox(width: AppDimensions.spacingXs),
                      Text(
                        '${category.friendUserIds.length} medlemmar',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build category carousel/horizontal list
  static Widget categoryCarousel({
    required List<FriendCategory> categories,
    required Function(FriendCategory) onCategoryTap,
    double height = 120,
    EdgeInsets? padding,
  }) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppDimensions.spacingMd),
        itemBuilder: (context, index) {
          final category = categories[index];
          return categoryCard(
            category: category,
            onTap: () => onCategoryTap(category),
            width: 140,
            showDescription: false,
          );
        },
      ),
    );
  }

  /// Build category summary row
  static Widget categorySummaryRow({
    required List<FriendCategory> categories,
    bool showTotalMembers = true,
    EdgeInsets? padding,
  }) {
    final totalMembers = categories.fold<int>(0, (sum, cat) => sum + cat.friendUserIds.length);
    
    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.category,
            color: AppColors.primaryBlue,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${categories.length} ${categories.length == 1 ? 'kategori' : 'kategorier'}',
                  style: AppTextStyles.titleMedium,
                ),
                if (showTotalMembers)
                  Text(
                    '$totalMembers totalt medlemmar',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMedium,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build empty categories state
  static Widget emptyState({
    String title = 'Inga kategorier',
    String subtitle = 'Skapa din första vänkategori',
    VoidCallback? onCreateCategory,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.category_outlined,
            size: AppDimensions.iconSizeXxl,
            color: AppColors.textMedium,
          ),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (onCreateCategory != null) ...[
            const SizedBox(height: AppDimensions.spacingL),
            ElevatedButton.icon(
              onPressed: onCreateCategory,
              icon: const Icon(Icons.add),
              label: const Text('Skapa kategori'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper widget for displaying statistics
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMedium,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}