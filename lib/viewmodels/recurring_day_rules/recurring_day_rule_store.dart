// BUT-2490: where "Fasta dagar" reads and writes its rules. The personal list
// lives on the profile, a group's on `chat_groups`; the list and the editor
// do not know which.
library;

import 'package:flutter/foundation.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/messaging/chat_group.dart';
import 'package:butlery/repositories/interfaces/chat_group_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/viewmodels/group_detail/chat_group_watch.dart';

abstract interface class RecurringDayRuleStore implements Listenable {
  List<RecurringDayRule> get rules;

  /// Whether the signed-in user may change the rules. The store's own answer
  /// is a convenience for the screens; a write is gated server-side.
  bool get canEdit;

  /// Replaces the stored list. False when it did not save.
  Future<bool> write(List<RecurringDayRule> next);

  void dispose();
}

/// The signed-in user's own rules, on their profile.
class ProfileRuleStore implements RecurringDayRuleStore {
  ProfileRuleStore({OwnProfileReader? reader, OwnProfileEditor? editor})
    : _reader = reader ?? ServiceLocator.get<OwnProfileReader>(),
      _editor = editor ?? ServiceLocator.get<OwnProfileEditor>();

  final OwnProfileReader _reader;
  final OwnProfileEditor _editor;

  @override
  List<RecurringDayRule> get rules =>
      _reader.currentUserProfile?.recurringDayRules ?? const [];

  @override
  bool get canEdit => true;

  @override
  Future<bool> write(List<RecurringDayRule> next) =>
      _editor.setRecurringDayRules(next);

  @override
  void addListener(VoidCallback listener) => _reader.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _reader.removeListener(listener);

  @override
  void dispose() {}
}

/// A group's rules, read live from the group document and saved through the
/// `setGroupRecurringDayRules` callable.
class GroupRuleStore extends ChangeNotifier implements RecurringDayRuleStore {
  GroupRuleStore({
    required this.chatGroupId,
    this.initial,
    ChatGroupRepository? repository,
    String? Function()? currentUserId,
  }) : _repository = repository ?? ServiceLocator.get<ChatGroupRepository>(),
       _currentUserId =
           currentUserId ??
           (() => ServiceLocator.get<PermissionService>().currentUserId) {
    _watch = ChatGroupWatch(repository: _repository, onChanged: _onGroup)
      ..syncGroupId(chatGroupId);
  }

  final String chatGroupId;

  /// The group as the opening screen already holds it, so the first frame has
  /// rules before the watch has answered.
  final ChatGroup? initial;

  final ChatGroupRepository _repository;
  final String? Function() _currentUserId;
  late final ChatGroupWatch _watch;

  // What the callable just saved, shown until the document says the same.
  List<RecurringDayRule>? _saved;

  ChatGroup? get _group => _watch.group ?? initial;

  void _onGroup() {
    _saved = null;
    notifyListeners();
  }

  @override
  List<RecurringDayRule> get rules =>
      _saved ?? _group?.recurringDayRules ?? const [];

  /// The auth uid against the stored admin list; false until a group is known.
  @override
  bool get canEdit {
    final uid = _currentUserId();
    return uid != null && (_group?.isAdmin(uid) ?? false);
  }

  @override
  Future<bool> write(List<RecurringDayRule> next) async {
    await _repository.setRecurringDayRules(chatGroupId, next);
    _saved = next;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _watch.cancel();
    super.dispose();
  }
}

/// Which rule list a screen shows, and how to build its store.
class RecurringRuleScope {
  const RecurringRuleScope.personal()
    : chatGroupId = null,
      groupName = null,
      group = null;

  const RecurringRuleScope.group({
    required String this.chatGroupId,
    required String this.groupName,
    this.group,
  });

  final String? chatGroupId;
  final String? groupName;
  final ChatGroup? group;

  bool get isGroup => chatGroupId != null;

  RecurringDayRuleStore createStore() => isGroup
      ? GroupRuleStore(chatGroupId: chatGroupId!, initial: group)
      : ProfileRuleStore();
}
