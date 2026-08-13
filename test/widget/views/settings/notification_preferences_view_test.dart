// BUT-1353 (SET-03): Widget tests for [NotificationPreferencesView].
//
// The view resolves [NotificationService] (loaded in initState) and, on the
// master toggle, [NotificationPermissionService] from the production
// ServiceLocator; `LayoutComponents.offlineIndicator()` resolves
// [OfflineService] in initState. We bridge all three through a DIContainer +
// ServiceLocator.initialize() (the same seam the real app uses) and assert the
// user-visible behaviour:
//   - loaded preferences render the master toggle reflecting the stored state;
//   - flipping the master toggle ON when the OS grant is DENIED leaves the
//     toggle OFF and never persists an enabled preference (the BUT-414 gate);
//   - flipping it ON when the grant is GRANTED persists the enabled preference.
//
// These are behavioural contracts (permission gating, persistence) — not theme
// or layout assertions — so they survive a design refactor.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_permission_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/views/settings/notification_preferences_view.dart';
import 'package:butlery/widgets/common/state_widget.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _FakePreferences extends Fake implements NotificationPreferences {}

class _FakeBuildContext extends Fake implements BuildContext {}

void main() {
  group('NotificationPreferencesView (BUT-1353 SET-03)', () {
    late MockNotificationService notificationService;
    late MockNotificationPermissionService permissionService;
    late MockOfflineService offlineService;
    final sv = AppLocalizationsSv();

    setUpAll(() {
      registerFallbackValue(_FakePreferences());
      registerFallbackValue(_FakeBuildContext());
    });

    setUp(() async {
      await GetIt.instance.reset();
      ServiceLocator.reset();

      notificationService = MockNotificationService();
      permissionService = MockNotificationPermissionService();
      offlineService = MockOfflineService();

      when(() => offlineService.isOnline).thenReturn(true);
      when(() => offlineService.addListener(any())).thenReturn(null);
      when(() => offlineService.removeListener(any())).thenReturn(null);

      final container = DIContainer();
      container.container.registerSingleton<NotificationService>(
        notificationService,
      );
      container.container.registerSingleton<NotificationPermissionService>(
        permissionService,
      );
      container.container.registerSingleton<OfflineService>(offlineService);
      ServiceLocator.initialize(container);
    });

    tearDown(() async {
      ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    Future<void> pumpView(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false, // the view supplies its own Scaffold.
          child: const NotificationPreferencesView(),
        ),
      );
      // Resolve the async getPreferences() future loaded in initState.
      await tester.pumpAndSettle();
    }

    testWidgets('renders the toggle sections once preferences load', (
      tester,
    ) async {
      // Proves: a successful load shows the preference form (master toggle +
      // category + quiet-hours), not a perpetual spinner.
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => NotificationPreferences.defaults());

      await pumpView(tester);

      expect(
        find.byType(StateWidget),
        findsNothing,
        reason: 'Loading/error state must clear once prefs resolve.',
      );
      expect(find.text(sv.notificationEnableTitle), findsOneWidget);
      expect(find.text(sv.notificationCategoriesTitle), findsOneWidget);
      expect(find.text(sv.notificationQuietHoursTitle), findsOneWidget);
    });

    testWidgets('no sound or vibration switch is offered (BUT-1783)', (
      tester,
    ) async {
      // Proves the BUT-1783 removal: neither switch may come back, because
      // nothing consults the stored value — sound and vibration belong to the
      // OS notification channel, so a switch here would silently do nothing.
      // Keyed on the three icons those two rows used (the sound row's icon was
      // state-dependent) rather than on their labels: the view no longer
      // renders either label. The two ARB keys are already deleted in the
      // working tree but held OUT of this commit — a parallel session owns
      // those files — so at this commit they still exist and are unreferenced.
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => NotificationPreferences.defaults());

      await pumpView(tester);

      // Control: findsNothing also passes on a view that rendered nothing at
      // all, so prove the form is on screen before asserting what is missing.
      expect(find.text(sv.notificationEnableTitle), findsOneWidget);
      // These two redden on a straight revert.
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
      expect(find.byIcon(Icons.vibration_outlined), findsNothing);
      // This one does NOT: with defaults() the sound row always drew the
      // volume-UP icon, so the off-state icon was unreachable even before the
      // removal. It is here to cover a revert that also flips the default.
      expect(find.byIcon(Icons.volume_off_outlined), findsNothing);
      // Icon-keying only catches an exact revert. The count catches ANY new
      // switch on this form: master + 7 categories + quiet-hours enable.
      expect(
        find.byType(SwitchListTile),
        findsNWidgets(9),
        reason:
            'BUT-1783: no new switch on this form. A legitimately added '
            'notification category also lands here — bump the count on '
            'purpose, do not delete the assertion.',
      );
    });

    testWidgets('master toggle reflects the stored enabled=false state', (
      tester,
    ) async {
      // Proves: the UI mirrors persisted state — if the user previously
      // disabled notifications the master switch shows OFF on next open.
      final disabled = _prefsWith(enabled: false);
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => disabled);

      await pumpView(tester);

      final masterSwitch = tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text(sv.notificationEnableTitle),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(masterSwitch.value, isFalse);
    });

    testWidgets('enabling master with OS permission DENIED keeps it off and never '
        'persists enabled=true', (tester) async {
      // Proves the BUT-414 runtime-permission gate: if the OS grant is refused,
      // the master toggle stays OFF and we must NOT save an enabled preference.
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => _prefsWith(enabled: false));
      when(
        () => permissionService.requestIfNeeded(any()),
      ).thenAnswer((_) async => false);

      await pumpView(tester);

      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();

      // Permission was asked, grant refused → no enabled persistence.
      verify(() => permissionService.requestIfNeeded(any())).called(1);
      verifyNever(() => notificationService.updatePreferences(any()));

      final masterSwitch = tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text(sv.notificationEnableTitle),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(
        masterSwitch.value,
        isFalse,
        reason: 'A denied OS grant must leave the master toggle OFF.',
      );
    });

    testWidgets(
      'enabling master with OS permission GRANTED persists enabled=true',
      (tester) async {
        // Proves the happy path of the same gate: a granted permission DOES
        // persist the enabled preference.
        when(
          () => notificationService.getPreferences(),
        ).thenAnswer((_) async => _prefsWith(enabled: false));
        when(
          () => permissionService.requestIfNeeded(any()),
        ).thenAnswer((_) async => true);
        when(
          () => notificationService.updatePreferences(any()),
        ).thenAnswer((_) async {});

        await pumpView(tester);

        await tester.tap(find.byType(SwitchListTile).first);
        await tester.pumpAndSettle();

        final saved =
            verify(
                  () => notificationService.updatePreferences(captureAny()),
                ).captured.single
                as NotificationPreferences;
        expect(
          saved.enabled,
          isTrue,
          reason: 'A granted OS permission must persist enabled=true.',
        );
      },
    );

    testWidgets('a failed preference load shows the retry error state', (
      tester,
    ) async {
      // Proves: a load failure surfaces the error/retry affordance instead of
      // hanging on the spinner — the user can recover.
      when(
        () => notificationService.getPreferences(),
      ).thenThrow(Exception('network down'));

      await pumpView(tester);

      expect(
        find.text(sv.commonRetry),
        findsOneWidget,
        reason: 'A failed load must offer a retry action.',
      );
    });
  });
}

NotificationPreferences _prefsWith({required bool enabled}) {
  final base = NotificationPreferences.defaults();
  return NotificationPreferences(
    enabled: enabled,
    categorySettings: base.categorySettings,
    typeSettings: base.typeSettings,
    allowBatching: base.allowBatching,
    digestFrequency: base.digestFrequency,
    quietHoursStart: base.quietHoursStart,
    quietHoursEnd: base.quietHoursEnd,
    lastUpdated: base.lastUpdated,
  );
}
