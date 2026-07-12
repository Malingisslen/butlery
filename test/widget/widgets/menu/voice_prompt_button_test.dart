/// Widget tests for [VoicePromptButton] (kb-whisper voice plan).
///
/// Intent: pin the degradation contract the stakeholder panel made binding —
/// the mic is an OFFER, never a gate. Denied permission or a missing model
/// resolves to a quiet snackbar; a successful capture hands the transcript to
/// the caller (who puts it in an editable field); the busy states never
/// submit anything on their own.
///
/// Harness: VoiceCaptureService is resolved from the production
/// ServiceLocator (GetIt bridge pattern from
/// veckomeny_cooking_session_card_test.dart); the permission gateway is the
/// injectable seam OsPermissionHelper defines.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/widgets/menu/voice_prompt_button.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _FakeVoiceCaptureService extends Fake implements VoiceCaptureService {
  _FakeVoiceCaptureService({
    this.modelReady = true,
    this.startSucceeds = true,
    this.transcript = 'tre middagar och två luncher',
  });

  final bool modelReady;
  final bool startSucceeds;
  final String? transcript;
  int cancelCalls = 0;

  @override
  Future<bool> prepareModel() async => modelReady;

  @override
  Future<bool> startRecording() async => startSucceeds;

  @override
  Future<String?> stopAndTranscribe() async => transcript;

  @override
  Future<void> cancelRecording() async {
    cancelCalls++;
  }
}

class _FakeGateway implements PermissionGateway {
  _FakeGateway(this.status, {this.requestOutcome});

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

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  void wire(_FakeVoiceCaptureService service) {
    GetIt.instance.registerSingleton<VoiceCaptureService>(service);
    production.ServiceLocator.initialize(DIContainer());
  }

  Future<void> pumpButton(
    WidgetTester tester, {
    required PermissionGateway gateway,
    required ValueChanged<String> onTranscript,
    bool enabled = true,
  }) {
    return tester.pumpWidget(
      createLocalizedTestApp(
        child: VoicePromptButton(
          onTranscript: onTranscript,
          enabled: enabled,
          permissionGateway: gateway,
        ),
      ),
    );
  }

  testWidgets('idle state renders the mic with the speak tooltip', (
    tester,
  ) async {
    wire(_FakeVoiceCaptureService());
    await pumpButton(
      tester,
      gateway: _FakeGateway(PermissionStatus.granted),
      onTranscript: (_) {},
    );

    expect(find.byIcon(Icons.mic_none), findsOneWidget);
    expect(find.byTooltip('Tala in veckomenyn'), findsOneWidget);
  });

  testWidgets(
    'granted permission: tap records, second tap delivers the transcript',
    (tester) async {
      wire(_FakeVoiceCaptureService(transcript: 'fyra middagar'));
      String? delivered;
      await pumpButton(
        tester,
        gateway: _FakeGateway(PermissionStatus.granted),
        onTranscript: (t) => delivered = t,
      );

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.stop),
        findsOneWidget,
        reason: 'recording state shows the stop affordance',
      );
      expect(delivered, isNull, reason: 'nothing is delivered mid-recording');

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(delivered, 'fyra middagar');
      expect(
        find.byIcon(Icons.mic_none),
        findsOneWidget,
        reason: 'button returns to idle after delivery',
      );
    },
  );

  testWidgets('missing model degrades to a quiet snackbar, never an error', (
    tester,
  ) async {
    wire(_FakeVoiceCaptureService(modelReady: false));
    String? delivered;
    await pumpButton(
      tester,
      gateway: _FakeGateway(PermissionStatus.granted),
      onTranscript: (t) => delivered = t,
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(delivered, isNull);
    expect(
      find.textContaining('Det går bra att skriva i stället'),
      findsOneWidget,
      reason: 'failure copy must point back to typed input',
    );
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
  });

  testWidgets('failed recording start degrades the same way', (tester) async {
    wire(_FakeVoiceCaptureService(startSucceeds: false));
    String? delivered;
    await pumpButton(
      tester,
      gateway: _FakeGateway(PermissionStatus.granted),
      onTranscript: (t) => delivered = t,
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(delivered, isNull);
    expect(
      find.textContaining('Det går bra att skriva i stället'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
  });

  testWidgets('failed transcription shows the quiet notice and resets', (
    tester,
  ) async {
    wire(_FakeVoiceCaptureService(transcript: null));
    String? delivered;
    await pumpButton(
      tester,
      gateway: _FakeGateway(PermissionStatus.granted),
      onTranscript: (t) => delivered = t,
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(delivered, isNull);
    expect(
      find.textContaining('Det går bra att skriva i stället'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
  });

  testWidgets(
    'permanently denied mic: settings snackbar, typed input untouched',
    (tester) async {
      final service = _FakeVoiceCaptureService();
      wire(service);
      String? delivered;
      await pumpButton(
        tester,
        gateway: _FakeGateway(PermissionStatus.permanentlyDenied),
        onTranscript: (t) => delivered = t,
      );

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(delivered, isNull);
      expect(find.text('Öppna inställningar'), findsOneWidget);
      expect(
        find.byIcon(Icons.mic_none),
        findsOneWidget,
        reason: 'denial never dead-ends the feature — idle mic remains',
      );
    },
  );

  testWidgets('first denial shows the on-device rationale before the OS ask', (
    tester,
  ) async {
    wire(_FakeVoiceCaptureService());
    await pumpButton(
      tester,
      gateway: _FakeGateway(
        PermissionStatus.denied,
        requestOutcome: PermissionStatus.denied,
      ),
      onTranscript: (_) {},
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('skickas aldrig vidare'),
      findsOneWidget,
      reason: 'rationale must state the on-device-only promise (DPO condition)',
    );
  });

  testWidgets('disabled while the menu generates', (tester) async {
    wire(_FakeVoiceCaptureService());
    await pumpButton(
      tester,
      gateway: _FakeGateway(PermissionStatus.granted),
      onTranscript: (_) {},
      enabled: false,
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('STOP stays tappable when the flow disables the button '
      'mid-recording (no hot mic without an exit)', (tester) async {
    wire(_FakeVoiceCaptureService(transcript: 'fem middagar'));
    String? delivered;

    // Rebuildable harness so `enabled` can flip while recording, like
    // veckomeny_view flipping isGenerating.
    final enabled = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (_, value, _) => VoicePromptButton(
            onTranscript: (t) => delivered = t,
            enabled: value,
            permissionGateway: _FakeGateway(PermissionStatus.granted),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.stop), findsOneWidget);

    enabled.value = false; // menu generation starts mid-recording
    await tester.pumpAndSettle();

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      button.onPressed,
      isNotNull,
      reason: 'the stop control must never go dead while the mic is hot',
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(delivered, 'fem middagar');
  });
}
