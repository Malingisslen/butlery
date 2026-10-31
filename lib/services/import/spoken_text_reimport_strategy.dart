import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';

/// Reads a saved caption or video transcript with AI. Only a re-import uses
/// it, and only after the rule-based text parser found no recipe in the same
/// text, so it is never picked for an input on its own.
class SpokenTextReimportStrategy implements ImportStrategy {
  SpokenTextReimportStrategy({required LlmEnhancementService llm}) : _llm = llm;

  final LlmEnhancementService _llm;

  @override
  String get strategyName => 'spoken_text_reimport';

  @override
  bool canHandle(String input) => false;

  @override
  bool validateInput(String input) => input.trim().isNotEmpty;

  @override
  String get inputExample => '';

  @override
  String get description => 'Re-reads a caption or transcript with AI';

  /// [options] `sourceUrl` is the post or video the text came from.
  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    final result = await _llm.extractFromTranscript(
      input,
      (options?['sourceUrl'] as String?).orEmpty(),
    );
    return result.toLegacyResult();
  }
}
