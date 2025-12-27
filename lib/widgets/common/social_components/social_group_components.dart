import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/social/social_facade.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

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

  /// Show create group dialog.
  static Future<bool?> showCreateGroupDialog({
    required BuildContext context,
    List<String>? preselectedMemberIds,
    String? initialGroupName,
    Function(String groupName, List<String> memberIds)? onGroupCreated,
  }) {
    return SocialFacade.showCreateGroupDialog(
      context,
      initialName: initialGroupName,
      onSuccess: onGroupCreated != null ? () => onGroupCreated('', []) : null,
    ).then((result) => result != null);
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
      name: currentGroupName ?? '',
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
      joinedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
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
              ? const Text(
                  '${0} medlemmar') // FriendCategory doesn't have memberIds
              : null,
          leading: const Icon(Icons.group),
          trailing: isSelected
              ? const Icon(Icons.check, color: AppColors.success)
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
    String text = 'Lägg till kategori',
    IconData icon = Icons.add,
    bool outlined = false,
  }) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
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
        addCategoryButton(
          onPressed: onAddCategory,
          text: 'Ny kategori',
          outlined: true,
        ),
        const Spacer(),
        if (showFilter)
          IconButton(
            onPressed: onFilterCategories,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrera kategorier',
          ),
        if (showSort)
          IconButton(
            onPressed: onSortCategories,
            icon: const Icon(Icons.sort),
            tooltip: 'Sortera kategorier',
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
              'Kategoristatistik',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(
                height: (AppDimensions.spacingSm + AppDimensions.spacingXs)),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.category,
                    value: totalCategories.toString(),
                    label: 'Kategorier',
                  ),
                ),
                if (showTotalMembers)
                  Expanded(
                    child: _buildStatItem(
                      context,
                      icon: Icons.people,
                      value: totalMembers.toString(),
                      label: 'Totalt medlemmar',
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
                      child: _buildStatItem(
                        context,
                        icon: Icons.analytics,
                        value: averageSize.toStringAsFixed(1),
                        label: 'Genomsnitt/kategori',
                      ),
                    ),
                  if (showLargestCategory && largestCategory != null)
                    Expanded(
                      child: _buildStatItem(
                        context,
                        icon: Icons.star,
                        value: largestCategory.name,
                        label: 'Största kategorin',
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

  /// Build statistic item helper
  static Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textMedium),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textMedium,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Build empty categories state.
  static Widget emptyCategoriesState(
    BuildContext context, {
    String title = 'Inga kategorier',
    String subtitle = 'Skapa din första vänkategori för att komma igång',
    IconData icon = Icons.category_outlined,
    VoidCallback? onCreateFirst,
    String? createButtonText = 'Skapa kategori',
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXxl, color: AppColors.textMedium),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMedium,
                ),
            textAlign: TextAlign.center,
          ),
          if (onCreateFirst != null && createButtonText != null) ...[
            const SizedBox(height: AppDimensions.spacingLg),
            ElevatedButton(
              onPressed: onCreateFirst,
              child: Text(createButtonText),
            ),
          ],
        ],
      ),
    );
  }

  /// Build categories loading state
  /// Shows loading indicator for categories
  static Widget categoriesLoading({
    String text = 'Laddar kategorier...',
  }) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppDimensions.spacingMd),
          Text('Laddar kategorier...'),
        ],
      ),
    );
  }
}
