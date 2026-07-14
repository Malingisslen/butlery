import 'package:butlery/services/parsing/_expected_model_hashes.dart';
import 'package:butlery/services/parsing/versioned_model_manager.dart';

/// Manages download, caching, and versioning of the line classifier ONNX
/// model.
///
/// Same family shape as [NerModelManager] — the shared flow lives in
/// [VersionedModelManager]; this class only declares paths, caps, registry,
/// and the vocab sidecar.
///
/// File layout in Firebase Storage:
///   models/line_classifier/v{N}/model.onnx
///   models/line_classifier/v{N}/vocab.txt
///   models/line_classifier/latest_version.txt
class LineClassifierModelManager
    extends VersionedModelManager<LineClassifierModelFiles> {
  static const _vocabFileName = 'vocab.txt';

  LineClassifierModelManager({super.storage});

  @override
  String get serviceName => 'LineClassifierModelManager';

  @override
  String get localDirName => 'line_classifier_model';

  @override
  Duration get checkInterval => const Duration(hours: 12);

  @override
  String get storageBasePath => 'models/line_classifier';

  @override
  String get modelFileName => 'model.onnx';

  /// 25 MB safety limit — the classifier graph is ~20 MB.
  @override
  int get maxModelSize => 25 * 1024 * 1024;

  @override
  Map<int, String> get hashRegistry => kExpectedLineClassifierModelHashes;

  @override
  String get modelName => 'line_classifier';

  @override
  String get registryConstantName => 'kExpectedLineClassifierModelHashes';

  @override
  List<ModelSidecarSpec> get sidecars => const [
    ModelSidecarSpec(fileName: _vocabFileName, maxSize: 5 * 1024 * 1024),
  ];

  @override
  LineClassifierModelFiles buildResult({
    required String modelPath,
    required Map<String, String> sidecarContents,
    required int version,
  }) => LineClassifierModelFiles(
    modelPath: modelPath,
    vocabContent: sidecarContents[_vocabFileName]!,
    version: version,
  );
}

/// Paths and content for a downloaded line classifier model.
class LineClassifierModelFiles {
  final String modelPath;
  final String vocabContent;
  final int version;

  const LineClassifierModelFiles({
    required this.modelPath,
    required this.vocabContent,
    required this.version,
  });
}
