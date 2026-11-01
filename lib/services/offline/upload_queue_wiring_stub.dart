// lib/services/offline/upload_queue_wiring_stub.dart
//
// Web has no upload queue.
library;

import 'package:butlery/core/storage/drift/app_database_stub_web.dart';
import 'package:butlery/services/offline/offline_service_links.dart';
import 'package:butlery/services/offline/offline_user_storage_stub.dart';

Future<void> sweepUnsentImages(AppDatabase database) async {}

Object? buildUploadQueueProcessor({
  required AppDatabase database,
  required OfflineUserStorage storage,
  required OfflineServiceLinks links,
}) => null;
