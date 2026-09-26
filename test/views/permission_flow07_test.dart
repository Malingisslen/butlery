/// P6-U07 · Flow 07, permissions (flows-roles-budget.md:98-106;
/// produktregler.md:423, 680-687, 738-740).
///
/// - Photo import explains each permission answer inline: a no offers
///   "Fråga igen", a permanent no "Öppna inställningar", a device block no
///   button to fix it, and limited access "Välj fler bilder". No camera leads
///   to the library; no library leads to writing the recipe yourself.
/// - The photo-import view model asks through the resolver before any pick,
///   and "Fråga igen" skips our explanation.
/// - A timer without notification permission is announced before it starts,
///   from the timer sheet as well as from the voice command.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/notifications/notification_permission_service.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/views/photo_import_view.dart';
import 'package:butlery/widgets/cooking/step_timer_widget.dart';

import '../infrastructure/mocks/production_mocks.dart';

class _Gateway implements PermissionGateway {
  _Gateway(this.status);

  PermissionStatus status;
  int settingsCalls = 0;

  @override
  Future<PermissionStatus> checkStatus(Permission permission) async => status;

  PermissionStatus? requestAnswer;
  int requests = 0;

  @override
  Future<PermissionStatus> request(Permission permission) async {
    requests++;
    return requestAnswer ?? status;
  }

  @override
  Future<bool> openSettings() async {
    settingsCalls++;
    return true;
  }
}

class _NonAndroid implements AndroidSdkVersionProvider {
  @override
  Future<int?> sdkInt() async => null;
}

class _Sdk implements AndroidSdkVersionProvider {
  _Sdk(this.value);
  final int value;

  @override
  Future<int?> sdkInt() async => value;
}

