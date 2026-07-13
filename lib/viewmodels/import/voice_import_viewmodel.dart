import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/voice_transcript_assembler.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// The three guided dictation sections. Order is presentational only —
/// direction B (Malin's pick) allows recording in any order.
enum VoiceImportSection { title, ingredients, steps }

/// Per-section interaction state driving the card UI.
enum VoiceSectionState { idle, preparing, recording, transcribing }

/// ViewModel for the "Tala in recept" checklist wizard (voice plan
/// roadmap #2). Owns the three section texts + recording lifecycle and the
/// final assemble→import call; the view owns navigation and the OS
/// permission flow (OsPermissionHelper needs a BuildContext).
///
/// VoiceCaptureService is an app-wide singleton shared with the menu
/// prompt button — every interaction here is ownership-guarded: the
/// auto-stop callback is per-capture (passed to startRecording, cleared by
/// the service), and dispose only cancels a capture THIS viewmodel started.
class VoiceImportViewModel extends BaseViewModel {
  VoiceImportViewModel({
    required ImportManager importManager,
    required VoiceCaptureService voiceCapture,
  }) : _importManager = importManager,
       _voiceCapture = voiceCapture;

  final ImportManager _importManager;
  final VoiceCaptureService _voiceCapture;

  final Map<VoiceImportSection, String> _texts = {
    for (final s in VoiceImportSection.values) s: '',
  };
  VoiceImportSection? _activeSection;
  VoiceSectionState _activeState = VoiceSectionState.idle;

  String textOf(VoiceImportSection section) => _texts[section]!;

  bool get hasActiveCapture => _activeSection != null;

  VoiceImportSection? get activeSection => _activeSection;

  VoiceSectionState stateOf(VoiceImportSection section) =>
      section == _activeSection ? _activeState : VoiceSectionState.idle;

  bool isDone(VoiceImportSection section) =>
      _texts[section]!.trim().isNotEmpty && section != _activeSection;

  /// All three sections carry text → the import button unlocks.
  bool get canImport =>
      !isLoading &&
      !hasActiveCapture &&
      VoiceImportSection.values.every((s) => _texts[s]!.trim().isNotEmpty);

  bool get isImporting => isLoading;

  String? get errorMessage => error;

  /// View-side edits (the fields are always typable — typing IS the
  /// denial/failure fallback, no dead ends).
  void updateText(VoiceImportSection section, String value) {
    if (_texts[section] == value) return;
    _texts[section] = value;
    _notify();
  }

  /// Starts capture into [section]. The OS mic permission must already be
  /// granted (view responsibility). Returns false when voice is
  /// unavailable — the card stays typable, and the view shows the quiet
  /// failure notice.
  Future<bool> startRecording(VoiceImportSection section) async {
    if (_activeSection != null || isLoading) return false;

    _activeSection = section;
    _activeState = VoiceSectionState.preparing;
    _notify();

    final modelReady = await _voiceCapture.prepareModel();
    if (isDisposed) return false;
    if (!modelReady) {
      _clearActive();
      return false;
    }

    // Per-capture callback: the 3-min cap already stopped the recorder
    // (service-enforced); finishing via stopRecording lands the capped
    // transcript exactly like a manual stop.
    final started = await _voiceCapture.startRecording(
      onAutoStopped: () => stopRecording(),
    );
    if (isDisposed) {
      await _voiceCapture.cancelRecording();
      return false;
    }
    if (!started) {
      _clearActive();
      return false;
    }
    _activeState = VoiceSectionState.recording;
    _notify();
    return true;
  }

  /// Stops the active capture and lands the transcript in its card.
  /// Returns false when transcription failed (card untouched, typable).
  Future<bool> stopRecording() async {
    final section = _activeSection;
    if (section == null || _activeState != VoiceSectionState.recording) {
      return false;
    }
    _activeState = VoiceSectionState.transcribing;
    _notify();

    final transcript = await _voiceCapture.stopAndTranscribe();
    if (isDisposed) return false;
    if (transcript != null) {
      // Re-dictation replaces the section — "gör om bara ingredienserna"
      // is one tap, the whole point of direction B.
      _texts[section] = transcript;
    }
    _clearActive();
    return transcript != null;
  }

  Future<void> cancelRecording() async {
    if (_activeSection == null) return;
    await _voiceCapture.cancelRecording();
    if (isDisposed) return;
    _clearActive();
  }

  /// Assembles the canonical recipe text and runs the voice import path
  /// (rate-limited + telemetry-tagged 'voice'). The caller navigates on
  /// the returned result.
  Future<ImportManagerResult?> importRecipe() async {
    if (!canImport) return null;
    setLoading(true);
    setError(null);

    try {
      final assembled = assembleRecipeText(
        title: _texts[VoiceImportSection.title]!,
        ingredientsTranscript: _texts[VoiceImportSection.ingredients]!,
        stepsTranscript: _texts[VoiceImportSection.steps]!,
      );
      final result = await _importManager.importVoiceTranscript(assembled);
      if (!result.isSuccess && !result.needsAssistance) {
        setError(result.error);
      }
      return result;
    } finally {
      setLoading(false);
    }
  }

  void _clearActive() {
    _activeSection = null;
    _activeState = VoiceSectionState.idle;
    _notify();
  }

  void _notify() {
    if (!isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    // Only abandon a capture THIS viewmodel started — the service is a
    // shared singleton and another surface may own the active capture.
    if (_activeSection != null) {
      _voiceCapture.cancelRecording();
    }
    super.dispose();
  }
}
