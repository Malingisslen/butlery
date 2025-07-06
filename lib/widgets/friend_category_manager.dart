// lib/widgets/friend_category_manager.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/friends_viewmodel.dart';
import '../services/friend_categories_service.dart';
import '../models/friend_category.dart';
import '../widgets/common/state_widget.dart'; // ✅ MIGRATION: Ersätt custom _buildEmptyState
import '../theme/app_theme.dart';
import '../core/utils/logger.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Friend Category Management Widget
/// File: widgets/friend_category_manager.dart
/// Quick Guide: Kategorisering av vänner för shopping list sharing
/// Dependencies IN: FriendCategoriesService, FriendsViewModel, StateWidget
/// Dependencies OUT: Category selection för shopping list sharing
/// Data flow: Load categories → Display with friends → Selection callback
/// State management: Local selection state + service integration
/// Purpose: Elegant category management för bulk friend sharing
/// Common issues: Category loading, friend assignment UI
/// Performance: ⚡ Cached categories, efficient friend loading
/// Connected to: Shopping list sharing dialogs, friend management
/// Used in phases: 18.4

class FriendCategoryManager extends StatefulWidget {
  final List<String> selectedFriendIds;
  final Function(List<String>) onSelectionChanged;
  final bool allowMultipleCategories;
  final String title;
  final String subtitle;

  const FriendCategoryManager({
    super.key,
    required this.selectedFriendIds,
    required this.onSelectionChanged,
    this.allowMultipleCategories = true,
    this.title = 'Välj vänner',
    this.subtitle = 'Välj kategorier eller individuella vänner',
  });

  @override
  State<FriendCategoryManager> createState() => _FriendCategoryManagerState();
}

class _FriendCategoryManagerState extends State<FriendCategoryManager> {
  late final Set<String> _selectedCategories;
  late final Set<String> _selectedFriends;

