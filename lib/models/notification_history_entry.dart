import 'package:butlery/core/utils/serialization_utils.dart';

/// A single notification history entry for the in-app notification inbox.
class NotificationHistoryEntry {
  final String id;
  final String notificationId;
  final String category;
  final String type;
  final Map<String, dynamic> data;
  final DateTime sentAt;
  final bool delivered;
  final bool opened;
  final DateTime? deliveredAt;
  final DateTime? openedAt;

  const NotificationHistoryEntry({
    required this.id,
    required this.notificationId,
    required this.category,
    required this.type,
    required this.data,
    required this.sentAt,
    this.delivered = false,
    this.opened = false,
    this.deliveredAt,
    this.openedAt,
  });

  factory NotificationHistoryEntry.fromFirestore(Map<String, dynamic> map) {
    return NotificationHistoryEntry(
      id: SerializationUtils.safeString(map, 'id'),
      notificationId: SerializationUtils.safeString(map, 'notificationId'),
      category: SerializationUtils.safeString(map, 'category'),
      type: SerializationUtils.safeString(map, 'type'),
      data: (map['data'] as Map<String, dynamic>?) ?? const {},
      sentAt: SerializationUtils.parseRequiredDateTimeValue(map['sentAt']),
      delivered: SerializationUtils.safeBool(map, 'delivered'),
      opened: SerializationUtils.safeBool(map, 'opened'),
      deliveredAt: SerializationUtils.parseDateTimeValue(map['deliveredAt']),
      openedAt: SerializationUtils.parseDateTimeValue(map['openedAt']),
    );
  }

  /// Display title derived from notification data.
  String get displayTitle => data['title'] as String? ?? category;

  /// Display body derived from notification data.
  String get displayBody => data['body'] as String? ?? '';

  NotificationHistoryEntry copyWith({
    bool? opened,
    DateTime? openedAt,
  }) {
    return NotificationHistoryEntry(
      id: id,
      notificationId: notificationId,
      category: category,
      type: type,
      data: data,
      sentAt: sentAt,
      delivered: delivered,
      opened: opened ?? this.opened,
      deliveredAt: deliveredAt,
      openedAt: openedAt ?? this.openedAt,
    );
  }
}
