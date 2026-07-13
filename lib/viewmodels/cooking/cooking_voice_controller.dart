import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/voice/cooking_command_interpreter.dart';
import 'package:butlery/services/voice/tts_service.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/viewmodels/cooking_mode_viewmodel.dart';

/// Where a capture was initiated from — the two modes Malin chose compose
/// here: an explicit button press expects feedback on failure, while the
/// hands-free talk-window after a readout must fail SILENTLY (a spoken
/// "jag uppfattade inte" after every quiet step would be maddening).
enum VoiceListenSource { buttonTap, talkWindow }

/// UI-facing assistant state (drives the mic button + indicator strip).
enum VoiceAssistState { idle, listening, transcribing, speaking }

/// Köksbutlern's conductor (tasks/koksbutlern-plan.md, Batch C): binds the
/// capture service, the TTS voice, the step timers and the cooking
/// viewmodel into one state machine.
///
/// THE invariant that stands in for audio-session machinery in v1: the
/// speaker and the microphone are strictly sequential. Speech is always
/// stopped before the mic opens; the talk-window opens only AFTER a
/// readout's completion; a capture never starts while speaking.
class CookingVoiceController extends ChangeNotifier {
  CookingVoiceController({
    required VoiceCaptureService voiceCapture,
    required TtsService tts,
    required StepTimerService timers,
    required CookingModeViewModel cookingVm,
  }) : _voice = voiceCapture,
       _tts = tts,
       _timers = timers,
       _cookingVm = cookingVm;

  /// Command captures are seconds, not minutes — the service cap doubles
  /// as the talk-window length, so the window can never hang open.
  static const Duration commandCaptureCap = Duration(seconds: 6);

  final VoiceCaptureService _voice;
  final TtsService _tts;
  final StepTimerService _timers;
  final CookingModeViewModel _cookingVm;

  VoiceAssistState _state = VoiceAssistState.idle;
  VoiceListenSource? _listenSource;
  String? _lastHeard;
  bool _muted = false;
  int _consecutiveButtonMisses = 0;
  bool _isDisposed = false;

  VoiceAssistState get state => _state;

  /// Initializes the voice stack (TTS configure + Swedish-voice probe) and
  /// notifies listeners — the app-bar mute toggle reveals through the
  /// normal ListenableBuilder path. (A view-level setState can't do this:
  /// the const content subtree short-circuits the rebuild — review
  /// finding, 2026-07-13.)
  Future<void> init() async {
    await _tts.init();
    _notify();
  }

  /// The last transcript, for the on-screen heard-chip (mishearings must
  /// be diagnosable, not mysterious).
  String? get lastHeard => _lastHeard;

  /// Speaker toggle: mutes readouts AND the talk-window (the window only
  /// makes sense as a follow-up to hearing a step).
  bool get muted => _muted;

  bool get ttsAvailable => _tts.isAvailable;

  set muted(bool value) {
    if (_muted == value) return;
    _muted = value;
    if (value) _tts.stop();
    _notify();
  }

  /// The big mic button. Idle → listen (button-sourced); listening → stop
  /// and interpret; speaking → barge-in (stop the voice, then listen);
  /// transcribing → ignored (about to resolve anyway).
  Future<void> onMicPressed() async {
    switch (_state) {
      case VoiceAssistState.idle:
        await _beginListening(VoiceListenSource.buttonTap);
      case VoiceAssistState.speaking:
        await _tts.stop();
        await _beginListening(VoiceListenSource.buttonTap);
      case VoiceAssistState.listening:
        await _finishListening();
      case VoiceAssistState.transcribing:
        break;
    }
  }

  /// Reads the current step aloud, then opens the hands-free talk-window.
  /// Called by VOICE-driven flows only — the on-screen step arrows stay
  /// silent by design (a cook tapping through with the sound off must not
  /// summon the butler).
  Future<void> readCurrentStep() async {
    final steps = _cookingVm.instructions;
    if (steps.isEmpty) return;
    final index = _cookingVm.currentStepIndex;
    await _speakThenWindow(
      AppLocale.current.voiceAssistStepPrefix(index + 1, steps.length) +
          steps[index],
    );
  }

  /// Single-flight guard: set SYNCHRONOUSLY before the first await, so a
  /// rapid double-tap can't run two _beginListening bodies concurrently —
  /// the loser used to clobber _state back to idle while the recorder was
  /// live, orphaning the capture and wedging the shared service for every
  /// voice feature in the app (review finding #2).
  bool _startingCapture = false;

  Future<void> _beginListening(VoiceListenSource source) async {
    if (_startingCapture ||
        _state == VoiceAssistState.listening ||
        _state == VoiceAssistState.transcribing) {
      return;
    }
    _startingCapture = true;
    try {
      // Sequencing invariant: never open the mic while speaking.
      if (_tts.isSpeaking) await _tts.stop();

      final started = await _voice.startRecording(
        maxDuration: commandCaptureCap,
        onAutoStopped: () => _finishListening(),
      );
      if (_isDisposed) {
        // Disposed mid-start: the capture we just opened has no owner —
        // abandon it explicitly or it blocks the singleton until app
        // restart (review finding #3).
        if (started) await _voice.cancelRecording();
        return;
      }
      if (!started) {
        // Model missing / mic busy: quiet failure — the buttons still work.
        _state = VoiceAssistState.idle;
        _notify();
        return;
      }
      _listenSource = source;
      _state = VoiceAssistState.listening;
      _notify();
    } finally {
      _startingCapture = false;
    }
  }

