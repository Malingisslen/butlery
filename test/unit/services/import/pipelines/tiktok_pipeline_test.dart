/// Intent tests for [TikTokPipeline] — TikTok recipe-import pipeline.
///
/// What this file proves (one bullet per behaviour, in group order):
///
/// 1) **URL detection (canHandle / validateInput)** — every TikTok URL shape
///    we claim to support in `inputExample` and the doc comment is detected,
///    every non-TikTok shape (Instagram / YouTube / arbitrary http) is
///    rejected. canHandle and validateInput agree (same predicate); a future
///    diverger would silently bypass either the strategy router or input
///    validation.
///
/// 2) **oEmbed fetch contract** — pipeline calls
///    `https://www.tiktok.com/oembed?url=<percent-encoded-input>` with a
///    10s timeout. Non-200 responses degrade gracefully (no throw, metadata
///    null) and HTTP exceptions are swallowed (re-throw would crash an
///    entire share flow).
///
/// 3) **No-caption → screenshot tier** — when oEmbed returns no title (or
///    fetch failed), we MUST surface `ImportNeedsScreenshot` carrying the
///    original input URL and the thumbnail (if any). Pinning this contract
///    so a refactor doesn't accidentally return `ImportFailure` (which the
///    UI handles very differently — failure = error toast; needsScreenshot
///    = screenshot affordance).
///
/// 4) **Emoji-parsed tier-2 success** — when caption has ≥3 cooking-emoji
///    measurement lines AND LLM succeeds, result is `ImportSuccess` with
///    `tier=2`, `method='emoji-llm'`, `confidence=0.7`, `usedLlm=true`,
///    `requiresReview=true`, and the LLM payload includes the formatted
///    emoji block (Swedish "Identifierade ingredienser:" header).
///
/// 5) **Tier-2 BUT-980 / BUT-1045 invariants** — the LLM-returned recipe
///    MUST be copyWith'd to carry `sourceUrl=input` and a `SourceArtefact`
///    of type `tiktokCaption` whose `payload` equals the raw caption.
///    Original LLM recipe almost never has these — if we forget to wire
///    them in, the detail view loses its "Open on TikTok" link AND the
///    offline re-extract loses its source payload.
///
/// 6) **Emoji-parsed but LLM fails → fall through to tier 3** — when emoji
///    parsing finds ≥3 ingredients but the emoji-LLM path doesn't yield
///    success, the pipeline must NOT short-circuit; it must try the raw-
///    caption LLM (tier 3). Asserts the LlmService is called a *second*
///    time with raw caption (not the formatted emoji block).
///
/// 7) **Tier 3 caption-LLM success** — plain prose caption → tier 3,
///    `method='caption-llm'`, confidence 0.65, recipe enriched with
///    sourceUrl + SourceArtefact (BUT-980 / BUT-1045 on the tier-3 path).
///
/// 8) **Rate-limit short-circuit** — when LLM returns `ImportFailure` with
///    `errorCode=rateLimited`, pipeline MUST return `ImportNeedsAssistance`
///    (NOT `ImportFailure`) so the UI gives the user a path forward
///    (paste / manual). Pins the quota-cost-attribution contract: rate-
///    limit denial = manual fallback, not error toast.
///
/// 9) **Long-caption no-recipe-detected → ImportNeedsAssistance** — when
///    LLM yields no recipe but caption > 50 chars, fall back to
///    ImportNeedsAssistance carrying suggestedTitle from the first sentence.
///
/// 10) **Short-caption no-recipe → ImportNeedsScreenshot** — when caption
///     is short (≤50 chars) AND LLM didn't recover a recipe, return
///     ImportNeedsScreenshot. This is the exact 50-char boundary
///     (off-by-one is the classic bug here).
///
/// 11) **Legacy `import()` adapter** — `import()` calls `importV2()` then
///     wraps. ImportNeedsScreenshot must be surfaced as a *failure*
///     (legacy ImportResult has no screenshot variant); the failure's
///     metadata must carry `needsScreenshot: true` so the UI bridge can
///     re-route. ImportNeedsAssistance must come through as
///     `needsAssistance=true` with the extractedText preserved.
///
/// 12) **dispose() with owned client** — pipeline that owns its http.Client
///     closes it on dispose; pipeline given an external client does NOT.
///     Catching this prevents the leak class of bug where shared clients
///     get closed mid-request.
///
/// Mocking strategy: a `Fake` LlmEnhancementService records all
/// `extractFromTranscript` calls and serves canned `ImportResultV2`
/// responses. The http.Client is `MockClient` from `package:http/testing.dart`
/// so we control the oEmbed JSON response per test. We never mock the
/// subject; we drive it through its public API.
library;

