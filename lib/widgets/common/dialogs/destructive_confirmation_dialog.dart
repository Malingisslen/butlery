import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// The one confirmation before something is deleted, removed or left
/// (BUT-2366, the drawn `#dialogradera`): the question as the title, Avbryt
/// on the left and a red filled button on the right that names what
/// disappears ("Radera receptet", "Ta bort som vän"), so there is no default
/// button text. Radera = the content stops existing; Ta bort = lifted out of a
/// list or relation (content-style-guide.md, Knapptexter).
///
/// With [onConfirm] the dialog does the work itself: the button keeps its
/// name and gets the plate line while it runs, and a failure stays in the
/// dialog with Försök igen. Without it the dialog only answers true.
class DestructiveConfirmationDialog extends BaseDialog<bool> {
  final String message;
  final String itemName;
  final Widget? customContent;

  /// A consequence the user should weigh, drawn in the warning colour.
  final String? warning;

  /// Adds "Det går inte att ångra." Leave it off when an undo or the trash
  /// can still bring the thing back.
  final bool irreversible;

  final Future<void> Function()? onConfirm;

  const DestructiveConfirmationDialog({
    super.key,
    required super.title,
    this.message = '',
    this.itemName = '',
    this.customContent,
    this.warning,
    this.irreversible = false,
    this.onConfirm,
    required String super.primaryActionText,
    super.secondaryActionText,
    super.primaryActionIcon = ButleryIcons.trash2,
  }) : super(titleIcon: ButleryIcons.triangleAlert, isDangerous: true);

  @override
  Widget buildContent(BuildContext context) {
    final lines = <Widget>[
      if (customContent != null)
        customContent!
      else if (message.isNotEmpty || itemName.isNotEmpty)
        Text.rich(
          TextSpan(
            style: AppTextStyles.bodyMedium,
            children: [
              TextSpan(text: message),
              // A caller without a name gives a complete message.
              if (itemName.isNotEmpty) ...[
                TextSpan(
                  text: message.isEmpty ? '”$itemName”' : ' ”$itemName”',
                  style: AppTextStyles.bodyBold,
                ),
                if (message.isNotEmpty) const TextSpan(text: '?'),
              ],
            ],
          ),
        ),
      if (warning != null)
        Text(
          warning!,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppModeColors.textWarning(Theme.of(context).brightness),
          ),
        ),
      if (irreversible)
        Text(
          context.l10n.deleteActionIrreversible,
          style: AppTextStyles.bodySmall,
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDimensions.spacingM),
          lines[i],
        ],
      ],
    );
  }

  @override
  Future<bool?> performAction(BuildContext context) async {
    await onConfirm?.call();
    return true;
  }

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String message = '',
    String itemName = '',
    Widget? customContent,
    String? warning,
    bool irreversible = false,
    Future<void> Function()? onConfirm,
    required String primaryActionText,
    String? secondaryActionText,
    IconData primaryActionIcon = ButleryIcons.trash2,
  }) {
    return showDialog<bool>(
      context: context,
      // A tap outside while onConfirm runs would close the dialog with null
      // and leave the caller without the outcome of work still in progress.
      barrierDismissible: onConfirm == null,
      builder: (context) => DestructiveConfirmationDialog(
        title: title,
        message: message,
        itemName: itemName,
        customContent: customContent,
        warning: warning,
        irreversible: irreversible,
        onConfirm: onConfirm,
        primaryActionText: primaryActionText,
        secondaryActionText: secondaryActionText,
        primaryActionIcon: primaryActionIcon,
      ),
    );
  }
}
