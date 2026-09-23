// lib/widgets/common/friends/friend_category_manager.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Friend Category Manager
/// Handles ONLY interactive friend category management with state.
/// This is a complex stateful widget for selecting friends and categories with full UI interaction.
class FriendCategoryManager extends StatefulWidget {
  final List<String> selectedFriendIds;
  final Function(List<String>) onSelectionChanged;
  final bool allowMultipleCategories;
  final String? title;
  final String? subtitle;

  const FriendCategoryManager({
    super.key,
    required this.selectedFriendIds,
    required this.onSelectionChanged,
    this.allowMultipleCategories = true,
    this.title,
    this.subtitle,
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
    return Consumer<FriendsViewModel>(
      builder: (context, friendsVM, child) {
        final categoriesService = context.read<UnifiedFriendsService>();
        if (categoriesService.isLoading || friendsVM.isLoading) {
          return Center(
            child: PlateLineMessage(
              message: context.l10n.friendLoadingFriendsAndCategories,
            ),
          );
        }

        if (categoriesService.hasError) {
          return Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(
                alpha: AppDimensions.opacityVeryLight,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withValues(
                  alpha: AppDimensions.opacityMediumLight,
                ),
              ),
            ),
            child: Text(
              categoriesService.error ??
                  context.l10n.errorCouldNotLoad(context.l10n.friendCategories),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          );
        }

        if (friendsVM.hasError) {
          return Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(
                alpha: AppDimensions.opacityVeryLight,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withValues(
                  alpha: AppDimensions.opacityMediumLight,
                ),
              ),
            ),
            child: Text(
              friendsVM.error ??
                  context.l10n.errorCouldNotLoad(
                    context.l10n.friendFriendsLabel,
                  ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          );
        }

        final categories = categoriesService.categoriesList;
        final friends = friendsVM.friends;

        if (categories.isEmpty && friends.isEmpty) {
          return StateWidget.empty(
            title: context.l10n.friendNoFriendsOrCategories,
            subtitle: context.l10n.friendAddFriendsAndCategoriesFirst,
            icon: Icons.people_outline,
            actionLabel: context.l10n.friendManageFriends,
            onAction: () => Navigator.pushNamed(context, Routes.friends),
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
    final displayTitle = widget.title ?? context.l10n.commonSelectFriends;
    final displaySubtitle =
        widget.subtitle ?? context.l10n.friendSelectCategoriesOrFriends;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayTitle,
          style: AppTextStyles.headlineBold,
        ),
        if (displaySubtitle.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            displaySubtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategorySection(
    List<FriendCategory> categories,
    UnifiedFriendsService service,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.category_outlined,
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Text(
              context.l10n.friendCategories,
              style: AppTextStyles.titleBold.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Text(
          context.l10n.friendSelectCategoriesForQuickShare,
          style: AppTextStyles.bodySmall.copyWith(
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
                      vertical: AppDimensions.borderWidthStandard,
                    ),
                    // The count stands on the page (unchosen) or on the
                    // surface.selected plate (chosen), opaque both ways and
                    // never a tint (tokens.json:40-53, :116-119).
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.surface
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.borderRadius8,
                      ),
                    ),
                    child: Text(
                      '${category.friendCount}',
                      style: AppTextStyles.badge.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              onSelected: (selected) => _toggleCategory(category, service),
              // Chosen is surface.selected with a real border, never a tint
              // (Grafisk manual v6:209 "Vald = riktig border"; tokens.json:40-53,
              // :108-119). surfaceContainerHighest is surface.raised, which
              // carries surface.selected's values in both modes; the border is
              // text.primary (onSurface): ink on light, paper on dark.
              selectedColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              checkmarkColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.outline,
                width: isSelected ? 1.5 : 1,
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
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Text(
              context.l10n.friendIndividualSelection,
              style: AppTextStyles.titleBold.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Text(
          context.l10n.friendSelectSpecificFriends,
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        SizedBox(
          height:
              320, // Increased from 240 to accommodate 5 friends (5 x ~64px)
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            child: friends.isEmpty
                ? StateWidget.empty(
                    title: context.l10n.friendNoFriendsToShow,
                    subtitle: context.l10n.friendAddFriendsFirst,
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
                        margin: const EdgeInsets.symmetric(
                          vertical: AppDimensions.spacingXs,
                        ),
                        // A chosen friend is surface.selected, never an ink tint
                        // (tokens.json:40-53, :116-119), with a real 1.5 px
                        // text.primary border (Grafisk manual v6:207-209).
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest
                            : null,
                        shape: isSelected
                            ? RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusCard,
                                ),
                                side: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  width: 1.5,
                                ),
                              )
                            : null,
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (selected) => _toggleFriend(friend.uid),
                          title: Text(
                            friend.displayName,
                            style: isSelected
                                ? AppTextStyles.bodyBold
                                : AppTextStyles.bodyMedium,
                          ),
                          subtitle: null,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacingS,
                            vertical: AppDimensions.spacingXs,
                          ),
                          activeColor: Theme.of(context).colorScheme.primary,
                          checkColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
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
        color:
            Theme.of(
              context,
            ).colorScheme.onSurface.withValues(
              alpha: AppDimensions.opacityVeryLight,
            ),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(
            alpha: AppDimensions.opacityMediumLight,
          ),
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
            child: Icon(
              Icons.group,
              color: Theme.of(context).colorScheme.onPrimary,
              size: AppDimensions.iconSizeM,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.friendSelectedFriends,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  context.l10n.friendSelectedCount(_selectedFriends.length),
                  style: AppTextStyles.contentLabel.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedFriends.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAllSelections,
              icon: const Icon(Icons.clear, size: AppDimensions.iconSizeS),
              label: Text(context.l10n.commonClear),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
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

  void _toggleCategory(FriendCategory category, UnifiedFriendsService service) {
    if (mounted) {
      setState(() {
        if (_selectedCategories.contains(category.id)) {
          _selectedCategories.remove(category.id);
          for (final friendId in category.friendUserIds) {
            _selectedFriends.remove(friendId);
          }
          AppLogger.info('Category "${category.name}" deselected');
        } else {
          if (widget.allowMultipleCategories || _selectedCategories.isEmpty) {
            _selectedCategories.add(category.id);
            _selectedFriends.addAll(category.friendUserIds);
            AppLogger.info(
              'Category "${category.name}" selected (${category.friendCount} friends)',
            );
          } else {
            _selectedCategories.clear();
            _selectedFriends.clear();
            _selectedCategories.add(category.id);
            _selectedFriends.addAll(category.friendUserIds);
            AppLogger.info(
              'Category "${category.name}" selected (replaced previous selection)',
            );
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
          AppLogger.info('Friend deselected');
        } else {
          _selectedFriends.add(friendId);
          AppLogger.info('Friend selected');
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
    AppLogger.info('All selections cleared');
  }

  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions
    // Dispose of resources
    super.dispose();
  }
}
