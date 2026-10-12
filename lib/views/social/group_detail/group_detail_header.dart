// lib/views/social/group_detail/group_detail_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/social/groups/group_household_join_tile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// What describes the group under its name in the bar: the description when
/// it has one, the household switch for an admin, and the join tile for a
/// member.
class GroupDetailHeader {
  static Widget build(
    BuildContext context,
    FriendCategory group, {
    bool isAdmin = false,
    bool isHousehold = false,
    ValueChanged<bool>? onToggleHousehold,
  }) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final description = group.description;
    final emoji = group.emoji;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (description != null && description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.space8),
            child: Text(
              emoji != null && emoji.isNotEmpty
                  ? '$emoji $description'
                  : description,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        if (isAdmin && onToggleHousehold != null)
          ButleryListSection(
            rows: [
              ButleryListRow.toggle(
                label: l10n.householdToggle,
                subtitle: l10n.householdToggleDescription,
                checked: isHousehold,
                onChanged: onToggleHousehold,
              ),
            ],
          ),
        // BUT-2267: a non-owner member joins the household. Hides itself
        // for everyone it does not apply to.
        GroupHouseholdJoinTile(group: group),
      ],
    );
  }
}