  Future<void> _finishListening() async {
    if (_state != VoiceAssistState.listening) return;
    final source = _listenSource ?? VoiceListenSource.buttonTap;
    _state = VoiceAssistState.transcribing;
    _notify();

    final transcript = await _voice.stopAndTranscribe();
    if (_isDisposed) return;
    _state = VoiceAssistState.idle;

    if (transcript == null || transcript.trim().isEmpty) {
      // Silence: from the talk-window this is the NORMAL case (the cook
      // just kept cooking) — close without comment. From the button it's
      // a miss worth acknowledging.
      if (source == VoiceListenSource.buttonTap) {
        await _handleMiss(heard: null);
      } else {
        _notify();
      }
      return;
    }

    final command = interpretCookingCommand(transcript);
    if (command is Unrecognized) {
      // The heard-chip exists to make MISHEARINGS diagnosable — it shows
      // only for unrecognized speech (review finding #9: keeping it after
      // successful commands left a stale "Hörde:" chip on screen forever).
      _lastHeard = transcript;
      if (source == VoiceListenSource.buttonTap) {
        await _handleMiss(heard: command.heard);
      } else {
        // Talk-window chatter ("kan du hämta smöret?") is not a miss —
        // show what was heard, act on nothing, stay quiet.
        _notify();
      }
      return;
    }

    _lastHeard = null;
    _consecutiveButtonMisses = 0;
    await _execute(command);
  }

  Future<void> _execute(CookingCommand command) async {
    switch (command) {
      case NextStep():
        if (_cookingVm.hasNextStep) {
          _cookingVm.nextStep();
          await readCurrentStep();
        } else {
          await _speakThenWindow(AppLocale.current.voiceAssistNoNextStep);
        }
      case PreviousStep():
        if (_cookingVm.hasPreviousStep) {
          _cookingVm.previousStep();
          await readCurrentStep();
        } else {
          await _speakThenWindow(AppLocale.current.voiceAssistNoPreviousStep);
        }
      case RepeatStep():
        await readCurrentStep();
      case ReadIngredients():
        final lines = _cookingVm.scaledIngredients;
        await _speakThenWindow(
          lines.isEmpty
              ? AppLocale.current.voiceAssistNoIngredients
              : lines.join('. '),
        );
      case SetTimer(:final duration):
        _timers.startTimer(
          id: 'voice-${clock.now().microsecondsSinceEpoch}',
          duration: duration,
          label: _speakableDuration(duration),
        );
        await _speakThenWindow(
          AppLocale.current.voiceAssistTimerStarted(
            _speakableDuration(duration),
          ),
        );
      case TimerQuery():
        await _speakThenWindow(_timerStatusAnnouncement());
      case StopCommand():
        await _tts.stop();
        _notify();
      case Unrecognized():
        // Handled by the caller; unreachable here but the sealed switch
        // must stay exhaustive.
        break;
    }
  }

  Future<void> _handleMiss({required String? heard}) async {
    _lastHeard = heard;
    _consecutiveButtonMisses++;
    final message = _consecutiveButtonMisses >= 2
        ? AppLocale.current.voiceAssistMissedTwice
        : AppLocale.current.voiceAssistMissed;
    await _speak(message);
    _notify();
  }

  /// Speaks (unless muted/unavailable), then opens the hands-free window.
  Future<void> _speakThenWindow(String text) async {
    await _speak(text);
    if (_isDisposed) return;
    // The window is the follow-up to HEARING the butler — muted or
    // voiceless sessions keep the button as the only entry point.
    if (!_muted && _tts.isAvailable) {
      await _beginListening(VoiceListenSource.talkWindow);
    }
  }

  Future<void> _speak(String text) async {
    if (_muted || !_tts.isAvailable) return;
    _state = VoiceAssistState.speaking;
    _notify();
    await _tts.speak(text);
    if (_isDisposed) return;
    if (_state == VoiceAssistState.speaking) {
      _state = VoiceAssistState.idle;
      _notify();
    }
  }

  String _timerStatusAnnouncement() {
    final running = _timers.currentTimers
        .where((t) => t.isRunning || t.isPaused)
        .toList();
    if (running.isEmpty) return AppLocale.current.voiceAssistNoTimers;
    // Timers come soonest-first from the service; the soonest is the one a
    // cook at the stove means.
    final soonest = running.first;
    return AppLocale.current.voiceAssistTimeLeft(
      _speakableDuration(soonest.remaining),
    );
  }

  /// "10 minuter", "1 timme och 30 minuter", "45 sekunder" — digits are
  /// fine for TTS; the structure is what makes it natural to hear.
  String _speakableDuration(Duration d) {
    final l10n = AppLocale.current;
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    final parts = <String>[
      if (hours > 0) l10n.voiceAssistHours(hours),
      if (minutes > 0) l10n.voiceAssistMinutes(minutes),
      if (seconds > 0 && hours == 0) l10n.voiceAssistSeconds(seconds),
    ];
    if (parts.isEmpty) return l10n.voiceAssistSeconds(0);
    if (parts.length == 1) return parts.single;
    return '${parts.sublist(0, parts.length - 1).join(', ')} '
        '${l10n.voiceAssistAnd} ${parts.last}';
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Abandon our capture (ownership: the assistant only ever records via
    // its own begin/finish, and cooking mode owns this controller) and
    // silence the voice.
    if (_state == VoiceAssistState.listening ||
        _state == VoiceAssistState.transcribing) {
      _voice.cancelRecording();
    }
    _tts.stop();
    super.dispose();
  }
}
