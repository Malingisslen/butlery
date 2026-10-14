// lib/views/social/friends_list/friends_list_cards.dart

import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/styled/styled_card.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/core/constants/routes.dart';

/// Consolidated friends list card components
/// This file contains card components for the friends list view:
/// - GroupCard: Group card with navigation to group detail
/// **Consolidation**: Merged from 3 separate files (~151 LOC) for better maintainability

/// Group card with navigation to group detail.
class GroupCard {
  static Widget build(
    BuildContext context,
    FriendCategory group,
  ) {
    final description = group.description;
    return StyledCard(
      child: ButleryItemRow(
        onTap: () => _navigateToGroupDetail(context, group),
        leading: AvatarCircle(glyph: group.emoji ?? '👥'),
        title: group.name,
        titleMaxLines: 1,
        subtitle: description?.isNotEmpty == true
            ? '$description\n${group.summary}'
            : group.summary,
        showChevron: true,
      ),
    );
  }

  static void _navigateToGroupDetail(
    BuildContext context,
    FriendCategory group,
  ) {
    Navigator.pushNamed(
      context,
      Routes.groupDetail,
      arguments: group.id,
    );
  }
}
