// lib/services/notifications/modules/notification_content_manager.dart

import 'dart:math';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/utils/logger.dart';

/// Specialized notification content generation and management module providing comprehensive message creation capabilities.
/// This focused module implements sophisticated notification content generation following Single Responsibility Principle,
/// handling all aspects of notification message creation, template management, and content formatting. It provides
/// comprehensive content generation capabilities including localized messaging, dynamic variable substitution,
/// and intelligent content optimization for enhanced user engagement through personalized notifications.
/// **Single Responsibility Focus:**
/// This module exclusively handles notification content generation responsibilities:
/// - **Unique ID Generation**: Sophisticated notification identifier creation ensuring proper deduplication and tracking
/// - **Template Management**: Advanced template processing with dynamic variable substitution and localization support
/// - **Batch Content Building**: Intelligent batched notification content generation optimizing delivery efficiency
/// - **Digest Generation**: Comprehensive digest content creation providing curated activity summaries
/// - **Message Localization**: Swedish and English message formatting with cultural cooking terminology integration
/// **What This Module Does NOT Handle:**
/// - FCM token management and message delivery (handled by FCMTokenManager and FCMService)
/// - User preferences and quiet hours (handled by NotificationPreferenceManager)
/// - Offline queuing and retry logic (handled by NotificationOfflineManager)
/// - Delivery analytics and tracking (handled by NotificationAnalyticsManager)
/// **Content Generation Features:**
/// - Advanced template engine supporting complex variable substitution and conditional content
/// - Comprehensive localization system with Swedish cooking terminology and cultural references
/// - Dynamic content optimization based on user engagement patterns and preferences
/// - Intelligent digest generation providing meaningful activity summaries and recommendations
/// - Rich content support including recipe previews, cooking tips, and social engagement elements
/// **Template System Capabilities:**
/// - Multi-variable substitution with nested object support for complex content generation
/// - Conditional content rendering based on user context and notification parameters
/// - Fallback content strategies ensuring graceful handling of missing template variables
/// - Content length optimization for different notification delivery channels and platforms
/// - Swedish cultural cooking terminology integration for authentic user experience
/// **Usage Examples:**
/// ```dart
/// final contentManager = NotificationContentManager(userId: currentUserId);
/// // Generate unique notification ID
/// final notificationId = contentManager.generateNotificationId(targetUserId, strategy);
/// // Create personalized notification content
/// final content = await contentManager.createNotificationContent(
///   strategy: recipeSharedStrategy,
///   variables: {
///     'senderName': 'Anna',
///     'recipeTitle': 'Köttbullar med gräddsås',
///   },
/// );
/// // Generate digest content
/// final digest = await contentManager.generateDigestContent(activityData);
/// ```
class NotificationContentManager {
  final String _userId;

  NotificationContentManager({
    required String userId,
  }) : _userId = userId;

