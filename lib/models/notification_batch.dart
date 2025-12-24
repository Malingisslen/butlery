// lib/models/notification_batch.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Notification batch model for grouped notifications
class NotificationBatch {
  final String batchKey;
  final String userId;
  final List<NotificationTemplate> notifications;
  final DateTime createdAt;
  final DateTime scheduledFor;

  const NotificationBatch({
    required this.batchKey,
    required this.userId,
    required this.notifications,
    required this.createdAt,
    required this.scheduledFor,
  });

  /// Create from repository data map (removes Firebase dependency)
  factory NotificationBatch.fromMap(String id, Map<String, dynamic> data) {
    final notificationsList = (data['notifications'] as List<dynamic>?).orEmpty();
    final notifications = notificationsList
        .map((item) => NotificationTemplateSerializer.fromMap(item as Map<String, dynamic>))
        .toList();

    return NotificationBatch(
      batchKey: SerializationUtils.safeString(data, 'batchKey'),
      userId: SerializationUtils.safeString(data, 'userId'),
      notifications: notifications,
      createdAt: data['createdAt'] is DateTime
          ? data['createdAt'] as DateTime
          : AppTimestamp.fromFirestore(data['createdAt']).dateTime,
      scheduledFor: data['scheduledFor'] is DateTime
          ? data['scheduledFor'] as DateTime
          : AppTimestamp.fromFirestore(data['scheduledFor']).dateTime,
    );
  }

  /// Create from Firestore document
  factory NotificationBatch.fromFirestore(DocumentSnapshot doc) {
    return NotificationBatch.fromMap(doc.id, ((doc.data() as Map<String, dynamic>?).orEmpty()));
  }
}

/// Extension for NotificationTemplate serialization
extension NotificationTemplateExtension on NotificationTemplate {
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'data': data,
      'imageUrl': imageUrl,
      'actions': actions?.map((a) => {
        'id': a.id,
        'title': a.title,
        'data': a.data,
      }).toList(),
    };
  }
}

/// Serialization helpers for NotificationTemplate
class NotificationTemplateSerializer {
  /// Create NotificationTemplate from map
  static NotificationTemplate fromMap(Map<String, dynamic> map) {
    final actionsList = (map['actions'] as List<dynamic>?).orEmpty();
    final actions = actionsList.isNotEmpty
        ? actionsList.map((item) {
            final actionMap = item as Map<String, dynamic>;
            return NotificationAction(
              id: SerializationUtils.safeString(actionMap, 'id'),
              title: SerializationUtils.safeString(actionMap, 'title'),
              data: actionMap['data'],
            );
          }).toList()
        : null;

    return NotificationTemplate(
      title: SerializationUtils.safeString(map, 'title'),
      body: SerializationUtils.safeString(map, 'body'),
      data: SerializationUtils.safeMap(map, 'data'),
      imageUrl: SerializationUtils.safeNullableString(map, 'imageUrl'),
      actions: actions,
    );
  }
}
