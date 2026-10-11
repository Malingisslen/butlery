// lib/views/social/group_detail/group_detail_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/social/groups/group_household_join_tile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_mode_colors.dart';

/// Avatar, name and meta line of a group, with the rows that describe it.
class GroupDetailHeader {
  static Widget build(
    BuildContext context,
    FriendCategory group, {
    bool isAdmin = false,
    bool isHousehold = false,
    ValueChanged<bool>? onToggleHousehold,
    int? memberCount,
  }) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final count = memberCount ?? group.friendCount;
    final description = group.description?.isNotEmpty == true
        ? group.description!
        : l10n.groupNoDescription;
    final emoji = group.emoji;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SocialAvatarComponents.avatar(
              announceName: false,
              size: ImageSize.large,
              displayName: group.name,
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      group.name,
                      style: AppTextStyles.sectionHeader.copyWith(
                        color: AppModeColors.textBody(cs.brightness),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  Text(
                    isAdmin
                        ? l10n.groupMetaMembersAdmin(count)
                        : l10n.groupMetaMembers(count),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          emoji != null && emoji.isNotEmpty
              ? '$emoji $description'
              : description,
          style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant),
        ),
        ButleryListSection(
          rows: [
            ButleryListRow.info(
              label: l10n.groupCreatedInfoRow,
              value: MaterialLocalizations.of(
                context,
              ).formatShortDate(group.createdAt),
            ),
            if (isAdmin && onToggleHousehold != null)
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