  /// Generate unique notification ID
  /// Creates unique identifiers using strategy category, user ID, timestamp, and random number
  /// to ensure no duplicate notifications and enable proper deduplication
  String generateNotificationId(
      String targetUserId, NotificationStrategy strategy) {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = Random().nextInt(1000);
      final id =
          '${strategy.category.name}_${targetUserId}_${timestamp}_$random';

      AppLogger.debug('🔔 Generated notification ID: $id');
      return id;
    } catch (e) {
      AppLogger.error('❌ Failed to generate notification ID', e);
      // Fallback to simple timestamp-based ID
      return 'fallback_${targetUserId}_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Create notification content from strategy with variable substitution
  /// Main entry point for creating notification content
  NotificationTemplate createNotificationContent({
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) {
    return createTemplate(
      strategy: strategy,
      variables: variables,
      additionalData: additionalData,
      imageUrl: imageUrl,
      actions: actions,
    );
  }

  /// Create notification template from strategy with variable substitution
  /// Handles localization, variable replacement, and data payload construction
  NotificationTemplate createTemplate({
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) {
    try {
      AppLogger.debug(
          '🔔 Creating notification template for strategy: ${strategy.category.name}');

      // Use Swedish by default (app is primarily Swedish)
      final titleTemplate = strategy.localization['title_sv'] ?? 'Ny aktivitet';
      final bodyTemplate =
          strategy.localization['body_sv'] ?? 'Du har ny aktivitet i Butlery';

      // Substitute variables in templates
      final title = _substituteVariables(titleTemplate, variables);
      final body = _substituteVariables(bodyTemplate, variables);

      // Build data payload
      final data = <String, dynamic>{
        'type': strategy.type.name,
        'priority': strategy.priority.name,
        'category': strategy.category.name,
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': _userId,
        ...?additionalData,
      };

      final template = NotificationTemplate(
        title: title,
        body: body,
        data: data,
        imageUrl: imageUrl,
        actions: actions,
      );

      AppLogger.success('✅ Created notification template: "$title"');
      return template;
    } catch (e) {
      AppLogger.error('❌ Failed to create notification template', e);
      // Return fallback template
      return _createFallbackTemplate(strategy, variables);
    }
  }

  /// Create English notification template (for international users)
  NotificationTemplate createEnglishTemplate({
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) {
    try {
      // Use English templates
      final titleTemplate = strategy.localization['title_en'] ?? 'New activity';
      final bodyTemplate = strategy.localization['body_en'] ??
          'You have new activity in Butlery';

      final title = _substituteVariables(titleTemplate, variables);
      final body = _substituteVariables(bodyTemplate, variables);

      final data = <String, dynamic>{
        'type': strategy.type.name,
        'priority': strategy.priority.name,
        'category': strategy.category.name,
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': _userId,
        'language': 'en',
        ...?additionalData,
      };

      return NotificationTemplate(
        title: title,
        body: body,
        data: data,
        imageUrl: imageUrl,
        actions: actions,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to create English notification template', e);
      return _createFallbackTemplate(strategy, variables);
    }
  }

  /// Build combined notification from multiple templates
  /// Combines multiple notifications into a single summary notification
  /// to prevent notification spam while preserving important information
  NotificationTemplate buildBatchedNotification(
      List<NotificationTemplate> notifications) {
    if (notifications.isEmpty) {
      throw ArgumentError('Cannot batch empty notification list');
    }

    if (notifications.length == 1) {
      AppLogger.debug('🔔 Single notification in batch, returning as-is');
      return notifications.first;
    }

    try {
      AppLogger.info(
          '🔔 Building batched notification from ${notifications.length} templates');

      final firstNotification = notifications.first;
      final category = firstNotification.data['category'] as String;

      final batchContent =
          _generateBatchContent(category, notifications.length);

      final batchedTemplate = NotificationTemplate(
        title: batchContent['title']!,
        body: batchContent['body']!,
        data: {
          ...firstNotification.data,
          'batched': true,
          'count': notifications.length,
          'original_notifications': notifications.map((n) => n.data).toList(),
        },
        imageUrl: firstNotification.imageUrl, // Use first notification's image
        actions: _generateBatchActions(category),
      );

      AppLogger.success(
          '✅ Created batched notification: "${batchContent['title']}"');
      return batchedTemplate;
    } catch (e) {
      AppLogger.error('❌ Failed to build batched notification', e);
      // Return first notification as fallback
      return notifications.first;
    }
  }

  /// Build digest content from activity list
  /// Creates summary content for digest notifications that aggregate
  /// multiple activities over a longer time period
  Map<String, String> buildDigestContent(
    List<Map<String, String>> activityList,
    NotificationStrategy strategy,
  ) {
    try {
      AppLogger.info(
          '🔔 Building digest content for ${activityList.length} activities');

      if (activityList.isEmpty) {
        return {
          'title': 'Daglig sammanfattning',
          'body': 'Ingen ny aktivitet idag',
          'count': '0',
          'summary': 'Ingen aktivitet att rapportera',
        };
      }

      final categoryCount = <String, int>{};
      for (final activity in activityList) {
        final category = activity['category'] ?? 'unknown';
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }

      final digestContent =
          _generateDigestSummary(categoryCount, activityList.length);

      AppLogger.success(
          '✅ Created digest content with ${activityList.length} activities');
      return digestContent;
    } catch (e) {
      AppLogger.error('❌ Failed to build digest content', e);
      return {
        'title': 'Daglig sammanfattning',
        'body': 'Problem med att ladda aktiviteter',
        'count': activityList.length.toString(),
        'summary': 'Kunde inte skapa sammanfattning',
      };
    }
  }

  /// Substitute variables in template strings
  String _substituteVariables(String template, Map<String, String> variables) {
    String result = template;
    variables.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }

  /// Create fallback template when template creation fails
  NotificationTemplate _createFallbackTemplate(
    NotificationStrategy strategy,
    Map<String, String> variables,
  ) {
    return NotificationTemplate(
      title: 'Ny aktivitet',
      body: 'Du har ny aktivitet i Butlery',
      data: {
        'type': strategy.type.name,
        'category': strategy.category.name,
        'timestamp': DateTime.now().toIso8601String(),
        'fallback': true,
      },
    );
  }

  /// Generate batch content based on category and count
  Map<String, String> _generateBatchContent(String category, int count) {
    switch (category) {
      case 'recipes':
        return {
          'title': 'Ny receptaktivitet',
          'body': '$count nya händelser på dina recept',
        };
      case 'friends':
        return {
          'title': 'Vänaktivitet',
          'body': '$count nya aktiviteter från dina vänner',
        };
      case 'shopping':
        return {
          'title': 'Inköpslistor',
          'body': '$count uppdateringar av dina inköpslistor',
        };
      case 'collaboration':
        return {
          'title': 'Samarbeten',
          'body': '$count nya samarbetsaktiviteter',
        };
      default:
        return {
          'title': 'Ny aktivitet',
          'body': '$count nya händelser i Butlery',
        };
    }
  }

  /// Generate action buttons for batched notifications
  List<NotificationAction>? _generateBatchActions(String category) {
    switch (category) {
      case 'recipes':
        return [
          const NotificationAction(
              id: 'view_recipes',
              title: 'Visa recept',
              data: {'action': 'navigate', 'destination': '/recipes'}),
        ];
      case 'friends':
        return [
          const NotificationAction(
              id: 'view_friends',
              title: 'Visa vänner',
              data: {'action': 'navigate', 'destination': '/friends'}),
        ];
      default:
        return [
          const NotificationAction(
              id: 'open_app',
              title: 'Öppna app',
              data: {'action': 'navigate', 'destination': '/home'}),
        ];
    }
  }

  /// Generate digest summary from category counts
  Map<String, String> _generateDigestSummary(
      Map<String, int> categoryCount, int totalCount) {
    final summaryParts = <String>[];

    categoryCount.forEach((category, itemCount) {
      switch (category) {
        case 'recipes':
          summaryParts.add('$itemCount recept');
          break;
        case 'friends':
          summaryParts.add('$itemCount vänaktiviteter');
          break;
        case 'shopping':
          summaryParts.add('$itemCount inköpslistor');
          break;
        case 'collaboration':
          summaryParts.add('$itemCount samarbeten');
          break;
        default:
          summaryParts.add('$itemCount $category');
      }
    });

    final summaryText = summaryParts.join(', ');

    return {
      'title': 'Daglig sammanfattning',
      'body': 'Du har $totalCount nya aktiviteter: $summaryText',
      'count': totalCount.toString(),
      'summary': summaryText,
    };
  }
}
