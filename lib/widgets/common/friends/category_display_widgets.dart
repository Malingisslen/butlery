// lib/widgets/common/friends/category_display_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Category Display Widgets
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
            color: AppColors.forestGreen,
          ),
          title: Text(category.name),
          subtitle: showMemberCount
              ? Text(
                  context.l10n.friendMemberCount(category.friendUserIds.length))
              : null,
          trailing: const Icon(Icons.arrow_forward_ios,
              size: AppDimensions.iconSizeS),
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
          child: Semantics(
            label: '${context.l10n.friendCategoryLabel}: ${category.name}',
            button: true,
            child: InkWell(
              onTap: () => onCategoryTap(category),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      category.emoji != null
                          ? Icons.emoji_emotions
                          : Icons.group,
                      size: AppDimensions.iconSizeXl,
                      color: AppColors.forestGreen,
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
                      context.l10n
                          .friendMemberCount(category.friendUserIds.length),
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build category statistics widget
  static Widget categoryStatistics({
    required BuildContext context,
    required List<FriendCategory> categories,
    EdgeInsets? padding,
  }) {
    final totalMembers =
        categories.fold<int>(0, (sum, cat) => sum + cat.memberIds.length);
    final averageSize =
        categories.isNotEmpty ? (totalMembers / categories.length).round() : 0;
    final largestCategory = categories.isNotEmpty
        ? categories
            .reduce((a, b) => a.memberIds.length > b.memberIds.length ? a : b)
        : null;

    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.friendCategoryStatistics,
              style: AppTextStyles.sectionTitleStyle,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.category,
                    label: context.l10n.friendCategories,
                    value: categories.length.toString(),
                    color: AppColors.forestGreen,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.people,
                    label: context.l10n.friendTotalMembers,
                    value: totalMembers.toString(),
                    color: AppColors.success,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.analytics,
                    label: context.l10n.friendAverage,
                    value: averageSize.toString(),
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            if (largestCategory != null) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                context.l10n.friendLargestCategory(
                    largestCategory.name, largestCategory.memberIds.length),
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
    required BuildContext context,
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
        child: Semantics(
          label: '${context.l10n.friendCategoryLabel}: ${category.name}',
          button: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Fix unbounded height issue
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize
                        .min, // Fix unbounded width constraints in horizontal scrollable
                    children: [
                      Icon(
                        category.emoji != null
                            ? Icons.emoji_emotions
                            : Icons.group,
                        color: AppColors.forestGreen,
                        size: AppDimensions.iconSizeM,
                      ),
                      const SizedBox(width: AppDimensions.spacingS),
                      Flexible(
                        child: Text(
                          category.name,
                          style: AppTextStyles.cardTitleStyle,
                          // Using Flexible instead of Expanded for horizontal scrollable context
                        ),
                      ),
                    ],
                  ),
                  if (showDescription &&
                      category.description != null &&
                      category.description!.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingS),
                    Text(
                      category.description!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Removed const Spacer() to fix unbounded height issues in scrollable contexts
                  if (showMemberCount) ...[
                    const SizedBox(height: AppDimensions.spacingS),
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          size: AppDimensions.iconSizeS,
                          color: AppColors.textMedium,
                        ),
                        const SizedBox(width: AppDimensions.spacingXs),
                        Text(
                          context.l10n
                              .friendMemberCount(category.friendUserIds.length),
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
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
        itemCount: categories.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppDimensions.spacingMd),
        itemBuilder: (context, index) {
          final category = categories[index];
          return categoryCard(
            context: context,
            category: category,
            onTap: () => onCategoryTap(category),
            // Removed fixed width to prevent layout constraints issues
            showDescription: false,
          );
        },
      ),
    );
  }

  /// Build category summary row
  static Widget categorySummaryRow({
    required BuildContext context,
    required List<FriendCategory> categories,
    bool showTotalMembers = true,
    EdgeInsets? padding,
  }) {
    final totalMembers =
        categories.fold<int>(0, (sum, cat) => sum + cat.friendUserIds.length);

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
            color: AppColors.forestGreen,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.friendCategoryCount(categories.length),
                  style: AppTextStyles.titleMedium,
                ),
                if (showTotalMembers)
                  Text(
                    context.l10n.friendTotalMembersCount(totalMembers),
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
    required BuildContext context,
    String? title,
    String? subtitle,
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
            title ?? context.l10n.emptyNoCategoriesTitle,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Text(
            subtitle ?? context.l10n.friendCreateFirstCategory,
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
              label: Text(context.l10n.friendCreateCategory),
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
          size: AppDimensions.iconSizeL,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          value,
          style: AppTextStyles.titleBold.copyWith(
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMedium,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
