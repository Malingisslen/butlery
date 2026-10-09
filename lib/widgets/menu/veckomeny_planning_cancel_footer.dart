import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// BUT-2157: "Avbryt planeringen" under the planning panel (Skarmar v12 del
/// 1 #veckogenererarpanel): an outlined full-width 48 dp button over a top
/// hairline, with the note on what cancelling keeps under it. Outlined,
/// because the view's one saffron action is Generera (Komponentark
/// v1:843-844).
class VeckomenyPlanningCancelFooter extends StatelessWidget {
  const VeckomenyPlanningCancelFooter({super.key, required this.onCancel});

  final VoidCallback onCancel;

  static const Key buttonKey = ValueKey<String>('veckomeny-planning-cancel');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: AppDimensions.spacingMd),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            key: buttonKey,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppDimensions.minTouchTarget),
            ),
            onPressed: onCancel,
            child: Text(l.weekMenuPlanningCancel),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            l.weekMenuPlanningCancelNote,
            textAlign: TextAlign.center,
            // text.secondary in both modes (onSurfaceVariant).
            style: AppTextStyles.captionBase.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
