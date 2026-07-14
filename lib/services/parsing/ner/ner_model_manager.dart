import 'package:butlery/services/parsing/_expected_model_hashes.dart';
import 'package:butlery/services/parsing/versioned_model_manager.dart';

/// Manages download, caching, and versioning of the BERT NER ONNX model.
///
/// The shared flow (download → SHA-256 fail-close verify → cache →
/// throttled version checks) lives in [VersionedModelManager]; this class
/// only declares the family: paths, caps, registry, and the WordPiece
/// vocab sidecar.
///
/// File layout in Firebase Storage:
///   models/ingredient_ner/v{N}/model.onnx
///   models/ingredient_ner/v{N}/vocab.txt
///
/// Local cache layout:
///   {appSupportDir}/ner_model/model.onnx
///   {appSupportDir}/ner_model/vocab.txt
///   {appSupportDir}/ner_model/version.txt
class NerModelManager extends VersionedModelManager<NerModelFiles> {
  static const _vocabFileName = 'vocab.txt';

  NerModelManager({super.storage});

  @override
  String get serviceName => 'NerModelManager';

  @override
  String get localDirName => 'ner_model';

  @override
  Duration get checkInterval => const Duration(hours: 12);

  @override
  String get storageBasePath => 'models/ingredient_ner';

  @override
  String get modelFileName => 'model.onnx';

  /// 25 MB safety limit — the BERT NER graph is ~20 MB.
  @override
  int get maxModelSize => 25 * 1024 * 1024;

  @override
  Map<int, String> get hashRegistry => kExpectedNerModelHashes;

  @override
  String get modelName => 'ingredient_ner';

  @override
  String get registryConstantName => 'kExpectedNerModelHashes';

  @override
  List<ModelSidecarSpec> get sidecars => const [
    ModelSidecarSpec(fileName: _vocabFileName, maxSize: 5 * 1024 * 1024),
  ];

  @override
  NerModelFiles buildResult({
    required String modelPath,
    required Map<String, String> sidecarContents,
    required int version,
  }) => NerModelFiles(
    modelPath: modelPath,
    vocabContent: sidecarContents[_vocabFileName]!,
    version: version,
  );
}

/// Paths and content for a downloaded NER model.
class NerModelFiles {
  /// Path to the ONNX model file on disk.
  final String modelPath;

  /// Content of vocab.txt for the WordPiece tokenizer.
  final String vocabContent;

  /// Model version number.
  final int version;

  const NerModelFiles({
    required this.modelPath,
    required this.vocabContent,
    required this.version,
  });
}
