/// Prelabel harness for the cookbook gold corpus.
///
/// This is a *script shaped as a test* (it needs the Flutter asset bundle for
/// CRF weights + the app DI for the parser) — NOT a CI test. It is double-
/// guarded so a normal `flutter test` never runs it:
///   1. Tagged `corpus-tools` (excluded by the default tag config).
///   2. Skips at runtime unless `RUN_CORPUS_PRELABEL=1`.
///
/// What it does, per image in `<book>/inbox/`:
///   1. OCR the image (OCR.space directly, shrunk to clear the 1.5 MB free cap)
///      → page-01.jpg (full-res) + ocr.txt + ocr.meta.json
///   2. Parse the text (ImportManager.autoParseOnly) → title/portions/time/steps
///   3. Structure each ingredient line (IngredientParsingStrategy.parseLine)
///   4. Write draft.json (the parser's prediction) + a gold.json seed
///      (verified:false copy you then correct by hand and flip to true)
///
/// Run it (all three are real ENV VARS, not dart-defines). The OCR key is
/// needed ONLY for pages with no stored `ocr.txt`: re-deriving drafts after a
/// PARSER change reuses every stored read and costs nothing, so the key is
/// demanded at the point of use rather than upfront. `FORCE_CORPUS_OCR=1`
/// re-reads every page anyway — a re-shoot, or a deliberate provider
/// comparison.
///
///   `OCR_SPACE_API_KEY=<key>` RUN_CORPUS_PRELABEL=1 \
///     flutter test test/corpus/corpus_prelabel_test.dart
///
/// On this Windows box the flutter wrapper needs System32 + Git + PowerShell on
/// PATH; the helper script `../run_prelabel.ps1` (outside the repo) sets that up
/// and reads the key from .env. A page whose OCR fails is recorded in
/// ocr.meta.json and skipped — the batch never aborts.
@Tags(['corpus-tools'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';

import '../../tools/corpus/corpus_models.dart';
import '../../tools/corpus/corpus_paths.dart';
import '../infrastructure/di/test_service_locator.dart';

const _enabled = bool.fromEnvironment('dart.vm.product') ? false : true;

bool get _shouldRun =>
    _enabled && Platform.environment['RUN_CORPUS_PRELABEL'] == '1';

/// Parse-only never saves, so [ImportManager]'s save dependency is never
/// invoked — a bare mock satisfies the constructor without real DI weight.
class _NoopPersonalOps extends Mock implements PersonalRecipeOperations {}

void main() {
  setUpAll(() async {
    // Skip heavy DI + OCR init entirely on a normal `flutter test` run — the
    // body is skipped anyway, and this keeps CI fast and side-effect-free.
    if (!_shouldRun) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    // flutter_test installs an HttpOverrides that returns HTTP 400 (empty body)
    // for every real network call. The corpus prelabel genuinely needs to reach
    // OCR.space, so restore real networking after the binding is up.
    HttpOverrides.global = null;
    // The parser caches read SharedPreferences; without a mock the plugin
    // channel throws MissingPluginException under flutter test.
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestServiceLocator.initialize();
  });

  test(
    'prelabel: OCR + parse every inbox image into draft/gold seeds',
    () async {
      final paths = CorpusPaths.resolve();
      if (!paths.exists) {
        fail(
          'Corpus root not found: ${paths.root}. '
          'Create it or set BUTLERY_CORPUS_DIR.',
        );
      }

      // NOT demanded upfront. Since OCR reuse landed, a parser-only
      // re-derivation touches no paid provider at all, and failing here made
      // that free path unreachable — the run this harness exists for could not
      // start without a key it would never use. Demanded at the point of use
      // instead, where the message can name the page that actually needs it.
      final ocrKey = Platform.environment['OCR_SPACE_API_KEY'] ?? '';

      final importManager = ImportManager(_NoopPersonalOps());
      final ingredientParser = IngredientParsingStrategy();

      var processed = 0;
      var failed = 0;

      for (final bookDir in paths.books()) {
        final bookSlug = _basename(bookDir.path);
        final inbox = Directory(paths.inbox(bookSlug));
        if (!inbox.existsSync()) continue;

        final images =
            inbox
                .listSync()
                .whereType<File>()
                .where((f) => _isImage(f.path))
                .toList()
              ..sort((a, b) => a.path.compareTo(b.path));

        for (final image in images) {
          final recipeId = _recipeIdFor(image.path);
          final recipeDir = Directory(paths.recipe(bookSlug, recipeId));
          recipeDir.createSync(recursive: true);

          final bytes = await image.readAsBytes();
          // page-01.jpg keeps the FULL-RES camera photo — the realistic
          // production artifact the corpus is meant to preserve.
          await File('${recipeDir.path}/page-01.jpg').writeAsBytes(bytes);

          // REUSE an existing read instead of paying for it again. Every run
          // used to re-OCR the whole corpus, so re-deriving drafts after a
          // PARSER change — the common case, and the whole point of the
          // corpus — cost one paid call per page (250 today). The stored
          // ocr.txt is the same artifact the eval already treats as the
          // baseline, so reusing it changes nothing about what is measured.
          // Set FORCE_CORPUS_OCR=1 to re-read anyway (a new photo, or a
          // deliberate OCR-provider comparison).
          final existingOcr = File(paths.ocrText(bookSlug, recipeId));
          final forceOcr = Platform.environment['FORCE_CORPUS_OCR'] == '1';
          final storedText = existingOcr.existsSync()
              ? existingOcr.readAsStringSync()
              : '';
          // Re-shoot protection: a newer inbox image against an older ocr.txt
          // means the stored read belongs to a DIFFERENT photo. Reusing it
          // there would let someone verify gold against the new image while
          // every metric still scores the old text — fresh gold, stale OCR,
          // and nothing anywhere says so.
          final stale =
              existingOcr.existsSync() &&
              existingOcr.lastModifiedSync().isBefore(image.lastModifiedSync());
          final _OcrOutcome ocr;
          if (!forceOcr && !stale && storedText.trim().isNotEmpty) {
            // Read the stored meta rather than inventing one. Fabricating
            // `provider: 'ocr_space'` mislabels text that came from another
            // tier, and fabricating a fresh timestamp erases when the page was
            // actually read.
            final metaFile = File(paths.ocrMeta(bookSlug, recipeId));
            final meta = metaFile.existsSync()
                ? OcrMeta.fromJson(
                    jsonDecode(metaFile.readAsStringSync())
                        as Map<String, dynamic>,
                  )
                : OcrMeta(provider: 'unknown', timestampIso: '');
            ocr = _OcrOutcome(storedText, meta);
            stdout.writeln('OCR[$bookSlug/$recipeId] reused stored ocr.txt');
          } else {
            if (ocrKey.isEmpty) {
              fail(
                'OCR_SPACE_API_KEY not set, and $bookSlug/$recipeId has no '
                'reusable ocr.txt (stale: $stale, forced: $forceOcr).',
              );
            }
            // OCR.space's free plan rejects payloads over 1.5 MB (E556). Phone
            // photos are 2–4 MB, so shrink the COPY sent to OCR — mirrors the
            // image_picker compression the real app applies before OCR. Text
            // OCR gains nothing above ~1600px, so this costs no accuracy.
            final ocrBytes = _shrinkForOcr(bytes);
            ocr = await _runOcr(ocrKey, ocrBytes, '$bookSlug/$recipeId');
            existingOcr.writeAsStringSync(ocr.text);
            File(
              paths.ocrMeta(bookSlug, recipeId),
            ).writeAsStringSync(encodeJsonPretty(ocr.meta.toJson()));
          }

          if (ocr.meta.isFailure || ocr.text.trim().isEmpty) {
            failed++;
            stderr.writeln(
              'OCR failed for $bookSlug/$recipeId: ${ocr.meta.error}',
            );
            // Leave the image in inbox-equivalent state (page-01.jpg kept) so it
            // can be retried; no draft written.
            continue;
          }

          final drafts = await _parseToDrafts(
            importManager,
            ingredientParser,
            ocr.text,
          );

          if (drafts.length == 1) {
            // Single-recipe page → flat layout (draft.json/gold.json at the image
            // dir), exactly as before. Minimises churn on existing corpora.
            _writeDraftAndSeed(
              paths.draft(bookSlug, recipeId),
              paths.gold(bookSlug, recipeId),
              drafts.first,
            );
          } else {
            // Multi-recipe page → one recipe-NN/ block per recipe; page-01.jpg and
            // ocr.txt stay shared at the image level.
            for (var i = 0; i < drafts.length; i++) {
              final blockId = 'recipe-${(i + 1).toString().padLeft(2, '0')}';
              Directory(
                paths.recipeBlock(bookSlug, recipeId, blockId),
              ).createSync(recursive: true);
              _writeDraftAndSeed(
                paths.draftBlock(bookSlug, recipeId, blockId),
                paths.goldBlock(bookSlug, recipeId, blockId),
                drafts[i],
              );
            }
          }

          processed++;
          stdout.writeln(
            'Prelabeled $bookSlug/$recipeId '
            '(${drafts.length} recipe(s))',
          );
        }
      }

      stdout.writeln(
        'Prelabel done: $processed processed, $failed OCR failures.',
      );
    },
    skip: _shouldRun
        ? false
        : 'set RUN_CORPUS_PRELABEL=1 to run the prelabel batch',
  );
}

/// Downscale (long edge ≤ 1600) + JPEG re-encode so the OCR payload clears
/// OCR.space's 1.5 MB free-plan cap. Returns the original bytes if decoding
/// fails — the provider may still handle a format we couldn't parse.
Uint8List _shrinkForOcr(Uint8List bytes) {
  const maxLongEdge = 1600;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final longEdge = math.max(decoded.width, decoded.height);
  final resized = longEdge > maxLongEdge
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxLongEdge : null,
          height: decoded.height > decoded.width ? maxLongEdge : null,
        )
      : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
}

class _OcrOutcome {
  final String text;
  final OcrMeta meta;
  const _OcrOutcome(this.text, this.meta);
}

/// Calls OCR.space directly with the proven request shape (multipart `file`
/// upload, OCREngine 2, language `eng` — engine 2 is language-independent and
/// reads Swedish fine; `swe` is rejected with E201). We bypass the app's
/// `OCRExtractionService` here on purpose: its base64 transport + 2048px
/// preprocessing still exceeded OCR.space's 1.5 MB free cap (E556) on phone
/// photos. The recognition engine and image are identical, so the OCR-quality
/// signal is faithful; only the transport differs.
Future<_OcrOutcome> _runOcr(
  String apiKey,
  Uint8List jpgBytes,
  String label,
) async {
  final ts = DateTime.now().toIso8601String();
  try {
    final req =
        http.MultipartRequest(
            'POST',
            Uri.parse('https://api.ocr.space/parse/image'),
          )
          ..fields['apikey'] = apiKey
          ..fields['OCREngine'] = '2'
          ..fields['language'] = 'eng'
          ..fields['scale'] = 'true'
          ..fields['isOverlayRequired'] = 'false'
          ..fields['filetype'] = 'JPG'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              jpgBytes,
              filename: 'page.jpg',
            ),
          );

    final resp = await http.Response.fromStream(await req.send());
    if (resp.statusCode != 200) {
      stderr.writeln('OCR[$label] HTTP ${resp.statusCode}: ${resp.body}');
      return _OcrOutcome(
        '',
        OcrMeta(
          provider: 'ocr_space',
          timestampIso: ts,
          error: 'HTTP ${resp.statusCode}',
        ),
      );
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json['IsErroredOnProcessing'] == true) {
      final em = json['ErrorMessage'];
      final msg = em is List ? em.join('; ') : em.toString();
      stderr.writeln('OCR[$label] OCR.space error: $msg');
      return _OcrOutcome(
        '',
        OcrMeta(provider: 'ocr_space', timestampIso: ts, error: msg),
      );
    }

    final results = json['ParsedResults'] as List?;
    final text = (results != null && results.isNotEmpty)
        ? (results.first['ParsedText']?.toString() ?? '')
        : '';
    stderr.writeln('OCR[$label] ok, ${text.length} chars');
    return _OcrOutcome(
      text,
      OcrMeta(
        provider: 'ocr_space',
        confidence: text.isNotEmpty ? 1.0 : 0.0,
        timestampIso: ts,
        error: text.isEmpty ? 'no text extracted' : null,
      ),
    );
  } catch (e, st) {
    stderr.writeln('OCR[$label] threw: $e\n$st');
    return _OcrOutcome(
      '',
      OcrMeta(provider: 'ocr_space', timestampIso: ts, error: e.toString()),
    );
  }
}

