/// Stub implementation of PwaInstallService for non-web platforms.
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/services/persistence_service.dart';

class PwaInstallService extends BaseService {
  /// Takes the web build's constructor arguments so the DI module compiles
  /// against either implementation.
  PwaInstallService({required PersistenceService Function() persistence});

  @override
  String get serviceName => 'PwaInstallService';

  bool get canPromptInstall => false;

  @override
  Future<void> onInitialize() async {}

  Future<void> promptInstall() async {}

  void dismissInstall() {}
}
