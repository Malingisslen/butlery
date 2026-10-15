import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';

/// How long copied backup codes stay on the clipboard. Clipboards are read by
/// other apps and synced between devices, so the codes are wiped after a
/// minute, which is time enough to paste them into a password manager.
const mfaBackupCodesClipboardLifetime = Duration(minutes: 1);

/// Outlives the dialog: the user usually pastes after closing it.
Timer? _clipboardWipe;

/// Copies a two-step-verification secret (the backup codes or the
/// authenticator key) and wipes the clipboard after
/// [mfaBackupCodesClipboardLifetime].
void copyMfaSecret(String text) {
  Clipboard.setData(ClipboardData(text: text));
  // Unconditional: reading the clipboard back to compare would make iOS ask
  // the user for paste permission.
  _clipboardWipe?.cancel();
  _clipboardWipe = Timer(
    mfaBackupCodesClipboardLifetime,
    () => Clipboard.setData(const ClipboardData(text: '')),
  );
}

/// The ten backup codes, shown once, before the factor is enrolled
/// (produktregler.md:748). "Fortsätt" stays off until the user says the
/// codes are saved; closing without that enrolls nothing.
class MfaBackupCodesDialog extends StatefulWidget {
  const MfaBackupCodesDialog({super.key, required this.codes});

  final List<String> codes;

  /// Returns true only when the user acknowledged the codes.
  static Future<bool> show(BuildContext context, List<String> codes) async {
    final result = await showButleryDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MfaBackupCodesDialog(codes: codes),
    );
    return result ?? false;
  }

  @override
  State<MfaBackupCodesDialog> createState() => _MfaBackupCodesDialogState();
}

class _MfaBackupCodesDialogState extends State<MfaBackupCodesDialog> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return ButleryDialog(
      key: const ValueKey('mfa.backupCodes'),
      title: l10n.mfaBackupCodesTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.mfaBackupCodesBody),
          const SizedBox(height: AppDimensions.space16),
          Container(
            padding: const EdgeInsets.all(AppDimensions.space16),
            color: cs.surfaceContainerHighest,
            child: SelectableText(
              widget.codes.join('\n'),
              key: const ValueKey('mfa.backupCodes.list'),
              style: AppTextStyles.bodyBold.copyWith(
                color: cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          ButleryTextButton(
            label: l10n.mfaBackupCodesCopy,
            icon: ButleryIcons.copy,
            onPressed: () {
              copyMfaSecret(widget.codes.join('\n'));
              SnackBarUtils.showInfo(context, l10n.mfaBackupCodesCopied);
            },
          ),
          ButleryCheckboxTile(
            boxFirst: true,
            key: const ValueKey('mfa.backupCodes.saved'),
            contentPadding: EdgeInsets.zero,
            value: _saved,
            onChanged: (v) => setState(() => _saved = v),
            title: Text(l10n.mfaBackupCodesSaved),
          ),
        ],
      ),
      actions: [
        DialogCancelButton(onPressed: () => Navigator.pop(context, false)),
        ButleryDialogPrimary(
          key: const ValueKey('mfa.backupCodes.continue'),
          label: l10n.mfaBackupCodesContinue,
          onPressed: _saved ? () => Navigator.pop(context, true) : null,
        ),
      ],
    );
  }
}
