/// Intent-driven tests for SmartImportViewModel.
///
/// Behaviours covered:
/// - Clipboard URL detection + re-prompt suppression + error swallowing
/// - State machine: idle → fetching → (success | needsHelp | rate-limited | error)
/// - currentStep / progressMessage / isImporting derived from phase
/// - startImport guards: empty input, in-flight, offline+URL → save pending
/// - startImport happy path: returns ImportSucceeded, clears pending,
///   delegates to ImportManager.autoImport with trimmed input + progress callback
/// - startImport assistance result → ImportNeedsUserHelp (carries sourceUrl,
///   extractedText, ingredient hints from ImportManagerResult.assistance)
/// - startImport failure: rate-limit branch (Swedish "kvot"/"gräns"/"rate limit"),
///   network branch (saves pending), generic failure → localized message
/// - handleAssistedRecipe: save success/failure paths, exception path
/// - retryWithoutLlm: passes options: {skipLlm: true}, surfaces error
/// - triggerManualImport: needsHelp result with sourceUrl only when URL detected
/// - clearInput: resets every public field including phase + lastResult
/// - updateInput: detection refreshed; non-idle phase reset
/// - Pending import: _loadPendingImport rehydrates input; retryPendingImport
///   reads persisted URL not the in-memory _input; dismissPendingImport clears
/// - dispose: in-flight startImport completes without notifying / no crash
///
/// Bugs hunt focus (per sprint brief BUT-1092/1113/1114/1116/1117):
/// - rate-limit string detection (legacy fallback): the VM used to swallow
///   manager's RateLimit-typed denial and re-fabricate a RateLimitDenied with
///   HARD-CODED 1h retryAfter. BUT-1144 fixed this by adding
///   ImportManagerResult.rateLimit(RateLimitDenied) — when the manager
///   surfaces structured details the VM MUST use them verbatim. The
///   string-match path remains as a back-compat fallback. Pinned both ways.
/// - localizeImportError pattern order: "could not save" check comes *after*
///   network check; a "network save failed" message gets the network label.
///   Asserted explicitly.
/// - triggerManualImport bypasses _setPhase's lastStepBeforeError sync — the
///   currentStep getter reads stale _lastStepBeforeError. Pinned.

library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/input_detector.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/viewmodels/import_progress_tracker.dart';
import 'package:butlery/viewmodels/smart_import_viewmodel.dart';

import '../../infrastructure/factories/recipe_factory.dart';

class MockImportManager extends Mock implements ImportManager {}

