/// Shared PermissionGateway fakes for widget tests (voice mics, notification
/// prompts). Shared home for new tests — the older per-file private copies
/// (review finding 2026-07-14: five near-identical fakes) migrate here
/// opportunistically when their files are next touched.
library;

import 'package:permission_handler/permission_handler.dart';

import 'package:butlery/core/utils/os_permission_helper.dart';

/// Gateway that reports a fixed [status] for both check and request.
class FakePermissionGateway implements PermissionGateway {
  FakePermissionGateway(this.status, {this.requestOutcome});

  final PermissionStatus status;
  final PermissionStatus? requestOutcome;
  bool settingsOpened = false;

  @override
  Future<PermissionStatus> checkStatus(Permission permission) async => status;

  @override
  Future<PermissionStatus> request(Permission permission) async =>
      requestOutcome ?? status;

  @override
  Future<bool> openSettings() async {
    settingsOpened = true;
    return true;
  }
}

class GrantedPermissionGateway extends FakePermissionGateway {
  GrantedPermissionGateway() : super(PermissionStatus.granted);
}

class PermanentlyDeniedPermissionGateway extends FakePermissionGateway {
  PermanentlyDeniedPermissionGateway()
    : super(PermissionStatus.permanentlyDenied);
}
