import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/models/parsing/field_correction.dart';
import 'package:butlery/models/parsing/ingredient_correction.dart';
import 'package:butlery/models/parsing/instruction_correction.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsing_correction.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/parsing/feedback/parse_correction_uploader.dart';

class _MockAnalyticsRepo extends Mock implements AnalyticsRepository {}

class _MockConsent extends Mock implements ConsentService {}

/// BUT-595: client-side fan-out + redaction-skip + error-swallow tests.
///
/// We exercise the public [ParseCorrectionUploader] surface with an in-memory
/// callable invoker. The real Cloud Function is tested separately
/// (functions/src/__tests__/log-parse-correction.test.ts).
void main() {
  ParsingCorrection makeCorrection({
    String? successfulTier = 'LLM',
    FieldCorrection? title,
    FieldCorrection? portions,
    List<IngredientCorrection> ingredients = const [],
    List<InstructionCorrection> instructions = const [],
  }) {
    return ParsingCorrection.create(
      recipeId: 'recipe-123',
      userId: 'user-abc',
      source: ImportSource.url,
      domain: 'ica.se',
      successfulTier: successfulTier,
      originalQuality: 0.6,
      titleCorrection: title,
      portionsCorrection: portions,
      ingredientCorrections: ingredients,
      instructionCorrections: instructions,
    );
  }

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(<String, Object>{});
    registerFallbackValue(ConsentPurpose.analytics);
  });

  group('ParseCorrectionUploader.expandFields', () {
    test('one diffed field expands to one payload', () {
      final uploader = ParseCorrectionUploader(invoker: (_, __) async {});
      final correction = makeCorrection(
        title: const FieldCorrection(
          originalValue: 'Kötbullar',
          correctedValue: 'Köttbullar',
        ),
      );

      final payloads = uploader.expandFields(correction);

      expect(payloads, hasLength(1));
      expect(payloads.first.correctedField, 'title');
      expect(payloads.first.fromValue, 'Kötbullar');
      expect(payloads.first.toValue, 'Köttbullar');
    });

    test(
      'three diffed fields produce three payloads (per-field aggregation)',
      () {
        final uploader = ParseCorrectionUploader(invoker: (_, __) async {});
        final correction = makeCorrection(
          title: const FieldCorrection(originalValue: 'A', correctedValue: 'B'),
          portions: const FieldCorrection(
            originalValue: '4',
            correctedValue: '6',
          ),
          ingredients: [
            IngredientCorrection.modified(
              originalIndex: 0,
              correctedIndex: 0,
              originalLine: '3 dl mjolk',
              correctedLine: '3 dl mjölk',
              quantityChanged: false,
              unitChanged: false,
              nameChanged: true,
            ),
          ],
        );

        final payloads = uploader.expandFields(correction);

        expect(
          payloads.map((p) => p.correctedField),
          containsAll(['title', 'portions', 'ingredients']),
        );
        expect(payloads, hasLength(3));
      },
    );

    test('whitespace-only diff is dropped before upload', () {
      final uploader = ParseCorrectionUploader(invoker: (_, __) async {});
      final correction = makeCorrection(
        title: const FieldCorrection(
          originalValue: 'Köttbullar',
          correctedValue: '  Köttbullar  ',
        ),
      );

      // The FieldCorrection.create factory itself wouldn't emit this — but a
      // raw construction can. The uploader is the second line of defence.
      final payloads = uploader.expandFields(correction);
      expect(
        payloads,
        isEmpty,
        reason: 'whitespace-only diffs carry no quality signal',
      );
    });

    test('case-only diff is dropped before upload', () {
      final uploader = ParseCorrectionUploader(invoker: (_, __) async {});
      final correction = makeCorrection(
        title: const FieldCorrection(
          originalValue: 'Köttbullar',
          correctedValue: 'KÖTTBULLAR',
        ),
      );

      final payloads = uploader.expandFields(correction);
      expect(payloads, isEmpty);
    });
  });

  group('ParseCorrectionUploader.upload', () {
    test('upload fires one callable per corrected field', () {
      final calls = <Map<String, dynamic>>[];
      final uploader = ParseCorrectionUploader(
        invoker: (name, body) async {
          calls.add({'name': name, 'body': body});
        },
      );

      final correction = makeCorrection(
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
        portions: const FieldCorrection(
          originalValue: '4',
          correctedValue: '6',
        ),
      );

      final n = uploader.upload(correction: correction, salt: 'test-salt');

      expect(n, 2);
      expect(calls, hasLength(2));
      expect(calls.every((c) => c['name'] == 'logParseCorrection'), isTrue);
    });

    test('upload swallows callable errors silently', () async {
      final uploader = ParseCorrectionUploader(
        invoker: (_, __) async => throw Exception('network fail'),
      );

      final correction = makeCorrection(
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );

      // Returns enqueued count; the awaitable failure is unawaited inside.
      final n = uploader.upload(correction: correction, salt: 'salt');

      // Let the unawaited future settle.
      await Future<void>.delayed(Duration.zero);

      expect(n, 1, reason: 'enqueued before the failure');
      // No exception should escape — the test reaching this line is the proof.
    });

    test('upload hashes userId/recipeId before sending', () {
      final calls = <Map<String, dynamic>>[];
      final uploader = ParseCorrectionUploader(
        invoker: (name, body) async {
          calls.add(body);
        },
      );

      final correction = makeCorrection(
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );

      uploader.upload(correction: correction, salt: 'test-salt');

      expect(calls, hasLength(1));
      final sentBody = calls.first;
      // Must NOT contain raw IDs.
      expect(sentBody.values.contains('user-abc'), isFalse);
      expect(sentBody.values.contains('recipe-123'), isFalse);
      // Must contain hex SHA-256 hashes (64 hex chars).
      final userHash = sentBody['userIdHash'] as String;
      final recipeHash = sentBody['recipeIdHash'] as String;
      expect(userHash, hasLength(64));
      expect(recipeHash, hasLength(64));
      expect(RegExp(r'^[a-f0-9]+$').hasMatch(userHash), isTrue);
      // Salt actually mixes in: same id + different salt = different hash.
      final hashA = ParseCorrectionUploader.hashId('user-abc', 'salt-a');
      final hashB = ParseCorrectionUploader.hashId('user-abc', 'salt-b');
      expect(hashA, isNot(equals(hashB)));
    });

    test('upload maps Dart tier identifier to server snake_case', () {
      final calls = <Map<String, dynamic>>[];
      final uploader = ParseCorrectionUploader(
        invoker: (_, body) async {
          calls.add(body);
        },
      );

      final correction = makeCorrection(
        successfulTier: 'SchemaOrg',
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );

      uploader.upload(correction: correction, salt: 's');
      expect(calls.first['sourceTier'], 'schema_org');
    });

    test('upload skips entirely when sourceTier is unknown', () {
      var called = 0;
      final uploader = ParseCorrectionUploader(
        invoker: (_, __) async {
          called++;
        },
      );

      final correction = makeCorrection(
        successfulTier: 'NonExistentTier',
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );

      final n = uploader.upload(correction: correction, salt: 's');
      expect(n, 0);
      expect(called, 0);
    });

    test('upload only includes promptVersion when tier is llm', () {
      final calls = <Map<String, dynamic>>[];
      final uploader = ParseCorrectionUploader(
        invoker: (_, body) async {
          calls.add(body);
        },
      );

      // Non-llm tier: promptVersion must NOT be sent.
      final reg = makeCorrection(
        successfulTier: 'RuleBased',
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );
      uploader.upload(correction: reg, salt: 's', promptVersion: 'v1');
      expect(calls.last.containsKey('promptVersion'), isFalse);

      // llm tier: promptVersion IS sent.
      calls.clear();
      final llm = makeCorrection(
        successfulTier: 'LLM',
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );
      uploader.upload(correction: llm, salt: 's', promptVersion: 'v3.1');
      expect(calls.last['promptVersion'], 'v3.1');
    });

    test('truncate caps oversize values at 500 chars', () {
      final long = 'x' * 600;
      final out = ParseCorrectionUploader.truncate(long);
      expect(out.length, kMaxCorrectionValueChars);
      expect(out.length, 500);
    });

    test(
      'upload aggregates instructions into one ingredient/instruction doc',
      () {
        final calls = <Map<String, dynamic>>[];
        final uploader = ParseCorrectionUploader(
          invoker: (_, body) async {
            calls.add(body);
          },
        );

        final correction = makeCorrection(
          instructions: [
            InstructionCorrection.modified(
              originalIndex: 0,
              correctedIndex: 0,
              originalText: 'Step one wrong',
              correctedText: 'Step one fixed',
            ),
            InstructionCorrection.modified(
              originalIndex: 1,
              correctedIndex: 1,
              originalText: 'Step two wrong',
              correctedText: 'Step two fixed',
            ),
          ],
        );

        uploader.upload(correction: correction, salt: 's');

        // Two corrected steps → still ONE per-field doc with newline-joined text.
        expect(calls, hasLength(1));
        expect(calls.first['correctedField'], 'instructions');
        expect(calls.first['fromValue'], contains('Step one wrong'));
        expect(calls.first['fromValue'], contains('Step two wrong'));
        expect(calls.first['toValue'], contains('Step one fixed'));
      },
    );
  });

  group('ParseCorrectionUploader tier vocabulary (BUT-1486)', () {
    // Pins the client copy of the canonical Dart→server tier mapping against
    // the server-side source of truth in
    // functions/src/shared/parse-tier-vocabulary.ts (DART_TO_SERVER_TIER).
    // Dart can't import the TypeScript module, so this literal contract is the
    // drift guard: if either side changes a tier name/id without updating the
    // other, this test (and the TS parse-tier-vocabulary suite) goes red.
    const canonicalMapping = <String, String>{
      'SchemaOrg': 'schema_org',
      'SiteConfig': 'site_config',
      'RuleBased': 'rule_based',
      'LLM': 'llm',
      'SelectiveEnhance': 'selective_enhance',
      'StructuredExtraction': 'structured_extraction',
      'WebScraper': 'web_scraper',
      'HtmlTextParse': 'html_text_parse',
      'UserAssisted': 'user_assisted',
    };

    test('client map matches the canonical Dart→server contract exactly', () {
      expect(ParseCorrectionUploader.dartToServerTier, canonicalMapping);
    });

    test('every mapped tier round-trips through upload as its server id', () {
      for (final entry in canonicalMapping.entries) {
        final calls = <Map<String, dynamic>>[];
        final uploader = ParseCorrectionUploader(
          invoker: (_, body) async => calls.add(body),
        );
        final correction = makeCorrection(
          successfulTier: entry.key,
          title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
        );

        final n = uploader.upload(correction: correction, salt: 's');

        expect(n, 1, reason: '${entry.key} should map and upload');
        expect(
          calls.single['sourceTier'],
          entry.value,
          reason: '${entry.key} must send server id ${entry.value}',
        );
      }
    });
  });

  group('ParseCorrectionUploader.isWhitespaceOrCaseOnly', () {
    test('whitespace collapse', () {
      expect(
        ParseCorrectionUploader.isWhitespaceOrCaseOnly('a  b', 'a b'),
        isTrue,
      );
    });
    test('case fold', () {
      expect(
        ParseCorrectionUploader.isWhitespaceOrCaseOnly('FOO', 'foo'),
        isTrue,
      );
    });
    test('real diff', () {
      expect(
        ParseCorrectionUploader.isWhitespaceOrCaseOnly('foo', 'bar'),
        isFalse,
      );
    });
  });

  // BUT-1645 (BUT-1486 follow-up): every silent drop must emit the
  // `parse_correction_upload_dropped` metric with the correct `reason`, so the
  // dashboard can measure the correction loss rate. This asserts all four drop
  // sites fire the metric via the static `AnalyticsService.tryLog` sink.
  group('BUT-1645: drop metric fires at all 4 silent-drop sites', () {
    const dropEvent = AnalyticsEvents.parseCorrectionUploadDropped;
    const spChannel = MethodChannel('plugins.flutter.io/shared_preferences');

    // Captures the parameter maps logged for the drop event so each test can
    // assert the `reason` (and `tier`) without depending on the nondeterministic
    // truncated `cause` string the error sites attach.
    late List<Map<String, Object>> dropped;

    void registerCapturingAnalytics() {
      final repo = _MockAnalyticsRepo();
      when(
        () => repo.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((invocation) async {
        final name = invocation.namedArguments[const Symbol('name')] as String;
        final params =
            invocation.namedArguments[const Symbol('parameters')]
                as Map<String, Object>?;
        if (name == dropEvent && params != null) {
          dropped.add(params);
        }
      });

      final consent = _MockConsent();
      when(() => consent.hasConsent(any())).thenAnswer((_) async => true);

      final service = AnalyticsService(repository: repo);
      service.setConsentService(consent);

      prod.ServiceLocator.initialize(DIContainer());
      GetIt.instance.registerSingleton<AnalyticsService>(service);
    }

    // `tryLog` fires the event without awaiting; the consent check and
    // `executeServiceOperation` add several async hops. Flush the microtask
    // queue enough times for the whole chain to reach the repository stub.
    Future<void> flush() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    void setSharedPreferencesHandler(
      Future<Object?> Function(MethodCall call)? handler,
    ) {
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(spChannel, handler);
    }

    setUp(() {
      dropped = <Map<String, Object>>[];
      registerCapturingAnalytics();
    });

    tearDown(() async {
      setSharedPreferencesHandler(null);
      // Clear the cached SharedPreferences instance so each test resolves the
      // salt fresh through its own mock channel handler. We never call
      // setMockInitialValues, so the platform store stays the method-channel
      // one both handlers drive.
      SharedPreferences.resetStatic();
      prod.ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    test('unknown_tier: unmapped server tier drops and emits reason', () async {
      final uploader = ParseCorrectionUploader(invoker: (_, __) async {});
      final correction = makeCorrection(
        successfulTier: 'NonExistentTier',
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );

      final n = uploader.upload(correction: correction, salt: 's');
      await flush();

      expect(n, 0);
      expect(dropped, hasLength(1));
      expect(dropped.single['reason'], 'unknown_tier');
      expect(dropped.single['tier'], 'NonExistentTier');
    });

    test(
      'payload_error: a throw inside upload drops and emits reason',
      () async {
        // A synchronously-throwing invoker makes the per-payload dispatch throw
        // inside upload()'s try block, exercising the catch-all drop site.
        final uploader = ParseCorrectionUploader(
          invoker: (_, __) => throw StateError('sync dispatch boom'),
        );
        final correction = makeCorrection(
          title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
        );

        final n = uploader.upload(correction: correction, salt: 's');
        await flush();

        expect(n, 0);
        expect(dropped, hasLength(1));
        expect(dropped.single['reason'], 'payload_error');
      },
    );

    test(
      'salt_error: a SharedPreferences failure drops and emits reason',
      () async {
        // Must run while the platform store is still the method-channel one (no
        // setMockInitialValues anywhere in this file), so this throwing handler
        // reaches getInstance() and trips uploadWithSharedSalt()'s catch block.
        setSharedPreferencesHandler(
          (_) async => throw PlatformException(code: 'prefs_unavailable'),
        );

        final uploader = ParseCorrectionUploader(invoker: (_, __) async {});
        final correction = makeCorrection(
          title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
        );

        final n = await uploader.uploadWithSharedSalt(correction: correction);
        await flush();

        expect(n, 0);
        expect(dropped, hasLength(1));
        expect(dropped.single['reason'], 'salt_error');
      },
    );

    test('no_salt: an empty analytics salt drops and emits reason', () async {
      // Empty prefs → salt is unset → uploadWithSharedSalt skips before upload.
      setSharedPreferencesHandler((_) async => <String, Object>{});

      final uploader = ParseCorrectionUploader(invoker: (_, __) async {});
      final correction = makeCorrection(
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );

      final n = await uploader.uploadWithSharedSalt(correction: correction);
      await flush();

      expect(n, 0);
      expect(dropped, hasLength(1));
      expect(dropped.single['reason'], 'no_salt');
    });
  });
}
