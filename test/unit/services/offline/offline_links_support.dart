// BUT-1508: links for tests of the offline queue. A service a test does not
// hand over fails loudly when the queue reaches for it.

import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/offline/offline_service_links.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/user_service.dart';

Never _unused(String name) => throw StateError('$name was not handed over');

OfflineServiceLinks testLinks({
  StorageService Function()? storage,
  UserService Function()? users,
  AuthRepository Function()? auth,
  MessagingRepository Function()? messaging,
  CommentsRepository Function()? comments,
  CookSnapRepository Function()? cookSnaps,
  CookSnapService Function()? cookSnapService,
  TaggingService Function()? tagging,
  RealtimeSyncService? Function()? realtimeSync,
}) => OfflineServiceLinks(
  storage: storage ?? () => _unused('storage'),
  users: users ?? () => _unused('users'),
  auth: auth ?? () => _unused('auth'),
  messaging: messaging ?? () => _unused('messaging'),
  comments: comments ?? () => _unused('comments'),
  cookSnaps: cookSnaps ?? () => _unused('cookSnaps'),
  cookSnapService: cookSnapService ?? () => _unused('cookSnapService'),
  tagging: tagging ?? () => _unused('tagging'),
  realtimeSync: realtimeSync ?? () => null,
);
