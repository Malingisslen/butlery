/// Unit tests for NotificationPermissionService (BUT-414).
///
/// Verifies the Android 13+ POST_NOTIFICATIONS runtime flow:
///   - granted status short-circuits to true, no side effects
///   - first-time denied shows rationale; accepting issues the OS request
///   - second denial (from the OS prompt) silently skips
///   - permanently denied surfaces the settings snackbar
///   - pre-Tiramisu SDK (API < 33) short-circuits to true without any calls
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/notifications/notification_permission_service.dart';

// Gateway was renamed to `PermissionGateway` and relocated to
// `lib/core/utils/os_permission_helper.dart`, but the service file re-exports
// it, so the import above still resolves it.
class _FakeGateway implements PermissionGateway {
  _FakeGateway({
    required List<PermissionStatus> statusQueue,
    PermissionStatus requestOutcome = PermissionStatus.granted,
  })  : _statusQueue = List.of(statusQueue),
        _requestOutcome = requestOutcome;

  final List<PermissionStatus> _statusQueue;
  PermissionStatus _requestOutcome;

  int statusCalls = 0;
  int requestCalls = 0;
  int openSettingsCalls = 0;

  void queueRequestOutcome(PermissionStatus status) {
    _requestOutcome = status;
  }

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

class _StaticSdkProvider implements AndroidSdkVersionProvider {
  const _StaticSdkProvider(this.value);
  final int? value;

