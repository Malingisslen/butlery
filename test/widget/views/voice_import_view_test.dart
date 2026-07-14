/// Widget tests for the "Tala in recept" checklist wizard (direction B +
/// A's big mic — Malin's pick 2026-07-13).
///
/// Intent: pin the wizard's contract — three always-typable cards, one
/// recording at a time with the large stop control in the active card,
/// transcript landing editable in its own card, the import button
/// unlocking only when all three sections have text, and voice failures
/// degrading to a quiet notice with typing untouched.
///
/// Harness: VoiceImportViewModel resolves from the production
/// ServiceLocator via the GetIt bridge; mic + whisper are faked at the
/// VoiceCaptureService seam; permission gateway stubbed granted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/viewmodels/import/voice_import_viewmodel.dart';
import 'package:butlery/views/voice_import_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _FakeVoiceCapture extends Fake implements VoiceCaptureService {
  _FakeVoiceCapture({this.modelReady = true});

  final bool modelReady;
  String? transcript = 'tre ägg';
  int cancelCalls = 0;

  /// Captured per-capture auto-stop wiring, so a test can fire the 3-min
  /// cap exactly as the service would.
  void Function()? capturedOnAutoStopped;

  @override
  Future<bool> prepareModel() async => modelReady;

  @override
  Future<bool> startRecording({
    void Function()? onAutoStopped,
    Duration? maxDuration,
  }) async {
    capturedOnAutoStopped = onAutoStopped;
    return true;
  }

  @override
  Future<String?> stopAndTranscribe() async => transcript;

  @override
  Future<void> cancelRecording() async {
    cancelCalls++;
  }
}

class _FakeImportManager extends Fake implements ImportManager {
  String? seenTranscript;

  @override
  Future<ImportManagerResult> importVoiceTranscript(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    seenTranscript = input;
    return ImportManagerResult.failure('stub');
  }
}

class _GrantedGateway implements PermissionGateway {
  @override
  Future<PermissionStatus> checkStatus(Permission permission) async =>
      PermissionStatus.granted;

  @override
  Future<PermissionStatus> request(Permission permission) async =>
      PermissionStatus.granted;

  @override
  Future<bool> openSettings() async => true;
}

void main() {
  late _FakeVoiceCapture voice;
  late _FakeImportManager importManager;

  setUp(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
    voice = _FakeVoiceCapture();
    importManager = _FakeImportManager();
    GetIt.instance.registerFactory<VoiceImportViewModel>(
      () => VoiceImportViewModel(
        importManager: importManager,
        voiceCapture: voice,
      ),
    );
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    createLocalizedTestApp(
      wrapInScaffold: false,
      child: VoiceImportView(permissionGateway: _GrantedGateway()),
    ),
  );

  testWidgets('renders three cards, all typable, submit locked', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('1 · Rättens namn'), findsOneWidget);
    expect(find.text('2 · Ingredienser'), findsOneWidget);
    expect(find.text('3 · Gör så här'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.scrollUntilVisible(
      find.text('Importera receptet'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.ancestor(
              of: find.text('Importera receptet'),
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNull,
      reason: 'submit stays locked until all three sections have text',
    );
  });

  testWidgets(
    'record → big stop in the active card → transcript lands editable',
    (tester) async {
      voice.transcript = 'två deciliter mjölk och tre ägg';
      await pump(tester);

      await tester.tap(find.byIcon(Icons.mic_none).at(1)); // ingredients
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.stop),
        findsOneWidget,
        reason: "direction A's big stop control shows in the active card",
      );
      // The other cards' mics pause while one records.
      expect(find.byIcon(Icons.mic_none), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pumpAndSettle();

      expect(find.text('två deciliter mjölk och tre ägg'), findsOneWidget);
      expect(
        find.byIcon(Icons.check),
        findsOneWidget,
        reason: 'the dictated card shows the done checkmark',
      );
    },
  );

  testWidgets(
    'a 3-min auto-stop lands the transcript in the text field with NO '
    'manual tap (the _syncControllersFromVm path, review finding #1)',
    (tester) async {
      // Distinct from the manual-stop test: here the stop arrives from the
      // service's cap callback, so the ONLY route into the visible text
      // field is the view's VM listener. A refactor that reintroduced a
      // manual controller write in the tap handler and dropped the listener
      // would keep the manual test green but fail this one — the capped
      // dictation would be invisible and one keystroke would erase it.
      voice.transcript = 'grädda i ugnen i tjugo minuter';
      await pump(tester);

      await tester.tap(find.byIcon(Icons.mic_none).at(2)); // steps
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.stop), findsOneWidget);

      // The service fires the per-capture cap callback — no user tap.
      voice.capturedOnAutoStopped!();
      await tester.pumpAndSettle();

      expect(
        find.text('grädda i ugnen i tjugo minuter'),
        findsOneWidget,
        reason: 'an auto-stopped dictation must be visible in its card',
      );
      expect(
        find.byIcon(Icons.stop),
        findsNothing,
        reason: 'the capture ended — the big stop control is gone',
      );
      // All three cards are idle again (mic stays on the done card too —
      // re-dictation is one tap), and only the dictated card shows done.
      expect(find.byIcon(Icons.mic_none), findsNWidgets(3));
      expect(find.byIcon(Icons.check), findsOneWidget);
    },
  );

  testWidgets('typing all three sections unlocks submit and sends the '
      'assembled text', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Pannkakor');
    await tester.enterText(find.byType(TextField).at(1), 'tre ägg, mjölk');
    await tester.enterText(find.byType(TextField).at(2), 'Vispa. Stek.');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Importera receptet'),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Importera receptet'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.text('Importera receptet'));
    await tester.pumpAndSettle();

    expect(importManager.seenTranscript, contains('Ingredienser:'));
    expect(importManager.seenTranscript, contains('Gör så här:'));
    expect(
      find.text('stub'),
      findsOneWidget,
      reason: 'a failed import surfaces its message as a quiet notice',
    );
  });

  testWidgets('voice unavailable → quiet notice, typing untouched', (
    tester,
  ) async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
    voice = _FakeVoiceCapture(modelReady: false);
    GetIt.instance.registerFactory<VoiceImportViewModel>(
      () => VoiceImportViewModel(
        importManager: importManager,
        voiceCapture: voice,
      ),
    );
    production.ServiceLocator.initialize(DIContainer());
    await pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Redan skrivet');
    await tester.tap(find.byIcon(Icons.mic_none).first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('inte tillgänglig just nu'),
      findsOneWidget,
      reason:
          'model missing = feature unavailable, not a failed '
          'interpretation (nothing was heard yet)',
    );
    expect(
      find.textContaining('Det går bra att skriva i stället'),
      findsOneWidget,
      reason: 'failure copy must point back to typed input',
    );
    expect(
      find.text('Redan skrivet'),
      findsOneWidget,
      reason: 'voice failure never clears typed text',
    );
  });
}
