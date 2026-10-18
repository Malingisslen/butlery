/// Notification payload route strings. `sendNotification` refuses a push
/// whose `route` is not in `NOTIFICATION_ROUTES` in
/// `functions/src/shared/notification-payload.ts`, and
/// `notification_routes_contract_test.dart` fails when the two lists differ.
abstract final class NotificationRoutes {
  /// Recipe detail. `targetId` = recipeId.
  static const String recipe = '/recipe';

  /// Friend request inbox. `targetId` ignored (the inbox is the recipient).
  static const String friendRequest = '/friend_request';

  /// Recipe detail with comment thread auto-scrolled. `targetId` = recipeId.
  static const String commentThread = '/comment_thread';

  /// Active cooking session. `targetId` = sessionId (group id).
  static const String cookingSession = '/cooking_session';

  /// Menu voting screen. `targetId` ignored.
  static const String menuVoting = '/menu_voting';

  /// Re-engagement / "we miss you" deep links — always land on home.
  /// `targetId` ignored.
  static const String winback = '/winback';

  /// The caller's own report decision. `targetId` = reportId.
  static const String myReports = '/my_reports';

  /// A decision about the caller's own content. `targetId` = reportId.
  static const String myContentDecisions = '/my_content_decisions';

  /// A chat. `targetId` = conversationId.
  static const String conversation = '/conversation';

  /// The friends list. `targetId` ignored.
  static const String friends = '/friends';

  /// A group's page, where its pings are shown. `targetId` = groupId.
  static const String group = '/group';

  /// Home, for a push with no screen of its own. `targetId` ignored.
  static const String home = '/home';

  /// All known route strings. Used by tests and by the unknown-route guard.
  static const Set<String> all = <String>{
    recipe,
    friendRequest,
    commentThread,
    cookingSession,
    menuVoting,
    winback,
    myReports,
    myContentDecisions,
    conversation,
    friends,
    group,
    home,
  };
}

/// Where a tapped push lands: a [NotificationRoutes] value, plus the key in
/// the send's `additionalData` whose value is the destination's id.
class NotificationDestination {
  final String route;
  final String? targetIdKey;

  const NotificationDestination(this.route, {this.targetIdKey});
}
