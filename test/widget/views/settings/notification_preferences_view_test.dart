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
//   - a stored digest frequency that was retired still reads as weekly, and
//     picking a frequency in the sheet shows and persists that value;
//   - every change saves at once with a snackbar, and the page has no Spara.
//
// The permission and persistence assertions are behavioural contracts, not
// theme or layout assertions, so they survive a design refactor. The switch
// count and the sheet's option list are deliberate structural guards: they
// are meant to redden when the form gains a control, and to be updated on
// purpose when that is legitimate.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/notifications/notification_permission_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/views/settings/notification_preferences_view.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/semantics_announcement.dart';

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
      // P6-U07: notifications are on in the phone unless a test says not.
      when(
        () => permissionService.blockedInSystem(),
      ).thenAnswer((_) async => false);
      when(
        () => permissionService.openSystemSettings(),
      ).thenAnswer((_) async => true);
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

    testWidgets('the settings are rows: no switch tiles, no Spara', (
      tester,
    ) async {
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => NotificationPreferences.defaults());

      await pumpView(tester);

      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(ButleryListSection), findsWidgets);
      expect(find.text(sv.commonSave), findsNothing);
    });

    // P7-A4: with the master toggle off the category rows are disabled, drawn
    // in text.disabled and never faded (tokens.json:41 "Opacitet är aldrig
    // ett tillstånd", :198; Butlery tillganglighetshandoff).
    for (final dark in [false, true]) {
      testWidgets('${dark ? 'dark' : 'light'}: master off draws the categories '
          'disabled, with no Opacity', (tester) async {
        final off = NotificationPreferences.defaults();
        when(() => notificationService.getPreferences()).thenAnswer(
          (_) async => NotificationPreferences(
            enabled: false,
            categorySettings: off.categorySettings,
            typeSettings: off.typeSettings,
            allowBatching: off.allowBatching,
            digestFrequency: off.digestFrequency,
            quietHoursStart: off.quietHoursStart,
            quietHoursEnd: off.quietHoursEnd,
            lastUpdated: off.lastUpdated,
          ),
        );
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Theme(
              data: theme,
              child: const NotificationPreferencesView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final title = find.text(sv.notificationCategoryRecipes);
        expect(title, findsOneWidget);
        expect(
          find.ancestor(of: title, matching: find.byType(Opacity)),
          findsNothing,
        );
        expect(
          tester.widget<Text>(title).style?.color,
          AppModeColors.textDisabled(theme.brightness),
        );
      });
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
      expect(find.text(sv.notifAllowRow), findsOneWidget);
      expect(
        find.text(sv.notifCategoriesSection.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(sv.notifDigestSection.toUpperCase()), findsOneWidget);
      expect(
        find.text(sv.notificationQuietHoursTitle.toUpperCase()),
        findsOneWidget,
      );
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

      expect(tester.takeException(), isNull);
      expect(find.byType(StateWidget), findsNothing);

      // The digest row reads the stored value, and a retired "daily" must
      // read as weekly — that is what the backend already sends for it.
      // Reading it as never would make the client disagree with the server,
      // i.e. a silent unsubscribe.
      final row = tester.widget<ButleryListRow>(
        find.widgetWithText(ButleryListRow, sv.notifDigestRow),
      );
      expect(row.value, sv.notificationDigestFrequencyWeekly);
      // A read must not write (BUT-1782): a future "heal the document on
      // load" edit would otherwise pass, because the catch in
      // _savePreferences swallows the unstubbed mock.
      verifyNever(() => notificationService.updatePreferences(any()));
    });

    testWidgets('picking a digest frequency shows and persists that value', (
      tester,
    ) async {
      // Two gaps this closes: the label mapping (swapping the two arms of
      // _digestLabel would put "Aldrig" on a weekly subscriber's screen) and
      // persistence (dropping `digestFrequency:` from _copyPreferences would
      // never save the choice).
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => NotificationPreferences.defaults());
      when(
        () => notificationService.updatePreferences(any()),
      ).thenAnswer((_) async {});

      await pumpView(tester);

      await tester.tap(find.text(sv.notifDigestRow));
      await tester.pumpAndSettle();
      // The sheet offers exactly the enum's values, in order.
      expect(find.text(sv.notificationDigestFrequencyTitle), findsOneWidget);
      final expected = [
        for (final f in DigestFrequency.values)
          switch (f) {
            DigestFrequency.never => sv.notificationDigestFrequencyNever,
            DigestFrequency.weekly => sv.notificationDigestFrequencyWeekly,
          },
      ];
      final sheetLabels =
          find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(Text),
              )
              .evaluate()
              .map((e) => e.widget as Text)
              .where((t) => expected.contains(t.data))
              .toList()
            ..sort(
              (a, b) => tester
                  .getTopLeft(find.byWidget(a))
                  .dy
                  .compareTo(tester.getTopLeft(find.byWidget(b)).dy),
            );
      expect(sheetLabels.map((t) => t.data).toList(), expected);
      await tester.tap(find.text(sv.notificationDigestFrequencyWeekly).last);
      await tester.pumpAndSettle();

      final saved =
          verify(
                () => notificationService.updatePreferences(captureAny()),
              ).captured.single
              as NotificationPreferences;
      expect(saved.digestFrequency, DigestFrequency.weekly);
      expect(
        tester
            .widget<ButleryListRow>(
              find.widgetWithText(ButleryListRow, sv.notifDigestRow),
            )
            .value,
        sv.notificationDigestFrequencyWeekly,
      );
      expect(find.text(sv.notificationSettingsSaved), findsOneWidget);
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
      expect(find.text(sv.notifAllowRow), findsOneWidget);
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
        find.byType(Switch),
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

      expect(_masterSwitch(tester).value, isFalse);
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

      await tester.tap(find.text(sv.notifAllowRow));
      await tester.pumpAndSettle();

      // Permission was asked, grant refused → no enabled persistence.
      verify(() => permissionService.requestIfNeeded(any())).called(1);
      verifyNever(() => notificationService.updatePreferences(any()));

      expect(
        _masterSwitch(tester).value,
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

        await tester.tap(find.text(sv.notifAllowRow));
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

    // P6-U07: notifications off in the phone — a row at the top leads to the
    // system settings and the switches stay visible but inactive
    // (produktregler.md:686,739; Skarmar v12 etapp 3 #behnotiser).
    testWidgets(
      'notifications off in the phone: top row, switches visible but inactive',
      (tester) async {
        when(
          () => notificationService.getPreferences(),
        ).thenAnswer((_) async => NotificationPreferences.defaults());
        when(
          () => permissionService.blockedInSystem(),
        ).thenAnswer((_) async => true);

        await pumpView(tester);

        expect(
          find.byKey(const ValueKey('notification-system-off-row')),
          findsOneWidget,
        );
        expect(find.text(sv.notifSystemOffRow), findsOneWidget);
        final switches = tester
            .widgetList<Switch>(find.byType(Switch))
            .toList();
        expect(switches, isNotEmpty, reason: 'the switches stay visible');
        for (final toggle in switches) {
          expect(toggle.onChanged, isNull, reason: 'and inactive');
        }

        final handle = tester.ensureSemantics();
        final openButton = find.byKey(
          const ValueKey('notification-system-off-open'),
        );
        expectActivatable(tester, openButton);
        handle.dispose();

        await tester.tap(openButton);
        await tester.pump();
        verify(() => permissionService.openSystemSettings()).called(1);
      },
    );

    testWidgets('each quiet-hours time row announces its caption and its time '
        'once, and can be activated', (tester) async {
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => NotificationPreferences.defaults());
      final handle = tester.ensureSemantics();

      await pumpView(tester);

      final from = find.bySemanticsLabel(RegExp(r'Från[\s\S]*22:00'));
      final to = find.bySemanticsLabel(RegExp(r'Till[\s\S]*08:00'));
      expect(from, findsOneWidget);
      expect(to, findsOneWidget);
      for (final row in [from, to]) {
        expectNothingAnnouncedTwice(tester, row);
        expectActivatable(tester, row);
      }
      expect(
        tester.getSemantics(from).id,
        isNot(tester.getSemantics(to).id),
        reason: 'two rows, two nodes',
      );
      handle.dispose();
    });

    testWidgets('a category toggle saves at once and shows the snackbar', (
      tester,
    ) async {
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => NotificationPreferences.defaults());
      when(
        () => notificationService.updatePreferences(any()),
      ).thenAnswer((_) async {});

      await pumpView(tester);
      await tester.tap(find.text(sv.notificationCategoryRecipes));
      await tester.pumpAndSettle();

      final saved =
          verify(
                () => notificationService.updatePreferences(captureAny()),
              ).captured.single
              as NotificationPreferences;
      expect(saved.categorySettings[NotificationCategory.recipes], isFalse);
      expect(find.text(sv.notificationSettingsSaved), findsOneWidget);
    });

    testWidgets('a failed save puts the toggle back and says so', (
      tester,
    ) async {
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => NotificationPreferences.defaults());
      when(
        () => notificationService.updatePreferences(any()),
      ).thenThrow(Exception('offline'));

      await pumpView(tester);
      await tester.tap(find.text(sv.notificationCategoryRecipes));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Switch>(
              find.descendant(
                of: find.widgetWithText(
                  ButleryListRow,
                  sv.notificationCategoryRecipes,
                ),
                matching: find.byType(Switch),
              ),
            )
            .value,
        isTrue,
      );
      expect(find.text(sv.notificationSettingsSaved), findsNothing);
    });

    testWidgets('quiet hours off hides the time rows and saves the clear', (
      tester,
    ) async {
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => NotificationPreferences.defaults());
      when(
        () => notificationService.updatePreferences(any()),
      ).thenAnswer((_) async {});

      await pumpView(tester);
      await tester.tap(find.text(sv.notificationQuietHoursEnable));
      await tester.pumpAndSettle();

      final saved =
          verify(
                () => notificationService.updatePreferences(captureAny()),
              ).captured.single
              as NotificationPreferences;
      expect(saved.quietHoursStart, isNull);
      expect(saved.quietHoursEnd, isNull);
      expect(find.text(sv.commonFrom), findsNothing);
    });

    testWidgets('a time row opens the time picker', (tester) async {
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => NotificationPreferences.defaults());

      await pumpView(tester);
      await tester.tap(find.text(sv.commonFrom));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
    });

    testWidgets('notifications on in the phone: no row, switches work', (
      tester,
    ) async {
      when(
        () => notificationService.getPreferences(),
      ).thenAnswer((_) async => NotificationPreferences.defaults());

      await pumpView(tester);

      expect(
        find.byKey(const ValueKey('notification-system-off-row')),
        findsNothing,
      );
      expect(_masterSwitch(tester).onChanged, isNotNull);
    });
  });
}

Switch _masterSwitch(WidgetTester tester) => tester.widget<Switch>(
  find.descendant(
    of: find.widgetWithText(
      ButleryListRow,
      AppLocalizationsSv().notifAllowRow,
    ),
    matching: find.byType(Switch),
  ),
);

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
