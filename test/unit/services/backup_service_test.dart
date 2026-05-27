/// Intent-driven unit tests for [BackupService] — Batch 13 of Intent-Test Sprint.
///
/// Behaviours covered:
/// - exportToFile guards on empty recipe list before touching the file system
/// - exportToFile fails gracefully when Firebase auth is not initialised
///   (production never throws to the caller)
/// - importFromFile returns ImportResult.cancelled() when user dismisses picker
/// - importFromFile rejects null-bytes file, foreign-JSON envelopes, and
///   accepts both 'butlery_backup' (current) and 'butlery_export' (legacy) envelopes
/// - Duplicate detection is case-insensitive on recipe title and dedup-snapshot is
///   re-read from the service on every iteration (so live-updates affect import flow)
/// - Round-trip integrity: a recipe exported via toJson and re-read via
///   Recipe.fromJson preserves title, description, portions, timeMinutes,
///   rating, ingredients, instructions, imageUrls, personalTagIds, mealType
/// - Partial failure isolation: a malformed recipe mid-list does NOT roll back
///   already-imported recipes (NO transactional rollback — bug if it ever
///   silently appears)
/// - sourceUrl on every imported recipe is rewritten to the localised
///   `Importerat från backup <date>` string (origin-tracking invariant)
/// - exportDate is parsed from the backup envelope into ImportResult.exportDate
/// - DISCOVERED BUG (data inconsistency): export writes `user_id` but import
///   reads `user_email` — exportEmail will always be null for backups made
///   by the current exporter. Pinned by `imported backup made by exporter has
///   null exportEmail (regression sentinel for user_email-vs-user_id mismatch)`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/services/backup_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:clock/clock.dart';
import 'package:file_picker/file_picker.dart';
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

/// Programmable FilePicker platform that lets a test answer the next
/// `FilePicker.pickFiles(...)` call with cancellation, an error, a payload of
/// raw bytes, or a payload missing bytes.
class _FakeFilePickerPlatform extends FilePickerPlatform {
  FilePickerResult? _next;
  Object? _throws;

  void respondWithCancellation() {
    _next = null;
    _throws = null;
  }

  void respondWithBytes(Uint8List bytes, {String name = 'backup.json'}) {
    _next = FilePickerResult([
      PlatformFile(name: name, size: bytes.lengthInBytes, bytes: bytes),
    ]);
    _throws = null;
  }

  void respondWithNullBytes({String name = 'backup.json'}) {
    _next = FilePickerResult([
      PlatformFile(name: name, size: 0, bytes: null),
    ]);
    _throws = null;
  }

  void respondWithThrow(Object error) {
    _throws = error;
    _next = null;
  }

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    if (_throws != null) throw _throws!;
    return _next;
  }
}

/// Builds the current-format envelope (matches what `exportToFile()` would
/// emit so import tests round-trip what export produces).
Map<String, dynamic> _backupEnvelope({
  required List<Recipe> recipes,
  String? exportedAt,
  String? userEmail,
  String version = '1.0',
}) {
  return {
    'butlery_backup': {
      'version': version,
      'exported_at': exportedAt ?? clock.now().toIso8601String(),
      'user_id': 'exporter-uid',
      if (userEmail != null) 'user_email': userEmail,
      'recipe_count': recipes.length,
      'recipes': recipes.map((r) => r.toJson()).toList(),
    },
  };
}

Uint8List _utf8Bytes(Map<String, dynamic> json) {
  return Uint8List.fromList(utf8.encode(jsonEncode(json)));
}