  @override
  void initState() {
    super.initState();
    _selectedCategories = <String>{};
    _selectedFriends = Set.from(widget.selectedFriendIds);

    // Load categories and friends when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoriesService = context.read<FriendCategoriesService>();
      final friendsViewModel = context.read<FriendsViewModel>();

      if (categoriesService.categories.isEmpty) {
        categoriesService.refresh();
      }

      if (friendsViewModel.friends.isEmpty) {
        friendsViewModel.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FriendCategoriesService, FriendsViewModel>(
      builder: (context, categoriesService, friendsVM, child) {
        if (categoriesService.isLoading || friendsVM.isLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTheme.mediumLoadingIndicator(),
                AppTheme.mediumGap,
                Text(
                  'Laddar vänner och kategorier...',
                  style: AppTheme.subtitleStyle,
                ),
              ],
            ),
          );
        }

        if (categoriesService.hasError) {
          return AppTheme.errorContainer(
            context,
            categoriesService.error ?? 'Kunde inte ladda kategorier',
          );
        }

        if (friendsVM.hasError) {
          return AppTheme.errorContainer(
            context,
            friendsVM.error ?? 'Kunde inte ladda vänner',
          );
        }

        final categories = categoriesService.categoriesWithFriends;
        final friends = friendsVM.friends;

        if (categories.isEmpty && friends.isEmpty) {
          // ✅ MIGRATION: Ersätt custom _buildEmptyState med StateWidget
          return StateWidget.empty(
            title: 'Inga vänner eller kategorier',
            subtitle: 'Lägg till vänner och skapa kategorier först',
            icon: Icons.people_outline,
            actionLabel: 'Hantera vänner',
            onAction: () => Navigator.pushNamed(context, '/friends'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(context),

            AppTheme.mediumGap,

            // Category Selection
            if (categories.isNotEmpty) ...[
              _buildCategorySection(categories, categoriesService),
              AppTheme.largeGap,
            ],

            // Individual Friend Selection
            if (friends.isNotEmpty) ...[
              _buildIndividualFriendsSection(friends),
              AppTheme.mediumGap,
            ],

            // Selection Summary
            if (_selectedFriends.isNotEmpty) ...[
              _buildSelectionSummary(),
              AppTheme.mediumGap,
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (widget.subtitle.isNotEmpty) ...[
          AppTheme.smallGap,
          Text(
            widget.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategorySection(
      List<FriendCategory> categories, FriendCategoriesService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.category_outlined,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.primary,
            ),
            AppTheme.smallHorizontalGap,
            Text(
              'Kategorier',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        AppTheme.smallGap,
        Text(
          'Välj hela kategorier för snabb delning',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        AppTheme.smallGap,
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingXs,
          children: categories.map((category) {
            final isSelected = _selectedCategories.contains(category.id);

            return FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (category.emoji != null && category.emoji!.isNotEmpty) ...[
                    Text(category.emoji!),
                    SizedBox(width: AppTheme.spacingXs),
                  ],
                  Text(category.name),
                  SizedBox(width: AppTheme.spacingXs),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXs,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${category.friendCount}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              onSelected: (selected) => _toggleCategory(category, service),
              selectedColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              checkmarkColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIndividualFriendsSection(List<dynamic> friends) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.people_outline,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.primary,
            ),
            AppTheme.smallHorizontalGap,
            Text(
              'Individuellt val',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        AppTheme.smallGap,
        Text(
          'Välj specifika vänner från din vänlista',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        AppTheme.smallGap,
        Container(
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
            borderRadius: AppTheme.mediumRadius,
          ),
          child: friends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: AppTheme.iconSizeDisplay,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      AppTheme.smallGap,
                      Text(
                        'Inga vänner att visa',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      AppTheme.tinyGap,
                      Text(
                        'Lägg till vänner först',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(AppTheme.spacingXs),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final isSelected = _selectedFriends.contains(friend.uid);

                    return Card(
                      elevation: 0,
                      margin:
                          EdgeInsets.symmetric(vertical: AppTheme.spacingXxs),
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1)
                          : null,
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (selected) => _toggleFriend(friend.uid),
                        title: Text(
                          friend.displayName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: friend.bio != null && friend.bio!.isNotEmpty
                            ? Text(
                                friend.bio!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                            : null,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.trailing,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSm,
                          vertical: AppTheme.spacingXxs,
                        ),
                        activeColor: Theme.of(context).colorScheme.primary,
                        checkColor: Colors.white,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSelectionSummary() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.spacingXs),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.group,
              color: Colors.white,
              size: AppTheme.iconSizeInfo,
            ),
          ),
          AppTheme.smallHorizontalGap,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valda vänner',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${_selectedFriends.length} ${_selectedFriends.length == 1 ? 'vän vald' : 'vänner valda'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          if (_selectedFriends.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAllSelections,
              icon: const Icon(
                Icons.clear,
                size: AppTheme.iconSizeInfo,
              ),
              label: const Text('Rensa'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: AppTheme.spacingXs,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleCategory(
      FriendCategory category, FriendCategoriesService service) {
    setState(() {
      if (_selectedCategories.contains(category.id)) {
        // Remove category and its friends
        _selectedCategories.remove(category.id);
        for (final friendId in category.friendUserIds) {
          _selectedFriends.remove(friendId);
        }
        AppLogger.info('🏷️ Kategori "${category.name}" avmarkerad');
      } else {
        // Add category and its friends
        if (widget.allowMultipleCategories || _selectedCategories.isEmpty) {
          _selectedCategories.add(category.id);
          _selectedFriends.addAll(category.friendUserIds);
          AppLogger.info(
              '🏷️ Kategori "${category.name}" vald (${category.friendCount} vänner)');
        } else {
          // Clear other categories if only single selection allowed
          _selectedCategories.clear();
          _selectedFriends.clear();
          _selectedCategories.add(category.id);
          _selectedFriends.addAll(category.friendUserIds);
          AppLogger.info(
              '🏷️ Kategori "${category.name}" vald (ersatt tidigare val)');
        }
      }
    });

    widget.onSelectionChanged(_selectedFriends.toList());
  }

  void _toggleFriend(String friendId) {
    setState(() {
      if (_selectedFriends.contains(friendId)) {
        _selectedFriends.remove(friendId);
        AppLogger.info('👤 Vän avmarkerad');
      } else {
        _selectedFriends.add(friendId);
        AppLogger.info('👤 Vän vald');
      }
    });

    widget.onSelectionChanged(_selectedFriends.toList());
  }

  void _clearAllSelections() {
    setState(() {
      _selectedCategories.clear();
      _selectedFriends.clear();
    });

    widget.onSelectionChanged([]);
    AppLogger.info('🗑️ Alla val rensade');
  }
}

/// Compact variant för mindre utrymmen
class CompactFriendCategoryManager extends StatelessWidget {
  final List<String> selectedFriendIds;
  final Function(List<String>) onSelectionChanged;
  final int maxHeight;

  const CompactFriendCategoryManager({
    super.key,
    required this.selectedFriendIds,
    required this.onSelectionChanged,
    this.maxHeight = 300,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight.toDouble()),
      child: FriendCategoryManager(
        selectedFriendIds: selectedFriendIds,
        onSelectionChanged: onSelectionChanged,
        title: 'Välj vänner',
        subtitle: 'Snabbval via kategorier',
      ),
    );
  }
}
