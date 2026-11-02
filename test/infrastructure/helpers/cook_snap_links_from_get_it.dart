import 'package:get_it/get_it.dart';

import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/cook_snap_links.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social/activity_feed_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';

/// Links that resolve from the services a test registered in GetIt. A service
/// the test did not register is null where production allows it, and throws
/// where production requires it.
CookSnapLinks cookSnapLinksFromGetIt() {
  final g = GetIt.instance;
  T? maybe<T extends Object>() => g.isRegistered<T>() ? g<T>() : null;
  return CookSnapLinks(
    connectivity: () => g<ConnectivityMonitoringService>(),
    offline: () => maybe<OfflineService>(),
    contentFilter: () => g<ContentFilterService>(),
    imagePicker: () => g<ImagePickerService>(),
    permissions: () => g<PermissionService>(),
    imageUpload: () => g<ImageUploadService>(),
    users: () => g<UserService>(),
    activityFeed: () => g<ActivityFeedService>(),
    friends: () => maybe<UnifiedFriendsService>(),
    notifications: () => g<NotificationService>(),
  );
}
