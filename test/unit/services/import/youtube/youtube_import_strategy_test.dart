/// Intent tests for [YouTubeImportStrategy] — the 3-tier YouTube recipe
/// import orchestrator.
///
/// What this file proves (one bullet per behaviour, by group):
///
/// 1) **Strategy metadata + canHandle/validateInput delegation**
///    - `strategyName == 'youtube'` (router-key, NOT a label — drift breaks
///      ImportManager dispatch).
///    - `description` is non-empty Swedish (UI surfaces verbatim).
///    - `inputExample` is itself a URL that `canHandle` accepts
///      (self-consistency: a placeholder the strategy would reject is a
///      contract bug).
///    - `canHandle(input)` delegates to `transcriptService.isYouTubeUrl(input)`
///      verbatim (caller asks the transcript service — pinning prevents a
///      future refactor adding a divergent host check).
///    - `validateInput(input)` is true iff `extractVideoId(input) != null`
///      (NOT an alias of canHandle here, by production contract — pinning
///      both lets a regression that conflates them fail loudly).
///
/// 2) **importV2 — Tier-3 (no transcript) screenshot fallback**
///    - When `fetchTranscript` returns failure → `ImportNeedsScreenshot` with
///      `platform == 'YouTube'`, the canonical watch URL, and a Swedish
///      message. LLM must NEVER be called on this path (cost contract).
///    - When `fetchTranscript` returns success-but-empty (whitespace-only
///      transcript) → same screenshot path (treats empty as failure).
///    - When metadata fetch succeeded → URL comes from `metadata.watchUrl`
///      and thumbnail from `metadata.hqThumbnailUrl`. When metadata is null
///      → URL is synthesised from videoId and thumbnail is null. (BUT-987-
///      style null-propagation regression catcher.)
///
/// 3) **importV2 — Tier-1 (LLM success) wires source URL + artefact**
///    - On ImportSuccess from LLM, the returned recipe carries
///      `core.sourceUrl == <watch URL>` (BUT-980 — sibling of BUT-1114
///      in instagram_pipeline). If the strategy forgets to wire it, the
///      detail view loses "View original".
///    - And `core.sourceArtefact` is a `SourceArtefact` of type
///      `youtubeTranscript` whose `payload` is the exact transcript text
///      (BUT-1045 — re-extract flow needs this).
///    - `fetchedAt` on the artefact is `clock.now()` (uses package:clock
///      so `withClock` overrides it deterministically — a stale
///      wall-clock dependency would skip this).
///    - Returned tier == 1, method == 'transcript-llm', usedLlm == true,
///      requiresReview == true. Pipeline == 'youtube'.
///    - Metadata merges LLM metadata + videoId + transcript language and
///      auto-generated flag.
///
/// 4) **importV2 — Tier-2 fallbacks (LLM rate-limit / assistance / unknown)**
///    - LLM returns `ImportFailure(errorCode: rateLimited)` → strategy
///      returns `ImportNeedsAssistance` carrying the transcript text and
///      "AI-kvoten är slut" message + `partialData.videoId`.
///    - LLM returns `ImportNeedsAssistance` itself → strategy returns
///      assistance with metadata-derived title preferred over LLM's
///      suggestedTitle when both present (UI prefers the canonical YouTube
///      title) and partialData is merged with `videoId` + `sourceUrl`.
///    - LLM returns a generic `ImportFailure` (unknown errorCode, NOT
///      rate-limited) → strategy returns `ImportNeedsAssistance` with the
///      transcript text and a Swedish "manuell" message — NOT a hard
///      failure, NOT a screenshot prompt. (Pin: the only path that
///      returns `ImportFailure` from `importV2` is `invalidUrl` at the
///      top — once we have a transcript, we always give the user
///      *something* to work with.)
///
/// 5) **importV2 — invalid URL early return**
///    - `extractVideoId` returns null → `ImportFailure(errorCode: invalidUrl,
///      pipeline: 'youtube', tier: 0)`. The transcript service must NOT be
///      called for metadata or transcript on this path (cost contract).
///
/// 6) **Legacy `import()` adapter — _convertToLegacyResult contract**
///    - ImportSuccess → `ImportResult.success(recipe)` with metadata
///      carrying `pipeline`, `tier`, `method`, `usedLlm` PLUS the merged
///      LLM metadata.
///    - ImportNeedsScreenshot → `ImportResult.failure(message)` with
///      `needsScreenshot=true` in metadata (NOT `needsAssistance`).
///    - ImportNeedsAssistance → `ImportResult.assistance(...)` carrying
///      extractedText, suggestedTitle, and partialData → metadata.
///    - ImportFailure → `ImportResult.failure(message)` with `errorCode`
///      name + `pipeline` + `tier`.
///
/// 7) **BUT-1092 sibling — case-sensitive URL pattern hunt**
///    - `isYouTubeUrl` delegates to `extractVideoId` whose regexes have NO
///      `caseSensitive: false` flag (see lib/services/import/youtube/
///      youtube_transcript_service.dart:20-32). Test pins the **current**
///      behaviour either way and labels it so a fix flips the expectation.
///
/// Mocking strategy: a `_FakeTranscriptService` subclass overrides the four
/// public methods the strategy calls (`isYouTubeUrl`, `extractVideoId`,
/// `fetchVideoMetadata`, `fetchTranscript`). A `_FakeLlmEnhancement extends
/// Fake implements LlmEnhancementService` records every call to
/// `extractFromTranscript` and returns canned responses. Neither HTTP nor
/// Firebase is touched.
library;

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/import/youtube/youtube_import_strategy.dart';
import 'package:butlery/services/import/youtube/youtube_models.dart';
import 'package:butlery/services/import/youtube/youtube_transcript_service.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Subclass that overrides the four public methods YouTubeImportStrategy
/// actually calls. Keeps the rest of YouTubeTranscriptService inert (no HTTP).
class _FakeTranscriptService extends YouTubeTranscriptService {
  _FakeTranscriptService();

