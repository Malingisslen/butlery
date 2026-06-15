import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// BUT-948: contextual bulk-action bar for multi-select lists — a close button,
/// a "{n} selected" label, and a delete action. Used at the bottom of a screen
/// (Scaffold.bottomNavigationBar or a Stack) while selection mode is active.
class SelectionBulkBar extends StatelessWidget {
  const SelectionBulkBar({
    super.key,
    required this.count,
    required this.label,
    required this.onClose,
    required this.onDelete,
  });

  /// Number of selected items (the delete action is disabled when zero).
  final int count;

  /// Localized "{n} selected" label.
  final String label;

  final VoidCallback onClose;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.commonCancel,
                color: cs.onPrimaryContainer,
                onPressed: onClose,
              ),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.titleSmall
                      .copyWith(color: cs.onPrimaryContainer),
                ),
              ),
              TextButton.icon(
                onPressed: count == 0 ? null : onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onPrimaryContainer,
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(context.l10n.commonDelete),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