/// Pumps an empty screen and hands back a context under it.
Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return ctx;
}

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.lightTheme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sv = AppLocalizationsSv();

  group('PhotoPermissionNoticeCard', () {
    late List<String> taps;

    Widget card(ImageSource source, OsPermissionOutcome outcome) =>
        PhotoPermissionNoticeCard(
          notice: PhotoPermissionNotice(source: source, outcome: outcome),
          onAskAgain: () => taps.add('ask'),
          onOpenSettings: () => taps.add('settings'),
          onChooseFromGallery: () => taps.add('gallery'),
          onWriteYourself: () => taps.add('write'),
        );

    setUp(() => taps = []);

    testWidgets('camera no: Fråga igen, and the library as the way on', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(card(ImageSource.camera, OsPermissionOutcome.denied)),
      );

      expect(find.text(sv.permCameraDenied), findsOneWidget);
      expect(find.text(sv.permAskAgain), findsOneWidget);
      expect(find.text(sv.permOpenSettings), findsNothing);

      await tester.tap(find.text(sv.permAskAgain));
      await tester.tap(find.text(sv.permFallbackGallery));
      expect(taps, ['ask', 'gallery']);
    });

    testWidgets(
      'library permanent no: Öppna inställningar, and write it yourself',
      (tester) async {
        await tester.pumpWidget(
          _app(
            card(ImageSource.gallery, OsPermissionOutcome.permanentlyDenied),
          ),
        );

        expect(find.text(sv.permPhotosPermanentlyDenied), findsOneWidget);
        expect(find.text(sv.permAskAgain), findsNothing);

        await tester.tap(find.text(sv.permOpenSettings));
        await tester.tap(find.text(sv.permFallbackWriteYourself));
        expect(taps, ['settings', 'write']);
      },
    );

    testWidgets('blocked by the device: no button to fix it', (tester) async {
      await tester.pumpWidget(
        _app(card(ImageSource.camera, OsPermissionOutcome.restricted)),
      );

      expect(find.text(sv.permCameraRestricted), findsOneWidget);
      expect(find.text(sv.permAskAgain), findsNothing);
      expect(find.text(sv.permOpenSettings), findsNothing);
      // The fallback is another way to the recipe, not a fix.
      expect(find.text(sv.permFallbackGallery), findsOneWidget);
    });

    testWidgets(
      'limited: its own state with Välj fler bilder, never an error',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(card(ImageSource.gallery, OsPermissionOutcome.limited)),
        );

        expect(find.text(sv.permPhotosLimited), findsOneWidget);
        expect(find.text(sv.permPhotosLimitedHint), findsOneWidget);
        expect(find.text(sv.permFallbackWriteYourself), findsNothing);

        await tester.tap(find.text(sv.permPhotosChooseMore));
        expect(taps, ['settings']);
      },
    );

    testWidgets('card colours follow the drawing in both modes', (
      tester,
    ) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          _app(
            card(ImageSource.camera, OsPermissionOutcome.denied),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        final cs = theme.colorScheme;
        final box = tester.widget<Container>(
          find.byKey(const ValueKey('photo-permission-notice-denied')),
        );
        // #behfoton slot 834: #E6EAD9 light, #24382C dark.
        expect(
          box.color,
          theme.brightness == Brightness.dark
              ? cs.primary
              : cs.surfaceContainerHighest,
        );
      }
    });
  });

  group('PhotoImportViewModel · permission before the pick', () {
    late PhotoImportViewModel vm;

    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      vm = PhotoImportViewModel(importManager: MockImportManager());
    });

    tearDown(() {
      vm.dispose();
      OCRExtractionService.resetForTesting();
    });

    test('a no becomes a notice and no picker opens', () async {
      final asked = <(ImageSource, bool)>[];
      vm.permissionResolver = (source, askAgain) async {
        asked.add((source, askAgain));
        return OsPermissionOutcome.denied;
      };

      await vm.pickImageFromCamera();

      expect(asked, [(ImageSource.camera, false)]);
      expect(vm.permissionNotice?.outcome, OsPermissionOutcome.denied);
      expect(vm.permissionNotice?.source, ImageSource.camera);
      expect(vm.hasImage, isFalse);
      expect(vm.hasError, isFalse, reason: 'a no is not an error');
    });

    test(
      'Fråga igen asks the same source again, without our explanation',
      () async {
        final asked = <(ImageSource, bool)>[];
        vm.permissionResolver = (source, askAgain) async {
          asked.add((source, askAgain));
          return OsPermissionOutcome.permanentlyDenied;
        };

        await vm.pickImageFromGallery();
        await vm.askPermissionAgain();

        expect(asked, [
          (ImageSource.gallery, false),
          (ImageSource.gallery, true),
        ]);
        expect(
          vm.permissionNotice?.outcome,
          OsPermissionOutcome.permanentlyDenied,
        );
      },
    );

    test(
      'a refused camera on add-page: the library fallback keeps the pages '
      'already taken and adds to them',
      () async {
        vm.stagePageForTesting(Uint8List.fromList([1]));
        vm.stagePageForTesting(Uint8List.fromList([2]));
        final asked = <ImageSource>[];
        vm.permissionResolver = (source, _) async {
          asked.add(source);
          return source == ImageSource.camera
              ? OsPermissionOutcome.denied
              : OsPermissionOutcome.granted;
        };

        await vm.addPageFromCamera();
        expect(vm.permissionNotice?.addAsPage, isTrue);

        // No platform picker in a unit test, so the pick itself fails after
        // the permission step; what matters is that nothing was cleared.
        await vm.chooseFromGalleryInstead();

        expect(asked, [ImageSource.camera, ImageSource.gallery]);
        expect(vm.pageCount, 2);
        expect(vm.permissionNotice, isNull);
      },
    );

    test(
      'handwritten cannot be switched on with several staged pages, so Läs '
      'av reads every page',
      () async {
        vm.stagePageForTesting(Uint8List.fromList([1]));
        vm.stagePageForTesting(Uint8List.fromList([2]));
        vm.stagePageForTesting(Uint8List.fromList([3]));

        expect(vm.canToggleHandwritten, isFalse);
        vm.setHandwritten(true);

        expect(vm.isHandwritten, isFalse);
        expect(vm.pageCount, 3);
        expect(vm.unreadPageCount, 3);
      },
    );

    test('handwritten can still be switched on with one staged page', () {
      vm.stagePageForTesting(Uint8List.fromList([1]));
      expect(vm.canToggleHandwritten, isTrue);
      vm.setHandwritten(true);
      expect(vm.isHandwritten, isTrue);
      expect(vm.canToggleHandwritten, isTrue, reason: 'off is always allowed');
    });

    test('clearing the photo clears the notice', () async {
      vm.permissionResolver = (_, __) async => OsPermissionOutcome.restricted;
      await vm.pickImageFromCamera();
      expect(vm.permissionNotice, isNotNull);

      vm.clearPhoto();

      expect(vm.permissionNotice, isNull);
    });
  });

  group('timer notice before the timer starts', () {
    testWidgets(
      'notifications permanently off: the notice shows, and says timers stay '
      'in the app',
      (tester) async {
        final gateway = _Gateway(PermissionStatus.permanentlyDenied);
        final service = NotificationPermissionService(
          gateway: gateway,
          sdkVersionProvider: _Sdk(33),
        );
        late BuildContext ctx;
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final shown = service.warnBeforeTimerIfNeeded(ctx);
        await tester.pumpAndSettle();

        expect(find.text(sv.timerNotifDeniedTitle), findsOneWidget);
        expect(find.text(sv.timerNotifDeniedBody), findsOneWidget);

        await tester.tap(find.text(sv.timerNotifDeniedStart));
        await tester.pumpAndSettle();
        expect(await shown, isTrue);
        expect(gateway.settingsCalls, 0);
      },
    );

    testWidgets('Öppna inställningar goes to the phone settings', (
      tester,
    ) async {
      final gateway = _Gateway(PermissionStatus.permanentlyDenied);
      final service = NotificationPermissionService(
        gateway: gateway,
        sdkVersionProvider: _Sdk(34),
      );
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final shown = service.warnBeforeTimerIfNeeded(ctx);
      await tester.pumpAndSettle();
      await tester.tap(find.text(sv.permOpenSettings));
      await tester.pumpAndSettle();

      expect(await shown, isTrue);
      expect(gateway.settingsCalls, 1);
    });

    for (final (label, provider) in [
      ('iOS', _NonAndroid()),
      ('Android 12', _Sdk(32)),
    ]) {
      testWidgets('$label is never asked: no notice, no prompt', (
        tester,
      ) async {
        // permission_handler reads a never-asked permission as denied; the
        // question is only asked on Android 13+ (produktregler.md:685).
        final gateway = _Gateway(PermissionStatus.denied);
        final service = NotificationPermissionService(
          gateway: gateway,
          sdkVersionProvider: provider,
        );
        final ctx = await _context(tester);

        expect(await service.warnBeforeTimerIfNeeded(ctx), isFalse);
        await tester.pumpAndSettle();
        expect(find.text(sv.timerNotifDeniedTitle), findsNothing);
        expect(find.text(sv.permOpenSettings), findsNothing);
        expect(gateway.requests, 0);
        expect(await service.notificationsAllowed(), isTrue);
      });
    }

    testWidgets(
      'Android 13+ never asked: our explanation, then the OS prompt; a yes '
      'starts the timer with no notice',
      (tester) async {
        final gateway = _Gateway(PermissionStatus.denied)
          ..requestAnswer = PermissionStatus.granted;
        var explained = 0;
        final service = NotificationPermissionService(
          gateway: gateway,
          sdkVersionProvider: _Sdk(33),
          rationalePresenter: (_) async {
            explained++;
            expect(gateway.requests, 0, reason: 'explanation comes first');
            return true;
          },
        );
        final ctx = await _context(tester);

        expect(await service.warnBeforeTimerIfNeeded(ctx), isFalse);
        await tester.pumpAndSettle();
        expect(explained, 1);
        expect(gateway.requests, 1);
        expect(find.text(sv.timerNotifDeniedBody), findsNothing);
        expect(find.text(sv.permOpenSettings), findsNothing);
      },
    );

    testWidgets(
      'Android 13+ never asked, the user says Inte nu: no OS prompt, no '
      'settings link, one line that the timer only shows in the app',
      (tester) async {
        final gateway = _Gateway(PermissionStatus.denied);
        final service = NotificationPermissionService(
          gateway: gateway,
          sdkVersionProvider: _Sdk(33),
          rationalePresenter: (_) async => false,
        );
        final ctx = await _context(tester);

        expect(await service.warnBeforeTimerIfNeeded(ctx), isTrue);
        await tester.pump();
        expect(gateway.requests, 0);
        expect(find.text(sv.timerInAppOnly), findsOneWidget);
        expect(find.text(sv.timerNotifDeniedBody), findsNothing);
        expect(find.text(sv.permOpenSettings), findsNothing);
      },
    );

    testWidgets('notifications allowed: no notice', (tester) async {
      final service = NotificationPermissionService(
        gateway: _Gateway(PermissionStatus.granted),
        sdkVersionProvider: _NonAndroid(),
      );
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(await service.warnBeforeTimerIfNeeded(ctx), isFalse);
      await tester.pumpAndSettle();
      expect(find.text(sv.timerNotifDeniedTitle), findsNothing);
    });

    testWidgets(
      'the timer sheet awaits the notice before startTimer is called',
      (tester) async {
        final timers = StepTimerService();
        addTearDown(timers.dispose);
        final gate = <String>[];
        var release = false;

        await tester.pumpWidget(
          _app(
            StepTimerWidget(
              service: timers,
              timerId: 'step-0',
              initialDuration: const Duration(minutes: 5),
              beforeStart: () async {
                gate.add('notice');
                expect(timers.isRunningFor('step-0'), isFalse);
                while (!release) {
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                }
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        expect(gate, ['notice']);
        expect(
          timers.isRunningFor('step-0'),
          isFalse,
          reason: 'the timer waits for the notice',
        );

        release = true;
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 20));

        expect(timers.isRunningFor('step-0'), isTrue);
        timers.resetTimer('step-0');
      },
    );
  });

  group('notification settings when notifications are off in the phone', () {
    test(
      'a permanent no or a device block counts as off; not-yet-asked not',
      () async {
        Future<bool> blocked(PermissionStatus s) =>
            NotificationPermissionService(
              gateway: _Gateway(s),
              sdkVersionProvider: _NonAndroid(),
            ).blockedInSystem();

        expect(await blocked(PermissionStatus.permanentlyDenied), isTrue);
        expect(await blocked(PermissionStatus.restricted), isTrue);
        expect(await blocked(PermissionStatus.denied), isFalse);
        expect(await blocked(PermissionStatus.granted), isFalse);
      },
    );
  });

  // Registered so mocktail fallbacks resolve for ImportManager mocks.
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });
}
