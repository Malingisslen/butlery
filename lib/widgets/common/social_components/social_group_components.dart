import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/social/social_facade.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/stat_item_widget.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Social group and friend category management components.
class SocialGroupComponents {
  /// Build friend category selector.
  static Widget friendCategorySelector(
    BuildContext context, {
    required List<FriendCategory> categories,
    FriendCategory? selectedCategory,
    Function(FriendCategory?)? onCategoryChanged,
    String? hint,
    bool enabled = true,
    Widget? leading,
    Widget? trailing,
    EdgeInsets? padding,
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    return SocialFacade.friendCategorySelector(
      context,
      categories: categories,
      selectedCategoryIds:
          selectedCategory != null ? {selectedCategory.id} : {},
      onCategoryToggled: (categoryId) {
        if (onCategoryChanged != null) {
          final category = categories.firstWhere((c) => c.id == categoryId);
          onCategoryChanged(category);
        }
      },
      title: hint,
      padding: padding,
    );
  }

  /// Build friend category chip
  /// Chip display for a single friend category
  static Widget friendCategoryChip(
    BuildContext context, {
    required FriendCategory category,
    bool selected = false,
    VoidCallback? onTap,
    VoidCallback? onDeleted,
    Color? backgroundColor,
    Color? selectedColor,
    EdgeInsets? padding,
  }) {
    return SocialFacade.friendCategoryChip(
      context,
      category: category,
      isSelected: selected,
      onTap: onTap ?? () {},
    );
  }

  /// Show create group dialog. Returns the created [FriendCategory] or null.
  static Future<FriendCategory?> showCreateGroupDialog({
    required BuildContext context,
    String? initialGroupName,
  }) {
    return SocialFacade.showCreateGroupDialog(
      context,
      initialName: initialGroupName,
    );
  }

  /// Show edit group dialog
  /// Launch dialog for editing an existing friend group
  static Future<bool?> showEditGroupDialog({
    required BuildContext context,
    required String groupId,
    String? currentGroupName,
    List<String>? currentMemberIds,
    Function(String groupName, List<String> memberIds)? onGroupUpdated,
  }) {
    // Create a dummy FriendCategory for the facade
    final group = FriendCategory(
      id: groupId,
      name: currentGroupName.orEmpty(),
      ownerId: 'dummy',
    );
    return SocialFacade.showEditGroupDialog(
      context,
      group: group,
      currentName: currentGroupName,
      onSuccess: onGroupUpdated != null ? () => onGroupUpdated('', []) : null,
    ).then((result) => result != null);
  }

  /// Show delete group dialog
  /// Launch confirmation dialog for deleting a friend group
  static Future<bool?> showDeleteGroupDialog({
    required BuildContext context,
    required String groupId,
    required String groupName,
    VoidCallback? onGroupDeleted,
  }) {
    // Create a dummy FriendCategory for the facade
    final group = FriendCategory(
      id: groupId,
      name: groupName,
      ownerId: 'dummy',
    );
    return SocialFacade.showDeleteGroupDialog(
      context,
      group: group,
      groupName: groupName,
      onSuccess: onGroupDeleted,
    );
  }

  /// Show remove member dialog
  /// Launch confirmation dialog for removing a member from a group
  static Future<bool?> showRemoveMemberDialog({
    required BuildContext context,
    required String groupId,
    required String memberId,
    required String memberName,
    VoidCallback? onMemberRemoved,
  }) {
    // Create dummy objects for the facade
    final group = FriendCategory(
      id: groupId,
      name: '',
      ownerId: 'dummy',
    );
    final member = UserProfile(
      uid: memberId,
      displayName: memberName,
      email: 'dummy@example.com',
      joinedAt: clock.now(),
      lastActiveAt: clock.now(),
    );
    return SocialFacade.showRemoveMemberDialog(
      context,
      group: group,
      member: member,
      onSuccess: onMemberRemoved,
    );
  }

  /// Build category list.
  static Widget categoryList({
    required List<FriendCategory> categories,
    FriendCategory? selectedCategory,
    Function(FriendCategory)? onCategoryTap,
    bool allowMultiSelect = false,
    List<FriendCategory>? selectedCategories,
    Function(List<FriendCategory>)? onMultiSelectChanged,
    bool showMemberCount = true,
    ScrollPhysics? physics,
  }) {
    return ListView.builder(
      physics: physics,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = allowMultiSelect
            ? selectedCategories?.contains(category) ?? false
            : selectedCategory == category;

        return ListTile(
          title: Text(category.name),
          subtitle: showMemberCount
              ? Text(context.l10n.socialMembersCount(
                  0)) // FriendCategory doesn't have memberIds
              : null,
          leading: const Icon(Icons.group),
          trailing: isSelected
              ? Icon(Icons.check, color: context.butleryColors.success)
              : null,
          selected: isSelected,
          onTap: () {
            if (allowMultiSelect && onMultiSelectChanged != null) {
              final currentSelection =
                  List<FriendCategory>.from(selectedCategories ?? []);
              if (isSelected) {
                currentSelection.remove(category);
              } else {
                currentSelection.add(category);
              }
              onMultiSelectChanged(currentSelection);
            } else if (onCategoryTap != null) {
              onCategoryTap(category);
            }
          },
        );
      },
    );
  }

