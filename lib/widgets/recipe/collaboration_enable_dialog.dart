import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

/// Picks the friends who may edit a recipe. Returns their uids, or null when
/// the dialog is cancelled; Aktivera stays off until someone is picked.
Future<Set<String>?> showCollaborationEnableDialog(
  BuildContext context, {
  required List<UserProfile> friends,
}) async {
  final selected = <String>{};
  final confirmed = await showButleryDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => ButleryDialog.confirm(
        title: ctx.l10n.collaborationEnableTitle,
        primaryLabel: ctx.l10n.commonEnable,
        primaryEnabled: selected.isNotEmpty,
        scrollable: false,
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: AppDimensions.dialogMaxHeightSmall,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final friend in friends)
                  ButleryCheckboxTile(
                    title: Text(friend.displayName),
                    value: selected.contains(friend.uid),
                    onChanged: (v) => setState(() {
                      if (v) {
                        selected.add(friend.uid);
                      } else {
                        selected.remove(friend.uid);
                      }
                    }),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return confirmed == true && selected.isNotEmpty ? selected : null;
}
