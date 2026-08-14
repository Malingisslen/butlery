// BUT-1353 (SET-03): Widget tests for [NotificationPreferencesView].
//
// The view resolves [NotificationService] (loaded in initState) and, on the
// master toggle, [NotificationPermissionService] from the production
// ServiceLocator; `LayoutComponents.offlineIndicator()` resolves
// [OfflineService] in initState. We bridge all three through a DIContainer +
// ServiceLocator.initialize() (the same seam the real app uses) and assert the
// user-visible behaviour. Among what the tests below cover:
//   - loaded preferences render the master toggle reflecting the stored state;
//   - flipping the master toggle ON when the OS grant is DENIED leaves the
//     toggle OFF and never persists an enabled preference (the BUT-414 gate);
//   - flipping it ON when the grant is GRANTED persists the enabled preference;
//   - no sound or vibration switch is offered (BUT-1783);
//   - a stored digest frequency the dropdown no longer offers still renders,
//     and picking a frequency shows and persists that value.
//
// The permission and persistence assertions are behavioural contracts, not
// theme or layout assertions, so they survive a design refactor. The two
// counting/structural guards — the switch count and the dropdown's item list —
// are deliberate exceptions: they are meant to redden when the form gains a
// control, and to be updated on purpose when that is legitimate.

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

    testWidgets('a stored digest frequency that was retired still renders', (
      tester,
    ) async {
      // The dropdown offered 'daily' between 920256e9e and 77ba0bd30 (fourteen
      // minutes on 2026-03-27); removing the option left any document holding
      // it carrying a value the list no longer contains, and DropdownButton
      // asserts exactly one item matches its value — so such a document would
      // have thrown on build in debug and rendered a blank control in release.
      //
      // Staged through fromMap on purpose: a constructor fixture cannot even
      // express 'daily' any more, so it would skip the parse under test.
      final stored = NotificationPreferences.fromMap('u', {
        'enabled': true,
        'categorySettings': const <String, dynamic>{},
        'typeSettings': const <String, dynamic>{},
        'allowBatching': true,
        'digestFrequency': 'daily',
        'lastUpdated': DateTime.utc(2026, 1, 1),
      });
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => stored);

      await pumpView(tester);

      // Cheap guard only. Since the field became an enum this can no longer
      // fail on the crash it names: `value` is non-nullable and the items are
      // generated one per enum value, so the SDK's exactly-one-match assert is
      // unreachable for every inhabitant of the type. That is the fix working,
      // not the test proving it. The two assertions below are the real ones.
      expect(tester.takeException(), isNull);
      expect(find.byType(StateWidget), findsNothing);

      // Assert on the widget, never with find.text: a dropdown builds EVERY
      // item into an IndexedStack, so both labels are in the tree whichever
      // one is selected.
      final dropdown = tester.widget<DropdownButton<DigestFrequency>>(
        find.byType(DropdownButton<DigestFrequency>),
      );
      expect(
        dropdown.value,
        DigestFrequency.weekly,
        reason:
            'A retired "daily" must read as weekly — that is what the backend '
            'already sends for it. Reading it as never would make the client '
            'disagree with the server, i.e. a silent unsubscribe.',
      );
      // What keeps the assert above unreachable is that the item list is
      // GENERATED from the enum. `toList()`, not `toSet()`, so a duplicate
      // reddens too. Analytically true today; this is the gate for the day
      // someone hand-writes the list again, which is how the bug happened.
      expect(
        dropdown.items!.map((item) => item.value).toList(),
        DigestFrequency.values,
      );
      // A read must not write (BUT-1782). Without this, a future "heal the
      // document on load" edit would pass: updatePreferences is unstubbed, so
      // mocktail throws inside _savePreferences' try, the catch swallows it,
      // and takeException stays null.
      verifyNever(() => notificationService.updatePreferences(any()));
    });

    testWidgets('picking a digest frequency shows and persists that value', (
      tester,
    ) async {
      // Two gaps this closes, both invisible to every other test:
      //
      // 1. The label mapping. Nothing else reads either label — swapping the
      //    two arms of the switch in _digestFrequencyItems compiles and leaves
      //    the whole suite green, while a weekly subscriber would read
      //    "Aldrig" on screen. That is the mirror of the bug being fixed.
      // 2. Persistence. Dropping the `digestFrequency:` argument from
      //    _copyPreferences also compiles and stays green; the choice would
      //    simply never be saved.
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => NotificationPreferences.defaults());
      when(
        () => notificationService.updatePreferences(any()),
      ).thenAnswer((_) async {});

      await pumpView(tester);

      await tester.tap(find.byType(DropdownButton<DigestFrequency>));
      await tester.pumpAndSettle();
      // The open menu renders a second copy of each label on top of the
      // IndexedStack one, so take the last.
      await tester.tap(find.text(sv.notificationDigestFrequencyWeekly).last);
      await tester.pumpAndSettle();

      final saved =
          verify(
                () => notificationService.updatePreferences(captureAny()),
              ).captured.single
              as NotificationPreferences;
      expect(
        saved.digestFrequency,
        DigestFrequency.weekly,
        reason:
            'Tapping the Veckovis row must persist weekly — this fails both '
            'if the labels are swapped and if the value is never passed on.',
      );
    });

    testWidgets('no sound or vibration switch is offered (BUT-1783)', (
      tester,
    ) async {
      // Proves the BUT-1783 removal: neither switch may come back, because
      // nothing consults the stored value — sound and vibration belong to the
      // OS notification channel, so a switch here would silently do nothing.
      // Keyed on the three icons those two rows used (the sound row's icon was
      // state-dependent) rather than on their labels: the view renders neither
      // label, so there is nothing for a label-based assertion to key on.
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