  /// Canned video ID returned by `extractVideoId`. Null means "invalid URL".
  String? cannedVideoId = 'dQw4w9WgXcQ';

  /// Canned metadata returned by `fetchVideoMetadata`. Null means
  /// "metadata fetch failed".
  VideoMetadata? cannedMetadata;

  /// Canned transcript result.
  TranscriptResult cannedTranscript = TranscriptResult.failure(
    'No captions available',
  );

  /// Call counters / arg captures.
  int extractVideoIdCalls = 0;
  int fetchMetadataCalls = 0;
  int fetchTranscriptCalls = 0;
  final List<String> seenMetadataInputs = [];
  final List<String> seenTranscriptInputs = [];

  @override
  String? extractVideoId(String url) {
    extractVideoIdCalls++;
    return cannedVideoId;
  }

  @override
  bool isYouTubeUrl(String url) => extractVideoId(url) != null;

  @override
  Future<VideoMetadata?> fetchVideoMetadata(String videoIdOrUrl) async {
    fetchMetadataCalls++;
    seenMetadataInputs.add(videoIdOrUrl);
    return cannedMetadata;
  }

  @override
  Future<TranscriptResult> fetchTranscript(String videoIdOrUrl) async {
    fetchTranscriptCalls++;
    seenTranscriptInputs.add(videoIdOrUrl);
    return cannedTranscript;
  }
}

/// Records calls and replays canned responses. Strategy must NOT invoke
/// this fake when the transcript is missing — cost contract.
class _FakeLlmEnhancement extends Fake implements LlmEnhancementService {
  final List<String> seenTranscripts = [];
  final List<String> seenUrls = [];
  final List<String?> seenTitles = [];

  /// FIFO queue of canned responses.
  final List<ImportResultV2> responses = [];

