// lib/core/events/group_events.dart - KOMPLETT FIXAD VERSION

import 'dart:async';

/// Group event types för att trigga UI-uppdateringar
enum GroupEventType {
  created, // Grupp skapad
  updated, // Grupp uppdaterad
  deleted, // Grupp borttagen
  memberAdded, // Medlem tillagd
  memberRemoved, // Medlem borttagen
}

/// Event bus för gruppändringar
class GroupEventBus {
  static final StreamController<GroupEventType> _controller =
      StreamController<GroupEventType>.broadcast();

  /// Stream getters
  static Stream<GroupEventType> get events => _controller.stream;
  static Stream<GroupEventType> get stream => _controller.stream;

  // ===== EVENT TRIGGERS =====

  /// ✅ FIXAT: Alla metoder som används i dialogs
  static void groupCreated() => _controller.add(GroupEventType.created);
  static void groupUpdated() => _controller.add(GroupEventType.updated);
  static void groupDeleted() => _controller.add(GroupEventType.deleted);
  static void memberAdded() => _controller.add(GroupEventType.memberAdded);
  static void memberRemoved() => _controller.add(GroupEventType.memberRemoved);

  /// Generic add method för flexibilitet
  static void add(GroupEventType eventType) => _controller.add(eventType);

  /// ✅ LÄGG TILL: Dispose metod för cleanup
  static void dispose() => _controller.close();
}
