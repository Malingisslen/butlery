// lib/services/offline/offline_service_links.dart
//
// BUT-1508: what the offline store and its upload queue reach for while they
// run. Each is a lookup, not an instance: the queue starts before the rest of
// the app has registered, and a user-scoped service is replaced at sign-in.
library;

import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/user_service.dart';

class OfflineServiceLinks {
  const OfflineServiceLinks({
    required this.storage,
    required this.users,
    required this.auth,
    required this.messaging,
    required this.comments,
    required this.cookSnaps,
    required this.cookSnapService,
    required this.tagging,
    required this.realtimeSync,
  });

  final StorageService Function() storage;
  final UserService Function() users;
  final AuthRepository Function() auth;
  final MessagingRepository Function() messaging;
  final CommentsRepository Function() comments;
  final CookSnapRepository Function() cookSnaps;
  final CookSnapService Function() cookSnapService;
  final TaggingService Function() tagging;

  /// Null when the service is not registered: a queued recipe conflict then
  /// has nowhere to be announced.
  final RealtimeSyncService? Function() realtimeSync;
}
