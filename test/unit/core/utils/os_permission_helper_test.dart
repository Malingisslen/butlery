/// Unit tests for OsPermissionHelper — covers each decision branch of the
/// OS-permission UX contract:
///   - already-granted short-circuit
///   - first-denial → rationale accept → OS grant (happy path)
///   - first-denial → rationale decline → no OS request
///   - first-denial → rationale accept → OS denies (plain) — no snackbar
///   - first-denial → rationale accept → OS permanently denies → snackbar
///   - pre-existing permanentlyDenied → snackbar, no rationale, no OS request
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:butlery/core/utils/os_permission_helper.dart';

class _FakeGateway implements PermissionGateway {
  _FakeGateway({
    required List<PermissionStatus> statusQueue,
    PermissionStatus requestOutcome = PermissionStatus.granted,
  })  : _statusQueue = List.of(statusQueue),
        _requestOutcome = requestOutcome;

  final List<PermissionStatus> _statusQueue;
  final PermissionStatus _requestOutcome;

  int statusCalls = 0;
  int requestCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<PermissionStatus> checkStatus(Permission permission) async {
    statusCalls++;
    return _statusQueue.isNotEmpty
        ? _statusQueue.removeAt(0)
        : PermissionStatus.denied;
  }

  @override
  Future<PermissionStatus> request(Permission permission) async {
    requestCalls++;
    return _requestOutcome;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return true;
  }
}

class _HostedContext {
  BuildContext? context;
}

Widget _buildHost(_HostedContext host) {
  return MaterialApp(
    home: Builder(
      builder: (ctx) {
        host.context = ctx;
        return const Scaffold(body: SizedBox.shrink());
      },
    ),
  );
}

Future<bool> _invoke({
  required BuildContext context,
  required PermissionGateway gateway,
  RationaleDialogPresenter? rationalePresenter,
  SettingsSnackbarPresenter? settingsSnackbarPresenter,
}) {
  return OsPermissionHelper.requestWithRationale(
    context: context,
    permission: Permission.notification,
    rationaleTitle: 'title',
    rationaleBody: 'body',
    grantLabel: 'grant',
    permanentlyDeniedMessage: 'denied-msg',
    openSettingsLabel: 'open-settings',
    gateway: gateway,
    rationalePresenter: rationalePresenter,
    settingsSnackbarPresenter: settingsSnackbarPresenter,
  );
}

void main() {
  group('OsPermissionHelper.requestWithRationale', () {
    testWidgets('already-granted returns true, no dialog, no request',
        (tester) async {
      final gateway = _FakeGateway(
        statusQueue: const [PermissionStatus.granted],
      );
      final host = _HostedContext();
      await tester.pumpWidget(_buildHost(host));

      final granted = await _invoke(
        context: host.context!,
        gateway: gateway,
        rationalePresenter: (_, __, ___, ____) async =>
            fail('rationale must not show on already-granted'),
        settingsSnackbarPresenter: (_, __, ___, ____) =>
            fail('snackbar must not show on already-granted'),
      );

      expect(granted, isTrue);
      expect(gateway.statusCalls, 1);
      expect(gateway.requestCalls, 0);
      expect(gateway.openSettingsCalls, 0);
    });

    testWidgets('first-denial → rationale accept → OS grant returns true',
        (tester) async {
      var rationaleShown = 0;
      final gateway = _FakeGateway(
        statusQueue: const [PermissionStatus.denied],
        requestOutcome: PermissionStatus.granted,
      );
      final host = _HostedContext();
      await tester.pumpWidget(_buildHost(host));

      final granted = await _invoke(
        context: host.context!,
        gateway: gateway,
        rationalePresenter: (_, __, ___, ____) async {
          rationaleShown++;
          return true;
        },
        settingsSnackbarPresenter: (_, __, ___, ____) =>
            fail('snackbar must not show on happy path'),
      );

      expect(granted, isTrue);
      expect(rationaleShown, 1);
      expect(gateway.requestCalls, 1);
      expect(gateway.openSettingsCalls, 0);
    });

    testWidgets('first-denial → rationale decline → false, no OS request',
        (tester) async {
      final gateway = _FakeGateway(
        statusQueue: const [PermissionStatus.denied],
      );
      final host = _HostedContext();
      await tester.pumpWidget(_buildHost(host));

      final granted = await _invoke(
        context: host.context!,
        gateway: gateway,
        rationalePresenter: (_, __, ___, ____) async => false,
        settingsSnackbarPresenter: (_, __, ___, ____) =>
            fail('snackbar must not show when user declines rationale'),
      );

      expect(granted, isFalse);
      expect(gateway.requestCalls, 0,
          reason: 'OS request must only fire on rationale accept');
      expect(gateway.openSettingsCalls, 0);
    });

    testWidgets(
      'first-denial → rationale accept → OS denies (plain) → false, no snackbar',
      (tester) async {
        var snackbarShown = 0;
        final gateway = _FakeGateway(
          statusQueue: const [PermissionStatus.denied],
          requestOutcome: PermissionStatus.denied,
        );
        final host = _HostedContext();
        await tester.pumpWidget(_buildHost(host));

        final granted = await _invoke(
          context: host.context!,
          gateway: gateway,
          rationalePresenter: (_, __, ___, ____) async => true,
          settingsSnackbarPresenter: (_, __, ___, ____) => snackbarShown++,
        );

        expect(granted, isFalse);
        expect(gateway.requestCalls, 1);
        expect(snackbarShown, 0,
            reason: 'Plain denial (not permanent) must NOT trigger snackbar');
      },
    );

    testWidgets(
      'first-denial → rationale accept → permanentlyDenied → snackbar shown, '
      'openSettings callable',
      (tester) async {
        var snackbarShown = 0;
        VoidCallback? capturedOpenSettings;
        final gateway = _FakeGateway(
          statusQueue: const [PermissionStatus.denied],
          requestOutcome: PermissionStatus.permanentlyDenied,
        );
        final host = _HostedContext();
        await tester.pumpWidget(_buildHost(host));

        final granted = await _invoke(
          context: host.context!,
          gateway: gateway,
          rationalePresenter: (_, __, ___, ____) async => true,
          settingsSnackbarPresenter: (_, __, ___, onOpenSettings) {
            snackbarShown++;
            capturedOpenSettings = onOpenSettings;
          },
        );

        expect(granted, isFalse);
        expect(snackbarShown, 1);
        expect(capturedOpenSettings, isNotNull);

        // Tapping the snackbar action routes to gateway.openSettings().
        capturedOpenSettings!();
        await tester.pump();
        expect(gateway.openSettingsCalls, 1);
      },
    );

    testWidgets(
      'pre-existing permanentlyDenied → snackbar, no rationale, no OS request',
      (tester) async {
        var snackbarShown = 0;
        final gateway = _FakeGateway(
          statusQueue: const [PermissionStatus.permanentlyDenied],
        );
        final host = _HostedContext();
        await tester.pumpWidget(_buildHost(host));

        final granted = await _invoke(
          context: host.context!,
          gateway: gateway,
          rationalePresenter: (_, __, ___, ____) =>
              fail('rationale must not run when already permanentlyDenied'),
          settingsSnackbarPresenter: (_, __, ___, ____) => snackbarShown++,
        );

        expect(granted, isFalse);
        expect(snackbarShown, 1);
        expect(gateway.requestCalls, 0,
            reason: 'Do not burn the OS prompt when already permanent');
      },
    );
  });
}
