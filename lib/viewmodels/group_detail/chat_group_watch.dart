// lib/viewmodels/group_detail/chat_group_watch.dart

import 'dart:async';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/messaging/chat_group.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/repositories/interfaces/chat_group_repository.dart';

/// Keeps a live view of the `chat_groups` document behind a group conversation.
///
/// Extracted from [GroupDetailViewModel] to keep it under the 500-line limit,
/// but it earns its own file for a second reason: the group document is the
/// SOLE authority on who may administer a group (BUT-1838). Keeping the
/// subscription, its teardown and the "which group am I watching" bookkeeping
/// in one small object makes it hard to leak — which the first version of this
/// code did, because `dispose()` cancelled its sibling subscription and not
/// this one.
class ChatGroupWatch {
  final ChatGroupRepository _repository;
  final void Function() _onChanged;

  StreamSubscription<ChatGroup?>? _subscription;
  String? _watchedGroupId;
  ChatGroup? _group;

  ChatGroupWatch({
    required ChatGroupRepository repository,
    required void Function() onChanged,
  }) : _repository = repository,
       _onChanged = onChanged;

  ChatGroup? get group => _group;

  /// True only when the group document says so. Never derived from the
  /// conversation's `metadata.creatorId`, which BUT-1838 retired as an
  /// authority, nor from the roster row's `role`, which is descriptive.
  bool isAdmin(String? userId) =>
      userId != null && (_group?.isAdmin(userId) ?? false);

  /// Points the watch at [conversation]'s group, or tears it down when there
  /// is none. A direct chat, or a group conversation predating BUT-1838, has no
  /// `groupId`; both leave [group] null rather than holding a stale one.
  void sync(Conversation? conversation) {
    final groupId = conversation?.groupId;
    if (groupId == null) {
      cancel();
      _group = null;
      return;
    }
    if (_watchedGroupId == groupId) return;

    _subscription?.cancel();
    _watchedGroupId = groupId;
    _subscription = _repository.watchGroup(groupId).listen(
      (group) {
        _group = group;
        _onChanged();
      },
      onError: (Object e) =>
          AppLogger.error('Failed to watch chat group $groupId', e),
    );
  }

  void cancel() {
    _subscription?.cancel();
    _subscription = null;
    _watchedGroupId = null;
  }
}