  /// Build category chips row
  /// Horizontal scrollable row of category chips
  static Widget categoryChipsRow(
    BuildContext context, {
    required List<FriendCategory> categories,
    List<FriendCategory>? selectedCategories,
    Function(FriendCategory)? onCategoryTap,
    EdgeInsets? padding,
    double spacing = 8.0,
    bool scrollable = true,
  }) {
    final chips = categories.map((category) {
      final isSelected = selectedCategories?.contains(category) ?? false;
      return friendCategoryChip(
        context,
        category: category,
        selected: isSelected,
        onTap: onCategoryTap != null ? () => onCategoryTap(category) : null,
      );
    }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: chips
              .expand((chip) => [chip, SizedBox(width: spacing)])
              .take(chips.length * 2 - 1)
              .toList(),
        ),
      );
    } else {
      return Wrap(
        spacing: spacing,
        children: chips,
      );
    }
  }

  /// Build add category button.
  static Widget addCategoryButton({
    VoidCallback? onPressed,
    String? text,
    IconData icon = Icons.add,
    bool outlined = false,
  }) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Builder(
            builder: (context) => Text(text ?? context.l10n.socialAddCategory)),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Builder(
            builder: (context) => Text(text ?? context.l10n.socialAddCategory)),
      );
    }
  }

  /// Build category management toolbar
  /// Toolbar with common category management actions
  static Widget categoryManagementToolbar({
    VoidCallback? onAddCategory,
    VoidCallback? onSortCategories,
    VoidCallback? onFilterCategories,
    bool showSort = true,
    bool showFilter = true,
  }) {
    return Row(
      children: [
        Builder(
          builder: (context) => addCategoryButton(
            onPressed: onAddCategory,
            text: context.l10n.socialNewCategory,
            outlined: true,
          ),
        ),
        const Spacer(),
        if (showFilter)
          Builder(
            builder: (context) => IconButton(
              onPressed: onFilterCategories,
              icon: const Icon(Icons.tune),
              tooltip: context.l10n.socialFilterCategories,
            ),
          ),
        if (showSort)
          Builder(
            builder: (context) => IconButton(
              onPressed: onSortCategories,
              icon: const Icon(Icons.sort),
              tooltip: context.l10n.socialSortCategories,
            ),
          ),
      ],
    );
  }

  /// Build category statistics widget.
  static Widget categoryStatistics(
    BuildContext context, {
    required List<FriendCategory> categories,
    bool showTotalMembers = true,
    bool showAverageSize = true,
    bool showLargestCategory = true,
  }) {
    final totalCategories = categories.length;
    const totalMembers = 0; // FriendCategory doesn't have memberIds
    final averageSize =
        totalCategories > 0 ? totalMembers / totalCategories : 0.0;
    final largestCategory = categories.isNotEmpty ? categories.first : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.socialCategoryStatistics,
              style: AppTextStyles.titleBold,
            ),
            const SizedBox(
                height: (AppDimensions.spacingSm + AppDimensions.spacingXs)),
            Row(
              children: [
                Expanded(
                  child: StatItemWidget(
                    icon: Icons.category,
                    value: totalCategories.toString(),
                    label: context.l10n.socialCategories,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    valueStyle: AppTextStyles.titleBold,
                    labelStyle: AppTextStyles.labelSmall,
                  ),
                ),
                if (showTotalMembers)
                  Expanded(
                    child: StatItemWidget(
                      icon: Icons.people,
                      value: totalMembers.toString(),
                      label: context.l10n.socialTotalMembers,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      valueStyle: AppTextStyles.titleBold,
                      labelStyle: AppTextStyles.labelSmall,
                    ),
                  ),
              ],
            ),
            if (showAverageSize || showLargestCategory) ...[
              const SizedBox(
                  height: (AppDimensions.spacingSm + AppDimensions.spacingXs)),
              Row(
                children: [
                  if (showAverageSize)
                    Expanded(
                      child: StatItemWidget(
                        icon: Icons.analytics,
                        value: averageSize.toStringAsFixed(1),
                        label: context.l10n.socialAveragePerCategory,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        valueStyle: AppTextStyles.titleBold,
                        labelStyle: AppTextStyles.labelSmall,
                      ),
                    ),
                  if (showLargestCategory && largestCategory != null)
                    Expanded(
                      child: StatItemWidget(
                        icon: Icons.star,
                        value: largestCategory.name,
                        label: context.l10n.socialLargestCategory,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        valueStyle: AppTextStyles.titleBold,
                        labelStyle: AppTextStyles.labelSmall,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build empty categories state.
  static Widget emptyCategoriesState(
    BuildContext context, {
    String? title,
    String? subtitle,
    IconData icon = Icons.category_outlined,
    VoidCallback? onCreateFirst,
    String? createButtonText,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXxl,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            title ?? context.l10n.socialNoCategories,
            style: AppTextStyles.titleBold,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            subtitle ?? context.l10n.socialCreateFirstCategory,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          if (onCreateFirst != null) ...[
            const SizedBox(height: AppDimensions.spacingLg),
            ElevatedButton(
              onPressed: onCreateFirst,
              child:
                  Text(createButtonText ?? context.l10n.socialCreateCategory),
            ),
          ],
        ],
      ),
    );
  }

  /// Build categories loading state
  /// Shows loading indicator for categories
  static Widget categoriesLoading({
    String? text,
  }) {
    return Builder(
      builder: (context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LoadingIndicator(),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(text ?? context.l10n.socialLoadingCategories),
          ],
        ),
      ),
    );
  }
}
