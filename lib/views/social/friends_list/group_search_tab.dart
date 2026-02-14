// lib/views/social/friends_list/group_search_tab.dart

import 'package:flutter/material.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/animations/animated_list_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/social/friends_list/friends_list_cards.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// GroupSearchTab - Group search tab component
/// Displays search results for filtering current groups.
class GroupSearchTab {
  static Widget build(
    BuildContext context,
    UnifiedFriendsService friendsService,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.groupSearchGroups,
        subtitle: context.l10n.groupSearchGroupsDescription,
        icon: Icons.search,
      );
    }

    // Filter current groups by search query
    final allGroups = friendsService.categories.categoriesList;
    final filteredGroups = allGroups
        .where((group) =>
            group.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    if (filteredGroups.isEmpty) {
      return StateWidget.noGroupsSearchResults();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      itemCount: filteredGroups.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppDimensions.spacingS),
      itemBuilder: (context, index) {
        final group = filteredGroups[index];
        return AnimatedListItem(
          index: index,
          child: GroupCard.build(context, group),
        );
      },
    );
  }
}
