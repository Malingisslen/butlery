/// Comprehensive group event system implementing reactive UI coordination for social group management features.
///
/// This event system serves as the centralized messaging infrastructure for all group-related state changes
/// throughout the Butlery application, providing reactive communication between group management services,
/// social views, and collaborative features. It ensures consistent UI updates across all group-related
/// components while maintaining optimal performance through broadcast stream architecture and comprehensive
/// event type coverage for Swedish cooking application's social collaboration requirements.
///
/// ## Core Architecture Features
/// 
/// **Reactive Event Broadcasting**
/// - Broadcast stream architecture for efficient multi-listener support
/// - Type-safe event enumeration for reliable event handling
/// - Comprehensive group lifecycle event coverage for complete state synchronization
/// - Performance-optimized stream management with proper resource cleanup
/// 
/// **Social Group Integration**
/// - Seamless integration with group creation, modification, and deletion workflows
/// - Member management event coordination for add/remove operations
/// - Real-time UI synchronization across all group-related views and components
/// - Event-driven architecture supporting complex social interaction patterns
/// 
/// **Swedish Localization Support**
/// - Event types aligned with Swedish cooking group terminology
/// - Comment documentation in Swedish for development team consistency
/// - Integration with Swedish social interaction patterns and user expectations
/// - Cultural design alignment for group management workflows
/// 
/// ## Event Types and Usage
/// 
/// **Group Lifecycle Events:**
/// ```dart
/// // Group creation workflow
/// await createGroup(groupData);
/// GroupEventBus.groupCreated(); // Triggers UI refresh across all group views
/// 
/// // Group modification workflow  
/// await updateGroup(groupId, changes);
/// GroupEventBus.groupUpdated(); // Updates group details in all active views
/// 
/// // Group deletion workflow
/// await deleteGroup(groupId);
/// GroupEventBus.groupDeleted(); // Removes group from UI and navigates appropriately
/// ```
/// 
/// **Member Management Events:**
/// ```dart
/// // Adding group members
/// await addMemberToGroup(groupId, userId);
/// GroupEventBus.memberAdded(); // Updates member lists and group statistics
/// 
/// // Removing group members
/// await removeMemberFromGroup(groupId, userId);
/// GroupEventBus.memberRemoved(); // Updates UI and handles permission changes
/// ```
/// 
/// **Event Listening Integration:**
/// ```dart
/// // In group-related ViewModels or Views
/// StreamSubscription? _eventSubscription;
/// 
/// void initState() {
///   _eventSubscription = GroupEventBus.events.listen((event) {
///     switch (event) {
///       case GroupEventType.created:
///         refreshGroupList();
///         break;
///       case GroupEventType.memberAdded:
///         updateMemberCount();
///         break;
///       // Handle other event types...
///     }
///   });
/// }
/// ```
/// 
/// ## Performance Characteristics
/// 
/// - **Stream Efficiency**: Broadcast streams allow multiple listeners without performance degradation
/// - **Memory Management**: Proper dispose patterns prevent memory leaks in long-running applications
/// - **Event Filtering**: Type-safe enumeration enables efficient event filtering and handling
/// - **Resource Cleanup**: Centralized disposal ensures proper resource management during app lifecycle
/// 
/// ## Integration Patterns
/// 
/// - **MVVM Architecture**: Events trigger ViewModel state updates for reactive UI synchronization
/// - **Service Layer**: Group services emit events after successful operations for consistent state management
/// - **View Layer**: Views listen to events for immediate UI updates without manual refresh logic
/// - **Collaborative Features**: Events coordinate updates across collaborative shopping and menu planning
/// 
/// This event system is essential for maintaining consistent group state across all social features
/// while providing reactive, performant UI updates that align with Swedish cooking application's
/// collaborative group management requirements and user experience expectations.

import 'dart:async';

/// Group event types för att trigga UI-uppdateringar (Group event types for triggering UI updates)
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
