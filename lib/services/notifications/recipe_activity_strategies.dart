import 'package:butlery/services/notifications/notification_types.dart';

/// Recipe-activity notifications other than a new comment. Each template
/// names exactly the variables its callers send; the pairing is pinned by
/// `recipe_activity_templates_test.dart`.
class RecipeActivityStrategies {
  RecipeActivityStrategies._();

  static const commentReply = NotificationStrategy(
    type: NotificationType.batchable,
    priority: NotificationPriority.medium,
    category: NotificationCategory.recipes,
    batchWindow: Duration(minutes: 5),
    maxBatchSize: 5,
    localization: {
      'title_sv': 'Svar på din kommentar',
      'title_en': 'Reply to your comment',
      'body_sv':
          '{replierName} svarade på din kommentar på {recipeName}: '
          '{replyPreview}',
      'body_en':
          '{replierName} replied to your comment on {recipeName}: '
          '{replyPreview}',
    },
  );

  static const commentMention = NotificationStrategy(
    type: NotificationType.batchable,
    priority: NotificationPriority.medium,
    category: NotificationCategory.recipes,
    batchWindow: Duration(minutes: 5),
    maxBatchSize: 5,
    localization: {
      'title_sv': 'Du blev nämnd',
      'title_en': 'You were mentioned',
      'body_sv':
          '{mentionerName} nämnde dig i en kommentar på {recipeName}: '
          '{commentPreview}',
      'body_en':
          '{mentionerName} mentioned you in a comment on '
          '{recipeName}: {commentPreview}',
    },
  );

  static const commentLike = NotificationStrategy(
    type: NotificationType.batchable,
    priority: NotificationPriority.medium,
    category: NotificationCategory.recipes,
    batchWindow: Duration(minutes: 5),
    maxBatchSize: 5,
    localization: {
      'title_sv': 'Gillad kommentar',
      'title_en': 'Comment liked',
      'body_sv': '{likerName} gillade din kommentar på {recipeName}',
      'body_en': '{likerName} liked your comment on {recipeName}',
    },
  );

  /// Ratings, rating milestones and rating summaries. The sentence is built
  /// by the caller, so the template only frames it.
  static const ratingNotice = NotificationStrategy(
    type: NotificationType.immediate,
    priority: NotificationPriority.medium,
    category: NotificationCategory.recipes,
    localization: {
      'title_sv': 'Betyg på {recipeName}',
      'title_en': 'Rating for {recipeName}',
      'body_sv': '{message}',
      'body_en': '{message}',
    },
  );
}
