import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

/// Push-to-talk microphone for text fields ("Tala in veckomenyn").
///
/// Tap → mic permission (rationale-first via [OsPermissionHelper]) → speech
/// model ready (one-time ~55 MB download) → record → tap again →
/// on-device KB-Whisper transcription → [onTranscript] with the text.
///
/// Degradation contract (Store/DPO panel conditions): every failure —
/// denied permission, missing model, failed transcription — resolves to a
/// quiet snackbar or silence, never a blocking error; the surrounding text
/// field stays the path of record. The transcript lands EDITABLE in the
/// field; this widget never submits anything.
class VoicePromptButton extends StatefulWidget {
  const VoicePromptButton({
    super.key,
    required this.onTranscript,
    this.enabled = true,
    this.permissionGateway = const DefaultPermissionGateway(),
    this.startTooltip,
    this.rationaleTitle,
    this.rationaleBody,
    this.compact = false,
  });

  /// Receives the transcribed text. The caller decides what field it fills.
  final ValueChanged<String> onTranscript;

  /// Disabled while the surrounding flow is busy (e.g. menu generating).
  final bool enabled;

  /// Injectable per OsPermissionHelper's contract — tests stub statuses
  /// without touching plugin channels.
  final PermissionGateway permissionGateway;

  /// Idle-state tooltip naming what will be dictated ("Tala in
  /// veckomenyn" / "Tala in din sökning"). Defaults to the weekly-menu
  /// copy, the button's original home.
  final String? startTooltip;

  /// Mic-permission rationale dialog copy. MUST name the actual surface —
  /// a permission dialog stating the wrong purpose ("för veckomenyn" on a
  /// search field) misstates data use exactly where the Store/DPO
  /// degradation contract cares. Defaults to the weekly-menu copy.
  final String? rationaleTitle;
  final String? rationaleBody;

  /// Compact visual density for tight suffix rows (search field stacks
  /// clear + mic + filter toggle on narrow phones).
  final bool compact;

  @override
  State<VoicePromptButton> createState() => _VoicePromptButtonState();
}

enum _VoiceState { idle, preparing, recording, transcribing }

class _VoicePromptButtonState extends State<VoicePromptButton> {
  late final VoiceCaptureService _voice;
  _VoiceState _state = _VoiceState.idle;

  @override
  void initState() {
    super.initState();
    _voice = ServiceLocator.get<VoiceCaptureService>();
  }

  @override
  void dispose() {
    // The service is an app-wide singleton (DI-owned); only abandon OUR
    // in-flight capture, don't dispose the service.
    if (_state == _VoiceState.recording) {
      _voice.cancelRecording();
    }
    super.dispose();
  }

  Future<void> _onTap() async {
    switch (_state) {
      case _VoiceState.idle:
        await _begin();
      case _VoiceState.recording:
        await _finish();
      case _VoiceState.preparing:
      case _VoiceState.transcribing:
        break; // Taps during busy states are ignored, not queued.
    }
  }

  Future<void> _begin() async {
    final granted = await OsPermissionHelper.requestWithRationale(
      context: context,
      permission: Permission.microphone,
      rationaleTitle:
          widget.rationaleTitle ?? context.l10n.voicePromptMicRationaleTitle,
      rationaleBody:
          widget.rationaleBody ?? context.l10n.voicePromptMicRationaleBody,
      grantLabel: context.l10n.voicePromptMicGrant,
      permanentlyDeniedMessage: context.l10n.voicePromptMicPermanentlyDenied,
      openSettingsLabel: context.l10n.voicePromptOpenSettings,
      gateway: widget.permissionGateway,
    );
    if (!granted || !mounted) return;

    setState(() => _state = _VoiceState.preparing);
    final modelReady = await _voice.prepareModel();
    if (!mounted) return;
    if (!modelReady) {
      // Nothing was heard yet — "couldn't interpret" would be misleading.
      setState(() => _state = _VoiceState.idle);
      _showQuietNotice(context.l10n.voiceUnavailable);
      return;
    }

    final started = await _voice.startRecording();
    if (!mounted) {
      await _voice.cancelRecording();
      return;
    }
    if (!started) {
      setState(() => _state = _VoiceState.idle);
      _showQuietNotice(context.l10n.voiceUnavailable);
      return;
    }
    setState(() => _state = _VoiceState.recording);
  }

  Future<void> _finish() async {
    setState(() => _state = _VoiceState.transcribing);
    final transcript = await _voice.stopAndTranscribe();
    if (!mounted) return;
    setState(() => _state = _VoiceState.idle);

    if (transcript == null) {
      _showQuietNotice(context.l10n.voicePromptFailed);
      return;
    }
    widget.onTranscript(transcript);
  }

  void _showQuietNotice(String message) {
    SnackBarUtils.showInfo(context, message);
  }

  @override
  Widget build(BuildContext context) {
    // Voice capture is a mobile capability (mic + native whisper.cpp); on
    // web the model cache is unavailable anyway (canCacheLocally = false).
    if (kIsWeb) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final busy =
        _state == _VoiceState.preparing || _state == _VoiceState.transcribing;

    if (busy) {
      return Tooltip(
        message: _state == _VoiceState.preparing
            ? context.l10n.voicePromptPreparing
            : context.l10n.voicePromptTranscribing,
        child: const Padding(
          padding: EdgeInsets.all(AppDimensions.paddingS),
          child: LoadingIndicator(size: AppDimensions.iconSizeAction),
        ),
      );
    }

    final recording = _state == _VoiceState.recording;
    return IconButton(
      visualDensity: widget.compact ? VisualDensity.compact : null,
      icon: Icon(
        recording ? Icons.stop : Icons.mic_none,
        size: AppDimensions.iconSizeAction,
        color: recording ? cs.error : cs.primary,
      ),
      tooltip: recording
          ? context.l10n.voicePromptStop
          : (widget.startTooltip ?? context.l10n.voicePromptStart),
      // STOP must stay tappable even when the surrounding flow disables the
      // button (menu starts generating mid-recording) — a hot mic with a
      // dead stop control would contradict the privacy posture.
      onPressed: (widget.enabled || recording) ? _onTap : null,
    );
  }
}
