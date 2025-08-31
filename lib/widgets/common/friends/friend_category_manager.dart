// lib/widgets/common/friends/friend_category_manager.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/state_widget.dart';
/// Friend Category Manager
/// 
/// Handles ONLY interactive friend category management with state.
/// This is a complex stateful widget for selecting friends and categories with full UI interaction.
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
    super.initState();
    _selectedCategories = <String>{};
    _selectedFriends = Set.from(widget.selectedFriendIds);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoriesService = context.read<UnifiedFriendsService>();
      final friendsViewModel = context.read<FriendsViewModel>();

      if (categoriesService.categoriesList.isEmpty) {
        categoriesService.refresh();
      }
      if (friendsViewModel.friends.isEmpty) {
        friendsViewModel.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UnifiedFriendsService, FriendsViewModel>(
      builder: (context, categoriesService, friendsVM, child) {
        if (categoriesService.isLoading || friendsVM.isLoading) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: AppDimensions.iconSizeM,
                  height: AppDimensions.iconSizeM,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXl),
                Text(
                  'Laddar vänner och kategorier...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        if (categoriesService.hasError) {
          return Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Text(
              categoriesService.error ?? 'Kunde inte ladda kategorier',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.error,
              ),
            ),
          );
        }

        if (friendsVM.hasError) {
          return Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Text(
              friendsVM.error ?? 'Kunde inte ladda vänner',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.error,
              ),
            ),
          );
        }

        final categories = categoriesService.categoriesList;
        final friends = friendsVM.friends;

        if (categories.isEmpty && friends.isEmpty) {
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
            _buildHeader(context),
            const SizedBox(height: AppDimensions.spacingXl),
            if (categories.isNotEmpty) ...[
              _buildCategorySection(categories, categoriesService),
              const SizedBox(height: AppDimensions.spacingL),
            ],
            if (friends.isNotEmpty) ...[
              _buildIndividualFriendsSection(friends),
              const SizedBox(height: AppDimensions.spacingXl),
            ],
            if (_selectedFriends.isNotEmpty) ...[
              _buildSelectionSummary(),
              const SizedBox(height: AppDimensions.spacingXl),
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
          const SizedBox(height: AppDimensions.spacingM),
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
      List<FriendCategory> categories, UnifiedFriendsService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.category_outlined,
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Text(
              'Kategorier',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Text(
          'Välj hela kategorier för snabb delning',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Wrap(
          spacing: AppDimensions.spacingS,
          runSpacing: AppDimensions.spacingXs,
          children: categories.map((category) {
            final isSelected = _selectedCategories.contains(category.id);
            return FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (category.emoji != null && category.emoji!.isNotEmpty) ...[
                    Text(category.emoji!),
                    const SizedBox(width: AppDimensions.spacingXs),
                  ],
                  Flexible(
                    child: Text(
                      category.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingXs,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neutralLight.withValues(alpha: 0.8)
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
                    ),
                    child: Text(
                      '${category.friendCount}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
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
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Text(
              'Individuellt val',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Text(
          'Välj specifika vänner från din vänlista',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        SizedBox(
          height: 320, // Increased from 240 to accommodate 5 friends (5 × ~64px)
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            child: friends.isEmpty
              ? StateWidget.empty(
                  title: 'Inga vänner att visa',
                  subtitle: 'Lägg till vänner först',
                  icon: Icons.people_outline,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppDimensions.spacingXs),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final isSelected = _selectedFriends.contains(friend.uid);

                    return Card(
                      elevation: 0,
                      margin:
                          const EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
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
                        subtitle: null,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.trailing,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingS,
                          vertical: AppDimensions.spacingXs,
                        ),
                        activeColor: Theme.of(context).colorScheme.primary,
                        checkColor: AppColors.neutralLight,
                      ),
                    );
                  },
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionSummary() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingXs),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius6),
            ),
            child: const Icon(
              Icons.group,
              color: AppColors.neutralLight,
              size: AppDimensions.iconSizeM,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingM),
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
              icon: const Icon(Icons.clear, size: 18.0),
              label: const Text('Rensa'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingS,
                  vertical: AppDimensions.spacingXs,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleCategory(
      FriendCategory category, UnifiedFriendsService service) {
    if (mounted) {
      setState(() {
        if (_selectedCategories.contains(category.id)) {
          _selectedCategories.remove(category.id);
          for (final friendId in category.friendUserIds) {
            _selectedFriends.remove(friendId);
          }
          AppLogger.info('🏷️ Kategori "${category.name}" avmarkerad');
        } else {
          if (widget.allowMultipleCategories || _selectedCategories.isEmpty) {
            _selectedCategories.add(category.id);
            _selectedFriends.addAll(category.friendUserIds);
            AppLogger.info(
                '🏷️ Kategori "${category.name}" vald (${category.friendCount} vänner)');
          } else {
            _selectedCategories.clear();
            _selectedFriends.clear();
            _selectedCategories.add(category.id);
            _selectedFriends.addAll(category.friendUserIds);
            AppLogger.info(
                '🏷️ Kategori "${category.name}" vald (ersatt tidigare val)');
          }
        }
      });
    }
    widget.onSelectionChanged(_selectedFriends.toList());
  }

  void _toggleFriend(String friendId) {
    if (mounted) {
      setState(() {
        if (_selectedFriends.contains(friendId)) {
          _selectedFriends.remove(friendId);
          AppLogger.info('👤 Vän avmarkerad');
        } else {
          _selectedFriends.add(friendId);
          AppLogger.info('👤 Vän vald');
        }
      });
    }
    widget.onSelectionChanged(_selectedFriends.toList());
  }

  void _clearAllSelections() {
    if (mounted) {
      setState(() {
        _selectedCategories.clear();
        _selectedFriends.clear();
      });
    }
    widget.onSelectionChanged([]);
    AppLogger.info('🗑️ Alla val rensade');
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    super.dispose();
  }
}