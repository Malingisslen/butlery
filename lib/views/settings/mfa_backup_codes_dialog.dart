import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// How long copied backup codes stay on the clipboard. Clipboards are read by
/// other apps and synced between devices, so the codes are wiped after a
/// minute, which is time enough to paste them into a password manager.
const mfaBackupCodesClipboardLifetime = Duration(minutes: 1);

/// Outlives the dialog: the user usually pastes after closing it.
Timer? _clipboardWipe;

/// The ten backup codes, shown once, before the phone is enrolled
/// (produktregler.md:748). "Fortsätt" stays off until the user says the
/// codes are saved; closing without that enrolls nothing.
class MfaBackupCodesDialog extends StatefulWidget {
  const MfaBackupCodesDialog({super.key, required this.codes});

  final List<String> codes;

  /// Returns true only when the user acknowledged the codes.
  static Future<bool> show(BuildContext context, List<String> codes) async {
    final result = await showDialog<bool>(
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
    return AlertDialog(
      key: const ValueKey('mfa.backupCodes'),
      scrollable: true,
      title: Text(l10n.mfaBackupCodesTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.mfaBackupCodesBody),
          const SizedBox(height: AppDimensions.spacingMd),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
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
          const SizedBox(height: AppDimensions.spacingSm),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.codes.join('\n')));
              // Unconditional: reading the clipboard back to compare would
              // make iOS ask the user for paste permission.
              _clipboardWipe?.cancel();
              _clipboardWipe = Timer(
                mfaBackupCodesClipboardLifetime,
                () => Clipboard.setData(const ClipboardData(text: '')),
              );
              SnackBarUtils.showInfo(context, l10n.mfaBackupCodesCopied);
            },
            icon: const ButleryIcon(ButleryIcons.copy),
            label: Text(l10n.mfaBackupCodesCopy),
          ),
          CheckboxListTile(
            key: const ValueKey('mfa.backupCodes.saved'),
            contentPadding: EdgeInsets.zero,
            value: _saved,
            onChanged: (v) => setState(() => _saved = v ?? false),
            title: Text(l10n.mfaBackupCodesSaved),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('mfa.backupCodes.continue'),
          onPressed: _saved ? () => Navigator.pop(context, true) : null,
          child: Text(l10n.mfaBackupCodesContinue),
        ),
      ],
    );
  }
}
