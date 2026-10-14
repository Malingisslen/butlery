import 'package:flutter/material.dart';

import 'package:butlery/core/utils/common_dialog_actions.dart';

/// Asks before a back gesture throws away what the user has typed. While
/// [isDirty] is false the page leaves as usual.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    required this.isDirty,
    required this.child,
    super.key,
  });

  final bool isDirty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await CommonDialogActions.showUnsavedChangesConfirmation(
          context: context,
        );
        if (leave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