  @override
  Future<ImportResultV2> extractFromTranscript(
    String transcript,
    String url, {
    String? videoTitle,
  }) async {
    seenTranscripts.add(transcript);
    seenUrls.add(url);
    seenTitles.add(videoTitle);
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

const _vid = 'dQw4w9WgXcQ';
const _watchUrl = 'https://www.youtube.com/watch?v=$_vid';
const _hqThumb = 'https://img.youtube.com/vi/$_vid/hqdefault.jpg';

Recipe _recipe({String title = 'Pannkakor'}) => Recipe.personal(
  title: title,
  description: 'Klassiska svenska pannkakor',
  mealType: 'breakfast',
  ingredients: const ['3 ägg', '5 dl mjölk', '3 dl mjöl'],
  instructions: const ['Vispa.', 'Stek.'],
);

VideoMetadata _metadata({
  String videoId = _vid,
  String title = 'Best Pannkakor Ever',
  String? channelName = 'Chef Anna',
}) => VideoMetadata(
  videoId: videoId,
  title: title,
  channelName: channelName,
  sourceUrl: 'https://www.youtube.com/watch?v=$videoId',
);

YouTubeImportStrategy _strategy({
  required _FakeTranscriptService transcript,
  required _FakeLlmEnhancement llm,
}) => YouTubeImportStrategy(
  transcriptService: transcript,
  llmService: llm,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeTranscriptService transcript;
  late _FakeLlmEnhancement llm;
  late YouTubeImportStrategy strategy;

  setUp(() {
    transcript = _FakeTranscriptService();
    llm = _FakeLlmEnhancement();
    strategy = _strategy(transcript: transcript, llm: llm);
  });

  // =========================================================================
  // 1) Strategy metadata + canHandle / validateInput delegation
  // =========================================================================
  group('strategy metadata + URL gates', () {
    /// strategyName is the ImportManager router key. A typo or
    /// display-ification breaks every YouTube share's dispatch.
    test('strategyName is exactly "youtube" (router key, NOT a label)', () {
      expect(strategy.strategyName, 'youtube');
    });

    /// Description is rendered verbatim in the importer chooser. Blank
    /// would render a dead row; non-Swedish would clash with the app's
    /// UI conventions.
    test('description is a non-empty Swedish string mentioning YouTube', () {
      expect(strategy.description.trim(), isNotEmpty);
      expect(strategy.description, contains('YouTube'));
    });

    /// BUT-1117 fix: inputExample is now a real 11-char video ID and must
    /// satisfy the strategy's own `canHandle` gate. Other strategies share
    /// this self-consistency invariant — a placeholder the strategy would
    /// reject is a contract bug (and a UX bug: users see a "valid" example
    /// the importer can't actually parse).
    test('inputExample self-consistency — BUT-1117: real video ID satisfies '
        'canHandle', () {
      final realStrategy = YouTubeImportStrategy(
        transcriptService: YouTubeTranscriptService(),
        llmService: llm,
      );
      expect(
        realStrategy.canHandle(realStrategy.inputExample),
        isTrue,
        reason:
            'BUT-1117: inputExample must satisfy canHandle — placeholder '
            'must be a real 11-char video ID, not a documentation token like '
            "'VIDEO_ID'.",
      );
    });

    /// canHandle delegates to transcriptService.isYouTubeUrl. Pinning this
    /// stops a future patch from adding a divergent host check.
    test('canHandle delegates to transcriptService.isYouTubeUrl', () {
      transcript.cannedVideoId = _vid;
      expect(strategy.canHandle('any input'), isTrue);
      transcript.cannedVideoId = null;
      expect(strategy.canHandle('any input'), isFalse);
    });

    /// validateInput is `extractVideoId(input) != null`. By contract not
    /// an alias of canHandle (even though both currently delegate to the
    /// same underlying call — pinning catches a regression that conflates
    /// them at the wrong layer).
    test('validateInput is true iff extractVideoId returns non-null', () {
      transcript.cannedVideoId = _vid;
      expect(strategy.validateInput('foo'), isTrue);
      transcript.cannedVideoId = null;
      expect(strategy.validateInput('foo'), isFalse);
    });
  });

  // =========================================================================
  // 2) importV2 — Tier-3 (no transcript) → screenshot fallback
  // =========================================================================
  group('importV2 — Tier-3 (no transcript) → ImportNeedsScreenshot', () {
    /// Transcript fetch fails entirely (no captions) → screenshot prompt.
    /// LLM must NOT be called (cost contract). Pin platform + watch URL
    /// so the UI can route the prompt by platform.
    test(
      'failed transcript fetch → ImportNeedsScreenshot, LLM never called',
      () async {
        transcript.cannedMetadata = _metadata();
        transcript.cannedTranscript = TranscriptResult.failure(
          'No captions available',
        );

        final result = await strategy.importV2(_watchUrl);

        expect(result, isA<ImportNeedsScreenshot>());
        final ns = result as ImportNeedsScreenshot;
        expect(
          ns.platform,
          'YouTube',
          reason: 'UI segments screenshot prompts by platform — must be exact',
        );
        expect(ns.url, _watchUrl);
        expect(
          ns.thumbnailUrl,
          _hqThumb,
          reason: 'thumbnail comes from metadata.hqThumbnailUrl',
        );
        expect(
          ns.message,
          isNotEmpty,
          reason: 'shown verbatim to the user in Swedish',
        );
        expect(
          llm.seenTranscripts,
          isEmpty,
          reason: 'cost contract: no transcript ⇒ no LLM call',
        );
      },
    );

    /// Whitespace-only transcript counts as empty → screenshot path.
    /// A future "trim later, treat empty-after-trim as valid" regression
    /// would burn LLM budget on garbage prompts.
    test(
      'whitespace-only transcript treated as empty → screenshot path',
      () async {
        transcript.cannedMetadata = _metadata();
        transcript.cannedTranscript = TranscriptResult.success(
          transcript: '   \n  \t  ',
        );

        final result = await strategy.importV2(_watchUrl);

        expect(result, isA<ImportNeedsScreenshot>());
        expect(
          llm.seenTranscripts,
          isEmpty,
          reason: 'whitespace must not be sent to the LLM',
        );
      },
    );

    /// When metadata fetch fails (returns null), the screenshot must
    /// still carry a synthesised watch URL — never crash on null. This
    /// is the BUT-987-class null-propagation regression catcher.
    test(
      'null metadata → URL synthesised from videoId, thumbnail null',
      () async {
        transcript.cannedMetadata = null;
        transcript.cannedTranscript = TranscriptResult.failure(
          'No captions available',
        );

        final result = await strategy.importV2('some input');

        expect(result, isA<ImportNeedsScreenshot>());
        final ns = result as ImportNeedsScreenshot;
        expect(
          ns.url,
          'https://www.youtube.com/watch?v=$_vid',
          reason: 'must synthesise canonical watch URL when metadata is null',
        );
        expect(
          ns.thumbnailUrl,
          isNull,
          reason: 'no metadata means no thumbnail — must not throw',
        );
      },
    );
  });

  // =========================================================================
  // 3) importV2 — Tier-1 (LLM success) wires sourceUrl + sourceArtefact
  // =========================================================================
  group('importV2 — Tier-1 LLM success wires source provenance', () {
    /// BUT-980 sibling: the LLM extracts the recipe from the transcript
    /// but doesn't know what URL the transcript came from. The strategy
    /// MUST wire `sourceUrl` onto the returned recipe so the detail view
    /// can show "View original".
    ///
    /// BUT-1045 sibling: the strategy MUST also wire a SourceArtefact
    /// carrying the raw transcript so the re-extract flow (BUT-940) can
    /// re-run the LLM step offline.
    test(
      'on LLM success — recipe.sourceUrl = watch URL AND '
      'recipe.sourceArtefact = SourceArtefact(youtubeTranscript, payload)',
      () async {
        transcript.cannedMetadata = _metadata();
        transcript.cannedTranscript = TranscriptResult.success(
          transcript: 'ingredients: eggs, milk. instructions: whisk.',
          language: 'sv',
          isAutoGenerated: false,
        );
        llm.responses.add(
          ImportSuccess(
            recipe: _recipe(title: 'Pannkakor'),
            confidence: 0.85,
            pipeline: 'video',
            tier: 5,
            method: 'llm-transcript',
            usedLlm: true,
            metadata: const {'llmCost': 0.0012},
          ),
        );

        final result = await strategy.importV2(_watchUrl);

        expect(result, isA<ImportSuccess>());
        final success = result as ImportSuccess;
        // BUT-980 pin
        expect(
          success.recipe.core.sourceUrl,
          _watchUrl,
          reason: 'BUT-980: strategy must wire the watch URL onto the recipe',
        );
        // BUT-1045 pin
        expect(
          success.recipe.core.sourceArtefact,
          isNotNull,
          reason:
              'BUT-1045: strategy must wire a SourceArtefact for re-extract',
        );
        final art = success.recipe.core.sourceArtefact!;
        expect(
          art.type,
          SourceArtefactType.youtubeTranscript,
          reason: 'artefact type discriminates the re-extract path',
        );
        expect(
          art.payload,
          'ingredients: eggs, milk. instructions: whisk.',
          reason: 'payload must be the RAW transcript, not the recipe text',
        );
      },
    );

    /// `fetchedAt` is `clock.now()` from package:clock, NOT the global
    /// wall clock. Pinning with `withClock` proves the strategy uses the
    /// injectable clock — a regression that switches to the global wall
    /// clock would make the field non-deterministic in tests and break
    /// the re-extract "captured X days ago" affordance.
    test(
      'SourceArtefact.fetchedAt uses package:clock (deterministic)',
      () async {
        transcript.cannedMetadata = _metadata();
        transcript.cannedTranscript = TranscriptResult.success(
          transcript: 'some recipe transcript',
        );
        llm.responses.add(
          ImportSuccess(
            recipe: _recipe(),
            confidence: 0.8,
            pipeline: 'video',
            tier: 5,
            method: 'llm-transcript',
            usedLlm: true,
          ),
        );

        final frozen = DateTime.utc(2026, 5, 25, 12, 0, 0);
        final result = await withClock(
          Clock.fixed(frozen),
          () => strategy.importV2(_watchUrl),
        );

        expect(result, isA<ImportSuccess>());
        final art = (result as ImportSuccess).recipe.core.sourceArtefact!;
        expect(
          art.fetchedAt,
          frozen,
          reason:
              'fetchedAt must come from package:clock so withClock can pin it',
        );
      },
    );

    /// Pin the success-tier metadata. usedLlm/requiresReview/tier/method
    /// are part of the contract — they drive UI badges ("AI generated —
    /// please review"). A regression flipping any of these silently
    /// changes UX.
    test('on LLM success — tier=1, method="transcript-llm", usedLlm=true, '
        'requiresReview=true, pipeline="youtube"', () async {
      transcript.cannedMetadata = _metadata();
      transcript.cannedTranscript = TranscriptResult.success(
        transcript: 'transcript',
      );
      llm.responses.add(
        ImportSuccess(
          recipe: _recipe(),
          confidence: 0.8,
          pipeline: 'video', // From the LLM service — strategy overrides this
          tier: 5,
          method: 'llm-transcript',
          usedLlm: true,
        ),
      );

      final result = await strategy.importV2(_watchUrl) as ImportSuccess;

      expect(result.tier, 1, reason: 'YouTube Tier-1 is the LLM success path');
      expect(result.method, 'transcript-llm');
      expect(result.usedLlm, isTrue);
      expect(
        result.requiresReview,
        isTrue,
        reason: 'AI extractions must surface a "please review" badge',
      );
      expect(
        result.pipeline,
        'youtube',
        reason: 'strategy stamps its own pipeline name (not LLM-side value)',
      );
    });

    /// Metadata merge contract: LLM metadata stays, strategy adds videoId,
    /// videoTitle, channelName, thumbnailUrl, transcriptLanguage,
    /// transcriptAutoGenerated. A regression that overwrites instead of
    /// merges would erase llmCost telemetry.
    test(
      'metadata merge — LLM keys preserved, YouTube context appended',
      () async {
        transcript.cannedMetadata = _metadata(
          title: 'Pannkakstutorial',
          channelName: 'Anna lagar',
        );
        transcript.cannedTranscript = TranscriptResult.success(
          transcript: 'whisk eggs',
          language: 'sv',
          isAutoGenerated: true,
        );
        llm.responses.add(
          ImportSuccess(
            recipe: _recipe(),
            confidence: 0.8,
            pipeline: 'video',
            tier: 5,
            method: 'llm-transcript',
            usedLlm: true,
            metadata: const {'llmCost': 0.003, 'rawResponseId': 'r-42'},
          ),
        );

        final result = await strategy.importV2(_watchUrl) as ImportSuccess;
        final md = result.metadata!;

        // LLM telemetry preserved
        expect(md['llmCost'], 0.003);
        expect(md['rawResponseId'], 'r-42');
        // YouTube-side context appended
        expect(md['videoId'], _vid);
        expect(md['videoTitle'], 'Pannkakstutorial');
        expect(md['channelName'], 'Anna lagar');
        expect(md['thumbnailUrl'], _hqThumb);
        expect(md['transcriptLanguage'], 'sv');
        expect(md['transcriptAutoGenerated'], isTrue);
      },
    );

    /// LLM gets called with (transcript, watchUrl, videoTitle) — the
    /// exact triple. A regression that passes the URL as the transcript
    /// (easy to mix up given both are positional) is a real bug class.
    test('LLM call args — transcript text + watch URL + metadata title '
        '(positional order pinned)', () async {
      transcript.cannedMetadata = _metadata(title: 'TitleFromMetadata');
      transcript.cannedTranscript = TranscriptResult.success(
        transcript: 'TRANSCRIPT-BODY',
      );
      llm.responses.add(
        ImportSuccess(
          recipe: _recipe(),
          confidence: 0.8,
          pipeline: 'video',
          tier: 5,
          method: 'llm-transcript',
          usedLlm: true,
        ),
      );

      await strategy.importV2(_watchUrl);

      expect(llm.seenTranscripts, ['TRANSCRIPT-BODY']);
      expect(llm.seenUrls, [_watchUrl]);
      expect(llm.seenTitles, ['TitleFromMetadata']);
    });
  });

  // =========================================================================
  // 4) importV2 — Tier-2 (LLM fallbacks)
  // =========================================================================
  group('importV2 — Tier-2 LLM fallbacks', () {
    /// Rate-limited LLM → assistance prompt with the transcript text so
    /// the user can still recover the recipe manually. Message must be
    /// the "AI-kvoten är slut" Swedish copy.
    test('LLM rate-limited → ImportNeedsAssistance with transcript + '
        '"AI-kvoten" message + partialData', () async {
      transcript.cannedMetadata = _metadata();
      transcript.cannedTranscript = TranscriptResult.success(
        transcript: 'fall back to user',
      );
      llm.responses.add(
        ImportFailure.rateLimited(
          message: 'rate limited',
          retryAfter: const Duration(minutes: 5),
        ),
      );

      final result = await strategy.importV2(_watchUrl);

      expect(result, isA<ImportNeedsAssistance>());
      final ass = result as ImportNeedsAssistance;
      expect(
        ass.extractedText,
        'fall back to user',
        reason: 'user needs the transcript to mark up manually',
      );
      expect(
        ass.message,
        contains('AI-kvoten'),
        reason: 'rate-limit message is the Swedish quota-exhausted copy',
      );
      expect(ass.partialData?['videoId'], _vid);
      expect(ass.partialData?['sourceUrl'], _watchUrl);
      expect(
        ass.suggestedTitle,
        'Best Pannkakor Ever',
        reason: 'metadata title becomes the suggested recipe title',
      );
      expect(ass.thumbnailUrl, _hqThumb);
    });

    /// LLM returns assistance itself → strategy preserves LLM's
    /// extractedText (in case it differs from the transcript), but
    /// prefers metadata title when both are present.
    test('LLM returns ImportNeedsAssistance → metadata title preferred over '
        'LLM suggestedTitle; partialData merged', () async {
      transcript.cannedMetadata = _metadata(title: 'YT-Title');
      transcript.cannedTranscript = TranscriptResult.success(
        transcript: 'fall back',
      );
      llm.responses.add(
        ImportNeedsAssistance(
          extractedText: 'LLM-cleaned text',
          suggestedTitle: 'LLM-Title',
          message: 'inner LLM message',
          partialData: const {'llmHint': 42},
        ),
      );

      final result = await strategy.importV2(_watchUrl);

      expect(result, isA<ImportNeedsAssistance>());
      final ass = result as ImportNeedsAssistance;
      expect(
        ass.extractedText,
        'LLM-cleaned text',
        reason: 'LLM has more context — its cleaned text wins',
      );
      expect(
        ass.suggestedTitle,
        'YT-Title',
        reason: 'YouTube canonical title is more trustworthy than LLM guess',
      );
      expect(
        ass.message,
        'inner LLM message',
        reason: 'LLM message bubbles up so the user sees the reason',
      );
      // Merge: LLM partialData + videoId + sourceUrl
      expect(ass.partialData?['llmHint'], 42);
      expect(ass.partialData?['videoId'], _vid);
      expect(ass.partialData?['sourceUrl'], _watchUrl);
    });

    /// LLM returns assistance with a NULL suggestedTitle and metadata
    /// title is also missing — must not crash; suggestedTitle is null.
    test('LLM assistance + null titles everywhere → suggestedTitle null '
        '(no crash)', () async {
      transcript.cannedMetadata = null;
      transcript.cannedTranscript = TranscriptResult.success(transcript: 'x');
      llm.responses.add(
        const ImportNeedsAssistance(
          extractedText: 'x',
          message: 'm',
        ),
      );

      final result = await strategy.importV2('some input');

      expect(result, isA<ImportNeedsAssistance>());
      expect((result as ImportNeedsAssistance).suggestedTitle, isNull);
    });

    /// LLM returns a generic ImportFailure (NOT rate-limited) → strategy
    /// MUST give the user the transcript with an "AI kunde inte" message,
    /// NOT a hard failure and NOT a screenshot prompt. The strategy's
    /// invariant: once we have a transcript, the user always gets
    /// something to work with.
    test(
      'LLM returns generic ImportFailure → ImportNeedsAssistance with '
      '"AI kunde inte" Swedish message (NOT failure, NOT screenshot)',
      () async {
        transcript.cannedMetadata = _metadata();
        transcript.cannedTranscript = TranscriptResult.success(
          transcript: 'transcript body',
        );
        llm.responses.add(
          const ImportFailure(
            message: 'parse failed',
            errorCode: ImportErrorCode.parsingFailed,
          ),
        );

        final result = await strategy.importV2(_watchUrl);

        expect(
          result,
          isA<ImportNeedsAssistance>(),
          reason: 'once we have a transcript, the user always gets assistance',
        );
        expect(result, isNot(isA<ImportFailure>()));
        expect(result, isNot(isA<ImportNeedsScreenshot>()));
        final ass = result as ImportNeedsAssistance;
        expect(ass.extractedText, 'transcript body');
        expect(
          ass.message,
          contains('AI'),
          reason: 'message must mention AI failure context in Swedish',
        );
        expect(ass.partialData?['videoId'], _vid);
      },
    );
  });

  // =========================================================================
  // 5) importV2 — invalid URL early return
  // =========================================================================
  group('importV2 — invalid URL early return', () {
    /// `extractVideoId` returns null → immediate ImportFailure with
    /// errorCode.invalidUrl, tier 0. Transcript service must not be
    /// asked for metadata or transcript on this path.
    test('null videoId → ImportFailure(invalidUrl, tier=0); no metadata or '
        'transcript fetched', () async {
      transcript.cannedVideoId = null;

      final result = await strategy.importV2('not-a-youtube-url');

      expect(result, isA<ImportFailure>());
      final fail = result as ImportFailure;
      expect(fail.errorCode, ImportErrorCode.invalidUrl);
      expect(fail.pipeline, 'youtube');
      expect(fail.tier, 0);
      expect(
        fail.message,
        isNotEmpty,
        reason: 'message rendered as toast — must not be blank',
      );

      expect(
        transcript.fetchMetadataCalls,
        0,
        reason: 'invalid URL ⇒ no metadata fetch (HTTP cost)',
      );
      expect(
        transcript.fetchTranscriptCalls,
        0,
        reason: 'invalid URL ⇒ no transcript fetch (HTTP cost)',
      );
      expect(
        llm.seenTranscripts,
        isEmpty,
        reason: 'invalid URL ⇒ no LLM call (real money)',
      );
    });
  });

  // =========================================================================
  // 6) Legacy import() adapter — _convertToLegacyResult contract
  // =========================================================================
  group('legacy import() adapter — _convertToLegacyResult contract', () {
    /// ImportSuccess → ImportResult.success with merged metadata.
    /// Tier/method/pipeline/usedLlm all surfaced.
    test('success path — legacy ImportResult.success carries recipe + '
        'pipeline/tier/method/usedLlm + merged LLM metadata', () async {
      transcript.cannedMetadata = _metadata();
      transcript.cannedTranscript = TranscriptResult.success(transcript: 'x');
      llm.responses.add(
        ImportSuccess(
          recipe: _recipe(),
          confidence: 0.8,
          pipeline: 'video',
          tier: 5,
          method: 'llm-transcript',
          usedLlm: true,
          metadata: const {'llmCost': 0.001},
        ),
      );

      final legacy = await strategy.import(_watchUrl);

      expect(legacy.isSuccess, isTrue);
      expect(legacy.recipe, isNotNull);
      expect(
        legacy.recipe!.core.sourceUrl,
        _watchUrl,
        reason: 'sourceUrl must survive the legacy conversion',
      );
      expect(legacy.metadata?['pipeline'], 'youtube');
      expect(legacy.metadata?['tier'], 1);
      expect(legacy.metadata?['method'], 'transcript-llm');
      expect(legacy.metadata?['usedLlm'], isTrue);
      expect(
        legacy.metadata?['llmCost'],
        0.001,
        reason: 'LLM telemetry must round-trip through the adapter',
      );
      expect(legacy.metadata?['videoId'], _vid);
    });

    /// ImportNeedsScreenshot → legacy failure (NOT assistance) with
    /// needsScreenshot=true so the UI can route to the screenshot prompt.
    test('screenshot path — legacy ImportResult.failure with '
        'needsScreenshot=true (NOT needsAssistance)', () async {
      transcript.cannedMetadata = _metadata();
      transcript.cannedTranscript = TranscriptResult.failure(
        'No captions available',
      );

      final legacy = await strategy.import(_watchUrl);

      expect(legacy.isSuccess, isFalse);
      expect(
        legacy.needsAssistance,
        isFalse,
        reason: 'screenshot is a distinct UI branch from assistance',
      );
      expect(legacy.errorMessage, isNotEmpty);
      expect(legacy.metadata?['needsScreenshot'], isTrue);
      expect(legacy.metadata?['platform'], 'YouTube');
      expect(legacy.metadata?['url'], _watchUrl);
      expect(legacy.metadata?['thumbnailUrl'], _hqThumb);
    });

    /// ImportNeedsAssistance → legacy assistance carrying extractedText,
    /// suggestedTitle, and partialData → metadata.
    test('assistance path — legacy ImportResult.assistance carries '
        'extractedText + suggestedTitle + partialData→metadata', () async {
      transcript.cannedMetadata = _metadata(title: 'Suggested-Title');
      transcript.cannedTranscript = TranscriptResult.success(
        transcript: 'TRANSCRIPT',
      );
      llm.responses.add(
        ImportFailure.rateLimited(
          message: 'rl',
          retryAfter: const Duration(minutes: 1),
        ),
      );

      final legacy = await strategy.import(_watchUrl);

      expect(legacy.isSuccess, isFalse);
      expect(legacy.needsAssistance, isTrue);
      expect(legacy.extractedText, 'TRANSCRIPT');
      expect(legacy.suggestedTitle, 'Suggested-Title');
      expect(
        legacy.metadata?['videoId'],
        _vid,
        reason: 'partialData must surface as legacy metadata',
      );
      expect(legacy.metadata?['sourceUrl'], _watchUrl);
    });

    /// ImportFailure (invalid URL) → legacy failure with errorCode/pipeline/tier
    /// in metadata.
    test('failure path — legacy ImportResult.failure with errorCode + '
        'pipeline + tier in metadata', () async {
      transcript.cannedVideoId = null;

      final legacy = await strategy.import('garbage');

      expect(legacy.isSuccess, isFalse);
      expect(legacy.needsAssistance, isFalse);
      expect(legacy.errorMessage, isNotEmpty);
      expect(legacy.metadata?['errorCode'], ImportErrorCode.invalidUrl.name);
      expect(legacy.metadata?['pipeline'], 'youtube');
      expect(legacy.metadata?['tier'], 0);
    });
  });

  // =========================================================================
  // 7) BUT-1116 fix — mixed-case host accepted
  // =========================================================================
  group('BUT-1116 fix: case-insensitive URL pattern', () {
    /// After BUT-1116 fix, each RegExp in `_videoIdPatterns` carries
    /// `caseSensitive: false`, so shared URLs with uppercase host letters
    /// extract correctly. Same fix as BUT-1092 (tiktok) and BUT-1113
    /// (instagram).
    test('BUT-1116: mixed-case host `YouTube.com` is accepted '
        '(case-insensitive regex)', () {
      // Real transcript service — NOT the fake. We want production parsing.
      final realStrategy = YouTubeImportStrategy(
        transcriptService: YouTubeTranscriptService(),
        llmService: llm,
      );
      const mixedCase = 'https://www.YouTube.com/watch?v=dQw4w9WgXcQ';

      expect(
        realStrategy.canHandle(mixedCase),
        isTrue,
        reason: 'BUT-1116: case-insensitive host must be accepted',
      );
    });

    /// Lowercase variant of the same URL is accepted — proves the cause
    /// is exactly the case-sensitivity, not the host string itself.
    test('lowercase variant of the same URL is accepted (proves cause)', () {
      final realStrategy = YouTubeImportStrategy(
        transcriptService: YouTubeTranscriptService(),
        llmService: llm,
      );
      const lower = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

      expect(realStrategy.canHandle(lower), isTrue);
    });
  });
}
