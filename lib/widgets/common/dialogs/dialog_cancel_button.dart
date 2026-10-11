import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// The one Avbryt a dialog draws on the left of its primary action.
///
/// It pops the route with null unless [onPressed] says otherwise. A dialog
/// passes `enabled: false` while its primary works, so the work cannot be
/// walked away from half done.
class DialogCancelButton extends StatelessWidget {
  final String? label;
  final VoidCallback? onPressed;
  final bool enabled;

  const DialogCancelButton({
    super.key,
    this.label,
    this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled
          ? (onPressed ?? () => Navigator.of(context).pop())
          : null,
      child: Text(label ?? context.l10n.commonCancel),
    );
  }
}
