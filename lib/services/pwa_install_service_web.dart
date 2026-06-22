/// Web implementation of PwaInstallService with JS interop.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/pwa/pwa_install_gate.dart';
import 'package:butlery/core/providers/application_provider.dart';

class PwaInstallService extends BaseService {
  @override
  String get serviceName => 'PwaInstallService';

  static const _sessionCountKey = 'butlery_pwa_session_count';
  static const _installDismissedKey = 'butlery_pwa_install_dismissed';

  final PwaInstallGate _gate = PwaInstallGate();

  bool get canPromptInstall =>
      _gate.canPrompt(hasDeferredPrompt: _hasDeferredPrompt);

  bool get _hasDeferredPrompt {
    try {
      final prompt = (web.window as JSObject)['deferredPwaPrompt'];
      return prompt.isA<JSObject>();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> onInitialize() async {
    try {
      final persistence = ServiceLocator.get<PersistenceService>();
      final alreadyDismissed = _gate.restore(
        sessionCount: await persistence.getInt(_sessionCountKey) ?? 0,
        dismissed: await persistence.getBool(_installDismissedKey) ?? false,
      );
      if (alreadyDismissed) return;
      final count = _gate.incrementSession();
      await persistence.setInt(_sessionCountKey, count);
    } catch (_) {}
  }

  Future<void> promptInstall() async {
    if (!canPromptInstall) return;
    try {
      final windowObj = web.window as JSObject;
      final prompt = windowObj['deferredPwaPrompt'];
      if (prompt.isA<JSObject>()) {
        (prompt as JSObject).callMethod('prompt'.toJS);
        windowObj.delete('deferredPwaPrompt'.toJS);
      }
    } catch (_) {}
  }

  void dismissInstall() {
    _gate.markDismissed();
    try {
      ServiceLocator.get<PersistenceService>()
          .setBool(_installDismissedKey, true);
    } catch (_) {}
  }
}
