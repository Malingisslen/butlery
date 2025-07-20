// lib/views/social/friends_list/friend_card.dart

import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../viewmodels/friends_viewmodel.dart';
import '../../../widgets/common/social_components.dart';
import '../../../core/dialogs/dialog_factory.dart';
import '../../../core/utils/snackbar_utils.dart';

/// FriendCard - Individual friend card component
///
/// Displays friend information with profile and remove actions.
class FriendCard {
  static Widget build(
    BuildContext context,
    UserProfile friend,
    FriendsViewModel viewModel,
  ) {
    return Card(
      child: ListTile(
        onTap: () => _navigateToProfile(context, friend),
        leading: SocialComponents.avatar(
          user: friend,
          size: ImageSize.small,
        ),
        title: Text(
          friend.displayName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: friend.bio?.isNotEmpty == true
            ? Text(
                friend.bio!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleAction(
            context,
            value,
            friend,
            viewModel,
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person),
                  SizedBox(width: 8),
                  Text('Visa profil'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(
                    Icons.person_remove,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ta bort vän',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _navigateToProfile(BuildContext context, UserProfile friend) {
    Navigator.pushNamed(
      context,
      '/friend-profile',
      arguments: friend,
    );
  }

  static void _handleAction(
    BuildContext context,
    String action,
    UserProfile friend,
    FriendsViewModel viewModel,
  ) {
    switch (action) {
      case 'profile':
        _navigateToProfile(context, friend);
        break;
      case 'remove':
        _showRemoveFriendDialog(context, friend, viewModel);
        break;
    }
  }

  static Future<void> _showRemoveFriendDialog(
    BuildContext context,
    UserProfile friend,
    FriendsViewModel viewModel,
  ) async {
    final shouldRemove = await DialogFactory.showDeleteConfirmation(
      context,
      itemName: friend.displayName,
      itemType: 'vän från din vänlista',
    );

    if (shouldRemove == true && context.mounted) {
      final success = await viewModel.removeFriend(friend.uid);
      if (success && context.mounted) {
        SnackBarUtils.showSuccess(
          context,
          '${friend.displayName} borttagen från vänlista',
        );
      }
    }
  }
}