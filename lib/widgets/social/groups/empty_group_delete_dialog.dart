// lib/widgets/social/groups/empty_group_delete_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Dialog shown when group owner wants to leave but is the only member.
/// Returns true if user wants to delete the empty group, false or null otherwise.
/// This dialog doesn't perform any actions - it just captures user intent.
class EmptyGroupDeleteDialog extends StatelessWidget {
  final FriendCategory group;

  const EmptyGroupDeleteDialog({
    super.key,
    required this.group,
  });

  /// Show the dialog and return user's choice
  static Future<bool?> show({
    required BuildContext context,
    required FriendCategory group,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => EmptyGroupDeleteDialog(group: group),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gruppen är tom'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Du är den enda medlemmen i "${group.name}".'),
          const SizedBox(height: AppDimensions.spacingM),
          const Text('Vill du ta bort gruppen när du lämnar den?'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Avbryt'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Ta bort gruppen'),
        ),
      ],
    );
  }
}
