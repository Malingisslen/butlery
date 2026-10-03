/// BUT-2182: a view that shows the offline banner looks up [OfflineService]
/// through the ServiceLocator when it builds.
library;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/services/offline_service.dart';

/// An [OfflineService] that is always online.
class OnlineOfflineService extends ChangeNotifier implements OfflineService {
  @override
  bool get isOnline => true;

  @override
  bool get isInitialized => true;

  @override
  String? get currentUserId => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Registers an [OnlineOfflineService] unless the suite registered its own.
void ensureOfflineService() {
  final getIt = GetIt.instance;
  if (!getIt.isRegistered<OfflineService>()) {
    getIt.registerSingleton<OfflineService>(OnlineOfflineService());
  }
}
