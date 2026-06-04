/// Intent-driven unit tests for [AutoSaveManager] (BUT-904).
///
/// The manager is the shared draft-persistence primitive extracted from five
/// per-surface copies. These tests prove the contract every surface relies on:
///
///   * load() round-trips a persisted draft and returns null when absent,
///     empty, or undecodable (a corrupt draft must never crash a screen).
///   * save() writes eagerly with Duration.zero, and treats an
///     empty/encode-null result as "clear the key" (typing then deleting
///     everything must drop the draft, not persist "").
///   * clear() removes the key (commit-past-draft path).
///   * debounce coalesces rapid saves to the latest value; dispose() cancels
///     a pending debounced write so a torn-down owner can't resurrect a draft.
///   * every operation is best-effort: a throwing storage layer is swallowed,
///     not propagated (a failed save must never break typing or navigation).
///   * the generic `<T>` genuinely works for a non-String payload (JSON map),
///     which is why the abstraction exists rather than a String-only helper.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/persistence/auto_save_manager.dart';

/// Lets fire-and-forget eager writes and getInstance microtasks settle.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

AutoSaveManager<String> _stringManager(
  String key, {
  Duration debounce = Duration.zero,
}) =>
    AutoSaveManager<String>(
      storageKey: key,
      encode: (text) => text,
      decode: (raw) => raw,
      debounce: debounce,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('load', () {
    test('returns null when the key is absent', () async {
      final manager = _stringManager('draft_absent');
      expect(await manager.load(), isNull);
    });

    test('returns the decoded draft when present', () async {
      SharedPreferences.setMockInitialValues({'draft_present': 'hello'});
      final manager = _stringManager('draft_present');
      expect(await manager.load(), 'hello');
    });

    test('treats an empty stored string as no draft', () async {
      SharedPreferences.setMockInitialValues({'draft_empty': ''});
      final manager = _stringManager('draft_empty');
      expect(await manager.load(), isNull);
    });

    test('returns null (no throw) when decode fails', () async {
      SharedPreferences.setMockInitialValues({'draft_bad': 'not-json'});
      final manager = AutoSaveManager<Map<String, dynamic>>(
        storageKey: 'draft_bad',
        encode: jsonEncode,
        decode: (raw) => jsonDecode(raw) as Map<String, dynamic>,
      );
      expect(await manager.load(), isNull);
    });
  });

  group('save (eager / Duration.zero)', () {
    test('persists the value under the storage key', () async {
      final manager = _stringManager('draft_save');
      manager.save('typed text');
      await _settle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_save'), 'typed text');
    });

    test('removes the key when the value encodes to empty', () async {
      SharedPreferences.setMockInitialValues({'draft_clearing': 'old'});
      final manager = _stringManager('draft_clearing');
      manager.save('');
      await _settle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_clearing'), isNull);
    });

    test('removes the key when the encoder returns null', () async {
      SharedPreferences.setMockInitialValues({'draft_null_enc': 'old'});
      final manager = AutoSaveManager<String?>(
        storageKey: 'draft_null_enc',
        encode: (value) => value, // null => remove
        decode: (raw) => raw,
      );
      manager.save(null);
      await _settle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_null_enc'), isNull);
    });
  });

  group('clear', () {
    test('removes the persisted draft', () async {
      SharedPreferences.setMockInitialValues({'draft_to_clear': 'x'});
      final manager = _stringManager('draft_to_clear');
      await manager.clear();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_to_clear'), isNull);
    });
  });

  group('debounce', () {
    test('coalesces rapid saves to the latest value', () async {
      final manager = _stringManager('draft_debounce',
          debounce: const Duration(milliseconds: 40));
      manager.save('a');
      manager.save('b');
      manager.save('c');

      // Before the window elapses, nothing is written yet.
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_debounce'), isNull);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_debounce'), 'c',
          reason: 'only the latest value of a debounced burst is persisted');
    });

    test('dispose cancels a pending debounced write', () async {
      final manager = _stringManager('draft_dispose',
          debounce: const Duration(milliseconds: 40));
      manager.save('pending');
      manager.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 80));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_dispose'), isNull,
          reason: 'a torn-down owner must not resurrect its draft');
    });

    test('save after dispose is a no-op', () async {
      final manager = _stringManager('draft_after_dispose');
      manager.dispose();
      manager.save('late');
      await _settle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_after_dispose'), isNull);
    });

    test('flush writes immediately, cancelling any pending debounce', () async {
      final manager =
          _stringManager('draft_flush', debounce: const Duration(seconds: 10));
      manager.save('debounced'); // would land in 10s
      await manager.flush('now');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_flush'), 'now');
    });
  });

  group('best-effort error handling', () {
    Future<SharedPreferences> alwaysThrows() =>
        Future<SharedPreferences>.error(StateError('storage down'));

    test('load swallows storage errors and returns null', () async {
      final manager = AutoSaveManager<String>(
        storageKey: 'draft_err',
        encode: (t) => t,
        decode: (r) => r,
        prefsProvider: alwaysThrows,
      );
      expect(await manager.load(), isNull);
    });

    test('save and clear never throw when storage fails', () async {
      final manager = AutoSaveManager<String>(
        storageKey: 'draft_err',
        encode: (t) => t,
        decode: (r) => r,
        prefsProvider: alwaysThrows,
      );
      // Neither should propagate.
      manager.save('x');
      await expectLater(manager.clear(), completes);
      await expectLater(manager.flush('y'), completes);
    });
  });

  group('generic <T> (non-String payload)', () {
    test('round-trips a JSON-encoded map', () async {
      final manager = AutoSaveManager<Map<String, dynamic>>(
        storageKey: 'draft_json',
        encode: jsonEncode,
        decode: (raw) => jsonDecode(raw) as Map<String, dynamic>,
      );
      await manager.flush({'name': 'soppa', 'servings': 4});

      final restored = await manager.load();
      expect(restored, {'name': 'soppa', 'servings': 4});
    });
  });
}
