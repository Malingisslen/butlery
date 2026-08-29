/// The group's weekly menu (BUT-1971).
///
/// Direction A from the design round Malin picked on 2026-08-29: the whole week
/// as a dense row list, empty days visible as empty. Face row on top, week
/// arrows at the bottom.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/operations/realtime_group_menu/realtime_group_menu_module.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu/group_weekly_menu_viewmodel.dart';
import 'package:butlery/widgets/menu/group_weekly_menu_widget.dart';

class GroupWeeklyMenuView extends StatelessWidget {
  final String groupId;
  final String groupName;
  final String currentUserId;

  /// Invoked by the empty state's call to action. The screen does not know how
  /// to start a poll — that lives in the chat it was opened from.
  final VoidCallback? onStartPoll;

  const GroupWeeklyMenuView({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUserId,
    this.onStartPoll,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GroupWeeklyMenuViewModel(
        service: ServiceLocator.get<GroupWeeklyMenuPlanService>(),
        realtime: ServiceLocator.get<RealtimeGroupMenuModule>(),
        userService: ServiceLocator.get<UserService>(),
        groupId: groupId,
        currentUserId: currentUserId,
      )..loadWeek(DateTime.now()),
      child: GroupWeeklyMenuWidget(
        groupName: groupName,
        onStartPoll: onStartPoll,
      ),
    );
  }
}