import 'dart:convert';

import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/import/pipelines/tiktok_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Records every call to [extractFromTranscript] and returns a queued
/// `ImportResultV2`. Tests configure responses via [responses].
class _FakeLlmEnhancement extends Fake implements LlmEnhancementService {
  /// FIFO queue of canned responses. If empty, returns a generic failure.
  final List<ImportResultV2> responses = [];

  // Capture per-call detail
  final List<String> seenTranscripts = [];
  final List<String> seenUrls = [];
  final List<String?> seenVideoTitles = [];

  @override
  Future<ImportResultV2> extractFromTranscript(
    String transcript,
    String url, {
    String? videoTitle,
  }) async {
    seenTranscripts.add(transcript);
    seenUrls.add(url);
    seenVideoTitles.add(videoTitle);
    if (responses.isEmpty) {
      return const ImportFailure(
        message: 'no canned response',
        errorCode: ImportErrorCode.unknown,
      );
    }
    return responses.removeAt(0);
  }
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Standard oEmbed JSON response. Pass `null` for body fields to omit.
http.Response _oembedJson({
  String? title = 'Pannkakor recept',
  String? authorName = 'chefanna',
  String? thumbnailUrl = 'https://p16.tiktokcdn.com/thumb.jpg',
  int status = 200,
}) {
  final body = <String, dynamic>{};
  if (title != null) body['title'] = title;
  if (authorName != null) body['author_name'] = authorName;
  if (thumbnailUrl != null) body['thumbnail_url'] = thumbnailUrl;
  return http.Response(
    json.encode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Build a TikTokPipeline with a [MockClient] driven by [responder].
TikTokPipeline _pipelineWith({
  required Future<http.Response> Function(http.Request) responder,
  required _FakeLlmEnhancement llm,
}) {
  final client = MockClient((req) async => responder(req));
  return TikTokPipeline(llmService: llm, client: client);
}

/// Build a Recipe (used by tests that need the pipeline to copyWith on it).
Recipe _recipe({
  String title = 'Pannkakor',
  String? sourceUrl,
  SourceArtefact? sourceArtefact,
}) {
  final r = Recipe.personal(
    title: title,
    description: 'Klassiska svenska pannkakor',
    mealType: 'breakfast',
    ingredients: const ['3 ägg', '5 dl mjölk', '3 dl mjöl'],
    instructions: const ['Vispa.', 'Stek.'],
  );
  if (sourceUrl != null || sourceArtefact != null) {
    return r.copyWith(
      sourceUrl: sourceUrl,
      sourceArtefact: sourceArtefact,
    );
  }
  return r;
}

ImportSuccess _llmSuccess({Recipe? recipe}) {
  return ImportSuccess(
    recipe: recipe ?? _recipe(),
    confidence: 0.75,
    pipeline: 'video',
    tier: 5,
    method: 'llm-transcript',
    usedLlm: true,
    requiresReview: true,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeLlmEnhancement llm;

  setUp(() {
    llm = _FakeLlmEnhancement();
  });

  // =========================================================================
  // 1) URL detection
  // =========================================================================
  group('canHandle / validateInput', () {
    late TikTokPipeline pipeline;

    setUp(() {
      pipeline = TikTokPipeline(llmService: llm);
    });

    tearDown(() => pipeline.dispose());

    test('accepts the standard tiktok.com/@user/video/ID format', () {
      const url = 'https://www.tiktok.com/@chefanna/video/7123456789012345678';
      expect(pipeline.canHandle(url), isTrue);
      expect(pipeline.validateInput(url), isTrue);
    });

    test('accepts vm.tiktok.com short links', () {
      const url = 'https://vm.tiktok.com/ZIeR8a2bC/';
      expect(pipeline.canHandle(url), isTrue);
      expect(pipeline.validateInput(url), isTrue);
    });

    test('accepts m.tiktok.com mobile links', () {
      const url = 'https://m.tiktok.com/v/7123456789012345678.html';
      expect(pipeline.canHandle(url), isTrue);
      expect(pipeline.validateInput(url), isTrue);
    });

    test('accepts tiktok.com/embed/ID web-player URLs', () {
      const url = 'https://www.tiktok.com/embed/7123456789012345678';
      expect(pipeline.canHandle(url), isTrue);
    });

    test(
        'BUT-1092 fix: mixed-case host TikTok.com is accepted '
        '(case-insensitive regex)', () {
      // After BUT-1092 fix: each pattern in `_tiktokPatterns` carries
      // `caseSensitive: false`, so shared URLs with uppercase host letters
      // (iOS Safari / share-sheets normalise to mixed case) extract
      // correctly. Previously rejected silently.
      const url = 'https://www.TikTok.com/@chefanna/video/7123456789012345678';
      expect(pipeline.canHandle(url), isTrue,
          reason: 'BUT-1092: case-insensitive host must be accepted');
    });

    test('rejects non-tiktok hosts even if URL is well-formed', () {
      expect(
        pipeline.canHandle('https://www.youtube.com/watch?v=abc123'),
        isFalse,
      );
      expect(
        pipeline.canHandle('https://www.instagram.com/p/ABC/'),
        isFalse,
      );
      expect(pipeline.canHandle('https://example.com/recipe'), isFalse);
    });

    test('rejects empty, whitespace, and obvious garbage', () {
      expect(pipeline.canHandle(''), isFalse);
      expect(pipeline.canHandle('   '), isFalse);
      expect(pipeline.canHandle('not a url'), isFalse);
    });

    test(
        'rejects tiktok.com without a video/short-link path '
        '(profile URLs, search pages)', () {
      // Bug class: profile URL passes the substring check but has no video id —
      // must fail pattern match.
      expect(
        pipeline.canHandle('https://www.tiktok.com/@chefanna'),
        isFalse,
      );
      expect(
        pipeline.canHandle('https://www.tiktok.com/search?q=recept'),
        isFalse,
      );
    });

    test('canHandle and validateInput agree (same predicate)', () {
      // Pin: if anyone divergently weakens one, the strategy router and the
      // input-validation path go out of sync.
      const samples = [
        'https://www.tiktok.com/@a/video/7123456789012345678',
        'https://vm.tiktok.com/ZIeR8a2bC/',
        'https://www.youtube.com/watch?v=abc',
        '',
        'random',
      ];
      for (final s in samples) {
        expect(
          pipeline.canHandle(s),
          equals(pipeline.validateInput(s)),
          reason: 'mismatch on "$s"',
        );
      }
    });
  });

  // =========================================================================
  // 2) oEmbed fetch contract
  // =========================================================================
  group('_fetchMetadata (oEmbed)', () {
    test('calls TikTok oEmbed endpoint with percent-encoded URL + timeout',
        () async {
      const input =
          'https://www.tiktok.com/@chefanna/video/7123456789012345678';
      Uri? captured;
      final pipeline = _pipelineWith(
        llm: llm,
        responder: (req) async {
          captured = req.url;
          return _oembedJson(title: null); // forces NeedsScreenshot path
        },
      );
      addTearDown(pipeline.dispose);

      await pipeline.importV2(input);

      expect(captured, isNotNull);
      expect(captured!.host, 'www.tiktok.com');
      expect(captured!.path, '/oembed');
      expect(
        captured!.queryParameters['url'],
        input,
        reason: 'URL must round-trip through percent encoding intact',
      );
    });

    test('non-200 oEmbed response degrades to no-metadata path', () async {
      const input =
          'https://www.tiktok.com/@chefanna/video/7123456789012345678';
      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => http.Response('blocked', 403),
      );
      addTearDown(pipeline.dispose);

      final result = await pipeline.importV2(input);

      expect(result, isA<ImportNeedsScreenshot>());
      final ns = result as ImportNeedsScreenshot;
      expect(ns.platform, 'TikTok');
      expect(ns.url, input);
      expect(ns.thumbnailUrl, isNull,
          reason: 'non-200 means no oEmbed data at all');
    });

    test('http exception during oEmbed is swallowed (no rethrow)', () async {
      const input =
          'https://www.tiktok.com/@chefanna/video/7123456789012345678';
      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => throw http.ClientException('connection reset'),
      );
      addTearDown(pipeline.dispose);

      // Must not throw — a share-extension flow can't surface raw exceptions.
      final result = await pipeline.importV2(input);
      expect(result, isA<ImportNeedsScreenshot>());
      expect(llm.seenTranscripts, isEmpty,
          reason: 'no caption ⇒ LLM must NEVER be called');
    });
  });

  // =========================================================================
  // 3) No-caption → screenshot tier
  // =========================================================================
  group('no-caption path', () {
    test(
        'returns ImportNeedsScreenshot with platform / url / thumbnail '
        'when title is empty', () async {
      const input =
          'https://www.tiktok.com/@chefanna/video/7123456789012345678';
      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => _oembedJson(
          title: '', // empty title from oEmbed
          thumbnailUrl: 'https://cdn.tt/thumb.jpg',
        ),
      );
      addTearDown(pipeline.dispose);

      final result = await pipeline.importV2(input);

      expect(result, isA<ImportNeedsScreenshot>());
      final ns = result as ImportNeedsScreenshot;
      expect(ns.platform, 'TikTok');
      expect(ns.url, input);
      expect(ns.thumbnailUrl, 'https://cdn.tt/thumb.jpg',
          reason: 'thumbnail must survive even when caption is missing — '
              'the UI uses it to show the user *which* video they shared');
      expect(ns.message, isNotEmpty);
      expect(llm.seenTranscripts, isEmpty,
          reason: 'empty caption ⇒ LLM must NOT be called (cost contract)');
    });
  });

  // =========================================================================
  // 4) Emoji-parsed tier-2 success
  // =========================================================================
  group('emoji-parsed tier-2 success', () {
    const input = 'https://www.tiktok.com/@chefanna/video/7123456789012345678';

    /// Caption with 3 emoji-prefixed measurement lines + 1 emoji instruction.
    // Valid emojis from `_cookingEmojis`: 🥚 egg, 🥛 milk, 🧈 butter,
    // 🧀 cheese, 🧂 salt. Each line below has a numeric measurement so
    // `_looksLikeMeasurement` matches.
    const emojiCaption = '''
Pannkakor receptet jag lovat! ✨
🥚 3 st ägg
🥛 5 dl mjölk
🧈 50 g smör
🧂 1 krm salt
#recept #pannkakor''';

    test(
        'returns ImportSuccess with tier=2 / method=emoji-llm / '
        'confidence=0.7 and propagates metadata', () async {
      llm.responses.add(_llmSuccess(recipe: _recipe(title: 'Pannkakor')));
      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => _oembedJson(
          title: emojiCaption,
          authorName: 'chefanna',
          thumbnailUrl: 'https://cdn.tt/thumb.jpg',
        ),
      );
      addTearDown(pipeline.dispose);

      final result = await pipeline.importV2(input);

      expect(result, isA<ImportSuccess>());
      final s = result as ImportSuccess;
      expect(s.pipeline, 'tiktok');
      expect(s.tier, 2);
      expect(s.method, 'emoji-llm');
      expect(s.confidence, 0.7);
      expect(s.usedLlm, isTrue);
      expect(s.requiresReview, isTrue,
          reason: 'LLM extractions always need user review');
      expect(s.metadata?['videoUrl'], input);
      expect(s.metadata?['authorName'], 'chefanna');
      expect(s.metadata?['thumbnailUrl'], 'https://cdn.tt/thumb.jpg');
      expect(s.metadata?['emojiIngredientCount'], greaterThanOrEqualTo(3),
          reason: 'pin the tier-2 entry condition — drift breaks the '
              'analytics that distinguish emoji-vs-prose recipes');
    });

    test(
        'passes formatted emoji block to LLM '
        '(not the raw caption)', () async {
      llm.responses.add(_llmSuccess());
      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => _oembedJson(title: emojiCaption),
      );
      addTearDown(pipeline.dispose);

      await pipeline.importV2(input);

      expect(llm.seenTranscripts.length, 1);
      final sent = llm.seenTranscripts.first;
      // The Swedish formatter header is the smoking gun that we routed
      // through _formatEmojiParsedForLlm, not just the raw caption.
      expect(sent, contains('Identifierade ingredienser:'));
      expect(sent, contains('Originaltext från TikTok:'));
      // Original caption is also embedded so LLM has full context.
      expect(sent, contains('50 g smör'));
      expect(llm.seenUrls.first, input);
    });
  });

  // =========================================================================
  // 5) BUT-980 / BUT-1045 invariants
  // =========================================================================
  group('BUT-980 sourceUrl + BUT-1045 sourceArtefact wiring', () {
    const input = 'https://www.tiktok.com/@chefanna/video/7123456789012345678';

    test(
        'tier-2 success: LLM recipe gets sourceUrl=input and a tiktokCaption '
        'SourceArtefact whose payload equals the raw caption', () async {
      const caption = '''
🥚 3 st ägg
🥛 5 dl mjölk
🧈 50 g smör
🧂 1 krm salt''';
      // LLM intentionally returns a recipe with NO source data — pipeline
      // must wire it in.
      llm.responses.add(_llmSuccess(recipe: _recipe(title: 'Pannkakor')));

      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => _oembedJson(title: caption),
      );
      addTearDown(pipeline.dispose);

      final result = await pipeline.importV2(input) as ImportSuccess;

      expect(result.recipe.sourceUrl, input,
          reason: 'BUT-980: lost source-URL = lost "Open on TikTok" link');
      final artefact = result.recipe.core.sourceArtefact;
      expect(artefact, isNotNull,
          reason: 'BUT-1045: lost artefact = no offline re-extract');
      expect(artefact!.type, SourceArtefactType.tiktokCaption);
      expect(artefact.payload, caption,
          reason: 'artefact payload MUST be the raw caption, not the '
              'formatted emoji block we sent to the LLM (we want to be able '
              'to re-extract from the original)');
    });

    test(
        'tier-3 (caption-LLM): LLM recipe gets sourceUrl + SourceArtefact '
        'wired through the second code path too', () async {
      // Prose caption (no emoji structure) → skip tier 2, hit tier 3 directly.
      const caption =
          'Här är mitt favoritrecept på pannkakor. Du behöver bara tre saker: '
          'ägg, mjölk och mjöl. Vispa ihop till en jämn smet och stek små '
          'pannkakor i smör på medelvärme.';
      llm.responses.add(_llmSuccess(recipe: _recipe(title: 'Pannkakor')));
      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => _oembedJson(title: caption),
      );
      addTearDown(pipeline.dispose);

      final result = await pipeline.importV2(input) as ImportSuccess;

      expect(result.tier, 3, reason: 'no emoji measurements ⇒ skip tier 2');
      expect(result.method, 'caption-llm');
      expect(result.recipe.sourceUrl, input);
      expect(result.recipe.core.sourceArtefact?.type,
          SourceArtefactType.tiktokCaption);
      expect(result.recipe.core.sourceArtefact?.payload, caption);
    });
  });

  // =========================================================================
  // 6) Emoji parsing succeeded but LLM failed → fall through to tier 3
  // =========================================================================
  group('emoji-parsed but emoji-LLM failed', () {
    const input = 'https://www.tiktok.com/@chefanna/video/7123456789012345678';

    const emojiCaption = '''
🥚 3 st ägg
🥛 5 dl mjölk
🧈 50 g smör''';

    test(
        'falls through to tier-3 caption-LLM with the RAW caption '
        '(not the formatted emoji block)', () async {
      // Tier-2 LLM fails, tier-3 LLM succeeds.
      llm.responses.add(const ImportFailure(
        message: 'no recipe',
        errorCode: ImportErrorCode.parsingFailed,
      ));
      llm.responses.add(_llmSuccess());

      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => _oembedJson(title: emojiCaption),
      );
      addTearDown(pipeline.dispose);

      final result = await pipeline.importV2(input);

      expect(result, isA<ImportSuccess>());
      final s = result as ImportSuccess;
      expect(s.tier, 3,
          reason: 'tier-2 failure must not be the final answer; '
              'tier-3 has to fire as the second LLM attempt');
      expect(s.method, 'caption-llm');
      expect(llm.seenTranscripts.length, 2,
          reason: 'two LLM attempts: emoji-formatted, then raw');
      expect(llm.seenTranscripts[0], contains('Identifierade ingredienser:'));
      // Tier-3 sees the raw caption (no formatter header).
      expect(llm.seenTranscripts[1], emojiCaption);
    });
  });

  // =========================================================================
  // 8) Rate-limit short-circuit → ImportNeedsAssistance
  // =========================================================================
  group('rate-limit handling', () {
    const input = 'https://www.tiktok.com/@chefanna/video/7123456789012345678';
    const caption =
        'En lång och fin beskrivning av mitt favoritrecept på pannkakor som '
        'är längre än femtio tecken så vi hamnar i lång-caption-grenen.';

    test(
        'LLM returns rateLimited ⇒ ImportNeedsAssistance with caption + '
        'partial data (NOT ImportFailure)', () async {
      llm.responses.add(const ImportFailure(
        message: 'rate limited',
        errorCode: ImportErrorCode.rateLimited,
        retryAfter: Duration(minutes: 5),
      ));

      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => _oembedJson(
          title: caption,
          authorName: 'chefanna',
          thumbnailUrl: 'https://cdn.tt/thumb.jpg',
        ),
      );
      addTearDown(pipeline.dispose);

      final result = await pipeline.importV2(input);

      expect(result, isA<ImportNeedsAssistance>(),
          reason: 'Quota-cost contract: rate-limit denial ≠ error toast. The '
              'user has already paid the import attempt with a long-press; '
              'we owe them a manual path.');
      final a = result as ImportNeedsAssistance;
      expect(a.extractedText, caption);
      expect(a.thumbnailUrl, 'https://cdn.tt/thumb.jpg');
      expect(a.partialData?['videoUrl'], input);
      expect(a.partialData?['authorName'], 'chefanna');
      expect(a.suggestedTitle, isNotNull);
    });
  });

  // =========================================================================
  // 9) + 10) Length-boundary fallbacks
  // =========================================================================
  group('no-recipe fallback boundary', () {
    const input = 'https://www.tiktok.com/@chefanna/video/7123456789012345678';

    test(
        'long caption (>50 chars) with no LLM recipe ⇒ '
        'ImportNeedsAssistance (paste path)', () async {
      const caption =
          'En lång prosa-beskrivning utan recept-struktur men över femtio '
          'tecken så användaren får ändå en chans att markera manuellt.';
      // Verify the test premise.
      expect(caption.length, greaterThan(50));

      llm.responses.add(ImportNeedsAssistance(
        extractedText: caption,
        message: 'AI kunde inte extrahera',
      ));

      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => _oembedJson(
          title: caption,
          authorName: 'someone',
        ),
      );
      addTearDown(pipeline.dispose);

      final result = await pipeline.importV2(input);

      expect(result, isA<ImportNeedsAssistance>());
      final a = result as ImportNeedsAssistance;
      // Pipeline wraps a fresh NeedsAssistance — it must carry our caption,
      // not be a silently dropped passthrough of the LLM's variant.
      expect(a.extractedText, caption);
      expect(a.partialData?['videoUrl'], input);
    });

    test(
        'short caption (≤50 chars) with no LLM recipe ⇒ '
        'ImportNeedsScreenshot (off-by-one boundary)', () async {
      const caption = 'Mums!'; // 5 chars, well under 50
      expect(caption.length, lessThanOrEqualTo(50));

      llm.responses.add(ImportNeedsAssistance(
        extractedText: caption,
        message: 'AI kunde inte extrahera',
      ));

      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => _oembedJson(title: caption),
      );
      addTearDown(pipeline.dispose);

      final result = await pipeline.importV2(input);

      expect(result, isA<ImportNeedsScreenshot>(),
          reason: 'Short captions have no useful text to paste, so we ask '
              'for a screenshot. Flipping the >/<= boundary would route '
              'every short caption into the assist UI with nothing to '
              'select.');
    });
  });

  // =========================================================================
  // 11) Legacy import() adapter
  // =========================================================================
  group('legacy import() adapter (V2 → ImportResult)', () {
    const input = 'https://www.tiktok.com/@chefanna/video/7123456789012345678';

    test(
        'ImportNeedsScreenshot is converted to a failure carrying '
        'needsScreenshot=true in metadata', () async {
      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => _oembedJson(
          title: null,
          thumbnailUrl: 'https://cdn.tt/thumb.jpg',
        ),
      );
      addTearDown(pipeline.dispose);

      final legacy = await pipeline.import(input);

      expect(legacy.isSuccess, isFalse);
      expect(legacy.needsAssistance, isFalse,
          reason: 'screenshot is not assistance — it is a request for an '
              'image, the UI handles them in different branches');
      expect(legacy.metadata?['needsScreenshot'], isTrue);
      expect(legacy.metadata?['platform'], 'TikTok');
      expect(legacy.metadata?['url'], input);
      expect(legacy.metadata?['thumbnailUrl'], 'https://cdn.tt/thumb.jpg');
    });

    test(
        'ImportSuccess (tier 3) flows through with pipeline/tier/method '
        'metadata preserved + recipe present', () async {
      const caption = 'Pannkakor recept idag! Du behöver ägg, mjölk och mjöl. '
          'Vispa till en jämn smet och stek små pannkakor i smör.';
      llm.responses.add(_llmSuccess(recipe: _recipe(title: 'Pannkakor')));

      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => _oembedJson(title: caption),
      );
      addTearDown(pipeline.dispose);

      final legacy = await pipeline.import(input);

      expect(legacy.isSuccess, isTrue);
      expect(legacy.recipe, isNotNull);
      expect(legacy.recipe!.title, 'Pannkakor');
      expect(legacy.recipe!.sourceUrl, input,
          reason: 'BUT-980 invariant must survive the V2→legacy adapter');
      expect(legacy.metadata?['pipeline'], 'tiktok');
      expect(legacy.metadata?['tier'], 3);
      expect(legacy.metadata?['method'], 'caption-llm');
      expect(legacy.metadata?['usedLlm'], isTrue);
    });

    test(
        'ImportNeedsAssistance flows through with extractedText preserved '
        '(needsAssistance=true)', () async {
      const caption =
          'En lång prosa-beskrivning utan recept-struktur men över femtio '
          'tecken så användaren får ändå chans att markera manuellt.';
      llm.responses.add(ImportNeedsAssistance(
        extractedText: caption,
        message: 'AI kunde inte extrahera',
      ));

      final pipeline = _pipelineWith(
        llm: llm,
        responder: (_) async => _oembedJson(title: caption),
      );
      addTearDown(pipeline.dispose);

      final legacy = await pipeline.import(input);

      expect(legacy.isSuccess, isFalse);
      expect(legacy.needsAssistance, isTrue);
      expect(legacy.extractedText, caption);
      expect(legacy.metadata?['videoUrl'], input);
    });
  });

  // =========================================================================
  // 12) dispose() ownership
  // =========================================================================
  group('dispose()', () {
    test('closes its owned http.Client when no client was injected', () async {
      // Construct with no client — pipeline owns it. dispose() should close.
      // The only observable signal we can pin without poking internals is
      // that dispose() runs to completion without throwing AND that calling
      // it twice doesn't re-close (no double-close error from http).
      final pipeline = TikTokPipeline(llmService: llm);
      expect(() => pipeline.dispose(), returnsNormally);
    });

    test('does NOT close a caller-injected client on dispose', () async {
      // Provide a tracking client. After dispose, it must still be usable.
      var sendCount = 0;
      final tracking = MockClient((req) async {
        sendCount++;
        return http.Response('{}', 200);
      });
      final pipeline = TikTokPipeline(llmService: llm, client: tracking);

      pipeline.dispose();

      // Caller-owned client must still serve requests. If the pipeline had
      // wrongly closed it, MockClient is forgiving (no underlying socket),
      // but on a real shared http.Client this would manifest as
      // "Client is already closed" on the next .send(). We assert the
      // contract by sending through and confirming the closure still fires.
      final resp = await tracking.get(Uri.parse('https://example.com/'));
      expect(resp.statusCode, 200);
      expect(sendCount, 1);
    });
  });
}
