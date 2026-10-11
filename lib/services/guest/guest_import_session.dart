import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';

/// The guest's import ids: one per import the guest starts, so the server can
/// count distinct imports (max 3) rather than calls. The set of ids that
/// succeeded is kept per uid; the server decides whether an import is
/// allowed.
///
/// Deliberately not a `BaseService`: local storage and a counter, no Firebase.
class GuestImportSession extends ChangeNotifier {
  GuestImportSession({required String? Function() uid, Random? random})
    : _uid = uid,
      _random = random ?? Random.secure();

  static const int maxImports = 3;
  static const int _idLength = 20;
  static const String _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  final String? Function() _uid;
  final Random _random;

  final ValueNotifier<int> _limitHits = ValueNotifier(0);

  String? _currentId;
  String? _loadedUid;
  // Saves finish after awaits, and the session can be disposed on sign-out
  // in between; a disposed notifier throws when told to notify.
  bool _disposed = false;
  Set<String> _used = {};

  static String _key(String uid) => 'guest_imports_used_$uid';

  String begin() {
    _currentId = String.fromCharCodes(
      List.generate(
        _idLength,
        (_) => _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
      ),
    );
    return _currentId!;
  }

  String get currentId => _currentId ?? begin();

  /// The counts are in memory, so call this before reading them.
  Future<void> load() async {
    final uid = _uid();
    if (uid == null || uid == _loadedUid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _used = (prefs.getStringList(_key(uid)) ?? const <String>[]).toSet();
      _loadedUid = uid;
      if (!_disposed) notifyListeners();
    } catch (e) {
      AppLogger.warning('GuestImportSession: could not read the count: $e');
    }
  }

  Future<void> recordSuccess() async {
    final uid = _uid();
    if (uid == null) return;
    await load();
    if (_loadedUid != uid) return;
    if (!_used.add(currentId)) return;
    if (!_disposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key(uid), _used.toList());
    } catch (e) {
      AppLogger.warning('GuestImportSession: could not save the count: $e');
    }
  }

  /// Ticks each time the server refuses an import for the limit, however many
  /// layers between the call and the screen swallowed the exception.
  Listenable get limitHits => _limitHits;

  /// The server said the three imports are used: the local count catches up
  /// to it, and whoever listens to [limitHits] is told.
  Future<void> recordLimitReached() async {
    if (_disposed) return;
    _limitHits.value++;
    final uid = _uid();
    if (uid == null) return;
    await load();
    if (_loadedUid != uid) return;
    for (var i = 0; _used.length < maxImports; i++) {
      _used.add('server-limit-$i');
    }
    if (!_disposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key(uid), _used.toList());
    } catch (e) {
      AppLogger.warning('GuestImportSession: could not save the count: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _limitHits.dispose();
    super.dispose();
  }

  int get usedCount =>
      _loadedUid != null && _loadedUid == _uid() ? _used.length : 0;

  int get remaining => max(0, maxImports - usedCount);
}