/// Parse one page's OCR text into N draft recipes via the multi-recipe path.
/// Returns one draft for a single-recipe page, several for a cookbook spread,
/// or a single title-only fallback when nothing parsed.
Future<List<GoldRecipe>> _parseToDrafts(
  ImportManager importManager,
  IngredientParsingStrategy ingredientParser,
  String ocrText,
) async {
  List<Recipe> recipes = const [];
  try {
    final result = await importManager.autoParseMulti(ocrText);
    recipes = result.successfulRecipes;
  } catch (_) {
    // Fall through to the title-only fallback below.
  }

  if (recipes.isEmpty) {
    return [
      GoldRecipe(
        verified: false,
        title: _firstNonEmptyLine(ocrText),
        ingredients: const [],
        instructions: const [],
        sourcePages: const ['page-01.jpg'],
      ),
    ];
  }

  final drafts = <GoldRecipe>[];
  for (final recipe in recipes) {
    drafts.add(await _recipeToGold(ingredientParser, recipe));
  }
  return drafts;
}

Future<GoldRecipe> _recipeToGold(
  IngredientParsingStrategy ingredientParser,
  Recipe recipe,
) async {
  final ingredients = <GoldIngredient>[];
  for (final line in recipe.ingredients) {
    ingredients.add(await _structureLine(ingredientParser, line));
  }
  return GoldRecipe(
    verified: false,
    title: recipe.title,
    portions: recipe.portions?.toString(),
    timeMinutes: _totalTime(recipe),
    ingredients: ingredients,
    instructions: recipe.instructions,
    sourcePages: const ['page-01.jpg'],
  );
}