  @override
  Future<int?> sdkInt() async => value;
}

/// Minimal BuildContext host so requestIfNeeded has a real (mounted) context.
class _HostedContext {
  BuildContext? context;
}

Widget _buildHost(_HostedContext host, {bool withScaffold = true}) {
  return MaterialApp(
    locale: const Locale('sv'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(
      builder: (ctx) {
        host.context = ctx;
        return withScaffold
            ? const Scaffold(body: SizedBox.shrink())
            : const SizedBox.shrink();
      },
    ),
  );
}

void main() {
  group('NotificationPermissionService', () {
    testWidgets(
      'pre-Tiramisu Android (SDK < 33) returns true without plugin calls',
      (tester) async {
        final gateway = _FakeGateway(statusQueue: const []);
        final service = NotificationPermissionService(
          gateway: gateway,
          sdkVersionProvider: const _StaticSdkProvider(32),
          rationalePresenter: (_) async => fail('rationale must not run'),
          settingsSnackbarPresenter: (_, __) => fail('snackbar must not run'),
        );

        final host = _HostedContext();
        await tester.pumpWidget(_buildHost(host));

        final granted = await service.requestIfNeeded(host.context!);

        expect(granted, isTrue);
        expect(gateway.statusCalls, 0);
        expect(gateway.requestCalls, 0);
        expect(gateway.openSettingsCalls, 0);
      },
    );

    testWidgets(
      'already-granted status short-circuits to true',
      (tester) async {
        final gateway = _FakeGateway(
          statusQueue: const [PermissionStatus.granted],
        );
        final service = NotificationPermissionService(
          gateway: gateway,
          sdkVersionProvider: const _StaticSdkProvider(34),
          rationalePresenter: (_) async =>
              fail('rationale must not run on granted'),
          settingsSnackbarPresenter: (_, __) =>
              fail('snackbar must not run on granted'),
        );

        final host = _HostedContext();
        await tester.pumpWidget(_buildHost(host));

        final granted = await service.requestIfNeeded(host.context!);

        expect(granted, isTrue);
        expect(gateway.requestCalls, 0);
        expect(gateway.openSettingsCalls, 0);
      },
    );

    testWidgets(
      'first-time denied → rationale accepted → OS grant returns true',
      (tester) async {
        var rationaleShown = 0;
        final gateway = _FakeGateway(
          statusQueue: const [PermissionStatus.denied],
          requestOutcome: PermissionStatus.granted,
        );
        final service = NotificationPermissionService(
          gateway: gateway,
          sdkVersionProvider: const _StaticSdkProvider(33),
          rationalePresenter: (_) async {
            rationaleShown++;
            return true;
          },
          settingsSnackbarPresenter: (_, __) =>
              fail('snackbar must not run on happy path'),
        );

        final host = _HostedContext();
        await tester.pumpWidget(_buildHost(host));

        final granted = await service.requestIfNeeded(host.context!);

        expect(granted, isTrue);
        expect(rationaleShown, 1);
        expect(gateway.requestCalls, 1);
        expect(gateway.openSettingsCalls, 0);
      },
    );

    testWidgets(
      'first-time denied → rationale declined → no OS request, returns false',
      (tester) async {
        final gateway = _FakeGateway(
          statusQueue: const [PermissionStatus.denied],
        );
        final service = NotificationPermissionService(
          gateway: gateway,
          sdkVersionProvider: const _StaticSdkProvider(33),
          rationalePresenter: (_) async => false,
          settingsSnackbarPresenter: (_, __) =>
              fail('snackbar must not run when user dismisses rationale'),
        );

        final host = _HostedContext();
        await tester.pumpWidget(_buildHost(host));

        final granted = await service.requestIfNeeded(host.context!);

        expect(granted, isFalse);
        expect(gateway.requestCalls, 0,
            reason: 'OS request must only fire on rationale accept');
        expect(gateway.openSettingsCalls, 0);
      },
    );

    testWidgets(
      'second denial (OS says denied after rationale accept) → silent skip',
      (tester) async {
        final gateway = _FakeGateway(
          statusQueue: const [PermissionStatus.denied],
          requestOutcome: PermissionStatus.denied,
        );
        var snackbarShown = 0;
        final service = NotificationPermissionService(
          gateway: gateway,
          sdkVersionProvider: const _StaticSdkProvider(34),
          rationalePresenter: (_) async => true,
          settingsSnackbarPresenter: (_, __) => snackbarShown++,
        );

        final host = _HostedContext();
        await tester.pumpWidget(_buildHost(host));

        final granted = await service.requestIfNeeded(host.context!);

        expect(granted, isFalse);
        expect(gateway.requestCalls, 1);
        expect(snackbarShown, 0,
            reason: 'Second denial must NOT trigger settings snackbar — '
                'that is reserved for permanentlyDenied');
        expect(gateway.openSettingsCalls, 0);
      },
    );

    testWidgets(
      'OS returns permanentlyDenied after rationale → settings snackbar',
      (tester) async {
        final gateway = _FakeGateway(
          statusQueue: const [PermissionStatus.denied],
          requestOutcome: PermissionStatus.permanentlyDenied,
        );
        var snackbarShown = 0;
        VoidCallback? capturedOpenSettings;
        final service = NotificationPermissionService(
          gateway: gateway,
          sdkVersionProvider: const _StaticSdkProvider(33),
          rationalePresenter: (_) async => true,
          settingsSnackbarPresenter: (_, onOpenSettings) {
            snackbarShown++;
            capturedOpenSettings = onOpenSettings;
          },
        );

        final host = _HostedContext();
        await tester.pumpWidget(_buildHost(host));

        final granted = await service.requestIfNeeded(host.context!);

        expect(granted, isFalse);
        expect(snackbarShown, 1);
        expect(capturedOpenSettings, isNotNull);

        // Invoking the snackbar action routes to openAppSettings.
        capturedOpenSettings!();
        await tester.pump();
        expect(gateway.openSettingsCalls, 1);
      },
    );

    testWidgets(
      'pre-existing permanentlyDenied status → settings snackbar without '
      'rationale or OS request',
      (tester) async {
        final gateway = _FakeGateway(
          statusQueue: const [PermissionStatus.permanentlyDenied],
        );
        var snackbarShown = 0;
        final service = NotificationPermissionService(
          gateway: gateway,
          sdkVersionProvider: const _StaticSdkProvider(34),
          rationalePresenter: (_) async =>
              fail('rationale must not run when already permanentlyDenied'),
          settingsSnackbarPresenter: (_, __) => snackbarShown++,
        );

        final host = _HostedContext();
        await tester.pumpWidget(_buildHost(host));

        final granted = await service.requestIfNeeded(host.context!);

        expect(granted, isFalse);
        expect(snackbarShown, 1);
        expect(gateway.requestCalls, 0,
            reason: 'We do not burn the OS prompt when already permanent');
      },
    );

    testWidgets(
      'rationale dialog widget renders Swedish strings and returns user choice',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('sv'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: ctx,
                      builder: (_) => const NotificationRationaleDialog(),
                    );
                    // Echo the result into a global so the test can assert.
                    _lastDialogResult = result;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Swedish title + body are rendered (default locale falls back to sv).
        expect(find.text('Aktivera aviseringar?'), findsOneWidget);
        expect(find.text('Tillåt'), findsOneWidget);
        expect(find.text('Avbryt'), findsOneWidget);

        await tester.tap(find.text('Tillåt'));
        await tester.pumpAndSettle();

        expect(_lastDialogResult, isTrue);
      },
    );
  });
}

bool? _lastDialogResult;
