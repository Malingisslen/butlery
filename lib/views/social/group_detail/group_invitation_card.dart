// lib/views/social/group_detail/group_invitation_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/injection.dart';

/// GroupInvitationCard - Invitation card component
///
/// Displays pending group invitation with cancel action.
class GroupInvitationCard {
  static Widget build(
    BuildContext context,
    GroupInvitation invitation,
    VoidCallback onCancelled,
  ) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
      child: ListTile(
        leading: Stack(
          children: [
            // Avatar based on username from invitation
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  invitation.fromUserName.isNotEmpty
                      ? invitation.fromUserName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Pending indicator
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          'Inbjudan skickad',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skickat: ${invitation.timeAgoText}'),
            Text('Går ut: ${invitation.expiresInText}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          onSelected: (value) => _handleAction(
            context,
            value,
            invitation,
            onCancelled,
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'cancel_invitation',
              child: Row(
                children: [
                  Icon(
                    Icons.cancel,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    'Avbryt inbjudan',
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

  static void _handleAction(
    BuildContext context,
    String action,
    GroupInvitation invitation,
    VoidCallback onCancelled,
  ) {
    switch (action) {
      case 'cancel_invitation':
        _cancelInvitation(context, invitation, onCancelled);
        break;
    }
  }

  static Future<void> _cancelInvitation(
    BuildContext context,
    GroupInvitation invitation,
    VoidCallback onCancelled,
  ) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avbryt inbjudan?'),
        content: Text(
          'Vill du verkligen avbryta inbjudan till "${invitation.fromUserName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nej'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Ja, avbryt'),
          ),
        ],
      ),
    );

    if (shouldCancel == true && context.mounted) {
      final groupInvitationService = sl<UnifiedFriendsService>();
      final success = await groupInvitationService.cancelSentInvitation(
        invitation.id,
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Inbjudan avbruten'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        onCancelled();
      } else if (context.mounted && 
                 groupInvitationService.invitations.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fel: ${groupInvitationService.invitations.error}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}