/// Stub implementation of PwaInstallService for non-web platforms.
import 'package:butlery/core/base/base_service.dart';

class PwaInstallService extends BaseService {
  @override
  String get serviceName => 'PwaInstallService';

  bool get canPromptInstall => false;

  @override
  Future<void> onInitialize() async {}

  Future<void> promptInstall() async {}

  void dismissInstall() {}
}
