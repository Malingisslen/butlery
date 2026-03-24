import 'package:flutter/material.dart';
import 'package:butlery/core/router/deferred_module_loader.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/user_profile.dart';

// Deferred imports for social views
import 'package:butlery/views/social/user_profile_edit_view.dart'
    deferred as profile_edit;
import 'package:butlery/views/social/friends_list_view.dart'
    deferred as friends_list;
import 'package:butlery/views/social/friend_requests_view.dart'
    deferred as friend_requests;
import 'package:butlery/views/social/shared_with_me_view.dart'
    deferred as shared_with_me;
import 'package:butlery/views/social/collaborative_shopping_view.dart'
    deferred as collab_shopping;
import 'package:butlery/views/social/menu_preview_view.dart'
    deferred as menu_preview;
import 'package:butlery/views/social/create_shared_shopping_list_view.dart'
    deferred as create_shared_shopping;
import 'package:butlery/views/social/friend_profile_view.dart'
    deferred as friend_profile;
import 'package:butlery/views/social/shared_shopping_lists_view.dart'
    deferred as shared_shopping_lists;
import 'package:butlery/views/social/group_detail_view.dart'
    deferred as group_detail;

/// Deferred module for social/friends related views
/// This module defers loading of all social views (~52 files, 2-3MB)
class SocialDeferredModule implements DeferredModule {
  bool _isLoaded = false;

  @override
  bool get isLoaded => _isLoaded;

  @override
  Set<String> get handledRoutes => {
        Routes.profileEdit,
        Routes.friends,
        Routes.friendRequests,
        Routes.shared,
        Routes.collaborativeShopping,
        Routes.menuPreview,
        Routes.createSharedShopping,
        Routes.friendProfile,
        Routes.sharedShoppingLists,
        Routes.groupDetail,
      };

  @override
  Future<void> load() async {
    if (_isLoaded) return;

    // Load all social view libraries in parallel
    try {
      await Future.wait([
        profile_edit.loadLibrary(),
        friends_list.loadLibrary(),
        friend_requests.loadLibrary(),
        shared_with_me.loadLibrary(),
        collab_shopping.loadLibrary(),
        menu_preview.loadLibrary(),
        create_shared_shopping.loadLibrary(),
        friend_profile.loadLibrary(),
        shared_shopping_lists.loadLibrary(),
        group_detail.loadLibrary(),
      ]);
    } on Exception catch (e) {
      throw StateError(
          'SocialDeferredModule: deferred library load failed: $e');
    }

    _isLoaded = true;
  }

  @override
  Widget buildRoute(String routeName, RouteSettings settings) {
    switch (routeName) {
      case Routes.profileEdit:
        return profile_edit.UserProfileEditView();

      case Routes.friends:
        return friends_list.FriendsListView();

      case Routes.friendRequests:
        return friend_requests.FriendRequestsView();

      case Routes.shared:
        return shared_with_me.SharedWithMeView();

      case Routes.collaborativeShopping:
        final listId = settings.arguments as String?;
        if (listId == null) {
          throw ArgumentError(
              'List ID argument missing for collaborative shopping');
        }
        return collab_shopping.CollaborativeShoppingView(listId: listId);

      case Routes.menuPreview:
        final menu = settings.arguments as SharedMenu?;
        if (menu == null) {
          throw ArgumentError('Menu argument missing for preview');
        }
        return menu_preview.MenuPreviewView(sharedMenu: menu);

      case Routes.createSharedShopping:
        return create_shared_shopping.CreateSharedShoppingListView();

      case Routes.friendProfile:
        final userProfile = settings.arguments as UserProfile?;
        if (userProfile == null) {
          throw ArgumentError('User profile argument missing');
        }
        return friend_profile.FriendProfileView(friend: userProfile);

      case Routes.sharedShoppingLists:
        return shared_shopping_lists.SharedShoppingListsView();

      case Routes.groupDetail:
        final groupId = settings.arguments as String?;
        if (groupId == null) {
          throw ArgumentError('Group ID argument missing for group detail');
        }
        return group_detail.GroupDetailView(groupId: groupId);

      default:
        throw ArgumentError('Unknown social route: $routeName');
    }
  }
}
