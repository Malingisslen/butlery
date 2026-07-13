import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_tts/flutter_tts.dart';

import 'package:butlery/core/utils/logger.dart';

/// Test seam over the flutter_tts plugin — production code (and
/// [TtsService]) talks only to this interface, so tests can fake speech
/// synthesis without a platform channel.
abstract class SpeechSynthesizer {
  /// Applies language selection, `awaitSpeakCompletion`, and audio-session
  /// configuration. Called once before any [speakAndWait] call.
  Future<void> configure();

  /// True when a Swedish (sv-SE) voice is installed on this device. Reflects
  /// the check [configure] already ran — cheap to call repeatedly.
  Future<bool> isSwedishAvailable();

  /// Speaks [text] and returns only when the utterance has COMPLETED.
  Future<void> speakAndWait(String text);

  /// Stops an in-progress utterance. Safe to call when idle.
  Future<void> stop();
}

/// flutter_tts-backed [SpeechSynthesizer] — Android `TextToSpeech` /
/// iOS `AVSpeechSynthesizer` passthrough.
///
/// Implements the Köksbutlern vendor-panel conditions
/// (tasks/koksbutlern-plan.md):
/// - `awaitSpeakCompletion(true)` so the `speak()` call's returned Future
///   genuinely resolves on completion (native code defers its method-channel
///   result until the utterance ends) instead of the plugin's well-known
///   "returns immediately" default.
/// - `setLanguage('sv-SE')` only AFTER `isLanguageAvailable('sv-SE')`
///   confirms the voice exists — Swedish voice presence varies by
///   device/OEM, so this never assumes it's there.
/// - Android: `speak(text, focus: true)` requests transient audio focus for
///   the utterance (flutter_tts 4.2.5's `speak(String, {bool focus})` API —
///   the `focus` flag is only wired to a platform channel on Android inside
///   the plugin itself, so passing it unconditionally is harmless elsewhere).
/// - iOS: `setSharedInstance(true)` + `setIosAudioCategory(.playback,
///   [.duckOthers], .spokenAudio)` so the butler's voice plays over
///   `AVAudioSession` and ducks (rather than silences) other audio.
class FlutterTtsSynthesizer implements SpeechSynthesizer {
  FlutterTtsSynthesizer({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  static const String _swedishLocale = 'sv-SE';

  bool _swedishAvailable = false;

  @override
  Future<void> configure() async {
    _tts.setErrorHandler((dynamic message) {
      AppLogger.debug('FlutterTtsSynthesizer: platform TTS error: $message');
    });
    await _tts.awaitSpeakCompletion(true);

    if (Platform.isIOS) {
      // Must be set before any speak() call, or the butler's voice fights
      // whatever audio session the app already holds.
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [IosTextToSpeechAudioCategoryOptions.duckOthers],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    }

    final result = await _tts.isLanguageAvailable(_swedishLocale);
    _swedishAvailable = result == true || result == 1;
    if (_swedishAvailable) {
      await _tts.setLanguage(_swedishLocale);
    }
  }

  @override
  Future<bool> isSwedishAvailable() async => _swedishAvailable;

  @override
  Future<void> speakAndWait(String text) async {
    // focus:true is Android-only inside the plugin (see class doc); passing
    // it on iOS/other platforms is a no-op there, not an error.
    await _tts.speak(text, focus: true);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

/// Speech output for Köksbutlern (cooking-mode voice assistant):
/// step readouts, ingredient lists, and command confirmations.
///
/// Documented [BaseService] non-adopter (lib/services/CLAUDE.md) — a thin
/// wrapper over a 3rd-party OS TTS passthrough, no Firebase operations.
///
/// **Serialization guarantee:** [speak] never runs two utterances
/// concurrently. A call that arrives while one is still in flight stops the
/// prior utterance first, then waits for it to actually settle before
/// starting its own. `CookingVoiceController` (Batch C) depends on this: its
/// speaker/microphone sequencing rule (never record while speaking) only
/// holds if "speaking" has a single, well-defined end.
///
/// **Degrade contract:** if [init] can't confirm a Swedish voice — missing
/// on the device, or the plugin itself fails to configure — [isAvailable]
/// stays false and [speak] becomes a silent no-op. Callers skip readouts and
/// fall back to on-screen text only; nothing here ever throws into the
/// controller's state machine.
class TtsService {
  TtsService({SpeechSynthesizer? synthesizer})
    : _synthesizer = synthesizer ?? FlutterTtsSynthesizer();

  final SpeechSynthesizer _synthesizer;

  bool _isAvailable = false;
  bool _isSpeaking = false;

  /// Monotonic supersession token: each [speak] takes the next value, and
  /// any await that resumes to find a NEWER token yields. Closes the
  /// three-caller race the completer scheme had (review finding #8: a call
  /// landing in the gap between a superseder's stop() and its bookkeeping
  /// saw "no previous utterance" and spoke concurrently).
  int _speakToken = 0;

  /// Resolves when the most recently started utterance has settled (spoken,
  /// stopped, or errored). `null` when nothing has ever spoken. Used to
  /// serialize overlapping [speak] calls — see class doc.
  Future<void>? _lastUtterance;

  /// Generous cap on one utterance: kitchen-step readouts run a handful of
  /// seconds. If the platform's completion callback never fires (a known
  /// flutter_tts edge case), this stops the controller's state machine from
  /// deadlocking in "speaking" forever — same rationale as
  /// VoiceCaptureService.transcriptionTimeout.
  static const Duration _speakTimeout = Duration(seconds: 30);

  bool get isAvailable => _isAvailable;
  bool get isSpeaking => _isSpeaking;

  /// Configures the synthesizer and probes Swedish-voice availability.
  /// Never throws — any failure degrades to [isAvailable] == false.
  Future<void> init() async {
    try {
      await _synthesizer.configure();
      _isAvailable = await _synthesizer.isSwedishAvailable();
    } catch (e) {
      AppLogger.warning('TtsService: init failed, degrading to text-only: $e');
      _isAvailable = false;
    }
  }

  /// Speaks [text], awaiting completion. No-op when unavailable or [text] is
  /// blank. Never throws — a synthesizer failure is logged and swallowed so
  /// the caller's flow (e.g. the voice controller's state machine) keeps
  /// moving.
  Future<void> speak(String text) async {
    if (!_isAvailable) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Claim the token FIRST (synchronously): from this instant every older
    // in-flight speak is superseded and will yield at its next resume.
    final token = ++_speakToken;

    // If an utterance is in flight, cut it off and wait for its
    // bookkeeping to settle, so speakAndWait calls never overlap. The
    // token check afterwards is what closes the three-caller race: a call
    // that lands while we settle claims a newer token, and we yield to it
    // instead of speaking a stale line.
    final previous = _lastUtterance;
    if (previous != null) {
      await stop();
      await previous;
    }
    if (token != _speakToken) return; // superseded while settling

    final completer = Completer<void>();
    _lastUtterance = completer.future;
    _isSpeaking = true;
    try {
      await _synthesizer.speakAndWait(trimmed).timeout(_speakTimeout);
    } catch (e) {
      AppLogger.warning('TtsService: speak failed, degrading silently: $e');
      // A fired timeout can mean the platform lost the completion callback
      // while audio still plays — stop the zombie so the next speak can't
      // overlap it (review low-priority hardening).
      await stop();
    } finally {
      // Only the still-latest call may flip the flag off — a superseder
      // has already claimed the speaking state for itself.
      if (token == _speakToken) _isSpeaking = false;
      completer.complete();
      if (identical(_lastUtterance, completer.future)) {
        _lastUtterance = null;
      }
    }
  }

  /// Stops an in-progress utterance. Safe (and cheap) to call when idle.
  Future<void> stop() async {
    try {
      await _synthesizer.stop();
    } catch (e) {
      AppLogger.debug('TtsService: stop failed: $e');
    } finally {
      _isSpeaking = false;
    }
  }

  Future<void> dispose() async {
    await stop();
  }
}
