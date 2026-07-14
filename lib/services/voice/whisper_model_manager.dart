import 'package:butlery/services/parsing/_expected_model_hashes.dart';
import 'package:butlery/services/parsing/versioned_model_manager.dart';

/// Manages download, caching, and versioning of the KB-Whisper Swedish
/// speech-to-text model (GGML format, executed by whisper.cpp).
///
/// Same delivery contract as the parsing models — the shared flow lives in
/// [VersionedModelManager]. Two family specifics: a GGML file is
/// self-contained (no sidecars), and downloads are USER-initiated (mic
/// tap), so a failed download must NOT arm the 12h check throttle — the
/// user's next tap simply retries ([armThrottleOnFailedDownload]).
///
/// File layout in Firebase Storage:
///   models/whisper_sv/v{N}/ggml-model.bin
///   models/whisper_sv/latest_version.txt
///
/// Local cache layout:
///   {appSupportDir}/whisper_model/ggml-model.bin
///   {appSupportDir}/whisper_model/version.txt
class WhisperModelManager extends VersionedModelManager<WhisperModelFile> {
  WhisperModelManager({super.storage});

  @override
  String get serviceName => 'WhisperModelManager';

  @override
  String get localDirName => 'whisper_model';

  @override
  Duration get checkInterval => const Duration(hours: 12);

  @override
  String get storageBasePath => 'models/whisper_sv';

  @override
  String get modelFileName => 'ggml-model.bin';

  /// The speech model is far bigger than the 25 MB parsing models:
  /// kb-whisper-base q5_0 is 55.3 MB; 80 MB leaves headroom for a q8
  /// variant without permitting a silent jump to `small` (190 MB), which
  /// would be a deliberate product decision, not a version bump.
  @override
  int get maxModelSize => 80 * 1024 * 1024;

  @override
  Map<int, String> get hashRegistry => kExpectedWhisperModelHashes;

  @override
  String get modelName => 'whisper_sv';

  @override
  String get registryConstantName => 'kExpectedWhisperModelHashes';

  /// Downloads here are user-initiated (mic tap): a transient failure
  /// (offline, Storage hiccup) must not brick the voice feature until app
  /// restart. Only success arms the throttle.
  @override
  bool get armThrottleOnFailedDownload => false;

  @override
  WhisperModelFile buildResult({
    required String modelPath,
    required Map<String, String> sidecarContents,
    required int version,
  }) => WhisperModelFile(modelPath: modelPath, version: version);
}

/// Path and version of a locally cached KB-Whisper model.
class WhisperModelFile {
  /// Path to the GGML model file on disk (whisper.cpp reads it directly).
  final String modelPath;

  /// Model version number.
  final int version;

  const WhisperModelFile({required this.modelPath, required this.version});
}
