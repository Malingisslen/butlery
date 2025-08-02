/// Group event bus for reactive UI updates.
import 'dart:async';

/// Group event types för att trigga UI-uppdateringar
enum GroupEventType {
  created,
  updated,
  deleted,
  memberAdded,
  memberRemoved,
}

/// Event bus för gruppändringar
class GroupEventBus {
  static final StreamController<GroupEventType> _controller =
      StreamController<GroupEventType>.broadcast();

  static Stream<GroupEventType> get events => _controller.stream;
  static Stream<GroupEventType> get stream => _controller.stream;

  static void groupCreated() => _controller.add(GroupEventType.created);
  static void groupUpdated() => _controller.add(GroupEventType.updated);
  static void groupDeleted() => _controller.add(GroupEventType.deleted);
  static void memberAdded() => _controller.add(GroupEventType.memberAdded);
  static void memberRemoved() => _controller.add(GroupEventType.memberRemoved);

  static void add(GroupEventType eventType) => _controller.add(eventType);

  static void dispose() => _controller.close();
}
