// lib/widgets/common/dialogs/inline_destructive_confirmation.dart
//
// The confirmation that opens under the row it is about, instead of a dialog
// over the page ("Ta bort Johan Lind ur samtalet?"): a
// tinted note with the question, what is kept and what is not, Avbryt and a
// red button that names the action. For removing someone from a list the
// person can be invited back to, where a dialog is more than the question
// needs.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';

class InlineDestructiveConfirmation extends StatelessWidget {
  const InlineDestructiveConfirmation({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  final String title;

  /// What the action does and what it leaves alone.
  final String message;

  /// The red button, named for what it does: "Ta bort".
  final String confirmLabel;

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: TintedNote(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTextStyles.bodyBold),
            const SizedBox(height: AppDimensions.space4),
            Text(message, style: TintedNote.textStyle(context)),
            const SizedBox(height: AppDimensions.space12),
            Row(
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: Text(context.l10n.commonCancel),
                ),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: ComponentThemes.dangerButtonStyle(cs),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
