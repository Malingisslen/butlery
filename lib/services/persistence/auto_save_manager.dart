import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';

/// Encodes a draft value to its persisted string form. Returning `null` — or an
/// empty string — means "nothing worth keeping", so the key is removed instead
/// of written. This matches the per-surface convention where clearing the field
/// drops the draft.
typedef DraftEncoder<T> = String? Function(T value);

/// Decodes a persisted string back into a draft value. Returning `null` means
/// "no usable draft" and is treated like an absent key.
typedef DraftDecoder<T> = T? Function(String raw);

/// Generic, best-effort draft persistence over [SharedPreferences].
///
/// BUT-904: extracted from five near-identical per-surface copies (URL import,
/// text import, comment composer, group creation, recipe-list filter), each of
/// which carried its own private `_loadDraft/_saveDraft/_clearDraft` try/catch
/// triad. This is the shared primitive they consolidate onto, and the one
/// BUT-910 (photo import) should adopt rather than become a sixth copy.
///
/// Deliberately NOT a [BaseService]/DI singleton: a manager is owned by a single
/// widget or view-model instance, scoped to one storage key, and disposed with
/// its owner. Construct it in `initState` and call [dispose] from the owner's
/// `dispose`.
///
/// Persistence is best-effort by design — a draft is a convenience, never a
/// source of truth. Every operation swallows storage errors to an
/// [AppLogger.warning]; a failed save must never break typing or navigation.
///
/// `recipe_auto_save_manager.dart` stays a documented exception: it is
/// `RecipeFormState`-coupled and manages a multi-draft metadata index, so it
/// does not fit this single-key primitive.
class AutoSaveManager<T> {
  AutoSaveManager({
    required this.storageKey,
    required DraftEncoder<T> encode,
    required DraftDecoder<T> decode,
    this.debounce = Duration.zero,
    String? logLabel,
    @visibleForTesting Future<SharedPreferences> Function()? prefsProvider,
  }) : _encode = encode,
       _decode = decode,
       _logLabel = logLabel ?? 'AutoSaveManager($storageKey)',
       _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  /// The SharedPreferences key this manager owns. Keep it stable across
  /// releases — changing it orphans every in-flight draft.
  final String storageKey;

  /// Debounce window for [save]. `Duration.zero` (default) writes eagerly on
  /// every call — correct for short-text surfaces (URL, comment) where write
  /// volume is bounded and SharedPreferences is isolate-fenced. A non-zero
  /// window coalesces rapid edits into a single write of the latest value.
  final Duration debounce;

  final DraftEncoder<T> _encode;
  final DraftDecoder<T> _decode;
  final String _logLabel;
  final Future<SharedPreferences> Function() _prefsProvider;

  Timer? _debounceTimer;
  bool _disposed = false;

  /// Reads and decodes the persisted draft. Returns `null` when the key is
  /// absent, empty, undecodable, or on any storage error (best-effort).
  Future<T?> load() async {
    try {
      final prefs = await _prefsProvider();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return null;
      return _decode(raw);
    } catch (e) {
      AppLogger.warning('$_logLabel: failed to load draft ($e)');
      return null;
    }
  }

  /// Persists [value], honouring [debounce]. After [dispose] this is a no-op so
  /// a late keystroke can't resurrect a draft the owner already abandoned.
  void save(T value) {
    if (_disposed) return;
    if (debounce == Duration.zero) {
      _write(value);
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => _write(value));
  }

  /// Persists [value] immediately, cancelling any pending debounced write. Use
  /// on app-background / explicit "save now" paths where a dropped write would
  /// lose data.
  Future<void> flush(T value) {
    _debounceTimer?.cancel();
    return _write(value);
  }

  Future<void> _write(T value) async {
    final encoded = _encode(value);
    try {
      final prefs = await _prefsProvider();
      if (encoded == null || encoded.isEmpty) {
        await prefs.remove(storageKey);
      } else {
        await prefs.setString(storageKey, encoded);
      }
    } catch (e) {
      AppLogger.warning('$_logLabel: failed to save draft ($e)');
    }
  }

  /// Removes the persisted draft. Call when the user commits past the draft
  /// stage (posts the comment, advances the import). Best-effort.
  Future<void> clear() async {
    _debounceTimer?.cancel();
    try {
      final prefs = await _prefsProvider();
      await prefs.remove(storageKey);
    } catch (e) {
      AppLogger.warning('$_logLabel: failed to clear draft ($e)');
    }
  }

  /// Cancels any pending debounced write and blocks further [save]s. Call from
  /// the owner's `dispose`. Does not flush: an eager (`Duration.zero`) save has
  /// already been written, and a pending debounced value is intentionally
  /// dropped because the owner is gone.
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
