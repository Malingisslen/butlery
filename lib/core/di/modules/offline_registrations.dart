/// BUT-1508: what the offline store and the "Väntar på synk" view reach for,
/// handed to them by `ContentModule` as lookups on the container the user
/// signed in under.
library;

import 'package:get_it/get_it.dart';

import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/offline/offline_service_links.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/user_service.dart';

abstract final class OfflineRegistrations {
  static OfflineServiceLinks links(GetIt container) => OfflineServiceLinks(
    storage: () => container<StorageService>(),
    users: () => container<UserService>(),
    auth: () => container<AuthRepository>(),
    messaging: () => container<MessagingRepository>(),
    comments: () => container<CommentsRepository>(),
    cookSnaps: () => container<CookSnapRepository>(),
    cookSnapService: () => container<CookSnapService>(),
    tagging: () => container<TaggingService>(),
    realtimeSync: () => container.isRegistered<RealtimeSyncService>()
        ? container<RealtimeSyncService>()
        : null,
  );

  static void wireSyncQueueSource(GetIt container) {
    SyncQueueSource.appSource = OfflineSyncQueueSource(
      offlineService: () => container.isRegistered<OfflineService>()
          ? container<OfflineService>()
          : null,
      authRepository: () => container.isRegistered<AuthRepository>()
          ? container<AuthRepository>()
          : null,
      messaging: () => container<MessagingRepository>(),
    );
  }
}
