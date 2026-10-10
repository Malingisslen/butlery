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
  const DishCredit({
    required this.userId,
    required this.displayName,
    this.isViewer = false,
  });

  final String userId;
  final String displayName;
  final bool isViewer;
}

/// Which dishes on a menu may carry their creator's name.
enum DishCreditScope {
  /// Only dishes made by the person who shared the menu. The rules pin who
  /// shares, so no one can put another person's name on a dish.
  sharerOnly,

  /// Every dish whose creator opted in, forwarded menus included. The default.
  /// A member with a hand-built client can write any uid into a dish's
  /// `createdBy`; the named person withdraws it through the report, which
  /// removes their uid from that dish.
  everyCreator,
}

class MenuDishCreditViewModel extends BaseViewModel {
  MenuDishCreditViewModel({
    required SharedMenu menu,
    this.scope = DishCreditScope.everyCreator,
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

  /// Above this many distinct creators besides the viewer no line is shown for
  /// them, which bounds the profile reads one menu can cause.
  static const int maxCreators = 10;

  final SharedMenu _menu;
  final DishCreditScope scope;
  final UserService _userService;
  final Set<String> Function() _blockedUserIds;
  final String? _viewerId;
  final Map<String, DishCredit> _credits = {};
  final Set<String> _withdrawnDishIds = {};

  String get menuId => _menu.id;
  String get sharerId => _menu.sharedByUserId;

  // The rules refuse a report whose owner is the reporter.
  bool get canReport => _viewerId != null && _viewerId != sharerId;

  /// Hides the viewer's own line on [dishId] after they filed the report; the
  /// server removes the uid, this keeps the open menu in step with it.
  void withdrawOwnCredit(String dishId) {
    if (_withdrawnDishIds.add(dishId)) notifyListeners();
  }

  /// Null when the dish gets no line. Every failure lands here too: a missing
  /// or unreadable profile shows nothing rather than an error.
  DishCredit? creditFor(Recipe dish) {
    final credit = _credits[dish.createdBy];
    if (credit == null) return null;
    if (credit.isViewer && _withdrawnDishIds.contains(dish.id)) return null;
    return credit;
  }

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
        isViewer: profile.uid == _viewerId,
      );
    }
    if (_credits.isNotEmpty) notifyListeners();
  }

  Set<String> _creatorIds() {
    final blocked = _blockedUserIds();
    final ids = <String>{};
    var viewerNamed = false;
    for (final dish in _menu.menuSnapshot.values.expand((dishes) => dishes)) {
      final id = dish.createdBy;
      if (id == null || !_isUserId(id)) continue;
      if (scope == DishCreditScope.sharerOnly && id != _menu.sharedByUserId) {
        continue;
      }
      if (id == _viewerId) {
        viewerNamed = true;
        continue;
      }
      if (blocked.contains(id)) continue;
      ids.add(id);
    }
    final others = ids.length > maxCreators ? <String>{} : ids;
    return viewerNamed ? {...others, _viewerId!} : others;
  }

  // `deleted` is what the erasure cascade writes in place of a uid.
  static bool _isUserId(String id) =>
      id.isNotEmpty && id != 'deleted' && !id.contains('/');
}