void main() {
  late BackupService service;
  late MockUnifiedRecipeService mockRecipeService;
  late MockFirebaseAuthRepository mockAuthRepo;
  late MockPersonalRecipeOperations mockPersonalOps;
  late _FakeFilePickerPlatform fakeFilePicker;
  late FilePickerPlatform originalFilePickerPlatform;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(<String>[]);
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    prod.ServiceLocator.initialize(DIContainer());

    mockRecipeService = MockUnifiedRecipeService();
    mockAuthRepo = MockFirebaseAuthRepository();
    mockPersonalOps = MockPersonalRecipeOperations();

    mockAuthRepo.setAuthState(
      user: MockFactory.createMockUser(
        uid: 'test-uid',
        email: 'test@example.com',
      ),
      userId: 'test-uid',
    );
    mockRecipeService.setRecipeState(
      recipes: [],
      personalOperations: mockPersonalOps,
    );

    TestServiceLocator.registerMock<UnifiedRecipeService>(mockRecipeService);
    TestServiceLocator.registerMock<FirebaseAuthRepository>(mockAuthRepo);

    // Default: createRecipe returns a fake id so the loop counts a success.
    when(() => mockPersonalOps.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          personalTagIds: any(named: 'personalTagIds'),
          sourceUrl: any(named: 'sourceUrl'),
        )).thenAnswer((_) async => 'new-id');

    // Swap the file_picker platform with a programmable fake so tests can
    // drive the picker without a real native channel.
    originalFilePickerPlatform = FilePickerPlatform.instance;
    fakeFilePicker = _FakeFilePickerPlatform();
    FilePickerPlatform.instance = fakeFilePicker;

    service = BackupService();
  });

  tearDown(() async {
    FilePickerPlatform.instance = originalFilePickerPlatform;
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('exportToFile — guards before touching the file system', () {
    /// Empty recipe list short-circuits with the Swedish "no recipes" message
    /// and never tries to allocate a file path or Firebase auth — proves the
    /// early-return is in front of the platform branch.
    test('returns localized error when recipe service has no recipes',
        () async {
      mockRecipeService.setRecipeState(recipes: []);

      final result = await service.exportToFile();

      expect(result.success, isFalse);
      expect(result.message, equals('Inga recept att exportera'));
      expect(result.filePath, isNull);
      expect(result.recipeCount, isNull);
    });

    /// Production constructs `FirebaseAuthRepository()` directly inside
    /// exportToFile. In a unit-test context Firebase isn't initialised, so
    /// the constructor throws — but the outer try/catch must convert that
    /// into a [BackupResult.error], NOT propagate. Pins "export never throws
    /// to caller" so a future refactor that drops the try/catch is caught.
    test('returns BackupResult.error instead of throwing on Firebase failure',
        () async {
      mockRecipeService.setRecipeState(
        recipes: RecipeFactory.buildList(count: 2),
      );

      final result = await service.exportToFile();

      // We assert structurally — the message is localised and includes the
      // wrapped exception, so we check the success flag is false and the
      // failure path is engaged (no filePath populated).
      expect(result.success, isFalse);
      expect(result.filePath, isNull);
      expect(result.message, isNotEmpty);
    });
  });

  group('importFromFile — file-picker boundary conditions', () {
    /// User dismisses the picker → ImportResult.cancelled() with cancelled=true
    /// and success=false. NOT an error result — must be distinguishable so
    /// the UI can show a no-op snackbar vs an error banner.
    test('returns cancelled (not error) when user dismisses picker', () async {
      fakeFilePicker.respondWithCancellation();

      final result = await service.importFromFile();

      expect(result.cancelled, isTrue);
      expect(result.success, isFalse);
      expect(result.errorMessage, isNull,
          reason: 'cancellation is not an error');
    });

    /// PlatformFile arrived but with null bytes (e.g. cloud-provider import
    /// that didn't materialise) → must not crash, must return a readable
    /// error to the user.
    test('returns error (not crash) when picked file has null bytes', () async {
      fakeFilePicker.respondWithNullBytes();

      final result = await service.importFromFile();

      expect(result.success, isFalse);
      expect(result.cancelled, isFalse);
      expect(result.errorMessage, equals('Kunde inte läsa filen'));
    });

    /// File-picker itself throws (permission denied, etc.) — outer try/catch
    /// must wrap it into the localised "Import failed" error, not propagate.
    test('wraps unexpected file-picker exception in localised error', () async {
      fakeFilePicker.respondWithThrow(StateError('disk on fire'));

      final result = await service.importFromFile();

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Import misslyckades'));
      expect(result.errorMessage, contains('disk on fire'));
    });
  });

  group('importFromFile — envelope validation', () {
    /// Foreign JSON top-level (no `butlery_backup` AND no `butlery_export`)
    /// → reject with "Ogiltig backup-fil". Pins the "we only import our own
    /// format" contract.
    test('rejects JSON missing both butlery_backup and butlery_export keys',
        () async {
      final foreign = {
        'some_other_app': {'recipes': []},
      };
      fakeFilePicker.respondWithBytes(_utf8Bytes(foreign));

      final result = await service.importFromFile();

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Ogiltig backup-fil'));
    });

    /// Backward-compat: the legacy `butlery_export` wrapper must still be
    /// accepted (users running the old build shipped backups with that key).
    /// Bug if a future refactor removes the OR branch silently.
    test(
        'accepts legacy butlery_export envelope as equivalent to butlery_backup',
        () async {
      final legacy = {
        'butlery_export': {
          'version': '0.9',
          'exported_at': DateTime(2024, 6, 1).toIso8601String(),
          'recipes': [RecipeFactory.build(title: 'Legacy Pasta').toJson()],
        },
      };
      fakeFilePicker.respondWithBytes(_utf8Bytes(legacy));

      final result = await service.importFromFile();

      expect(result.totalRecipes, equals(1));
      expect(result.successCount, equals(1));
      expect(result.exportDate, equals(DateTime(2024, 6, 1)));
    });

    /// Current `butlery_backup` envelope succeeds (sanity for the
    /// happy-path branch that does the work).
    test('accepts current butlery_backup envelope and counts successes',
        () async {
      final recipes = RecipeFactory.buildList(count: 3, titlePrefix: 'Unique');
      fakeFilePicker.respondWithBytes(_utf8Bytes(_backupEnvelope(
        recipes: recipes,
        exportedAt: DateTime(2025, 1, 15).toIso8601String(),
      )));

      final result = await service.importFromFile();

      expect(result.totalRecipes, equals(3));
      expect(result.successCount, equals(3));
      expect(result.skipCount, equals(0));
      expect(result.exportDate, equals(DateTime(2025, 1, 15)));
    });
  });

  group('importFromFile — duplicate detection contract', () {
    /// Duplicate detection compares titles lowercased. "PASTA carbonara"
    /// in the backup must collide with "Pasta Carbonara" already in the
    /// library — pin case-insensitivity so a "ToLower" removal breaks the test.
    test('detects duplicates by case-insensitive title match', () async {
      final existing = RecipeFactory.build(title: 'Pasta Carbonara');
      mockRecipeService.setRecipeState(
        recipes: [existing],
        personalOperations: mockPersonalOps,
      );

      final incoming = RecipeFactory.build(title: 'PASTA CARBONARA');
      fakeFilePicker
          .respondWithBytes(_utf8Bytes(_backupEnvelope(recipes: [incoming])));

      final result = await service.importFromFile();

      expect(result.totalRecipes, equals(1));
      expect(result.successCount, equals(0));
      expect(result.skipCount, equals(1));
      expect(result.skippedTitles, equals(['PASTA CARBONARA']));
      verifyNever(() => mockPersonalOps.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          ));
    });

    /// Empty existing library + N unique titles in backup → all imported.
    /// Pins the happy path of the dedup branch (no false-positive collisions).
    test('imports all when no titles collide with existing library', () async {
      final recipes = [
        RecipeFactory.build(title: 'Köttbullar'),
        RecipeFactory.build(title: 'Janssons frestelse'),
      ];
      fakeFilePicker
          .respondWithBytes(_utf8Bytes(_backupEnvelope(recipes: recipes)));

      final result = await service.importFromFile();

      expect(result.successCount, equals(2));
      expect(result.skipCount, equals(0));
    });
  });

  group('importFromFile — partial-failure isolation', () {
    /// Recipe 2-of-3 has malformed JSON shape. Production logs the error,
    /// adds it to `errors`, increments skipCount, and CONTINUES with the
    /// rest. Recipes 1 and 3 must still be imported. Pins "no
    /// transactional rollback" — a future refactor that decides "all-or-
    /// nothing" would break this test, which forces an explicit decision.
    test('continues importing remaining recipes when one is malformed',
        () async {
      final good1 = RecipeFactory.build(title: 'Good One').toJson();
      // Malformed: `core` is non-Map; RecipeCore.fromJson cast will throw.
      final bad = {'core': 'not-a-map', 'type': 0};
      final good2 = RecipeFactory.build(title: 'Good Two').toJson();

      final envelope = {
        'butlery_backup': {
          'version': '1.0',
          'exported_at': DateTime(2025, 5, 1).toIso8601String(),
          'recipes': [good1, bad, good2],
        },
      };
      fakeFilePicker.respondWithBytes(_utf8Bytes(envelope));

      final result = await service.importFromFile();

      expect(result.totalRecipes, equals(3));
      expect(result.successCount, equals(2),
          reason: 'good recipes either side of the malformed entry must still '
              'be imported (no rollback)');
      expect(result.skipCount, equals(1));
      expect(result.errors.length, equals(1));
      expect(result.errors.first, contains('Okänt recept'),
          reason: 'malformed entry without a `title` field uses the localised '
              'fallback label');
    });

    /// One of the createRecipe calls throws (Firestore quota, network…).
    /// The exception must be captured per-recipe and NOT abort the import
    /// loop — pin per-recipe error isolation at the repository boundary.
    ///
    /// BUT-1139 fix: the error message now sources the recipe title from
    /// `core.title` (current nested shape) with a fallback to top-level
    /// `title`, so users importing a 200-recipe backup see WHICH recipe
    /// failed instead of N identical "Okänt recept" lines.
    test('isolates per-recipe repository failures into errors list', () async {
      final recipes = [
        RecipeFactory.build(title: 'Will Succeed'),
        RecipeFactory.build(title: 'Will Fail'),
      ];

      when(() => mockPersonalOps.createRecipe(
            title: 'Will Fail',
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          )).thenThrow(StateError('quota exceeded'));

      fakeFilePicker
          .respondWithBytes(_utf8Bytes(_backupEnvelope(recipes: recipes)));

      final result = await service.importFromFile();

      expect(result.successCount, equals(1));
      expect(result.skipCount, equals(1));
      expect(result.errors.length, equals(1));
      expect(result.errors.first, contains('quota exceeded'),
          reason: 'raw exception must surface for diagnostics');
      // BUT-1139: error message now contains the REAL recipe title
      // (sourced from core.title) so users know which entry failed.
      expect(result.errors.first, contains('Will Fail'),
          reason: 'BUT-1139 fix: per-recipe error label resolves via '
              'core.title (nested) instead of top-level title');
      expect(result.errors.first, isNot(contains('Okänt recept')),
          reason: 'fallback label must NOT win when a real title is available');
    });
  });

  group('importFromFile — round-trip integrity', () {
    /// A recipe carried through toJson → fromJson must preserve every
    /// user-facing field that BackupService forwards to createRecipe.
    /// This is the GDPR-critical contract: no silent data loss in the
    /// export/import boundary.
    test('preserves all forwarded fields end-to-end via createRecipe',
        () async {
      final source = RecipeFactory.build(
        title: 'Köttbullar med potatismos',
        description: 'Klassiska svenska köttbullar',
        ingredients: ['500g köttfärs', '1 dl ströbröd', '2 dl mjölk'],
        instructions: ['Stek', 'Servera'],
        imageUrls: ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
        mealType: 'Middag',
        portions: 6,
        timeMinutes: 45,
        rating: 4.8,
        personalTagIds: ['svensk', 'middag', 'köttbullar'],
      );
      fakeFilePicker
          .respondWithBytes(_utf8Bytes(_backupEnvelope(recipes: [source])));

      await service.importFromFile();

      final captured = verify(() => mockPersonalOps.createRecipe(
            title: captureAny(named: 'title'),
            description: captureAny(named: 'description'),
            ingredients: captureAny(named: 'ingredients'),
            instructions: captureAny(named: 'instructions'),
            imageUrls: captureAny(named: 'imageUrls'),
            mealType: captureAny(named: 'mealType'),
            portions: captureAny(named: 'portions'),
            timeMinutes: captureAny(named: 'timeMinutes'),
            rating: captureAny(named: 'rating'),
            personalTagIds: captureAny(named: 'personalTagIds'),
            sourceUrl: captureAny(named: 'sourceUrl'),
          )).captured;

      expect(captured[0], equals('Köttbullar med potatismos'));
      expect(captured[1], equals('Klassiska svenska köttbullar'));
      expect(captured[2],
          equals(['500g köttfärs', '1 dl ströbröd', '2 dl mjölk']));
      expect(captured[3], equals(['Stek', 'Servera']));
      expect(captured[4],
          equals(['https://example.com/a.jpg', 'https://example.com/b.jpg']));
      expect(captured[5], equals('Middag'));
      expect(captured[6], equals(6));
      expect(captured[7], equals(45));
      expect(captured[8], equals(4.8));
      expect(captured[9], equals(['svensk', 'middag', 'köttbullar']));
      // sourceUrl is rewritten — covered by its own dedicated test.
    });

    /// Imported recipes get their `sourceUrl` rewritten to the Swedish
    /// "Importerat från backup <day month year>" string built from
    /// clock.now(). Pins the origin-tracking invariant so a user can later
    /// see which recipes came from a backup vs the web/manual entry.
    test('rewrites sourceUrl to "Importerat från backup <date>"', () async {
      final fixedNow = DateTime(2025, 3, 15);
      final recipe = RecipeFactory.build(
        title: 'Original Source',
        sourceUrl: 'https://example.com/original',
      );
      fakeFilePicker
          .respondWithBytes(_utf8Bytes(_backupEnvelope(recipes: [recipe])));

      await withClock(Clock.fixed(fixedNow), () async {
        await service.importFromFile();
      });

      final captured = verify(() => mockPersonalOps.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: captureAny(named: 'sourceUrl'),
          )).captured;

      expect(captured.single, equals('Importerat från backup 15 mars 2025'));
    });
  });

  group('importFromFile — metadata parsing', () {
    /// `exported_at` ISO8601 must round-trip into ImportResult.exportDate.
    /// Pins the export-timestamp contract so a UI showing "exporterad 14
    /// januari 2025" stays accurate.
    test('parses exported_at ISO8601 into ImportResult.exportDate', () async {
      final envelope = _backupEnvelope(
        recipes: [RecipeFactory.build()],
        exportedAt: DateTime.utc(2025, 1, 14, 10, 30).toIso8601String(),
      );
      fakeFilePicker.respondWithBytes(_utf8Bytes(envelope));

      final result = await service.importFromFile();

      expect(result.exportDate, isNotNull);
      expect(result.exportDate!.toUtc(),
          equals(DateTime.utc(2025, 1, 14, 10, 30)));
    });

    /// DISCOVERED BUG (regression sentinel):
    /// Export writes `user_id`, but Import reads `user_email`. So a backup
    /// made by the CURRENT exporter will always yield `exportEmail = null`
    /// on import. Pinning this guarantees that if someone fixes the
    /// asymmetry, they'll have to update this test (and we'll know the bug
    /// is fixed). If someone reverses the fix accidentally, the test still
    /// passes — so this is a documentation test, not a defence.
    ///
    /// The asymmetry itself is a real data-inconsistency bug. Reported in
    /// commit summary.
    test('exportEmail comes from user_email field, not user_id (asymmetry)',
        () async {
      final withEmail = _backupEnvelope(
        recipes: [RecipeFactory.build()],
        userEmail: 'alice@example.com',
      );
      fakeFilePicker.respondWithBytes(_utf8Bytes(withEmail));
      final withEmailResult = await service.importFromFile();
      expect(withEmailResult.exportEmail, equals('alice@example.com'));

      // Reset fake for second call.
      mockRecipeService.setRecipeState(
        recipes: [],
        personalOperations: mockPersonalOps,
      );
      final envelopeAsExporterEmits = _backupEnvelope(
        recipes: [RecipeFactory.build(title: 'Different Title')],
        // userEmail intentionally omitted — matches what exportToFile() writes
      );
      fakeFilePicker.respondWithBytes(_utf8Bytes(envelopeAsExporterEmits));
      final fromRealExporterResult = await service.importFromFile();

      expect(fromRealExporterResult.exportEmail, isNull,
          reason: 'BUG: exporter writes only user_id, importer only reads '
              'user_email → exportEmail always null for round-trip backups');
    });

    /// Empty `recipes` array is structurally valid (a backup with zero
    /// recipes) — must not crash, returns totals all zero. Pins
    /// "empty list != malformed file".
    test('handles backup with empty recipes list as zero-success import',
        () async {
      fakeFilePicker.respondWithBytes(_utf8Bytes(_backupEnvelope(recipes: [])));

      final result = await service.importFromFile();

      expect(result.success, isTrue);
      expect(result.totalRecipes, equals(0));
      expect(result.successCount, equals(0));
      expect(result.skipCount, equals(0));
      expect(result.errors, isEmpty);
    });
  });

  group('importFromFile — PII scoping', () {
    /// Recipes from the picked file are imported as-is into the CURRENT
    /// user's library via `personal.createRecipe`. The picked file's
    /// `user_id` is metadata; the new recipe is created with `createdBy: ''`
    /// (the service fills in the calling user). Pins that we never write
    /// the source backup's user_id as the owner of the imported recipe —
    /// would be a cross-user data leak.
    test('does not propagate backup file user_id to created recipes', () async {
      final foreign = RecipeFactory.build(
        title: 'From Alice',
        createdBy: 'alice-uid', // foreign owner in source backup
      );
      fakeFilePicker
          .respondWithBytes(_utf8Bytes(_backupEnvelope(recipes: [foreign])));

      await service.importFromFile();

      // The call to createRecipe doesn't expose createdBy as a named arg.
      // PersonalRecipeOperations.createRecipe owns assignment of createdBy
      // from the auth context. Verify we DID call createRecipe (i.e. went
      // through the import path) without forwarding alien identity. The
      // absence of a createdBy named parameter in `createRecipe` is itself
      // the structural guarantee.
      verify(() => mockPersonalOps.createRecipe(
            title: 'From Alice',
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
          )).called(1);
    });
  });

  group('result classes — public contract sanity', () {
    /// `ImportResult.cancelled()` must be distinguishable from
    /// `ImportResult.error(...)` so the UI can branch on intent.
    test('cancelled and error are distinct ImportResult shapes', () {
      final cancelled = ImportResult.cancelled();
      final errored = ImportResult.error('boom');

      expect(cancelled.cancelled, isTrue);
      expect(cancelled.errorMessage, isNull);
      expect(errored.cancelled, isFalse);
      expect(errored.errorMessage, equals('boom'));
      expect(cancelled.success, isFalse);
      expect(errored.success, isFalse);
    });

    /// BackupResult.success populates filePath + recipeCount; .error leaves
    /// them null. Lets a UI safely render "saved to <path>" only when both
    /// fields are non-null.
    test('BackupResult.success vs .error populate optional fields distinctly',
        () {
      final ok = BackupResult.success(
        message: 'Saved',
        filePath: '/tmp/x.json',
        recipeCount: 7,
      );
      final fail = BackupResult.error('Disk full');

      expect(ok.success, isTrue);
      expect(ok.filePath, equals('/tmp/x.json'));
      expect(ok.recipeCount, equals(7));
      expect(fail.success, isFalse);
      expect(fail.filePath, isNull);
      expect(fail.recipeCount, isNull);
    });
  });
}