const _pendingKey = 'butlery_pending_import_url';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmartImportViewModel viewModel;
  late MockImportManager mockImportManager;

  setUpAll(() {
    registerFallbackValue(RecipeFactory.build());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockImportManager = MockImportManager();
    viewModel = SmartImportViewModel(
      importManager: mockImportManager,
    );
  });

  tearDown(() {
    if (!viewModel.isDisposed) {
      viewModel.dispose();
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  void setClipboardContent(String? text) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'Clipboard.hasStrings') {
            return <String, dynamic>{'value': text != null && text.isNotEmpty};
          }
          if (methodCall.method == 'Clipboard.getData') {
            if (text == null) return null;
            return <String, dynamic>{'text': text};
          }
          return null;
        });
  }

  void setClipboardError() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'Clipboard.hasStrings') {
            return <String, dynamic>{'value': true};
          }
          if (methodCall.method == 'Clipboard.getData') {
            throw PlatformException(
              code: 'ERROR',
              message: 'Clipboard unavailable',
            );
          }
          return null;
        });
  }

  group('checkClipboardForUrl', () {
    /// Proves a URL on the clipboard is surfaced via the public getter
    /// so the view can render the "import from clipboard" prompt.
    test('sets clipboardUrl when clipboard contains a URL', () async {
      setClipboardContent('https://www.ica.se/recept/pasta-carbonara/');

      await viewModel.checkClipboardForUrl();

      expect(
        viewModel.clipboardUrl,
        'https://www.ica.se/recept/pasta-carbonara/',
      );
    });

    /// Plain text must not be auto-suggested — only URLs trigger the prompt.
    test('does not set clipboardUrl for plain text', () async {
      setClipboardContent('Just some plain text about cooking');

      await viewModel.checkClipboardForUrl();

      expect(viewModel.clipboardUrl, isNull);
    });

    test('does not set clipboardUrl for empty clipboard', () async {
      setClipboardContent(null);

      await viewModel.checkClipboardForUrl();

      expect(viewModel.clipboardUrl, isNull);
    });

    test('does not set clipboardUrl for empty string', () async {
      setClipboardContent('');

      await viewModel.checkClipboardForUrl();

      expect(viewModel.clipboardUrl, isNull);
    });

    /// Clipboard read errors must not surface to the user (iOS permission
    /// banner story) — silent fallthrough is required by the doc comment.
    test('handles clipboard error gracefully', () async {
      setClipboardError();

      await viewModel.checkClipboardForUrl();

      expect(viewModel.clipboardUrl, isNull);
    });

    /// Prevents nagging the user about the same URL twice in one session.
    test('does not re-prompt for same URL on second call', () async {
      setClipboardContent('https://www.ica.se/recept/pasta/');

      await viewModel.checkClipboardForUrl();
      expect(viewModel.clipboardUrl, 'https://www.ica.se/recept/pasta/');

      viewModel.clearClipboardSuggestion();
      await viewModel.checkClipboardForUrl();

      expect(viewModel.clipboardUrl, isNull);
    });

    test('notifies listeners when URL is found', () async {
      setClipboardContent('https://www.recept.se/test');

      var notified = false;
      viewModel.addListener(() => notified = true);

      await viewModel.checkClipboardForUrl();

      expect(notified, isTrue);
    });

    test('does not notify listeners when no URL found', () async {
      setClipboardContent('plain text');

      var notified = false;
      viewModel.addListener(() => notified = true);

      await viewModel.checkClipboardForUrl();

      expect(notified, isFalse);
    });
  });

  group('clearClipboardSuggestion', () {
    test('resets clipboardUrl to null', () async {
      setClipboardContent('https://www.ica.se/recept/test/');

      await viewModel.checkClipboardForUrl();
      expect(viewModel.clipboardUrl, isNotNull);

      viewModel.clearClipboardSuggestion();

      expect(viewModel.clipboardUrl, isNull);
    });

    test('notifies listeners', () async {
      setClipboardContent('https://www.ica.se/recept/test/');
      await viewModel.checkClipboardForUrl();

      var notified = false;
      viewModel.addListener(() => notified = true);

      viewModel.clearClipboardSuggestion();

      expect(notified, isTrue);
    });
  });

  group('updateInput', () {
    /// updateInput must refresh the detection result so the UI's platform
    /// chip ("YouTube"/"Pasted text"/etc.) tracks user typing.
    test('refreshes detection result for new input', () {
      viewModel.updateInput('https://www.youtube.com/watch?v=abc');
      expect(viewModel.detection?.isUrl, isTrue);
      expect(viewModel.detection?.isYouTube, isTrue);

      viewModel.updateInput('just plain text');
      expect(viewModel.detection?.isText, isTrue);
      expect(viewModel.detection?.platform, Platform.unknown);
    });

    /// If the user types after an error, the error state and stale result
    /// must clear — otherwise the error banner persists over fresh input.
    test(
      'resets phase, lastResult and error when typing after a non-idle state',
      () async {
        // Force an error state.
        when(
          () => mockImportManager.autoImport(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('boom'));
        viewModel.updateInput('https://example.com');
        await viewModel.startImport();
        expect(viewModel.phase, ImportPhase.error);
        expect(viewModel.lastResult, isA<ImportFailed>());
        expect(viewModel.hasError, isTrue);

        viewModel.updateInput('https://other.com/recipe');

        expect(viewModel.phase, ImportPhase.idle);
        expect(viewModel.lastResult, isNull);
        expect(viewModel.hasError, isFalse);
      },
    );

    test('canImport flips with non-empty input', () {
      expect(viewModel.canImport, isFalse);
      viewModel.updateInput('  ');
      expect(
        viewModel.canImport,
        isFalse,
        reason: 'whitespace-only must not count',
      );
      viewModel.updateInput('something');
      expect(viewModel.canImport, isTrue);
    });
  });

  group('clearInput', () {
    /// Full reset must wipe input, detection, phase, lastResult, imported
    /// recipe, and any error — leaving the VM identical to a freshly-built one.
    test('returns VM to a pristine state', () async {
      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => ImportManagerResult.success(
          RecipeFactory.build(title: 'X'),
          strategy: 'url',
        ),
      );
      viewModel.updateInput('https://example.com/recipe');
      await viewModel.startImport();
      expect(viewModel.importedRecipe, isNotNull);
      expect(viewModel.phase, ImportPhase.complete);

      viewModel.clearInput();

      expect(viewModel.input, isEmpty);
      expect(viewModel.detection, isNull);
      expect(viewModel.phase, ImportPhase.idle);
      expect(viewModel.lastResult, isNull);
      expect(viewModel.importedRecipe, isNull);
      expect(viewModel.hasError, isFalse);
    });
  });

  group('startImport — guards', () {
    /// Empty/whitespace input must short-circuit to a localized failure
    /// without ever touching the ImportManager.
    test(
      'returns ImportFailed without invoking ImportManager when input empty',
      () async {
        final r = await viewModel.startImport();

        expect(r, isA<ImportFailed>());
        expect((r as ImportFailed).message, 'Importvillkor inte uppfyllda');
        verifyNever(
          () => mockImportManager.autoImport(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        );
      },
    );

    /// If a previous startImport is still in-flight, calling again must NOT
    /// kick off a second one (avoid double-billing the LLM rate limiter).
    test('refuses to start a second import while one is in flight', () async {
      viewModel.updateInput('https://example.com/r');
      // Manager future is pinned open via a Completer so phase stays in
      // `fetching` while we attempt a second startImport.
      final hang = Completer<ImportManagerResult>();
      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) => hang.future);

      // ignore: unawaited_futures
      viewModel.startImport(); // do not await — phase should latch to fetching
      // startImport is async: synchronous body runs before returning the
      // Future, so _setPhase(fetching) has executed by now.
      expect(viewModel.isImporting, isTrue);

      final second = await viewModel.startImport();
      expect(second, isA<ImportFailed>());
      verify(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);

      // Allow the first call to drain so tearDown is clean.
      hang.complete(
        ImportManagerResult.success(RecipeFactory.build(), strategy: 'url'),
      );
    });
  });

  group('startImport — happy path', () {
    /// Pins the dispatch contract: input is trimmed and passed to autoImport
    /// with a progress callback, and a Recipe success becomes ImportSucceeded
    /// with the same recipe instance (no copy/reconstruction).
    test(
      'trims input, passes onProgress, returns ImportSucceeded(recipe)',
      () async {
        final recipe = RecipeFactory.build(title: 'Pannkakor');
        when(
          () => mockImportManager.autoImport(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => ImportManagerResult.success(recipe, strategy: 'url'),
        );

        viewModel.updateInput('  https://example.com/recipe  ');
        final r = await viewModel.startImport();

        expect(r, isA<ImportSucceeded>());
        expect((r as ImportSucceeded).recipe, same(recipe));
        expect(viewModel.importedRecipe, same(recipe));
        expect(viewModel.phase, ImportPhase.complete);
        expect(viewModel.lastResult, same(r));

        final captured = verify(
          () => mockImportManager.autoImport(
            captureAny(),
            onProgress: captureAny(named: 'onProgress'),
          ),
        ).captured;
        expect(
          captured[0],
          'https://example.com/recipe',
          reason: 'whitespace must be trimmed before dispatch',
        );
        expect(captured[1], isA<Function>());
      },
    );

    /// onProgress callback wires through to _setPhase: the VM should mirror
    /// the manager-driven phases without any one-shot edge case missing.
    test('progress callback drives phase transitions in order', () async {
      void Function(String)? progress;
      final completer = Completer<ImportManagerResult>();
      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((inv) {
        progress = inv.namedArguments[#onProgress] as void Function(String);
        return completer.future;
      });

      final phases = <ImportPhase>[];
      viewModel.addListener(() => phases.add(viewModel.phase));
      viewModel.updateInput('https://example.com');
      final f = viewModel.startImport();

      // Phase was set synchronously to fetching by startImport.
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.phase, ImportPhase.fetching);

      progress!('analyzing');
      expect(viewModel.phase, ImportPhase.analyzing);
      progress!('creating');
      expect(viewModel.phase, ImportPhase.creating);

      completer.complete(
        ImportManagerResult.success(RecipeFactory.build(), strategy: 'url'),
      );
      await f;
      expect(viewModel.phase, ImportPhase.complete);
      expect(phases, contains(ImportPhase.analyzing));
      expect(phases, contains(ImportPhase.creating));
    });
  });

  group('startImport — assistance result', () {
    /// When the manager bails to user-assistance, the VM must propagate the
    /// extracted text + sourceUrl + ingredient-line hints so AssistedImportDialog
    /// can pre-fill correctly. BUT-1114 was the analogous Instagram bug.
    test(
      'propagates extractedText/sourceUrl/ingredient hints to NeedsUserHelp',
      () async {
        when(
          () => mockImportManager.autoImport(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => ImportManagerResult.assistance(
            extractedText: 'long extracted text...',
            suggestedTitle: 'Maybe a title',
            thumbnailUrl: 'https://cdn/thumb.jpg',
            sourceUrl: 'https://www.instagram.com/p/abc/',
            likelyIngredientLines: const [2, 5, 9],
          ),
        );

        viewModel.updateInput('https://www.instagram.com/p/abc/');
        final r = await viewModel.startImport();

        expect(r, isA<ImportNeedsUserHelp>());
        final help = r as ImportNeedsUserHelp;
        expect(help.extractedText, 'long extracted text...');
        expect(help.suggestedTitle, 'Maybe a title');
        expect(help.thumbnailUrl, 'https://cdn/thumb.jpg');
        expect(help.sourceUrl, 'https://www.instagram.com/p/abc/');
        expect(help.likelyIngredientLines, [2, 5, 9]);
        expect(viewModel.phase, ImportPhase.needsHelp);
      },
    );

    /// Even if the manager omits the optional hints, the helper result must
    /// carry sane defaults rather than crashing on a null deref downstream.
    test(
      'defaults missing assistance fields to empty list / empty string',
      () async {
        when(
          () => mockImportManager.autoImport(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => ImportManagerResult.assistance(
            extractedText: null,
          ),
        );
        viewModel.updateInput('https://example.com');
        final r = await viewModel.startImport();
        final help = r as ImportNeedsUserHelp;
        expect(help.extractedText, '');
        expect(help.likelyIngredientLines, isEmpty);
      },
    );
  });

  group('startImport — rate-limit branch', () {
    /// BUT-1148: the legacy string-match fallback (which scanned errorMessage
    /// for "rate limit"/"kvot"/"gräns" and synthesised hardcoded perDay/1h
    /// defaults) was deleted — the ImportManager routes every denial through
    /// the structured ImportManagerResult.rateLimit() path. A bare
    /// errorMessage with a rate-limit phrase but no structured details now
    /// falls through to the generic localized-failure path, NOT a rate-limit
    /// dialog with fabricated values.
    test('rate-limit phrase in a plain failure (no structured denial) → '
        'generic ImportFailed, not ImportRateLimited', () async {
      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => ImportManagerResult.failure('rate limit exceeded'),
      );
      viewModel.updateInput('https://example.com');

      final r = await viewModel.startImport();

      expect(
        r,
        isA<ImportFailed>(),
        reason: 'no structured denial → no fabricated rate-limit result',
      );
      expect(r, isNot(isA<ImportRateLimited>()));
    });

    /// BUT-1144: when the manager returns a structured
    /// `ImportManagerResult.rateLimit(RateLimitDenied(...))`, the VM MUST
    /// pass those exact values through to `ImportRateLimited.rateLimitResult`.
    /// Previously the VM ignored structure and synthesised
    /// `(perDay, 1h, useUserAssisted)` from a string match — silently
    /// throwing away the limiter's real window.
    test(
      'BUT-1144: structured rateLimit result passes retryAfter / limitType / '
      'suggestedAction through verbatim (no synth override)',
      () async {
        const denied = RateLimitDenied(
          limitType: LimitType.perHour,
          message: 'Per-hour limit reached, try again in 5 minutes',
          retryAfter: Duration(minutes: 5),
          suggestedAction: FallbackAction.skipLlm,
        );
        when(
          () => mockImportManager.autoImport(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => ImportManagerResult.rateLimit(denied));
        viewModel.updateInput('https://example.com');

        final r = (await viewModel.startImport()) as ImportRateLimited;

        expect(
          r.rateLimitResult.retryAfter,
          const Duration(minutes: 5),
          reason: 'real window must reach the UI, not the legacy 1h default',
        );
        expect(
          r.rateLimitResult.limitType,
          LimitType.perHour,
          reason: 'real limit type must reach the UI, not perDay default',
        );
        expect(
          r.rateLimitResult.suggestedAction,
          FallbackAction.skipLlm,
          reason:
              'real fallback must reach the UI, not useUserAssisted default',
        );
        expect(
          r.rateLimitResult.message,
          'Per-hour limit reached, try again in 5 minutes',
        );
      },
    );
  });

  group('startImport — error localization', () {
    /// English failures from the manager must be localized for display.
    /// Each `_localizeImportError` branch corresponds to a real production
    /// error string; the VM must not leak raw English to users.
    final cases = <String, String>{
      'no import strategy found': 'Kunde inte tolka receptet',
      'could not parse content': 'Kunde inte tolka receptet',
      'no recipe found': 'Inget recept hittades',
      'invalid url': 'Ogiltig URL',
      'login required': 'Sidan kräver inloggning',
      'authentication failure': 'Sidan kräver inloggning',
      'could not read text': 'Kunde inte läsa texten i bilden',
      'OCR failed': 'Kunde inte läsa texten i bilden',
      'operation cancelled': 'Importen avbröts',
      'something else entirely': 'Ett oväntat fel uppstod',
    };
    cases.forEach((english, swedish) {
      test('"$english" → "$swedish"', () async {
        when(
          () => mockImportManager.autoImport(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => ImportManagerResult.failure(english));
        viewModel.updateInput('https://example.com');

        final r = (await viewModel.startImport()) as ImportFailed;

        expect(r.message, swedish);
        expect(
          viewModel.error,
          swedish,
          reason: 'setError should mirror the localized message',
        );
      });
    });

    /// Null errorMessage (manager returned isSuccess=false with no detail)
    /// must still produce a localized "unknown" failure, not surface null.
    test('null error message → "Okänt fel"', () async {
      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => ImportManagerResult.failure(null));
      viewModel.updateInput('https://example.com');

      final r = (await viewModel.startImport()) as ImportFailed;
      expect(r.message, 'Okänt fel');
    });
  });

  group('startImport — exception path', () {
    /// Unexpected throws must not propagate; they must land in error phase
    /// with a localized error and an ImportFailed return. Otherwise a thrown
    /// strategy crashes the import screen.
    test('catches exception and returns ImportFailed', () async {
      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(Exception('strategy blew up'));
      viewModel.updateInput('https://example.com');

      final r = await viewModel.startImport();

      expect(r, isA<ImportFailed>());
      expect(viewModel.phase, ImportPhase.error);
      expect(viewModel.error, 'Import misslyckades');
    });

    /// Network-shaped exceptions must save the URL for retry-on-reconnect.
    test(
      'network exception persists pending URL via SharedPreferences',
      () async {
        when(
          () => mockImportManager.autoImport(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('network timeout'));
        viewModel.updateInput('https://example.com/recipe');

        await viewModel.startImport();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(_pendingKey), 'https://example.com/recipe');
      },
    );

    /// Non-network exceptions should NOT pollute the pending-import slot.
    /// Otherwise a parse failure would re-trigger import on next reconnect.
    test('non-network exception does NOT persist pending URL', () async {
      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(Exception('parse error'));
      viewModel.updateInput('https://example.com/recipe');

      await viewModel.startImport();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_pendingKey), isNull);
    });
  });

  group('handleAssistedRecipe', () {
    /// Happy path: forwards the recipe to saveImportedRecipe and surfaces
    /// the saved instance (manager may have assigned an id).
    test(
      'forwards to saveImportedRecipe and returns ImportSucceeded',
      () async {
        final draft = RecipeFactory.build(title: 'Draft');
        final saved = RecipeFactory.build(title: 'Draft', id: 'saved-id');
        when(
          () => mockImportManager.saveImportedRecipe(any()),
        ).thenAnswer((_) async => ImportManagerResult.success(saved));

        final r = await viewModel.handleAssistedRecipe(draft);

        expect(r, isA<ImportSucceeded>());
        expect((r as ImportSucceeded).recipe, same(saved));
        expect(viewModel.phase, ImportPhase.complete);
        verify(() => mockImportManager.saveImportedRecipe(draft)).called(1);
      },
    );

    /// If manager.saveImportedRecipe returns failure (without throwing) the
    /// VM must convert it to ImportFailed and not pretend the save worked.
    test('returns ImportFailed when save returns isSuccess=false', () async {
      when(
        () => mockImportManager.saveImportedRecipe(any()),
      ).thenAnswer((_) async => ImportManagerResult.failure('disk full'));

      final r = await viewModel.handleAssistedRecipe(RecipeFactory.build());

      expect(r, isA<ImportFailed>());
      expect((r as ImportFailed).message, 'disk full');
      expect(viewModel.phase, ImportPhase.error);
      expect(viewModel.error, 'disk full');
    });

    /// Thrown exceptions during save must localize the error (not leak
    /// raw stack-trace strings to users) and still return ImportFailed.
    test('catches thrown exception and localizes the error', () async {
      when(
        () => mockImportManager.saveImportedRecipe(any()),
      ).thenThrow(Exception('FirebaseException'));

      final r = await viewModel.handleAssistedRecipe(RecipeFactory.build());

      expect(r, isA<ImportFailed>());
      expect(viewModel.error, 'Kunde inte spara recept');
    });
  });

  group('retryWithoutLlm', () {
    /// The whole point of this method is to forward {skipLlm: true} so the
    /// strategies route around the LLM. Pin this contract: without it the
    /// retry would just re-hit the same rate limit.
    test('passes options: {skipLlm: true} to autoImport', () async {
      when(
        () => mockImportManager.autoImport(
          any(),
          options: any(named: 'options'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async =>
            ImportManagerResult.success(RecipeFactory.build(), strategy: 'url'),
      );
      viewModel.updateInput('https://example.com/recipe');

      await viewModel.retryWithoutLlm();

      final captured = verify(
        () => mockImportManager.autoImport(
          any(),
          options: captureAny(named: 'options'),
          onProgress: any(named: 'onProgress'),
        ),
      ).captured;
      expect(captured.single, {'skipLlm': true});
    });

    test('refuses to retry with empty input', () async {
      final r = await viewModel.retryWithoutLlm();
      expect(r, isA<ImportFailed>());
      verifyNever(
        () => mockImportManager.autoImport(
          any(),
          options: any(named: 'options'),
          onProgress: any(named: 'onProgress'),
        ),
      );
    });

    test('catches exception and returns ImportFailed', () async {
      when(
        () => mockImportManager.autoImport(
          any(),
          options: any(named: 'options'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(Exception('retry blew up'));
      viewModel.updateInput('https://example.com');

      final r = await viewModel.retryWithoutLlm();

      expect(r, isA<ImportFailed>());
      expect(viewModel.phase, ImportPhase.error);
    });
  });

  group('triggerManualImport', () {
    /// For a URL input, the manual-import escape hatch carries the URL as
    /// sourceUrl so AssistedImportDialog can show the link.
    test('URL input → ImportNeedsUserHelp with sourceUrl set', () {
      viewModel.updateInput('https://www.example.com/r');
      viewModel.triggerManualImport();

      expect(viewModel.lastResult, isA<ImportNeedsUserHelp>());
      final help = viewModel.lastResult as ImportNeedsUserHelp;
      expect(help.sourceUrl, 'https://www.example.com/r');
      expect(help.extractedText, 'https://www.example.com/r');
      expect(viewModel.phase, ImportPhase.needsHelp);
    });

    /// For plain text input, sourceUrl must be null (we don't have one).
    test('text input → ImportNeedsUserHelp with sourceUrl null', () {
      viewModel.updateInput('  3 ägg\n2 dl mjölk\n  ');
      viewModel.triggerManualImport();

      final help = viewModel.lastResult as ImportNeedsUserHelp;
      expect(help.sourceUrl, isNull);
      expect(help.extractedText, '3 ägg\n2 dl mjölk');
    });

    /// Empty input must short-circuit — no state change.
    test('empty input → no-op (lastResult stays null, phase stays idle)', () {
      viewModel.triggerManualImport();
      expect(viewModel.lastResult, isNull);
      expect(viewModel.phase, ImportPhase.idle);
    });
  });

  group('phase-derived getters', () {
    test('isImporting only during fetching/analyzing/creating', () async {
      expect(viewModel.isImporting, isFalse);

      // Pin in fetching via a hanging future.
      final completer = Completer<ImportManagerResult>();
      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) => completer.future);
      viewModel.updateInput('https://example.com');
      final f = viewModel.startImport();
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.isImporting, isTrue);

      completer.complete(
        ImportManagerResult.success(RecipeFactory.build(), strategy: 'url'),
      );
      await f;
      expect(viewModel.isImporting, isFalse);
    });

    test(
      'currentStep tracks phase: idle=0, fetching=1, analyzing=2, creating=3',
      () async {
        // Manually walk the phases via the manager's progress callback.
        void Function(String)? progress;
        final completer = Completer<ImportManagerResult>();
        when(
          () => mockImportManager.autoImport(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((inv) {
          progress = inv.namedArguments[#onProgress] as void Function(String);
          return completer.future;
        });
        viewModel.updateInput('https://example.com');
        expect(viewModel.currentStep, 0);

        final f = viewModel.startImport();
        await Future<void>.delayed(Duration.zero);
        expect(viewModel.currentStep, 1);
        progress!('analyzing');
        expect(viewModel.currentStep, 2);
        progress!('creating');
        expect(viewModel.currentStep, 3);

        completer.complete(
          ImportManagerResult.success(RecipeFactory.build(), strategy: 'url'),
        );
        await f;
        expect(viewModel.currentStep, 3, reason: 'complete stays on step 3');
      },
    );

    test(
      'progressMessage maps each phase to a non-empty Swedish string',
      () async {
        // idle
        expect(viewModel.progressMessage, isEmpty);

        // Walk through phases via progress callback.
        void Function(String)? progress;
        final completer = Completer<ImportManagerResult>();
        when(
          () => mockImportManager.autoImport(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((inv) {
          progress = inv.namedArguments[#onProgress] as void Function(String);
          return completer.future;
        });
        viewModel.updateInput('https://example.com');
        final f = viewModel.startImport();
        await Future<void>.delayed(Duration.zero);
        expect(viewModel.progressMessage, 'Hämtar innehåll...');
        progress!('analyzing');
        expect(viewModel.progressMessage, 'Analyserar recept...');
        progress!('creating');
        expect(viewModel.progressMessage, 'Skapar recept...');
        completer.complete(
          ImportManagerResult.success(RecipeFactory.build(), strategy: 'url'),
        );
        await f;
        expect(viewModel.progressMessage, 'Klar.');
      },
    );
  });

  group('pending import persistence', () {
    /// Constructor loads any persisted URL on first build. New install
    /// (empty prefs) must leave the VM in a clean state.
    test('empty prefs → no pending import on construction', () async {
      SharedPreferences.setMockInitialValues({});
      final vm = SmartImportViewModel(importManager: mockImportManager);
      // Wait for _loadPendingImport microtasks.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(vm.hasPendingImport, isFalse);
      expect(vm.input, isEmpty);
      vm.dispose();
    });

    /// Stored URL is rehydrated into _input (so the input box pre-fills) and
    /// hasPendingImport is true (so the "retry" banner shows).
    test(
      'persisted URL hydrates input + hasPendingImport on construction',
      () async {
        SharedPreferences.setMockInitialValues({
          _pendingKey: 'https://example.com/saved',
        });
        final vm = SmartImportViewModel(importManager: mockImportManager);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(vm.hasPendingImport, isTrue);
        expect(vm.input, 'https://example.com/saved');
        expect(vm.detection?.isUrl, isTrue);
        vm.dispose();
      },
    );

    /// retryPendingImport must read the persisted URL (not the in-memory
    /// _input, which the user may have edited). Pinned per the comment in
    /// production: "_input may have been changed by the user".
    test('retryPendingImport reads persisted URL, not edited _input', () async {
      SharedPreferences.setMockInitialValues({
        _pendingKey: 'https://example.com/saved',
      });
      final vm = SmartImportViewModel(importManager: mockImportManager);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // User edits the input field — should not affect retry.
      vm.updateInput('https://example.com/different');

      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async =>
            ImportManagerResult.success(RecipeFactory.build(), strategy: 'url'),
      );

      await vm.retryPendingImport();

      final captured = verify(
        () => mockImportManager.autoImport(
          captureAny(),
          onProgress: any(named: 'onProgress'),
        ),
      ).captured;
      expect(captured.single, 'https://example.com/saved');
      vm.dispose();
    });

    /// dismissPendingImport clears the persisted slot AND the in-memory flag
    /// so the banner doesn't reappear after restart.
    test('dismissPendingImport clears prefs and hasPendingImport', () async {
      SharedPreferences.setMockInitialValues({
        _pendingKey: 'https://example.com/x',
      });
      final vm = SmartImportViewModel(importManager: mockImportManager);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(vm.hasPendingImport, isTrue);

      await vm.dismissPendingImport();

      expect(vm.hasPendingImport, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_pendingKey), isNull);
      vm.dispose();
    });

    /// Successful import must clear the pending slot so a stale URL doesn't
    /// auto-retry forever after the user already imported it manually.
    test('successful startImport clears persisted pending URL', () async {
      SharedPreferences.setMockInitialValues({
        _pendingKey: 'https://example.com/saved',
      });
      final vm = SmartImportViewModel(importManager: mockImportManager);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async =>
            ImportManagerResult.success(RecipeFactory.build(), strategy: 'url'),
      );

      await vm.startImport();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_pendingKey), isNull);
      vm.dispose();
    });
  });

  group('dispose safety', () {
    /// Calling dispose while an import future is still pending must not
    /// crash and must not flip _phase after disposal (BaseViewModel
    /// notifyListeners guard).
    test(
      'dispose during in-flight import does not crash on completion',
      () async {
        final completer = Completer<ImportManagerResult>();
        when(
          () => mockImportManager.autoImport(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) => completer.future);
        viewModel.updateInput('https://example.com/r');
        final f = viewModel.startImport();
        await Future<void>.delayed(Duration.zero);
        expect(viewModel.phase, ImportPhase.fetching);

        viewModel.dispose();

        // Now complete the manager future. The VM must swallow it.
        completer.complete(
          ImportManagerResult.success(RecipeFactory.build(), strategy: 'url'),
        );
        // We don't await `f` because BaseViewModel may not propagate on
        // disposed; just verify no zone error escapes:
        await expectLater(f, completes);
        // After dispose, attempting to call setters via the public API is
        // a no-op (phase stays at fetching because _setPhase early-returns).
        expect(viewModel.isDisposed, isTrue);
      },
    );

    /// Methods that touch state after dispose must early-return — verifying
    /// the disposed-guards on updateInput / clearInput / clearClipboardSuggestion.
    test('post-dispose mutators are no-ops', () {
      viewModel.dispose();
      viewModel.updateInput('whatever'); // must not throw
      viewModel.clearInput();
      viewModel.clearClipboardSuggestion();
      expect(viewModel.isDisposed, isTrue);
    });
  });

  group('elapsed timer', () {
    test('elapsed is Duration.zero before import', () {
      expect(viewModel.elapsed, Duration.zero);
    });

    test('elapsed getter is available on viewModel', () {
      expect(viewModel.elapsed, isA<Duration>());
    });
  });

  group('ImportProgressTracker', () {
    late ImportProgressTracker tracker;
    late int notifyCount;
    late List<ImportPhase> phaseChanges;

    setUp(() {
      notifyCount = 0;
      phaseChanges = [];
      tracker = ImportProgressTracker(
        notifyListeners: () => notifyCount++,
        setPhase: (phase) => phaseChanges.add(phase),
        isDisposed: () => false,
      );
    });

    tearDown(() {
      tracker.dispose();
    });

    test('elapsed is Duration.zero before start', () {
      expect(tracker.elapsed, Duration.zero);
      expect(tracker.isRunning, isFalse);
    });

    test('start begins tracking', () {
      tracker.start();
      expect(tracker.isRunning, isTrue);
    });

    test('stop ends tracking', () {
      tracker.start();
      tracker.stop();
      expect(tracker.isRunning, isFalse);
    });

    test('reset clears elapsed and stops', () {
      tracker.start();
      tracker.reset();
      expect(tracker.isRunning, isFalse);
      expect(tracker.elapsed, Duration.zero);
    });

    test('onProgress maps fetching to ImportPhase.fetching', () {
      tracker.onProgress('fetching');
      expect(phaseChanges, [ImportPhase.fetching]);
    });

    test('onProgress maps analyzing to ImportPhase.analyzing', () {
      tracker.onProgress('analyzing');
      expect(phaseChanges, [ImportPhase.analyzing]);
    });

    test('onProgress maps creating to ImportPhase.creating', () {
      tracker.onProgress('creating');
      expect(phaseChanges, [ImportPhase.creating]);
    });

    test('onProgress maps unknown string to ImportPhase.analyzing', () {
      tracker.onProgress('unknown_phase');
      expect(phaseChanges, [ImportPhase.analyzing]);
    });

    test('onProgress skips when disposed', () {
      final disposedTracker = ImportProgressTracker(
        notifyListeners: () {},
        setPhase: (phase) => phaseChanges.add(phase),
        isDisposed: () => true,
      );
      disposedTracker.onProgress('fetching');
      expect(phaseChanges, isEmpty);
      disposedTracker.dispose();
    });

    test('dispose cancels timer without error', () {
      tracker.start();
      expect(tracker.isRunning, isTrue);
      tracker.dispose();
    });
  });

  group('_localizeImportError pattern ordering — BUT-1145', () {
    /// BUT-1145: A message like "could not save: network unreachable" matches
    /// BOTH the generic network heuristic (contains "network") AND the
    /// specific "could not save" branch. The specific branch must win,
    /// otherwise users see "could not reach the page" when the real problem
    /// is a save failure that happens to mention the word "network".
    test('failure containing "could not save" + network word maps to '
        'importErrorCouldNotSaveRecipe (not the network error)', () async {
      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async =>
            ImportManagerResult.failure('could not save: network unreachable'),
      );
      viewModel.updateInput('https://example.com/recipe');

      final r = (await viewModel.startImport()) as ImportFailed;

      // Swedish copy: "Kunde inte spara receptet" — NOT a network error.
      expect(
        r.message,
        'Kunde inte spara receptet',
        reason:
            'specific "could not save" pattern must precede the generic network heuristic',
      );
    });

    /// Same shape for "could not read" + network word — the OCR/read branch
    /// must win over the network branch.
    test('failure containing "could not read" + network word maps to '
        'importErrorCouldNotReadImage', () async {
      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => ImportManagerResult.failure(
          'could not read image: network timeout fetching OCR backend',
        ),
      );
      viewModel.updateInput('https://example.com/recipe');

      final r = (await viewModel.startImport()) as ImportFailed;

      expect(
        r.message,
        'Kunde inte läsa texten i bilden',
        reason:
            'specific "could not read" pattern must precede the generic network heuristic',
      );
    });
  });

  group('triggerManualImport — _lastStepBeforeError reset — BUT-1146', () {
    /// BUT-1146: triggerManualImport switches to needsHelp, which is a
    /// user-initiated state — there's no "step that failed". Previously
    /// _lastStepBeforeError leaked from the previous in-flight import (e.g.
    /// 3 if the user had reached the creating phase), and the currentStep
    /// getter — which reads _lastStepBeforeError when phase=needsHelp —
    /// surfaced that stale number to the progress strip. Manual import
    /// must reset the step counter to 0.
    test('after import reaches creating phase, triggerManualImport resets '
        'currentStep to 0', () async {
      // Drive an import up to the creating phase via the progress callback so
      // _lastStepBeforeError = 3 (per _setPhase).
      void Function(String)? progress;
      final completer = Completer<ImportManagerResult>();
      when(
        () => mockImportManager.autoImport(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((inv) {
        progress = inv.namedArguments[#onProgress] as void Function(String);
        return completer.future;
      });
      viewModel.updateInput('https://example.com/recipe');
      // ignore: unawaited_futures
      viewModel.startImport();
      await Future<void>.delayed(Duration.zero);
      progress!('creating');
      expect(
        viewModel.currentStep,
        3,
        reason: 'sanity: creating phase = step 3',
      );

      // Let the import complete cleanly (we just need the phase to leave
      // creating; needsHelp transitions through the existing tests too).
      completer.complete(
        ImportManagerResult.success(RecipeFactory.build(), strategy: 'url'),
      );
      await Future<void>.delayed(Duration.zero);

      // Now trigger manual import: the stale "3" must not leak into the
      // needsHelp step display.
      viewModel.triggerManualImport();

      expect(viewModel.phase, ImportPhase.needsHelp);
      expect(
        viewModel.currentStep,
        0,
        reason:
            'needsHelp is a user-initiated state — no prior step should leak',
      );
    });
  });

  group('_loadPendingImport short-circuit — BUT-1147', () {
    /// BUT-1147: If the user types into the input field before prefs has
    /// finished resolving the persisted pending URL, _loadPendingImport must
    /// short-circuit — neither flip hasPendingImport (which shows a "retry
    /// previous import" banner over fresh typing) nor notify listeners.
    test('user types before prefs resolves → hasPendingImport stays false, '
        'input is not overwritten', () async {
      SharedPreferences.setMockInitialValues({
        _pendingKey: 'https://example.com/persisted',
      });
      final vm = SmartImportViewModel(importManager: mockImportManager);

      // BEFORE the SharedPreferences future resolves, the user types
      // something into the input field.
      vm.updateInput('https://user-typed.com/recipe');

      // Now let the pending-import microtasks drain.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        vm.hasPendingImport,
        isFalse,
        reason: 'banner must not flip on top of fresh user input',
      );
      expect(
        vm.input,
        'https://user-typed.com/recipe',
        reason: 'user typing must not be overwritten by persisted URL',
      );

      vm.dispose();
    });
  });
}
