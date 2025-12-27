/// Group event bus for reactive UI updates.
import 'dart:async';

/// Group event types for triggering UI updates.
enum GroupEventType {
  created,
  updated,
  deleted,
  memberAdded,
  memberRemoved,
}

/// Event bus for group changes.
/// Uses lazy initialization to support hot restart and proper lifecycle management.
class GroupEventBus {
  static StreamController<GroupEventType>? _controller;

  static StreamController<GroupEventType> get _safeController {
    _controller ??= StreamController<GroupEventType>.broadcast();
    return _controller!;
  }

  static Stream<GroupEventType> get events => _safeController.stream;
  static Stream<GroupEventType> get stream => _safeController.stream;

  static void groupCreated() => _safeController.add(GroupEventType.created);
  static void groupUpdated() => _safeController.add(GroupEventType.updated);
  static void groupDeleted() => _safeController.add(GroupEventType.deleted);
  static void memberAdded() => _safeController.add(GroupEventType.memberAdded);
  static void memberRemoved() =>
      _safeController.add(GroupEventType.memberRemoved);

  static void add(GroupEventType eventType) => _safeController.add(eventType);

  /// Dispose the event bus. Safe to call multiple times.
  /// After disposal, the bus will be recreated on next use.
  static void dispose() {
    _controller?.close();
    _controller = null;
  }
}
