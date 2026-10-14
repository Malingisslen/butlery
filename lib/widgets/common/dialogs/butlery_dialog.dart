// lib/widgets/common/dialogs/butlery_dialog.dart
//
// The shell every hand-built dialog stands in. A view gives the title, the
// words or a body and the primary action; the shell draws the frame, the
// Avbryt on the left and the primary on the right, with the plate line while
// the primary works. A dialog that confirms a deletion keeps using
// DestructiveConfirmationDialog; this is for the rest.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// Opens [builder] as a dialog. The one way a hand-built dialog opens, so a
/// change to how dialogs open is made here.
Future<T?> showButleryDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    builder: builder,
  );
}

/// The primary action on the right of a dialog: a filled button, red when it
/// removes something. While [busy] it keeps its name and gets the plate line.
class ButleryDialogPrimary extends StatelessWidget {
  const ButleryDialogPrimary({
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.busy = false,
    this.icon,
    super.key,
  });

  final String label;

  /// A glyph before the words, such as a history clock on "Fortsätt".
  final IconData? icon;

  /// Null disables the button.
  final VoidCallback? onPressed;

  final bool danger;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final own = danger
        ? ComponentThemes.dangerButtonStyle(theme.colorScheme)
        : null;
    return BusyButtonSemantics(
      busy: busy,
      name: label,
      child: FilledButton(
        onPressed: busy ? PlateLineButton.ignore : onPressed,
        style: busy
            ? PlateLineButton.busyStyle(own, theme.filledButtonTheme.style)
            : own,
        child: icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ButleryIcon(icon!),
                  const SizedBox(width: AppDimensions.space8),
                  Flexible(child: Text(label)),
                ],
              ),
      ),
    );
  }
}

class ButleryDialog extends StatelessWidget {
  /// A dialog with the actions the caller lays out, usually built from
  /// [DialogCancelButton] and [ButleryDialogPrimary].
  const ButleryDialog({
    required this.title,
    required this.actions,
    this.message,
    this.content,
    this.scrollable = true,
    this.titleIcon,
    super.key,
  }) : assert(
         message == null || content == null,
         'Give the words or a body, not both.',
       );

  /// Avbryt and one primary. [onPrimary] pops with true when null.
  ButleryDialog.confirm({
    required this.title,
    required String primaryLabel,
    this.message,
    this.content,
    VoidCallback? onPrimary,
    String? cancelLabel,
    bool danger = false,
    bool busy = false,
    bool primaryEnabled = true,
    IconData? primaryIcon,
    this.scrollable = true,
    this.titleIcon,
    super.key,
  }) : assert(
         message == null || content == null,
         'Give the words or a body, not both.',
       ),
       actions = [
         Builder(
           builder: (context) =>
               DialogCancelButton(label: cancelLabel, enabled: !busy),
         ),
         Builder(
           builder: (context) => ButleryDialogPrimary(
             label: primaryLabel,
             danger: danger,
             busy: busy,
             icon: primaryIcon,
             onPressed: primaryEnabled
                 ? (onPrimary ?? () => Navigator.of(context).pop(true))
                 : null,
           ),
         ),
       ];

  /// A dialog that only tells: one Stäng, never OK.
  ButleryDialog.notice({
    required this.title,
    this.message,
    this.content,
    String? closeLabel,
    this.scrollable = true,
    this.titleIcon,
    super.key,
  }) : assert(
         message == null || content == null,
         'Give the words or a body, not both.',
       ),
       actions = [
         Builder(
           builder: (context) => ButleryTextButton(
             label: closeLabel ?? context.l10n.commonClose,
             onPressed: () => Navigator.of(context).pop(),
           ),
         ),
       ];

  final String title;

  /// A glyph above the title, as the dialog's mark.
  final IconData? titleIcon;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  /// The body scrolls when it is taller than the screen allows.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: scrollable,
      icon: titleIcon == null ? null : ButleryIcon(titleIcon!),
      title: Text(title),
      content:
          content ??
          (message == null
              ? null
              : Text(message!, style: AppTextStyles.bodyMedium)),
      actions: actions,
    );
  }
}

/// The dialog that only says what is happening: the plate line with the words,
/// no buttons. The caller opens it with `barrierDismissible: false` and closes
/// it when the work ends.
class ButleryProgressDialog extends StatelessWidget {
  const ButleryProgressDialog({required this.message, this.value, super.key});

  /// What is being done, such as "Laddar upp bilden …".
  final String message;

  /// 0–1 when the work can be measured, otherwise null.
  final double? value;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: PlateLineMessage(message: message, value: value),
    );
  }
}
