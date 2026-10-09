// BUT-2221: names the creator under a dish on a shared menu, for creators who
// opted in on their public profile. Nothing is stored on the menu: the name
// and the opt-in are read from the profile each time the menu opens.

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// What the credit line under one dish shows.
class DishCredit {
  const DishCredit({required this.userId, required this.displayName});

  final String userId;
  final String displayName;
}

/// Which dishes on a menu may carry their creator's name.
enum DishCreditScope {
  /// Only dishes made by the person who shared the menu. The rules pin who
  /// shares, so no one can put another person's name on a dish.
  sharerOnly,

  /// Every dish whose creator opted in, forwarded menus included. A member
  /// with a hand-built client can write any uid into a dish's `createdBy`.
  everyCreator,
}

class MenuDishCreditViewModel extends BaseViewModel {
  MenuDishCreditViewModel({
    required SharedMenu menu,
    this.scope = DishCreditScope.sharerOnly,
    UserService? userService,
    Set<String> Function()? blockedUserIds,
    String? viewerId,
  }) : _menu = menu,
       _userService = userService ?? ServiceLocator.get<UserService>(),
       _blockedUserIds =
           blockedUserIds ??
           (() =>
               ServiceLocator.tryGet<UnifiedFriendsService>()?.blockedUsers ??
               const <String>{}),
       _viewerId =
           viewerId ?? ServiceLocator.get<PermissionService>().currentUserId;

  /// Above this many distinct creators no line is shown at all, which bounds
  /// the profile reads one menu can cause.
  static const int maxCreators = 10;

  final SharedMenu _menu;
  final DishCreditScope scope;
  final UserService _userService;
  final Set<String> Function() _blockedUserIds;
  final String? _viewerId;
  final Map<String, DishCredit> _credits = {};

  /// Null when the dish gets no line. Every failure lands here too: a missing
  /// or unreadable profile shows nothing rather than an error.
  DishCredit? creditFor(Recipe dish) => _credits[dish.createdBy];

  Future<void> load() async {
    final ids = _creatorIds();
    if (ids.isEmpty) return;
    final lookup = await _userService.getUserProfiles(ids.toList());
    if (isDisposed) return;
    for (final profile in lookup.profiles) {
      final name = profile.displayName.trim();
      if (!ids.contains(profile.uid) ||
          !profile.showNameOnSharedDishes ||
          profile.isHidden ||
          name.isEmpty) {
        continue;
      }
      _credits[profile.uid] = DishCredit(
        userId: profile.uid,
        displayName: name,
      );
    }
    if (_credits.isNotEmpty) notifyListeners();
  }

  Set<String> _creatorIds() {
    final blocked = _blockedUserIds();
    final ids = <String>{};
    for (final dish in _menu.menuSnapshot.values.expand((dishes) => dishes)) {
      final id = dish.createdBy;
      if (id == null ||
          !_isUserId(id) ||
          id == _viewerId ||
          blocked.contains(id)) {
        continue;
      }
      if (scope == DishCreditScope.sharerOnly && id != _menu.sharedByUserId) {
        continue;
      }
      ids.add(id);
    }
    return ids.length > maxCreators ? const {} : ids;
  }

  // `deleted` is what the erasure cascade writes in place of a uid.
  static bool _isUserId(String id) =>
      id.isNotEmpty && id != 'deleted' && !id.contains('/');
}
