import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';

/// Whether this guest has dealt with Hem's allergy card (opened the settings
/// or closed it). Per uid, so a second guest on the device meets it again.
///
/// Deliberately not a `BaseService`: local storage only, no Firebase.
class GuestAllergyCardStore {
  const GuestAllergyCardStore();

  static String _key(String uid) => 'guest_allergy_card_done_$uid';

  Future<bool> isDone(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key(uid)) ?? false;
    } catch (e) {
      AppLogger.warning('GuestAllergyCardStore: could not read: $e');
      return false;
    }
  }

  Future<void> markDone(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(uid), true);
    } catch (e) {
      AppLogger.warning('GuestAllergyCardStore: could not save: $e');
    }
  }
}