/// Write the prediction to draft.json and seed gold.json from it — but only if
/// gold.json doesn't exist yet, so a re-run never clobbers human corrections.
void _writeDraftAndSeed(String draftPath, String goldPath, GoldRecipe draft) {
  File(draftPath).writeAsStringSync(encodeJsonPretty(draft.toJson()));
  final goldFile = File(goldPath);
  if (!goldFile.existsSync()) {
    goldFile.writeAsStringSync(
      encodeJsonPretty(draft.copyWith(verified: false).toJson()),
    );
  }
}

Future<GoldIngredient> _structureLine(
  IngredientParsingStrategy parser,
  String line,
) async {
  try {
    // ocrCorrection mirrors the production photo path (TextImportStrategy now
    // corrects too) so the corpus measures the same text the app would parse.
    final p = await parser.parseLine(line, ocrCorrection: true);
    return GoldIngredient(
      name: p.name.isEmpty ? line : p.name,
      originalLine: p.originalLine.isEmpty ? line : p.originalLine,
      quantity: p.quantity,
      unit: p.unit,
      size: p.size,
      preparation: p.preparation,
    );
  } catch (_) {
    // Structuring is best-effort; a name-only ingredient is still a usable seed.
    return GoldIngredient(name: line, originalLine: line);
  }
}

