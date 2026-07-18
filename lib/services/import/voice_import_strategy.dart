import 'package:clock/clock.dart';

import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/parsing/feedback/import_correction_snapshot.dart';

/// Import strategy for voice-dictated recipes (guided sections, on-device
/// KB-Whisper transcription — see the voice plan).
///
/// Thin by design: the input is the ALREADY-ASSEMBLED canonical recipe
/// text from voice_transcript_assembler.dart, and parsing is delegated to
/// [TextImportStrategy]. The strategy exists so voice gets its own
/// identity end-to-end (Data/Integrations panel condition): the 'Voice
/// Import' name maps to parse_events source 'voice', and the recipe's
/// provenance is stamped [SourceArtefactType.voiceDictation] — dictated
/// recipes must never pollute the pasted-text telemetry bucket.
class VoiceImportStrategy implements ImportStrategy {
  VoiceImportStrategy({TextImportStrategy? textStrategy})
    : _textStrategy = textStrategy ?? TextImportStrategy();

  final TextImportStrategy _textStrategy;

  @override
  String get strategyName => 'Voice Import';

  @override
  String get description =>
      'Voice-dictated recipe (on-device Swedish transcription)';

  @override
  String get inputExample =>
      'Köttbullar\n\nIngredienser:\n500 g köttfärs\n...\n\nGör så här:\n...';

  /// Never auto-selected: voice input is explicitly launched from its own
  /// UI (mirrors FileImportStrategy's picker-driven pattern). autoImport's
  /// fallback loop must not claim arbitrary pasted text as "voice".
  @override
  bool canHandle(String input) => false;

  @override
  bool validateInput(String input) => input.trim().isNotEmpty;

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    final result = await _textStrategy.import(input, options: options);
    if (!result.isSuccess || result.recipe == null) return result;

    // Override the text strategy's textPaste artefact: the transcript is
    // the practical re-extract source (audio is never stored), same
    // pattern as PhotoImportStrategy's photoOcr override (BUT-922).
    final recipe = result.recipe!.copyWith(
      sourceArtefact: SourceArtefact(
        type: SourceArtefactType.voiceDictation,
        payload: input,
        fetchedAt: clock.now(),
      ),
    );

    // BUT-1469: re-tag the correction snapshot the inner text strategy stored
    // as `voice` (same recipe id — copyWith preserves it — so this overwrites),
    // keeping dictation corrections out of the pasted-text training bucket.
    ImportCorrectionSnapshot.capture(recipe, source: ImportSource.voice);

    return ImportResult.success(
      recipe,
      warnings: result.warnings,
      metadata: result.metadata,
    );
  }
}
