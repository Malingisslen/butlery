// The group page's bar the way ButleryPage draws it, for tests that open the
// ⋯ sheet without the rest of the page.

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/views/social/group_detail/group_detail_app_bar.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

PreferredSizeWidget buildGroupDetailBar(
  BuildContext context, {
  required FriendCategory group,
  bool isResolvingLeave = false,
  required Function(String action) onMenuAction,
}) {
  return ButleryTopBar.undersida(
    title: group.name,
    backTo: context.l10n.socialFriendsAndGroups,
    actions: GroupDetailAppBar.actions(
      context,
      group: group,
      isResolvingLeave: isResolvingLeave,
      onMenuAction: onMenuAction,
    ),
  );
}
