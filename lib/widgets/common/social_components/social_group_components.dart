// lib/widgets/common/social_components/social_group_components.dart

import 'package:flutter/material.dart';
import '../../../models/friend_category.dart';
import '../../../models/user_profile.dart';
import '../social/social_facade.dart';

/// Social group and friend category management components
/// 
/// This module handles ONLY group and friend category widgets:
/// - Friend category selectors and chips
/// - Group dialog launchers
/// - Friend category management interfaces
/// - Group creation and management dialogs
/// 
/// ❌ DOES NOT CONTAIN: Avatars, collaborative indicators, invitations, builders
class SocialGroupComponents {

  // ===== FRIEND CATEGORY MANAGEMENT =====

  /// Build friend category selector
  /// 
  /// Dropdown or selection interface for choosing friend categories
  static Widget friendCategorySelector({
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
      categories: categories,
      selectedCategoryIds: selectedCategory != null ? {selectedCategory.id} : {},
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
  /// 
  /// Chip display for a single friend category
  static Widget friendCategoryChip({
    required FriendCategory category,
    bool selected = false,
    VoidCallback? onTap,
    VoidCallback? onDeleted,
    Color? backgroundColor,
    Color? selectedColor,
    EdgeInsets? padding,
  }) {
    return SocialFacade.friendCategoryChip(
      category: category,
      isSelected: selected,
      onTap: onTap ?? () {},
    );
  }

  // ===== GROUP DIALOGS =====

  /// Show create group dialog
  /// 
  /// Launch dialog for creating a new friend group
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
  /// 
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
  /// 
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
  /// 
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

  // ===== CATEGORY DISPLAY VARIANTS =====

  /// Build category list
  /// 
  /// Display list of friend categories
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
              ? Text('${0} medlemmar') // FriendCategory doesn't have memberIds
              : null,
          leading: const Icon(Icons.group),
          trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
          selected: isSelected,
          onTap: () {
            if (allowMultiSelect && onMultiSelectChanged != null) {
              final currentSelection = List<FriendCategory>.from(selectedCategories ?? []);
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
  /// 
  /// Horizontal scrollable row of category chips
  static Widget categoryChipsRow({
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

  // ===== CATEGORY MANAGEMENT ACTIONS =====

  /// Build add category button
  /// 
  /// Button to create a new friend category
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
  /// 
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

  // ===== CATEGORY STATISTICS =====

  /// Build category statistics widget
  /// 
  /// Shows statistics about categories and their usage
  static Widget categoryStatistics({
    required List<FriendCategory> categories,
    bool showTotalMembers = true,
    bool showAverageSize = true,
    bool showLargestCategory = true,
  }) {
    final totalCategories = categories.length;
    final totalMembers = 0; // FriendCategory doesn't have memberIds
    final averageSize = totalCategories > 0 ? totalMembers / totalCategories : 0.0;
    final largestCategory = categories.isNotEmpty
        ? categories.first
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kategoristatistik',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.category,
                    value: totalCategories.toString(),
                    label: 'Kategorier',
                  ),
                ),
                if (showTotalMembers)
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.people,
                      value: totalMembers.toString(),
                      label: 'Totalt medlemmar',
                    ),
                  ),
              ],
            ),
            if (showAverageSize || showLargestCategory) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (showAverageSize)
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.analytics,
                        value: averageSize.toStringAsFixed(1),
                        label: 'Genomsnitt/kategori',
                      ),
                    ),
                  if (showLargestCategory && largestCategory != null)
                    Expanded(
                      child: _buildStatItem(
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
  static Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ===== EMPTY STATES AND LOADING =====

  /// Build empty categories state
  /// 
  /// Shows when no categories are available
  static Widget emptyCategoriesState({
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
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (onCreateFirst != null && createButtonText != null) ...[
            const SizedBox(height: 24),
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
  /// 
  /// Shows loading indicator for categories
  static Widget categoriesLoading({
    String text = 'Laddar kategorier...',
  }) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Laddar kategorier...'),
        ],
      ),
    );
  }
}