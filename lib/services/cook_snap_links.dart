// BUT-1508: the services a cook snap reaches for. Each is a lookup because most
// are user-scoped and replaced at sign-in.
library;

import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social/activity_feed_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';

class CookSnapLinks {
  const CookSnapLinks({
    required this.connectivity,
    required this.offline,
    required this.contentFilter,
    required this.imagePicker,
    required this.permissions,
    required this.imageUpload,
    required this.users,
    required this.activityFeed,
    required this.friends,
    required this.notifications,
  });

  final ConnectivityMonitoringService Function() connectivity;

  /// Null on platforms without the offline queue.
  final OfflineService? Function() offline;
  final ContentFilterService Function() contentFilter;
  final ImagePickerService Function() imagePicker;
  final PermissionService Function() permissions;
  final ImageUploadService Function() imageUpload;
  final OwnProfileReader Function() users;
  final ActivityFeedService Function() activityFeed;

  /// Null before the friends service exists: friend ids come from the
  /// repository instead.
  final UnifiedFriendsService? Function() friends;
  final NotificationService Function() notifications;
}
