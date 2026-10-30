import 'dart:async';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/import/import_event.dart';
import 'package:butlery/services/import/import_manager_result.dart';
import 'package:butlery/services/llm/llm_service.dart';

/// Offers a finished import to the server's parser shadow comparison
/// (ADR-0037), which may ask the AI for a reference parse of the same input.
///
/// Whether a sample is actually taken is decided on the server (rate, budget,
/// kill switch, consent). This side only avoids sending what the server would
/// refuse anyway, and it never lets the import wait for, or fail on, a sample.
class ParserShadowSampler extends BaseService {
  @override
  String get serviceName => 'ParserShadowSampler';

  final ConsentService _consentService;
  final LlmService _llmService;
  final bool Function() _isGuest;
  final Duration _timeout;

  ParserShadowSampler({
    required ConsentService consentService,
    required LlmService llmService,
    bool Function()? isGuest,
    Duration timeout = const Duration(seconds: 30),
  }) : _consentService = consentService,
       _llmService = llmService,
       _isGuest = isGuest ?? (() => false),
       _timeout = timeout;

  /// The server's label check; a label that would fail it is left out
  /// rather than costing the whole sample.
  static final RegExp _label = RegExp(r'^[A-Za-z0-9_.-]{1,40}$');

  /// The server's channel per import channel.
  static const Map<ImportChannel, String> _channelFor = {
    ImportChannel.text: 'text',
    ImportChannel.photo: 'photo',
    ImportChannel.link: 'link',
  };

  /// The server refuses longer text, so such a call is not made.
  static const int _maxTextChars = 50000;

  /// The artefact types whose payload is the text the parser read. OCR text
  /// the photo flow hands to `autoParseMulti` carries `textPaste`, so the
  /// type cannot name the channel.
  static const Set<SourceArtefactType> _textCaptures = {
    SourceArtefactType.textPaste,
    SourceArtefactType.photoOcr,
  };

  /// Returns whether the server took a sample. Never throws.
  Future<bool> sample(ImportChannel channel, ImportManagerResult result) async {
    try {
      return await _sample(channel, result).timeout(_timeout);
    } catch (e) {
      AppLogger.debug('ParserShadowSampler: skipped - $e');
      return false;
    }
  }

  Future<bool> _sample(
    ImportChannel channel,
    ImportManagerResult result,
  ) async {
    final recipe = result.recipe;
    if (!result.isSuccess || recipe == null) return false;
    final payload = shadowPayload(channel, recipe, result.metadata);
    if (payload == null) return false;
    if (_isGuest()) return false;
    if (!await _consentService.hasConsent(ConsentPurpose.aiProcessing)) {
      return false;
    }
    return _llmService.shadowCompareImport(payload);
  }

  /// The callable's payload, or null when the import kept no comparable text.
  static Map<String, dynamic>? shadowPayload(
    ImportChannel importChannel,
    Recipe recipe,
    Map<String, dynamic>? metadata,
  ) {
    final channel = _channelFor[importChannel];
    final artefact = recipe.core.sourceArtefact;
    if (channel == null || artefact == null) return null;
    final meta = metadata ?? const <String, dynamic>{};
    final String text;
    if (_textCaptures.contains(artefact.type)) {
      text = artefact.payload;
    } else if (artefact.type == SourceArtefactType.url) {
      // A link import's artefact is the URL; the page text it read rides in
      // the metadata. A recipe the AI answered has no parse to compare.
      final pageText = meta['pageText'];
      if (pageText is! String || meta['successfulTier'] == 'LLM') return null;
      text = pageText;
    } else {
      return null;
    }
    if (text.trim().isEmpty || text.length > _maxTextChars) return null;

    String? label(Object? v) => v is String && _label.hasMatch(v) ? v : null;
    return {
      'text': text,
      'parserOutput': parserOutputOf(recipe),
      'channel': channel,
      'successfulTier': ?label(meta['successfulTier']),
      'parserVersion': ?label(meta['parserVersion']),
      if (channel == 'photo') 'photoAiFallback': meta['usedLlm'] == true,
    };
  }

  /// The one adapter from the app's recipe to the corpus GoldRecipe shape
  /// (`tools/corpus/corpus_models.dart`), so both sides are scored alike.
  static Map<String, dynamic> parserOutputOf(Recipe recipe) {
    // One entry per ingredient line; lines without parsed parts fall back
    // to the line itself, which is what the corpus gold does too.
    final ingredients = [
      for (final i in recipe.structuredIngredients)
        {
          'name': i.name,
          'originalLine': i.raw,
          if (i.amount != null) 'quantity': _formatAmount(i.amount!),
          'unit': ?i.unit,
          'preparation': ?i.note,
        },
    ];
    return {
      'title': recipe.title,
      if (recipe.portions != null) 'portions': '${recipe.portions}',
      'timeMinutes': ?recipe.timeMinutes,
      'ingredients': ingredients,
      'instructions': recipe.instructions,
    };
  }

  static String _formatAmount(num amount) =>
      amount == amount.roundToDouble() ? '${amount.toInt()}' : '$amount';
}
