// lib/widgets/social/groups/ownership_transfer_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Dialog for selecting a new group owner when the current owner wants to leave.
/// Returns the selected UserProfile or null if cancelled.
/// This dialog doesn't perform any actions - it just captures user selection.
class OwnershipTransferDialog extends StatelessWidget {
  final FriendCategory group;
  final List<UserProfile> availableMembers;

  const OwnershipTransferDialog({
    super.key,
    required this.group,
    required this.availableMembers,
  });

  /// Show the dialog and return selected member
  static Future<UserProfile?> show({
    required BuildContext context,
    required FriendCategory group,
    required List<UserProfile> availableMembers,
  }) async {
    return await showDialog<UserProfile>(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => OwnershipTransferDialog(
        group: group,
        availableMembers: availableMembers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Överför gruppägande'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Du är ägare av "${group.name}". Du måste välja en ny ägare innan du kan lämna gruppen.',
          ),
          const SizedBox(height: AppDimensions.spacingL),
          const Text(
            'Välj ny ägare:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          // List of available members
          ...availableMembers.map((member) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: member.avatarUrl != null
                      ? NetworkImage(member.avatarUrl!)
                      : null,
                  child: member.avatarUrl == null
                      ? Text(member.displayName[0].toUpperCase())
                      : null,
                ),
                title: Text(member.displayName),
                subtitle: Text(member.email),
                onTap: () => Navigator.pop(context, member),
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Avbryt'),
        ),
      ],
    );
  }
}
