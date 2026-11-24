import 'package:flutter/foundation.dart';

import 'package:butlery/models/menu/menu_wish.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';

import '../infrastructure/mocks/production_mocks.dart';
import 'user_profile_factory.dart';

/// The own-profile edge of the saved week-menu wishes: reads and writes the
/// two fields on an in-memory profile and tells its listeners, as the
/// profile cache does.
class FakeMenuWishProfile extends MockUserService {
  /// [base] is the profile the rest of the test already reads, so
  /// registering this fake as the profile reader changes nothing but the two
  /// wish fields.
  FakeMenuWishProfile({
    UserProfile? base,
    List<MenuWish> wishes = const [],
    LastMenuWish? lastWish,
  }) : profile = (base ?? testUserProfile()).copyWith(
         savedMenuWishes: wishes,
         lastMenuWish: lastWish,
       );

  UserProfile profile;

  void seed({List<MenuWish> wishes = const [], LastMenuWish? lastWish}) {
    profile = profile.copyWith(savedMenuWishes: wishes, lastMenuWish: lastWish);
  }

  bool failWrites = false;

  /// While set, a wish-list write waits for it, so a test can look at the
  /// screen between the tap and the answer.
  Future<void>? gate;

  /// Every list written by [setSavedMenuWishes], refused writes included.
  final List<List<MenuWish>> savedWrites = [];
  final List<LastMenuWish> lastWrites = [];
  final _listeners = <VoidCallback>{};

  @override
  UserProfile? get currentUserProfile => profile;

  @override
  String? get currentUserId => profile.uid;

  @override
  UserAllergenPreferences get allergenPreferences =>
      UserAllergenPreferences.defaults;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notify() {
    for (final listener in _listeners.toList()) {
      listener();
    }
  }

  @override
  Future<bool> setSavedMenuWishes(List<MenuWish> wishes) async {
    savedWrites.add(wishes);
    await gate;
    if (failWrites) return false;
    profile = profile.copyWith(savedMenuWishes: wishes);
    _notify();
    return true;
  }

  @override
  Future<void> rememberLastMenuWish(LastMenuWish wish) async {
    lastWrites.add(wish);
    profile = profile.copyWith(lastMenuWish: wish);
    _notify();
  }
}