int? _totalTime(Recipe? r) {
  if (r == null) return null;
  final prep = r.prepTimeMinutes ?? 0;
  final cook = r.cookTimeMinutes ?? 0;
  final total = prep + cook;
  if (total > 0) return total;
  // The TEXT/photo path never fills the split prep/cook fields — it writes a
  // single `timeMinutes` (TextImportStrategy._extractTime). Reading only
  // prep+cook made the eval report 0.0% time accuracy for every photographed
  // page regardless of what the parser found: a broken yardstick, not a
  // measured failure. Fall back to the field that path actually populates.
  return r.timeMinutes;
}

String _firstNonEmptyLine(String text) => text
    .split('\n')
    .map((l) => l.trim())
    .firstWhere((l) => l.isNotEmpty, orElse: () => 'Namnlöst recept');

bool _isImage(String path) {
  final p = path.toLowerCase();
  return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png');
}

String _basename(String p) {
  final cleaned = p.replaceAll('\\', '/');
  final i = cleaned.lastIndexOf('/');
  return i < 0 ? cleaned : cleaned.substring(i + 1);
}

/// Stable recipe id from the image filename (e.g. `scan_007.jpg` → `scan_007`).
String _recipeIdFor(String imagePath) {
  final base = _basename(imagePath);
  final dot = base.lastIndexOf('.');
  final stem = dot < 0 ? base : base.substring(0, dot);
  return stem.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}
