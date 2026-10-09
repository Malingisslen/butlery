import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_draft.dart';

/// BUT-2157: keeps the week generation's draft on this device, per person,
/// for [lifetime] since its last change. Built like
/// `WeeklyMenuOverflowTrayStore`: nothing here reaches the cloud, and the key
/// carries the user id so another account on the same device never sees
/// someone else's draft.
///
/// Logout: [clearAll] is the hook, and it belongs in the manual sign-out path
/// only (`AuthService.clearDeviceDraftsOnExplicitSignOut`). PQ-12 = A keeps
/// device drafts through an automatic sign-out.
///
/// Best-effort: a storage error is logged and never breaks generation. Not a
/// `BaseService`: it is device storage with no Firebase operation and no
/// service lifecycle (lib/services/CLAUDE.md, documented non-adopters).
class WeeklyMenuDraftStore {
  WeeklyMenuDraftStore({Future<SharedPreferences> Function()? prefsProvider})
    : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefsProvider;

  /// Every key this store writes starts with this.
  static const String keyPrefix = 'weekly_menu_draft_v1:';

  static const Duration lifetime = WeeklyMenuDraft.lifetime;

  static String keyFor(String userId) => '$keyPrefix$userId';

  /// The kept draft for [userId], or null when there is none or it cannot be
  /// read. A corrupt, empty or expired draft is deleted on the way.
  Future<WeeklyMenuDraft?> load(String userId) async {
    try {
      final prefs = await _prefsProvider();
      final raw = prefs.getString(keyFor(userId));
      if (raw == null || raw.isEmpty) return null;
      WeeklyMenuDraft? draft;
      try {
        draft = WeeklyMenuDraft.fromJson(jsonDecode(raw));
      } on FormatException {
        draft = null;
      }
      if (draft == null || draft.isEmpty || draft.isExpired) {
        await prefs.remove(keyFor(userId));
        return null;
      }
      return draft;
    } catch (e) {
      AppLogger.warning('WeeklyMenuDraftStore: load failed ($e)');
      return null;
    }
  }

  /// Keeps [draft] for [userId]; a null or empty draft deletes it.
  Future<void> save(String userId, WeeklyMenuDraft? draft) async {
    try {
      final prefs = await _prefsProvider();
      if (draft == null || draft.isEmpty) {
        await prefs.remove(keyFor(userId));
        return;
      }
      await prefs.setString(keyFor(userId), jsonEncode(draft.toJson()));
    } catch (e) {
      AppLogger.warning('WeeklyMenuDraftStore: save failed ($e)');
    }
  }

  /// The manual-logout hook: deletes the draft of [userId], the person
  /// logging out. Another account's draft on the same device stays, since an
  /// automatic logout is meant to keep it (PQ-12 = A). Without a [userId]
  /// every kept draft on the device goes.
  static Future<void> clearAll({
    String? userId,
    Future<SharedPreferences> Function()? prefsProvider,
  }) async {
    try {
      final prefs = await (prefsProvider ?? SharedPreferences.getInstance)();
      if (userId != null) {
        await prefs.remove(keyFor(userId));
        return;
      }
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(keyPrefix)) await prefs.remove(key);
      }
    } catch (e) {
      AppLogger.warning('WeeklyMenuDraftStore: clearAll failed ($e)');
    }
  }
}
