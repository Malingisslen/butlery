// BUT-2490: a group's fixed days as the group week uses them. The week only
// SHOWS a rule; nothing is written until someone picks a dish.
library;

import 'package:clock/clock.dart';

import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/messaging/chat_group.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/repositories/interfaces/chat_group_repository.dart';
import 'package:butlery/viewmodels/group_detail/chat_group_watch.dart';

class GroupWeekRules {
  /// Inactive (reads nothing) when [enabled] is false, when the conversation
  /// has no chat group (a direct chat, or a group from before BUT-1838), or
  /// when no [repository] is given.
  GroupWeekRules({
    required bool enabled,
    required String? chatGroupId,
    required ChatGroupRepository? repository,
    required void Function() onChanged,
    this.participantIds = const [],
  }) : _chatGroupId = chatGroupId,
       active = enabled && chatGroupId != null && repository != null {
    if (active) {
      _watch = ChatGroupWatch(repository: repository!, onChanged: onChanged);
    }
  }

  final bool active;
  final String? _chatGroupId;

  /// Everyone in the conversation, for seeding a week nobody has planned yet.
  final List<String> participantIds;
  ChatGroupWatch? _watch;

  /// Starts the one read of the group document. Safe to call again.
  void start() => _watch?.syncGroupId(_chatGroupId);

  ChatGroup? get group => _watch?.group;

  List<RecurringDayRule> get rules =>
      active ? (group?.recurringDayRules ?? const []) : const [];

  bool get hasActiveRules => rules.any((r) => r.isActive);

  /// The active rule for a place, or null. Övrigt takes no rule.
  RecurringDayRule? ruleFor(DayOfWeek day, MealSlot slot) {
    if (slot.isMulti) return null;
    for (final rule in rules) {
      if (rule.isActive && rule.day == day && rule.meal == slot) return rule;
    }
    return null;
  }

  Set<DayOfWeek> get ruleDays => {
    for (final rule in rules)
      if (rule.isActive) rule.day,
  };

  /// By the group document, never the week's roster.
  bool isGroupAdmin(String userId) => group?.isAdmin(userId) ?? false;

  /// The roster the poll close gives a week it builds: every conversation
  /// participant edits, the one building it administers.
  List<GroupMenuParticipant> seedRoster(String builderId) {
    final now = clock.now();
    return [
      for (final id in {...participantIds, builderId})
        GroupMenuParticipant(
          userId: id,
          permission: id == builderId
              ? SharedListPermission.admin
              : SharedListPermission.edit,
          addedAt: now,
        ),
    ];
  }

  void dispose() => _watch?.cancel();
}
