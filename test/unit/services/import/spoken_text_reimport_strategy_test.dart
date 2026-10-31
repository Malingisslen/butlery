import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/import/spoken_text_reimport_strategy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

class _RecordingLlm extends Fake implements LlmEnhancementService {
  _RecordingLlm(this.answer);
  final ImportResultV2 answer;
  final List<String> transcripts = [];
  final List<String> urls = [];

  @override
  Future<ImportResultV2> extractFromTranscript(
    String transcript,
    String url, {
    String? videoTitle,
  }) async {
    transcripts.add(transcript);
    urls.add(url);
    return answer;
  }
}

void main() {
  test('the saved text and the post it came from reach the AI read, and its '
      'recipe comes back with the AI use marked', () async {
    final recipe = RecipeFactory.build(id: 'r1', title: 'Krämig pasta');
    final llm = _RecordingLlm(
      ImportSuccess(
        recipe: recipe,
        confidence: 0.8,
        pipeline: 'tiktok',
        tier: 1,
        method: 'llm',
        usedLlm: true,
      ),
    );

    final r = await SpokenTextReimportStrategy(llm: llm).import(
      'gör en god pasta med lite grädde',
      options: {'sourceUrl': 'https://www.tiktok.com/@a/video/1'},
    );

    expect(llm.transcripts, ['gör en god pasta med lite grädde']);
    expect(llm.urls, ['https://www.tiktok.com/@a/video/1']);
    expect(r.isSuccess, isTrue);
    expect(r.recipe?.title, 'Krämig pasta');
    expect(r.metadata?['usedLlm'], isTrue);
  });

  test('without a source link the AI read gets an empty link', () async {
    final llm = _RecordingLlm(
      const ImportFailure(
        message: 'inget recept',
        errorCode: ImportErrorCode.noRecipeContent,
      ),
    );

    final r = await SpokenTextReimportStrategy(llm: llm).import('pasta');

    expect(llm.urls, ['']);
    expect(r.isSuccess, isFalse);
  });

  test('it is never picked for an input on its own', () {
    expect(
      SpokenTextReimportStrategy(
        llm: _RecordingLlm(
          const ImportFailure(message: '', errorCode: ImportErrorCode.unknown),
        ),
      ).canHandle('https://www.tiktok.com/@a/video/1'),
      isFalse,
    );
  });
}
