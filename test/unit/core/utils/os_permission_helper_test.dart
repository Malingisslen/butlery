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
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

class _FakeGateway implements PermissionGateway {
  _FakeGateway({
    required List<PermissionStatus> statusQueue,
    PermissionStatus requestOutcome = PermissionStatus.granted,
  }) : _statusQueue = List.of(statusQueue),
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
    testWidgets('already-granted returns true, no dialog, no request', (
      tester,
    ) async {
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

    testWidgets('first-denial → rationale accept → OS grant returns true', (
      tester,
    ) async {
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

    testWidgets('first-denial → rationale decline → false, no OS request', (
      tester,
    ) async {
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
      expect(
        gateway.requestCalls,
        0,
        reason: 'OS request must only fire on rationale accept',
      );
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
        expect(
          snackbarShown,
          0,
          reason: 'Plain denial (not permanent) must NOT trigger snackbar',
        );
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
        expect(
          gateway.requestCalls,
          0,
          reason: 'Do not burn the OS prompt when already permanent',
        );
      },
    );
  });

  // P6-U07 (flow 07): the typed outcome. flows-roles-budget.md:98-106;
  // produktregler.md:680-687.
  group('OsPermissionHelper.request — typed outcome', () {
    Future<OsPermissionOutcome> request(
      BuildContext context,
      PermissionGateway gateway, {
      RationaleDialogPresenter? rationale,
      SettingsSnackbarPresenter? snackbar,
      bool skipRationale = false,
      String? restrictedMessage,
    }) => OsPermissionHelper.request(
      context: context,
      permission: Permission.camera,
      rationaleTitle: 'title',
      rationaleBody: 'body',
      grantLabel: 'grant',
      permanentlyDeniedMessage: 'denied-msg',
      openSettingsLabel: 'open-settings',
      gateway: gateway,
      rationalePresenter: rationale,
      settingsSnackbarPresenter: snackbar,
      skipRationale: skipRationale,
      restrictedMessage: restrictedMessage,
    );

    test('outcomeOf maps every status to the five flow-07 states', () {
      expect(
        OsPermissionHelper.outcomeOf(PermissionStatus.granted),
        OsPermissionOutcome.granted,
      );
      expect(
        OsPermissionHelper.outcomeOf(PermissionStatus.provisional),
        OsPermissionOutcome.granted,
      );
      expect(
        OsPermissionHelper.outcomeOf(PermissionStatus.limited),
        OsPermissionOutcome.limited,
      );
      expect(
        OsPermissionHelper.outcomeOf(PermissionStatus.denied),
        OsPermissionOutcome.denied,
      );
      expect(
        OsPermissionHelper.outcomeOf(PermissionStatus.permanentlyDenied),
        OsPermissionOutcome.permanentlyDenied,
      );
      expect(
        OsPermissionHelper.outcomeOf(PermissionStatus.restricted),
        OsPermissionOutcome.restricted,
      );
      expect(OsPermissionOutcome.limited.isUsable, isTrue);
      expect(OsPermissionOutcome.restricted.isUsable, isFalse);
    });

    testWidgets('limited is its own usable state, asked for nothing', (
      tester,
    ) async {
      final gateway = _FakeGateway(
        statusQueue: const [PermissionStatus.limited],
      );
      final host = _HostedContext();
      await tester.pumpWidget(_buildHost(host));

      final outcome = await request(
        host.context!,
        gateway,
        rationale: (_, __, ___, ____) async => fail('no rationale'),
      );

      expect(outcome, OsPermissionOutcome.limited);
      expect(gateway.requestCalls, 0);
    });

    testWidgets(
      'restricted: an explanation without a button, and no OS request',
      (tester) async {
        final gateway = _FakeGateway(
          statusQueue: const [PermissionStatus.restricted],
        );
        final host = _HostedContext();
        await tester.pumpWidget(_buildHost(host));

        final outcome = await request(
          host.context!,
          gateway,
          rationale: (_, __, ___, ____) async => fail('no rationale'),
          snackbar: (_, __, ___, ____) => fail('no settings link'),
          restrictedMessage: 'Enheten har spärrat kameran.',
        );
        await tester.pump();

        expect(outcome, OsPermissionOutcome.restricted);
        expect(gateway.requestCalls, 0);
        expect(find.text('Enheten har spärrat kameran.'), findsOneWidget);
        expect(
          find.byType(SnackBarAction),
          findsNothing,
          reason: 'there is nothing the user can do (flows-roles-budget:104)',
        );
      },
    );

    testWidgets('the OS is asked only after Tillåt; "Inte nu" is denied', (
      tester,
    ) async {
      final gateway = _FakeGateway(
        statusQueue: const [PermissionStatus.denied],
      );
      final host = _HostedContext();
      await tester.pumpWidget(_buildHost(host));

      final outcome = await request(
        host.context!,
        gateway,
        rationale: (_, __, ___, ____) async => false,
      );

      expect(outcome, OsPermissionOutcome.denied);
      expect(gateway.requestCalls, 0);
    });

    testWidgets('"Fråga igen" skips our explanation and asks the OS', (
      tester,
    ) async {
      final gateway = _FakeGateway(
        statusQueue: const [PermissionStatus.denied],
        requestOutcome: PermissionStatus.granted,
      );
      final host = _HostedContext();
      await tester.pumpWidget(_buildHost(host));

      final outcome = await request(
        host.context!,
        gateway,
        skipRationale: true,
        rationale: (_, __, ___, ____) async =>
            fail('a second explanation is not shown (produktregler:683)'),
      );

      expect(outcome, OsPermissionOutcome.granted);
      expect(gateway.requestCalls, 1);
    });

    testWidgets('a second no after Tillåt is a silent denied', (tester) async {
      final gateway = _FakeGateway(
        statusQueue: const [PermissionStatus.denied],
        requestOutcome: PermissionStatus.denied,
      );
      final host = _HostedContext();
      await tester.pumpWidget(_buildHost(host));

      final outcome = await request(
        host.context!,
        gateway,
        rationale: (_, __, ___, ____) async => true,
        snackbar: (_, __, ___, ____) => fail('silent skip'),
      );

      expect(outcome, OsPermissionOutcome.denied);
    });

    testWidgets(
      'the drawn explanation: title, body, consequence, Inte nu and Tillåt',
      (tester) async {
        final host = _HostedContext();
        await tester.pumpWidget(_buildHost(host));

        final future = OsPermissionHelper.presentExplanation(
          host.context!,
          title: 'Fotografera receptet',
          body: 'Jag läser texten ur bilden.',
          consequence: 'Säger du nej går det att skriva själv.',
          grantLabel: 'Tillåt',
          declineLabel: 'Inte nu',
          icon: ButleryIcons.camera,
        );
        await tester.pumpAndSettle();

        expect(find.text('Fotografera receptet'), findsOneWidget);
        expect(find.text('Jag läser texten ur bilden.'), findsOneWidget);
        expect(
          find.text('Säger du nej går det att skriva själv.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(OutlinedButton, 'Inte nu'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Tillåt'), findsOneWidget);

        await tester.tap(find.text('Inte nu'));
        await tester.pumpAndSettle();
        expect(await future, isFalse);
      },
    );
  });
}
